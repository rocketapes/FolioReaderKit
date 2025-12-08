//
//  FolioLogger.swift
//  FolioReaderKit
//
//  Structured logging system using Apple's unified logging (OSLog)
//  Provides categorized logging with proper log levels for filtering and debugging
//

import Foundation
import OSLog

/// Log categories for different domains within FolioReaderKit
public enum FolioLogCategory {
    // MARK: - Core
    case readerKit         // general reader operations
    case lifecycle         // reader open/close/state

    // MARK: - Content
    case epubParser        // epub parsing and validation
    case contentLoading    // html/resource loading
    case pagination        // page calculations

    // MARK: - Reading State
    case lastRead          // last read position tracking
    case highlights        // highlight operations
    case annotations       // annotation operations

    // MARK: - Navigation
    case navigation        // page navigation
    case tableOfContents   // toc operations
    case search            // search functionality

    // MARK: - Media
    case audio             // audio playback
    case media             // images, videos

    // MARK: - UI
    case webView           // webview operations
    case fontsMenu         // font/theme customization
    case gestures          // touch/gesture handling

    // MARK: - Storage
    case database          // realm operations
    case fileSystem        // file operations

    var rawValue: String {
        switch self {
        case .readerKit: return "SDK.ReaderKit"
        case .lifecycle: return "SDK.ReaderKit.Lifecycle"
        case .epubParser: return "SDK.EPUB.Parser"
        case .contentLoading: return "SDK.Content.Loading"
        case .pagination: return "SDK.Pagination"
        case .lastRead: return "SDK.LastRead"
        case .highlights: return "SDK.Highlights"
        case .annotations: return "SDK.Annotations"
        case .navigation: return "SDK.Navigation"
        case .tableOfContents: return "SDK.TableOfContents"
        case .search: return "SDK.Search"
        case .audio: return "SDK.Audio"
        case .media: return "SDK.Media"
        case .webView: return "SDK.WebView"
        case .fontsMenu: return "SDK.FontsMenu"
        case .gestures: return "SDK.Gestures"
        case .database: return "SDK.Database"
        case .fileSystem: return "SDK.FileSystem"
        }
    }
}

/// Structured logger wrapper around os.Logger
/// Usage:
///   let logger = FolioLogger(category: .lastRead)
///   logger.info("saveReaderState() called")
public struct FolioLogger {
    private let osLogger: Logger
    private let categoryName: String

    public init(category: FolioLogCategory) {
        self.categoryName = category.rawValue
        self.osLogger = Logger(
            subsystem: "com.folioreader.kit",
            category: category.rawValue
        )
    }

    // MARK: - Log Levels

    /// Debug-level logging for development details and verbose information
    /// Example: detailed position data, scroll offsets, js callbacks
    public func debug(_ message: String) {
        self.osLogger.debug("[\(self.categoryName)] \(message)")
    }

    /// Info-level logging for normal operational events
    /// Example: reader opened, page navigation, highlight created
    public func info(_ message: String) {
        self.osLogger.info("[\(self.categoryName)] \(message)")
    }

    /// Notice-level logging for important but normal events
    /// Example: state saved successfully, epub parsed, resources loaded
    public func notice(_ message: String) {
        self.osLogger.notice("[\(self.categoryName)] \(message)")
    }

    /// Warning-level logging for recoverable issues
    /// Example: could not parse rangy (fallback used), missing resources
    public func warning(_ message: String) {
        self.osLogger.warning("[\(self.categoryName)] \(message)")
    }

    /// Error-level logging for failed operations requiring attention
    /// Example: failed to save state, realm write error, invalid epub structure
    public func error(_ message: String) {
        self.osLogger.error("[\(self.categoryName)] \(message)")
    }

    /// Fault-level logging for critical errors
    /// Example: database corruption, critical reader state failure
    public func fault(_ message: String) {
        self.osLogger.fault("[\(self.categoryName)] \(message)")
    }
}
