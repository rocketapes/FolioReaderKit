//
//  FolioReaderKit.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift

// MARK: - Internal constants

internal let kApplicationDocumentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
internal let kCurrentFontFamily = "com.folioreader.kCurrentFontFamily"
internal let kCurrentFontSize = "com.folioreader.kCurrentFontSize"
internal let kCurrentAudioRate = "com.folioreader.kCurrentAudioRate"
internal let kCurrentHighlightStyle = "com.folioreader.kCurrentHighlightStyle"
internal let kCurrentMediaOverlayStyle = "com.folioreader.kMediaOverlayStyle"
internal let kCurrentScrollDirection = "com.folioreader.kCurrentScrollDirection"
internal let kNightMode = "com.folioreader.kNightMode"
internal let kCurrentTOCMenu = "com.folioreader.kCurrentTOCMenu"
internal let kHighlightRange = 30
internal let kReuseCellIdentifier = "com.folioreader.Cell.ReuseIdentifier"

public enum FolioReaderError: Error, LocalizedError {
    case bookNotAvailable
    case errorInContainer
    case errorInOpf
    case authorNameNotAvailable
    case coverNotAvailable
    case invalidImage(path: String)
    case titleNotAvailable
    case fullPathEmpty

    public var errorDescription: String? {
        switch self {
        case .bookNotAvailable:
            return "Book not found"
        case .errorInContainer, .errorInOpf:
            return "Invalid book format"
        case .authorNameNotAvailable:
            return "Author name not available"
        case .coverNotAvailable:
            return "Cover image not available"
        case let .invalidImage(path):
            return "Invalid image at path: " + path
        case .titleNotAvailable:
            return "Book title not available"
        case .fullPathEmpty:
            return "Book corrupted"
        }
    }
}

/// Defines the media overlay and TTS selection
///
/// - `default`: The background is colored
/// - underline: The underlined is colored
/// - textColor: The text is colored
public enum MediaOverlayStyle: Int {
    case `default`
    case underline
    case textColor

    init() {
        self = .default
    }

    func className() -> String {
        return "mediaOverlayStyle\(self.rawValue)"
    }
}

/// FolioReader actions delegate
@objc public protocol FolioReaderDelegate: class {
    
    /// Did finished loading book.
    ///
    /// - Parameters:
    ///   - folioReader: The FolioReader instance
    ///   - book: The Book instance
    @objc optional func folioReader(_ folioReader: FolioReader, didFinishedLoading book: FRBook)
    
    /// Called when reader did closed.
    ///
    /// - Parameter folioReader: The FolioReader instance
    @objc optional func folioReaderDidClose(_ folioReader: FolioReader)
    
    /// Called when reader did closed.
    @available(*, deprecated, message: "Use 'folioReaderDidClose(_ folioReader: FolioReader)' instead.")
    @objc optional func folioReaderDidClosed()
    
    @objc optional func folioReaderDidChangeNightMode(_ folioReader: FolioReader, nightMode: Bool)
    @objc optional func folioReaderDidChangeFont(_ folioReader: FolioReader, font: String)
    @objc optional func folioReaderDidChangeFontSize(_ folioReader: FolioReader, fontSize: Int)
    @objc optional func folioReaderDidChangeScrollDirection(_ folioReader: FolioReader, isVertical: Bool)
}

/// Main Library class with some useful constants and methods
open class FolioReader: NSObject {

    public override init() { }

    deinit {
        removeObservers()
    }

    /// Custom unzip path
    open var unzipPath: String?

    /// FolioReaderDelegate
    open weak var delegate: FolioReaderDelegate?
    
    open weak var readerContainer: FolioReaderContainer?
    open weak var readerAudioPlayer: FolioReaderAudioPlayer?
    open weak var readerCenter: FolioReaderCenter? {
        return self.readerContainer?.centerViewController
    }

    /// Check if reader is open
    open var isReaderOpen = false

