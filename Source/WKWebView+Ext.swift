//
//  UIWebView+Ext.swift
//  AEXML
//
//  Created by Dung Le on 10/20/18.
//

import Foundation
import WebKit

extension WKWebView {
    
    
    // MARK: - Java Script Bridge
    
    open func js(_ script: String, completion: @escaping JSCallback) {
        evaluateJavaScript(script) { (result, error) in
            completion(result as? String)
        }
    }
    
}
