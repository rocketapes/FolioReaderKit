//
//  LastReadSaveManager.swift
//  FolioReaderKit
//
//  Thread-safe manager for persisting reading position with debounce support.
//

import Foundation
import RealmSwift

// MARK: - LastReadSaveManager

/// Manages persistence of the user's last read position in an ebook.
///
/// This manager provides:
/// - **Debounced saves**: Rapid page changes are coalesced to avoid excessive writes
/// - **Thread safety**: Actor-based isolation ensures safe concurrent access
/// - **Coalescing**: Skips redundant saves when position hasn't changed
/// - **Immediate flush**: For critical moments like app close or backgrounding
///
/// ## Usage
/// ```swift
/// // On page change (debounced)
/// await LastReadSaveManager.shared.scheduleSave(state: state)
///
/// // On close (immediate with rangy)
/// await LastReadSaveManager.shared.flushWithRangy(freshState: state, rangy: rangyString)
///
/// // On book switch or close
/// await LastReadSaveManager.shared.reset()
/// ```
actor LastReadSaveManager {

    static let shared = LastReadSaveManager()

    // MARK: - Types

    /// Immutable snapshot of reading state, safe to pass between actors.
    struct StateSnapshot: Sendable {
        let bookId: Int
        let pageNumber: Int
        let filePath: String?
        let pageOffsetX: CGFloat
        let pageOffsetY: CGFloat
        let fontSize: Int
        let isVertical: Bool
        let isLandscape: Bool
        let subPage: Int
        let pageSize: String
        let timestamp: Date

        /// Unique key for coalescing - skips save if unchanged.
        var coalescingKey: String { "\(bookId):\(pageNumber):\(subPage)" }
    }

    // MARK: - Configuration

    private let debounceInterval: TimeInterval = 0.5
    private let lifecycleSaveTimeout: TimeInterval = 5.0

    // MARK: - State (automatically protected by actor)

    private var pendingState: StateSnapshot?
    private var debounceTask: Task<Void, Never>?
    private var lastPersistedKey: String = ""
    private var isLifecycleSaveInProgress: Bool = false
    private var lifecycleSaveStartTime: Date?

    private init() {}

    // MARK: - Public API

    /// Schedules a debounced save. Coalesces rapid page changes.
    /// - Parameter state: Current reading position to save.
    func scheduleSave(state: StateSnapshot) {
        guard state.coalescingKey != lastPersistedKey else { return }

        // Cancel previous debounce
        debounceTask?.cancel()
        pendingState = state

        // Schedule new debounced save
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }
            await self?.executeDebouncedSave()
        }
    }

    /// Executes the pending debounced save.
    private func executeDebouncedSave() async {
        guard let state = pendingState else { return }
        pendingState = nil
        lastPersistedKey = state.coalescingKey
        await persistToRealm(state: state, rangy: nil)
    }

    /// Immediately saves with pre-extracted rangy. Use on close/background (completion-based).
    /// - Parameters:
    ///   - freshState: New state to save, or nil to save pending state.
    ///   - rangy: Rangy string for precise position (extract before webView is deallocated).
    ///   - completion: Called on main thread after save.
    nonisolated func flushWithRangy(freshState: StateSnapshot?, rangy: String?, completion: (() -> Void)?) {
        Task {
            await flushWithRangy(freshState: freshState, rangy: rangy, isLifecycleSave: false)
            await MainActor.run { completion?() }
        }
    }

    /// Async version of flushWithRangy for cleaner async/await usage.
    /// Includes protection against concurrent lifecycle saves.
    /// - Parameters:
    ///   - freshState: New state to save, or nil to save pending state.
    ///   - rangy: Rangy string for precise position.
    ///   - isLifecycleSave: True for app lifecycle events (resign active, terminate).
    func flushWithRangy(freshState: StateSnapshot?, rangy: String?, isLifecycleSave: Bool = false) async {
        // For lifecycle saves, check and acquire lock if needed
        if isLifecycleSave {
            guard tryAcquireLifecycleSaveLock() else {
                print("[LastRead:SAVE] Lifecycle save already in progress, skipping")
                return
            }

            // Ensure lock is always released
            defer { releaseLifecycleSaveLock() }

            // Perform the save
            await performSave(freshState: freshState, rangy: rangy)
        } else {
            // Regular saves don't need lifecycle lock
            await performSave(freshState: freshState, rangy: rangy)
        }
    }

    // MARK: - Private Helpers

    /// Attempts to acquire the lifecycle save lock. Returns true if acquired, false if already locked.
    /// Automatically recovers from stuck saves (>5s timeout).
    private func tryAcquireLifecycleSaveLock() -> Bool {
        // Check if save is already in progress
        if isLifecycleSaveInProgress {
            // Check for stuck save (timeout recovery)
            if isLifecycleSaveStuck() {
                resetLifecycleSaveLock()
                print("[LastRead:SAVE] Recovered from stuck lifecycle save (>5s)")
                acquireLifecycleSaveLock()
                return true
            } else {
                // Valid save in progress, deny lock
                return false
            }
        } else {
            // No save in progress, acquire lock
            acquireLifecycleSaveLock()
            return true
        }
    }

    /// Checks if the current lifecycle save has exceeded the timeout threshold.
    private func isLifecycleSaveStuck() -> Bool {
        guard let startTime = lifecycleSaveStartTime else { return false }
        return Date().timeIntervalSince(startTime) > lifecycleSaveTimeout
    }

    /// Marks a lifecycle save as in-progress.
    private func acquireLifecycleSaveLock() {
        isLifecycleSaveInProgress = true
        lifecycleSaveStartTime = Date()
    }

    /// Releases the lifecycle save lock.
    private func releaseLifecycleSaveLock() {
        resetLifecycleSaveLock()
    }

    /// Resets lifecycle save state (must be called on stateQueue).
    private func resetLifecycleSaveLock() {
        isLifecycleSaveInProgress = false
        lifecycleSaveStartTime = nil
    }

    /// Performs the actual save operation.
    private func performSave(freshState: StateSnapshot?, rangy: String?) async {
        // Cancel any pending debounced save
        debounceTask?.cancel()
        debounceTask = nil

        let stateToSave = freshState ?? pendingState
        pendingState = nil

        guard let state = stateToSave else { return }

        lastPersistedKey = state.coalescingKey
        await persistToRealm(state: state, rangy: rangy)
    }

    /// Resets all state. Call on close or book switch.
    func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        pendingState = nil
        lastPersistedKey = ""
        isLifecycleSaveInProgress = false
        lifecycleSaveStartTime = nil
    }

    // MARK: - Private

    /// Persists state to Realm on a background thread.
    private func persistToRealm(state: StateSnapshot, rangy: String?) async {
        await Task.detached(priority: .utility) {
            do {
                let realm = try Realm()
                try realm.write {
                    let lastRead = FolioLastRead()
                    lastRead.bookId = state.bookId
                    lastRead.page = state.pageNumber
                    lastRead.position = rangy
                    lastRead.created = state.timestamp
                    lastRead.modified = state.timestamp
                    lastRead.filePath = state.filePath
                    lastRead.pageOffsetX = state.pageOffsetX
                    lastRead.pageOffsetY = state.pageOffsetY
                    lastRead.fontSize = state.fontSize
                    lastRead.isVertical = state.isVertical
                    lastRead.isLandscape = state.isLandscape
                    lastRead.subPage = state.subPage
                    lastRead.pageSize = state.pageSize
                    realm.add(lastRead, update: .all)
                }
                print("[LastRead:SAVE] page=\(state.pageNumber), subPage=\(state.subPage), rangy=\(rangy != nil)")
            } catch {
                print("[LastRead:SAVE] ERROR: \(error.localizedDescription)")
            }
        }.value
    }
}
