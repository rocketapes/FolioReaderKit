//
//  RWLastRead.swift
//  ebook
//
//  Created by Christian Denker on 15.01.18.
//  Copyright © 2018 ZWEIDENKER GmbH. All rights reserved.
//

import Foundation
import RealmSwift

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
        guard let pos = position, !pos.isEmpty else {
            print("[LastRead:RANGY] rangyId extraction failed - position is nil or empty")
            return nil
        }

        // Try iOS format first: uses $ separator (e.g., "type:textContent$...$selectionBoundary_123$...")
        let dollarElements = pos.split(separator: "$")
        if dollarElements.count > 2 {
            let rangyId = String(dollarElements[2])
            print("[LastRead:RANGY] rangyId extracted (iOS format): \(rangyId)")
            return rangyId
        }

        // Try Android format: uses | separator (e.g., "type:textContent|de.rheinwerk.ebook...")
        // Android format doesn't contain a usable rangyId - it's just metadata
        let pipeElements = pos.split(separator: "|")
        if pipeElements.count >= 2 {
            print("[LastRead:RANGY] Android format detected - no usable rangyId (position='\(pos)')")
            // Android format doesn't have a rangyId we can use for scrollTo()
            return nil
        }

        print("[LastRead:RANGY] rangyId extraction failed - unknown format (position='\(pos)', $count=\(dollarElements.count), |count=\(pipeElements.count))")
        return nil
    }
    
    override open class func primaryKey()-> String {
        return "bookId"
    }
}

extension FolioLastRead {
    public static func lastRead(from bookId: Int) -> FolioLastRead? {
        do {
            let realm = try Realm()
            return realm.object(ofType: FolioLastRead.self, forPrimaryKey: bookId)
        } catch {
            return nil
        }
    }
}