    /// Check if reader is open and ready
    open var isReaderReady = false

    /// Check if layout needs to change to fit Right To Left
    open var needsRTLChange: Bool {
        return (self.readerContainer?.book.spine.isRtl == true && self.readerContainer?.readerConfig.scrollDirection == .horizontal)
    }

    func isNight<T>(_ f: T, _ l: T) -> T {
        return (self.nightMode == true ? f : l)
    }

    /// UserDefault for the current ePub file.
    fileprivate var defaults: FolioReaderUserDefaults {
        return FolioReaderUserDefaults(withIdentifier: self.readerContainer?.readerConfig.identifier)
    }

    // Add necessary observers
    fileprivate func addObservers() {
        removeObservers()
        print("[LastRead:OBSERVERS] Adding observers for instance \(Unmanaged.passUnretained(self).toOpaque())")
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillResignActive), name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppWillTerminate), name: .UIApplicationWillTerminate, object: nil)
    }

    /// Remove necessary observers
    fileprivate func removeObservers() {
        print("[LastRead:OBSERVERS] Removing observers for instance \(Unmanaged.passUnretained(self).toOpaque())")
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillTerminate, object: nil)
    }

    /// Handle app will resign active - flush pending save immediately (fast, no rangy)
    /// App may come back, so we just need the page position saved
    @objc private func handleAppWillResignActive() {
        print("[LastRead:APP] App will resign active (instance \(Unmanaged.passUnretained(self).toOpaque()))")
        let freshState = captureStateSnapshot()
        Task {
            // Manager will handle duplicate prevention with isLifecycleSave=true
            await LastReadSaveManager.shared.flushWithRangy(
                freshState: freshState,
                rangy: nil,
                isLifecycleSave: true
            )
        }
    }

    /// Handle app will terminate - extract rangy first, then flush
    /// Note: UIApplicationWillTerminate gives very limited time (~5s), so we try rangy but may timeout
    @objc private func handleAppWillTerminate() {
        print("[LastRead:APP] App will terminate (instance \(Unmanaged.passUnretained(self).toOpaque()))")
        let freshState = captureStateSnapshot()
        Task { [weak self] in
            let rangy = await self?.extractRangy()
            // Manager will handle duplicate prevention with isLifecycleSave=true
            await LastReadSaveManager.shared.flushWithRangy(
                freshState: freshState,
                rangy: rangy,
                isLifecycleSave: true
            )
        }
    }
}

// MARK: - Present FolioReader

extension FolioReader {

    /// Present a Folio Reader Container modally on a Parent View Controller.
    ///
    /// - Parameters:
    ///   - parentViewController: View Controller that will present the reader container.
    ///   - epubPath: String representing the path on the disk of the ePub file. Must not be nil nor empty string.
	///   - unzipPath: Path to unzip the compressed epub.
    ///   - config: FolioReader configuration.
    ///   - shouldRemoveEpub: Boolean to remove the epub or not. Default true.
    ///   - animated: Pass true to animate the presentation; otherwise, pass false.
    public func presentReader(parentViewController: UIViewController, rwBook: FolioRWBook?, withEpubPath epubPath: String, unzipPath: String? = nil, andConfig config: FolioReaderConfig, shouldRemoveEpub: Bool = true, animated:
        Bool = true) -> FolioReaderContainer {
        let readerContainer = FolioReaderContainer(withConfig: config, rwBook: rwBook, folioReader: self, epubPath: epubPath, unzipPath: unzipPath, removeEpub: shouldRemoveEpub)
        self.readerContainer = readerContainer
        readerContainer.modalPresentationStyle = .fullScreen
        parentViewController.present(readerContainer, animated: animated, completion: nil)
        addObservers()
        return readerContainer
    }

}

// MARK: -  Getters and setters for stored values

extension FolioReader {

    public func register(defaults: [String: Any]) {
        self.defaults.register(defaults: defaults)
    }

