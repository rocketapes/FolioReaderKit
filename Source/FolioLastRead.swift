//
//  RWLastRead.swift
//  ebook
//
//  Created by Christian Denker on 15.01.18.
//  Copyright © 2018 ZWEIDENKER GmbH. All rights reserved.
//

import Foundation
import RealmSwift

// MARK: - Logging
private let logger = FolioLogger(category: .lastRead)
private let databaseLogger = FolioLogger(category: .database)

class PageSize {
    var width: CGFloat
    var height: CGFloat
    
    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

open class FolioLastRead: Object {
    
    // MARK: Properties
    @objc open dynamic var bookId : Int = -1
    @objc open dynamic var accountId : Int = -1
    @objc open dynamic var filePath : String?
    @objc open dynamic var position : String?
    @objc open dynamic var created: Date?
    @objc open dynamic var modified: Date?
    @objc open dynamic var page: Int = 0
    @objc open dynamic var subPage: Int = 0
    @objc open dynamic var pageSize: String?
    @objc open dynamic var isSynced: Bool = false
    @objc open dynamic var pageOffsetX: CGFloat = 0
    @objc open dynamic var pageOffsetY: CGFloat = 0
    @objc open dynamic var isVertical: Bool = false
    @objc open dynamic var isLandscape: Bool = false
    @objc open dynamic var fontSize: Int = 2
    
    var pageSizeObject: PageSize? {
        guard let sizes = self.pageSize?.split(separator: "x"),
            sizes.count >= 2 else {
            return nil
        }
        let width = ( String.init(sizes[0]) as NSString).floatValue
        let height = ( String.init(sizes[1]) as NSString).floatValue
        return PageSize.init(width: CGFloat(width), height: CGFloat(height))
    }
    
    var rangyId: String? {
        guard let elements = position?.split(separator: "$"),
            elements.count > 2
        else {
            return nil
        }
        return String.init(elements[2])
    }
    
    override open class func primaryKey()-> String {
        return "bookId"
    }
}

extension FolioLastRead {
    public static func lastRead(from bookId: Int) -> FolioLastRead? {
        do {
            let realm = try Realm()
            let result = realm.object(ofType: FolioLastRead.self, forPrimaryKey: bookId)
            if let lastRead = result {
                logger.debug("lastRead(from:) found position for bookId=\(bookId): page=\(lastRead.page), subPage=\(lastRead.subPage), offsetX=\(lastRead.pageOffsetX), offsetY=\(lastRead.pageOffsetY), created=\(lastRead.created?.description ?? "nil")")
            } else {
                logger.debug("lastRead(from:) NO position found for bookId=\(bookId)")
            }
            return result
        } catch {
            databaseLogger.error("lastRead(from:) failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Remote Sync Support

    /// Result type for updateFromRemote operation
    public enum UpdateResult {
        case inserted           // no local data, remote was inserted
        case skippedLocalNewer  // local timestamp is newer, kept local
        case skippedSameData    // same page with local precision, kept local
        case merged             // same page, merged local offsets into remote
        case overwritten        // different page, remote overwrote local
        case error(String)      // operation failed
    }

    /// Update local data from remote source (server sync).
    /// This method handles merge logic to preserve local precision data (offsets, subPage)
    /// that the server doesn't store.
    ///
    /// Merge rules:
    /// - If no local data exists → insert remote
    /// - If local is newer (by timestamp) → skip, keep local
    /// - If same page and local has offsets but remote doesn't → skip, keep local (has more precision)
    /// - If same page → merge (keep local offsets, take remote timestamp/position)
    /// - If different page and remote is newer → overwrite (offsets are meaningless for different page)
    ///
    /// - Parameter remote: The FolioLastRead object from server
    /// - Returns: UpdateResult indicating what action was taken
    @discardableResult
    public static func updateFromRemote(_ remote: FolioLastRead) -> UpdateResult {
        do {
            let realm = try Realm()

            guard let local = realm.object(ofType: FolioLastRead.self, forPrimaryKey: remote.bookId) else {
                // no local data, just insert remote
                logger.info("updateFromRemote() INSERT: No local data for bookId=\(remote.bookId), inserting remote")
                try realm.write {
                    remote.isSynced = true
                    realm.add(remote, update: .all)
                }
                return .inserted
            }

            // compare timestamps
            let localCreated = local.created ?? Date.distantPast
            let remoteCreated = remote.created ?? Date.distantPast

            // if local is strictly newer, skip
            if localCreated > remoteCreated {
                logger.debug("updateFromRemote() SKIP: Local is newer for bookId=\(remote.bookId), local=\(localCreated), remote=\(remoteCreated)")
                return .skippedLocalNewer
            }

            // same page: check if local has precision that remote lacks
            if local.page == remote.page {
                let localHasOffset = local.pageOffsetX > 0 || local.pageOffsetY > 0 || local.subPage > 0
                let remoteHasOffset = remote.pageOffsetX > 0 || remote.pageOffsetY > 0 || remote.subPage > 0

                if localHasOffset && !remoteHasOffset {
                    // local has precision, remote doesn't - this is likely our own data bouncing back
                    // optionally update rangy position if remote has it
                    logger.debug("updateFromRemote() SKIP: Local has precision for bookId=\(remote.bookId), keeping local offsets")

                    try realm.write {
                        // take rangy position from remote if we don't have one
                        if let remotePosition = remote.position, !remotePosition.isEmpty,
                           (local.position == nil || local.position?.isEmpty == true) {
                            local.position = remotePosition
                            logger.debug("updateFromRemote() Updated rangy position from remote")
                        }
                        local.isSynced = true
                    }
                    return .skippedSameData
                }

                // same page, merge: keep local offsets, take remote metadata
                logger.info("updateFromRemote() MERGE: Same page for bookId=\(remote.bookId), merging data")
                try realm.write {
                    local.position = remote.position ?? local.position
                    local.created = remote.created ?? local.created
                    local.modified = remote.modified ?? local.modified
                    local.accountId = remote.accountId
                    // keep local offsets (server doesn't have these)
                    // pageOffsetX, pageOffsetY, subPage, fontSize, isVertical, isLandscape stay as-is
                    local.isSynced = true
                }
                return .merged
            }

            // different page and remote is newer (or equal) → overwrite
            // offsets from a different page are meaningless
            logger.info("updateFromRemote() OVERWRITE: Different page for bookId=\(remote.bookId), local.page=\(local.page), remote.page=\(remote.page)")
            try realm.write {
                remote.isSynced = true
                realm.add(remote, update: .all)
            }
            return .overwritten

        } catch {
            databaseLogger.error("updateFromRemote() failed: \(error.localizedDescription)")
            return .error(error.localizedDescription)
        }
    }
}
