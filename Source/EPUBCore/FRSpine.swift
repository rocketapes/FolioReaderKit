//
//  FRSpine.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 06/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

struct Spine {
    var resource: FRResource

    init(resource: FRResource) {
        self.resource = resource
    }
}

class FRSpine: NSObject {
    var pageProgressionDirection: String?
    var spineReferences = [Spine]()

    var isRtl: Bool {
        if let pageProgressionDirection = pageProgressionDirection , pageProgressionDirection == "rtl" {
            return true
        }
        return false
    }

    func nextChapter(_ href: String) -> FRResource? {
        spineReferences.first { $0.resource.href == href }?.resource
    }
}