    /// Check if current theme is Night mode
    open var nightMode: Bool {
        get { return self.defaults.bool(forKey: kNightMode) }
        set (value) {
            if value != self.nightMode {
                self.delegate?.folioReaderDidChangeNightMode?(self, nightMode: value)
            }
            self.defaults.set(value, forKey: kNightMode)

            if let readerCenter = self.readerCenter {
                UIView.animate(withDuration: 0.6, animations: {
                    // Update all visible pages, not just current page
                    for case let cell as FolioReaderPage in readerCenter.collectionView.visibleCells {
                        cell.webView?.js("nightMode(\(self.nightMode))") { _ in }
                    }

                    readerCenter.pageIndicatorView?.reloadColors()
                    readerCenter.configureNavBar()
                    readerCenter.scrollScrubber?.reloadColors()
                    readerCenter.collectionView.backgroundColor = (self.nightMode == true ? self.readerContainer?.readerConfig.nightModeBackground : UIColor.white)
                }, completion: { (finished: Bool) in
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "needRefreshPageMode"), object: nil)
                })
            }
        }
    }

    /// Check current font name. Default .andada
    open var currentFont: FolioReaderFont {
        get {
            guard
                let rawValue = self.defaults.value(forKey: kCurrentFontFamily) as? Int,
                let font = FolioReaderFont(rawValue: rawValue) else {
                    return .andada
            }

            return font
        }
        set (font) {
            if font != self.currentFont {
                self.delegate?.folioReaderDidChangeFont?(self, font: font.name)
            }
            self.defaults.set(font.rawValue, forKey: kCurrentFontFamily)

            // Update all visible pages, not just current page
            guard let readerCenter = self.readerCenter else { return }
            for case let cell as FolioReaderPage in readerCenter.collectionView.visibleCells {
                cell.webView?.js("setFontName('\(font.cssIdentifier)')")  { _ in }
            }
        }
    }

    /// Check current font size. Default .m
    open var currentFontSize: FolioReaderFontSize {
        get {
            guard
                let rawValue = self.defaults.value(forKey: kCurrentFontSize) as? Int,
                let size = FolioReaderFontSize(rawValue: rawValue) else {
                    return .m
            }

            return size
        }
        set (value) {
            if value != self.currentFontSize {
                self.delegate?.folioReaderDidChangeFontSize?(self, fontSize: value.rawValue)
            }
            self.defaults.set(value.rawValue, forKey: kCurrentFontSize)

            // Update all visible pages, not just current page
            guard let readerCenter = self.readerCenter else { return }
            for case let cell as FolioReaderPage in readerCenter.collectionView.visibleCells {
                cell.webView?.js("setFontSize('\(value.cssIdentifier)')")  { _ in }
            }
        }
    }

    /// Check current audio rate, the speed of speech voice. Default 0
    open var currentAudioRate: Int {
        get { return self.defaults.integer(forKey: kCurrentAudioRate) }
        set (value) {
            self.defaults.set(value, forKey: kCurrentAudioRate)
        }
    }

    /// Check the current highlight style.Default 0
    open var currentHighlightStyle: Int {
        get { return self.defaults.integer(forKey: kCurrentHighlightStyle) }
        set (value) {
            self.defaults.set(value, forKey: kCurrentHighlightStyle)
        }
    }

    /// Check the current Media Overlay or TTS style
    open var currentMediaOverlayStyle: MediaOverlayStyle {
        get {
            guard let rawValue = self.defaults.value(forKey: kCurrentMediaOverlayStyle) as? Int,
                let style = MediaOverlayStyle(rawValue: rawValue) else {
                return MediaOverlayStyle.default
            }
            return style
        }
        set (value) {
            self.defaults.set(value.rawValue, forKey: kCurrentMediaOverlayStyle)
        }
    }

    /// Check the current scroll direction. Default .defaultVertical
    open var currentScrollDirection: Int {
        get {
            guard let value = self.defaults.value(forKey: kCurrentScrollDirection) as? Int else {
                return FolioReaderScrollDirection.defaultVertical.rawValue
            }

            return value
        }
        set (value) {
            let direction = (FolioReaderScrollDirection(rawValue: value) ?? .defaultVertical)
            if value != self.currentScrollDirection {
                self.delegate?.folioReaderDidChangeScrollDirection?(self, isVertical: direction.isVertical)
            }
            self.defaults.set(value, forKey: kCurrentScrollDirection)

            self.readerCenter?.setScrollDirection(direction)
        }
    }

    open var currentMenuIndex: Int {
        get { return self.defaults.integer(forKey: kCurrentTOCMenu) }
        set (value) {
            self.defaults.set(value, forKey: kCurrentTOCMenu)
        }
    }

    open var savedPositionForCurrentBook: [String: Any]? {
        get {
            guard let bookId = self.readerContainer?.book.name else {
                return nil
            }
            return self.defaults.value(forKey: bookId) as? [String : Any]
        }
        set {
            guard let bookId = self.readerContainer?.book.name else {
                return
            }
            self.defaults.set(newValue, forKey: bookId)
        }
    }
}

// MARK: - Metadata

extension FolioReader {

    // TODO QUESTION: The static `getCoverImage` function used the shared instance before and ignored the `unzipPath` parameter.
    // Should we properly implement the parameter (what has been done now) or should change the API to only use the current FolioReader instance?

    /**
     Read Cover Image and Return an `UIImage`
     */
    open class func getCoverImage(_ epubPath: String, unzipPath: String? = nil) throws -> UIImage {
        return try FREpubParser().parseCoverImage(epubPath, unzipPath: unzipPath)
    }

    open class func getTitle(_ epubPath: String, unzipPath: String? = nil) throws -> String {
        return try FREpubParser().parseTitle(epubPath, unzipPath: unzipPath)
    }

    open class func getAuthorName(_ epubPath: String, unzipPath: String? = nil) throws-> String {
        return try FREpubParser().parseAuthorName(epubPath, unzipPath: unzipPath)
    }
}

// MARK: - Exit, save and close FolioReader

extension FolioReader {

    /// Capture current UI state snapshot (must be called on main thread)
    fileprivate func captureStateSnapshot() -> LastReadSaveManager.StateSnapshot? {
        assert(Thread.isMainThread, "captureStateSnapshot must be called on main thread")

        guard isReaderOpen,
              let currentPage = self.readerCenter?.currentPage,
              let webView = currentPage.webView,
              let bookId = self.readerCenter?.rwBook?.id,
              let currentPageNumber = self.readerCenter?.currentPageNumber,
              let isVertical = self.readerContainer?.readerConfig.scrollDirection.isVertical
        else { return nil }

        let pageNumber = max(currentPageNumber - 1, 0)
        let offsetX = webView.scrollView.contentOffset.x
        let offsetY = webView.scrollView.contentOffset.y
        let subPage = isVertical
            ? Int(offsetY / UIScreen.main.bounds.size.height)
            : Int(offsetX / UIScreen.main.bounds.size.width)

        return LastReadSaveManager.StateSnapshot(
            bookId: bookId,
            pageNumber: pageNumber,
            filePath: currentPage.resource?.href,
            pageOffsetX: offsetX,
            pageOffsetY: offsetY,
            fontSize: self.currentFontSize.rawValue,
            isVertical: isVertical,
            isLandscape: UIDevice.current.orientation.isLandscape,
            subPage: subPage,
            pageSize: "\(Int(UIScreen.main.bounds.size.width))x\(Int(UIScreen.main.bounds.size.height))",
            timestamp: Date()
        )
    }

    /// Extract rangy position via JavaScript (async/await)
    fileprivate func extractRangy() async -> String? {
        guard let webView = self.readerCenter?.currentPage?.webView else {
            return nil
        }

        let height = UIScreen.main.bounds.height - 75

        return await withCheckedContinuation { continuation in
            var completed = false

            // Timeout after 2 seconds to prevent hanging
            let timeoutWorkItem = DispatchWorkItem {
                if !completed {
                    completed = true
                    print("[LastRead:RANGY] Extraction timed out after 2s")
                    continuation.resume(returning: nil)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeoutWorkItem)

            webView.js("createSelectionFromPoint(0, 1, 250, \(height))") { _ in
                webView.js("getHighlightSerialization('last-read')") { result in
                    guard !completed else { return }
                    completed = true
                    timeoutWorkItem.cancel()

                    var rangy: String?
                    if let data = result?.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? NSArray,
                       let dict = json?.firstObject as? [String: String],
                       let rangyStr = dict["rangy"] {
                        rangy = FolioUtils.makeRangyValidIfNeeded(rangy: Highlight.typeTextContentWithLine + rangyStr)
                    }
                    continuation.resume(returning: rangy)
                }
            }
        }
    }

    // MARK: - Public API

    /// Update reading position with debounced save.
    /// Call on every page change (scroll end, navigation, etc.)
    open func updateCurrentState() {
        guard let state = captureStateSnapshot() else { return }
        Task {
            await LastReadSaveManager.shared.scheduleSave(state: state)
        }
    }

    /// Save Reader state. Use isClosingSave=true when closing to include rangy.
    @objc open func saveReaderState(isClosingSave: Bool = false) {
        if isClosingSave {
            // For closing save, use Task to await rangy extraction
            let freshState = captureStateSnapshot()
            Task {
                let rangy = await extractRangy()
                await LastReadSaveManager.shared.flushWithRangy(
                    freshState: freshState,
                    rangy: rangy
                )
            }
        } else {
            updateCurrentState()
        }
    }

    /// Legacy method - kept for API compatibility
    open func markPreNavigationSave() {}

    /// Legacy method - kept for API compatibility
    open func clearPreNavigationSave() {}

    /// Closes and saves the reader current instance.
    open func close() {
        print("[LastRead:CLOSE] Closing reader...")

        // Capture state while UI is still valid
        let freshState = captureStateSnapshot()

        // Use Task to properly sequence: extract rangy → save → teardown
        Task { [weak self] in
            // Extract rangy (handles nil webView)
            let rangy = await self?.extractRangy()

            // Save to Realm and wait for completion
            await LastReadSaveManager.shared.flushWithRangy(
                freshState: freshState,
                rangy: rangy
            )

            // Now safe to teardown - save is complete
            await MainActor.run {
                self?.performTeardown()
            }
        }
    }

    /// Clean up reader state after close
    private func performTeardown() {
        removeObservers()  // Clean up notification observers
        Task {
            await LastReadSaveManager.shared.reset()
        }
        isReaderOpen = false
        isReaderReady = false
        readerAudioPlayer?.stop(immediate: true)
        defaults.set(0, forKey: kCurrentTOCMenu)
        delegate?.folioReaderDidClose?(self)
        print("[LastRead:CLOSE] Reader closed")
    }
}

extension Realm {
    func writeAsync<T : ThreadConfined>(obj: T, errorHandler: @escaping ((_ error : Swift.Error) -> Void) = { _ in return }, block: @escaping ((Realm, T?) -> Void)) {
        let wrappedObj = ThreadSafeReference(to: obj)
        let config = self.configuration
        DispatchQueue(label: "folio.queue.background").async {
            autoreleasepool {
                do {
                    let realm = try Realm(configuration: config)
                    let obj = realm.resolve(wrappedObj)
                    
                    try realm.write {
                        block(realm, obj)
                    }
                }
                catch {
                    errorHandler(error)
                }
            }
        }
    }
}
