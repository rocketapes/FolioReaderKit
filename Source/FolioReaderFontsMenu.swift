//
//  FolioReaderFontsMenu.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 27/08/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import Foundation

public enum CommonJSResult {
    case ok
    case error(String)
    case unknown(String?)
    
    static func from(jsReturn value: String?) -> CommonJSResult {
        guard let value = value else { return .unknown(nil) }
        if value == "ok" { return .ok }
        if value.hasPrefix("error:") { return .error(String(value.dropFirst(6))) }
        return .unknown(value)
    }
}

// MARK: - Logging
private let fontsMenuLogger = FolioLogger(category: .fontsMenu)

public enum FolioReaderFont: Int {
    case andada = 0
    case lato
    case lora
    case raleway

    public static func folioReaderFont(fontName: String) -> FolioReaderFont? {
        var font: FolioReaderFont?
        switch fontName {
        case "andada": font = .andada
        case "lato": font = .lato
        case "lora": font = .lora
        case "raleway": font = .raleway
        default: break
        }
        return font
    }

    public var cssIdentifier: String {
        switch self {
        case .andada: return "andada"
        case .lato: return "lato"
        case .lora: return "lora"
        case .raleway: return "raleway"
        }
    }
    
    public var name: String {
        switch self {
        case .andada: return "andada"
        case .lato: return "lato"
        case .lora: return "lora"
        case .raleway: return "raleway"
        }
    }
}

public enum FolioReaderFontSize: Int {
    case xs = 0
    case s
    case m
    case l
    case xl

    public static func folioReaderFontSize(fontSizeStringRepresentation: String) -> FolioReaderFontSize? {
        var fontSize: FolioReaderFontSize?
        switch fontSizeStringRepresentation {
        case "textSizeOne": fontSize = .xs
        case "textSizeTwo": fontSize = .s
        case "textSizeThree": fontSize = .m
        case "textSizeFour": fontSize = .l
        case "textSizeFive": fontSize = .xl
        default: break
        }
        return fontSize
    }

    public var cssIdentifier: String {
        switch self {
        case .xs: return "textSizeOne"
        case .s: return "textSizeTwo"
        case .m: return "textSizeThree"
        case .l: return "textSizeFour"
        case .xl: return "textSizeFive"
        }
    }
}

class FolioReaderFontsMenu: UIViewController, SMSegmentViewDelegate, UIGestureRecognizerDelegate {
    var menuView: UIView!

    fileprivate var readerConfig: FolioReaderConfig
    fileprivate var folioReader: FolioReader
    
    // Track pending operations to prevent race conditions
    private var pendingOperations = 0
    private let operationQueue = DispatchQueue(label: "com.folioreader.fontmenu", qos: .userInteractive)
    
    // Store the pending font size value for debouncing
    private var pendingFontSizeValue: Int?
    private var fontSizeDebounceTimer: Timer?

    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        self.readerConfig = readerConfig
        self.folioReader = folioReader

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.backgroundColor = UIColor.clear

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(FolioReaderFontsMenu.closeFontMenuTapGesture))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    
        

        // Menu view
        let visibleHeight: CGFloat = self.readerConfig.canChangeScrollDirection ? 222 : 170
        let bottomInset = view.safeAreaInsets.bottom
        menuView = UIView(frame: CGRect(x: 0, y: view.frame.height-visibleHeight-bottomInset, width: view.frame.width, height: view.frame.height))
        menuView.backgroundColor = self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white)
        menuView.autoresizingMask = .flexibleWidth
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 6
        menuView.layer.shadowPath = UIBezierPath(rect: menuView.bounds).cgPath
        menuView.layer.rasterizationScale = UIScreen.main.scale
        menuView.layer.shouldRasterize = true
        view.addSubview(menuView)
        
        // Accessibility -> needs menuView
//        setupCloseButtonAccessibility()

        let normalColor = UIColor(white: 0.5, alpha: 0.7)
        let selectedColor = self.readerConfig.tintColor
        let sun = UIImage(readerImageNamed: "icon-sun")
        let moon = UIImage(readerImageNamed: "icon-moon")
        let fontSmall = UIImage(readerImageNamed: "icon-font-small")
        let fontBig = UIImage(readerImageNamed: "icon-font-big")

        let sunNormal = sun?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let moonNormal = moon?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let fontSmallNormal = fontSmall?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let fontBigNormal = fontBig?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)

        let sunSelected = sun?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
        let moonSelected = moon?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)

        // Day night mode
        let dayNight = SMSegmentView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 55),
                                     separatorColour: self.readerConfig.nightModeSeparatorColor,
                                     separatorWidth: 1,
                                     segmentProperties:  [
                                        keySegmentTitleFont: UIFont(name: "Avenir-Light", size: 17)!,
                                        keySegmentOnSelectionColour: UIColor.clear,
                                        keySegmentOffSelectionColour: UIColor.clear,
                                        keySegmentOnSelectionTextColour: selectedColor,
                                        keySegmentOffSelectionTextColour: normalColor,
                                        keyContentVerticalMargin: 17 as AnyObject
            ])
        dayNight.delegate = self
        dayNight.tag = 1
        dayNight.addSegmentWithTitle(self.readerConfig.localizedFontMenuDay, onSelectionImage: sunSelected, offSelectionImage: sunNormal)
        dayNight.addSegmentWithTitle(self.readerConfig.localizedFontMenuNight, onSelectionImage: moonSelected, offSelectionImage: moonNormal)
        dayNight.selectSegmentAtIndex(self.folioReader.nightMode.intValue)
        menuView.addSubview(dayNight)


        // Separator
        let line = UIView(frame: CGRect(x: 0, y: dayNight.frame.height+dayNight.frame.origin.y, width: view.frame.width, height: 1))
        line.backgroundColor = self.readerConfig.nightModeSeparatorColor
        menuView.addSubview(line)

        // Fonts adjust
        let fontName = SMSegmentView(frame: CGRect(x: 15, y: line.frame.height+line.frame.origin.y, width: view.frame.width-30, height: 55),
                                     separatorColour: UIColor.clear,
                                     separatorWidth: 0,
                                     segmentProperties:  [
                                        keySegmentOnSelectionColour: UIColor.clear,
                                        keySegmentOffSelectionColour: UIColor.clear,
                                        keySegmentOnSelectionTextColour: selectedColor,
                                        keySegmentOffSelectionTextColour: normalColor,
                                        keyContentVerticalMargin: 17 as AnyObject
            ])
        fontName.delegate = self
        fontName.tag = 2

        fontName.addSegmentWithTitle("Andada", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Lato", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Lora", onSelectionImage: nil, offSelectionImage: nil)
        fontName.addSegmentWithTitle("Raleway", onSelectionImage: nil, offSelectionImage: nil)

        fontName.segments[0].titleFont = UIFont(name: "Andada-Regular", size: 18) ?? .systemFont(ofSize: 18)
        fontName.segments[1].titleFont = UIFont(name: "Lato-Regular", size: 18) ?? .systemFont(ofSize: 18)
        fontName.segments[2].titleFont = UIFont(name: "Lora-Regular", size: 18) ?? .systemFont(ofSize: 18)
        fontName.segments[3].titleFont = UIFont(name: "Raleway-Regular", size: 18) ?? .systemFont(ofSize: 18)

        fontName.selectSegmentAtIndex(self.folioReader.currentFont.rawValue)
        menuView.addSubview(fontName)

        // Separator 2
        let line2 = UIView(frame: CGRect(x: 0, y: fontName.frame.height+fontName.frame.origin.y, width: view.frame.width, height: 1))
        line2.backgroundColor = self.readerConfig.nightModeSeparatorColor
        menuView.addSubview(line2)

        // Font slider size
        let slider = HADiscreteSlider(frame: CGRect(x: 60, y: line2.frame.origin.y+2, width: view.frame.width-120, height: 55))
        slider.tickStyle = ComponentStyle.rounded
        slider.tickCount = 5
        slider.tickSize = CGSize(width: 8, height: 8)

        slider.thumbStyle = ComponentStyle.rounded
        slider.thumbSize = CGSize(width: 28, height: 28)
        slider.thumbShadowOffset = CGSize(width: 0, height: 2)
        slider.thumbShadowRadius = 3
        slider.thumbColor = selectedColor

        slider.backgroundColor = UIColor.clear
        slider.tintColor = self.readerConfig.nightModeSeparatorColor
        slider.minimumValue = 0
        slider.value = CGFloat(self.folioReader.currentFontSize.rawValue)
        slider.addTarget(self, action: #selector(FolioReaderFontsMenu.sliderValueChanged(_:)), for: UIControlEvents.valueChanged)

        // Force remove fill color
        slider.layer.sublayers?.forEach({ layer in
            layer.backgroundColor = UIColor.clear.cgColor
        })

        menuView.addSubview(slider)

        // Font icons
        let fontSmallView = UIImageView(frame: CGRect(x: 20, y: line2.frame.origin.y+14, width: 30, height: 30))
        fontSmallView.image = fontSmallNormal
        fontSmallView.contentMode = UIViewContentMode.center
        menuView.addSubview(fontSmallView)

        let fontBigView = UIImageView(frame: CGRect(x: view.frame.width-50, y: line2.frame.origin.y+14, width: 30, height: 30))
        fontBigView.image = fontBigNormal
        fontBigView.contentMode = UIViewContentMode.center
        menuView.addSubview(fontBigView)

        // Only continues if user can change scroll direction
        guard (self.readerConfig.canChangeScrollDirection == true) else {
            return
        }

        // Separator 3
        let line3 = UIView(frame: CGRect(x: 0, y: line2.frame.origin.y+56, width: view.frame.width, height: 1))
        line3.backgroundColor = self.readerConfig.nightModeSeparatorColor
        menuView.addSubview(line3)

        let vertical = UIImage(readerImageNamed: "icon-menu-vertical")
        let horizontal = UIImage(readerImageNamed: "icon-menu-horizontal")
        let verticalNormal = vertical?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let horizontalNormal = horizontal?.imageTintColor(normalColor)?.withRenderingMode(.alwaysOriginal)
        let verticalSelected = vertical?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)
        let horizontalSelected = horizontal?.imageTintColor(selectedColor)?.withRenderingMode(.alwaysOriginal)

        // Layout direction
        let layoutDirection = SMSegmentView(frame: CGRect(x: 0, y: line3.frame.origin.y, width: view.frame.width, height: 55),
                                            separatorColour: self.readerConfig.nightModeSeparatorColor,
                                            separatorWidth: 1,
                                            segmentProperties:  [
                                                keySegmentTitleFont: UIFont(name: "Avenir-Light", size: 17)!,
                                                keySegmentOnSelectionColour: UIColor.clear,
                                                keySegmentOffSelectionColour: UIColor.clear,
                                                keySegmentOnSelectionTextColour: selectedColor,
                                                keySegmentOffSelectionTextColour: normalColor,
                                                keyContentVerticalMargin: 17 as AnyObject
            ])
        layoutDirection.delegate = self
        layoutDirection.tag = 3
        layoutDirection.addSegmentWithTitle(self.readerConfig.localizedLayoutVertical, onSelectionImage: verticalSelected, offSelectionImage: verticalNormal)
        layoutDirection.addSegmentWithTitle(self.readerConfig.localizedLayoutHorizontal, onSelectionImage: horizontalSelected, offSelectionImage: horizontalNormal)

        var scrollDirection = FolioReaderScrollDirection(rawValue: self.folioReader.currentScrollDirection)

        if scrollDirection == .defaultVertical && self.readerConfig.scrollDirection != .defaultVertical {
            scrollDirection = self.readerConfig.scrollDirection
        }

        switch scrollDirection ?? .vertical {
        case .vertical, .defaultVertical:
            layoutDirection.selectSegmentAtIndex(FolioReaderScrollDirection.vertical.rawValue)
        case .horizontal, .horizontalWithVerticalContent:
            layoutDirection.selectSegmentAtIndex(FolioReaderScrollDirection.horizontal.rawValue)
        }
        menuView.addSubview(layoutDirection)
    }
    
    // MARK: Accessibility
    
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyInputEscape, modifierFlags: [], action: #selector(closeFontMenuTapGesture))
        ]
    }

    func setupCloseButtonAccessibility() {
        
        guard menuView != nil else {
            fontsMenuLogger.error("menuView is nil!")
            return
        }
        
        let closeButton = UIButton(type: .system)
        closeButton.isAccessibilityElement = true
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        closeButton.addTarget(self, action: #selector(closeFontMenuTapGesture), for: .touchUpInside)
        closeButton.accessibilityLabel = NSLocalizedString("close_font_menu", comment: "Close font menu")

        let blueColor = UIColor(red: 12/255.0, green: 88/255.0, blue: 165/255.0, alpha: 1.0) // #0C58A5
        closeButton.backgroundColor = UIColor.white
        closeButton.setTitleColor(blueColor, for: .normal)
        closeButton.setTitleColor(blueColor.withAlphaComponent(0.7), for: .highlighted)

        closeButton.layer.cornerRadius = 18
        closeButton.layer.borderWidth = 2
        closeButton.layer.borderColor = blueColor.cgColor

        closeButton.layer.shadowColor = UIColor.black.cgColor
        closeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        closeButton.layer.shadowOpacity = 0.4
        closeButton.layer.shadowRadius = 4

        closeButton.frame = CGRect(x: view.frame.width - 55, y: menuView.frame.origin.y + 10, width: 36, height: 36)
        closeButton.autoresizingMask = .flexibleLeftMargin
        view.addSubview(closeButton)
    }

    // MARK: - SMSegmentView delegate

    func segmentView(_ segmentView: SMSegmentView, didSelectSegmentAtIndex index: Int) {
        guard (self.folioReader.readerCenter?.currentPage) != nil else { return }

        if segmentView.tag == 1 {
            // Night mode change - synchronous UI update with async WebView updates
            let newNightMode = (index == 1)
            guard newNightMode != self.folioReader.nightMode else { return }
            
            applyNightModeChange(newNightMode)

        } else if segmentView.tag == 2 {
            // Font change
            guard let newFont = FolioReaderFont(rawValue: index),
            newFont != self.folioReader.currentFont else { return }
            
            applyFontChange(newFont)

        } else if segmentView.tag == 3 {
            // Scroll direction change
            guard self.folioReader.currentScrollDirection != index else { return }
            applyScrollDirectionChange(index)
        }
    }
    
    // MARK: - Robust Change Application
    
    private func applyNightModeChange(_ nightMode: Bool) {
        // Update state first
        self.folioReader.nightMode = nightMode
        
        // Update menu background immediately (synchronous)
        UIView.animate(withDuration: 0.6) {
            self.menuView.backgroundColor = self.folioReader.isNight(
            self.readerConfig.nightModeMenuBackground, UIColor.white
            )
        }
        
        // Queue WebView updates for all visible pages
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateAllVisiblePages { page in
                    page.webView?.js("nightMode(\(nightMode))") { result in
                        switch CommonJSResult.from(jsReturn: result) {
                        case .ok:
                            print("Night Mode changed.")
                            break
                        case .error(let message):
                            print("Night Mode JS error: \(message)")
                        case .unknown(let returnValue):
                            print("Font size JS returned unknown value: \(String(describing: returnValue))")
                        }
                    }
                }
            }
        }
    }
    
    private func applyFontChange(_ font: FolioReaderFont) {
        // Update state
        self.folioReader.currentFont = font
        
        // Queue WebView updates
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateAllVisiblePages { page in
                    page.webView?.js("setFontName('\(font.cssIdentifier)')") { result in
                        switch CommonJSResult.from(jsReturn: result) {
                        case .ok:
                            print("Font changed on page \(page.pageNumber ?? 0)")
                            break
                        case .error(let message):
                            print("Font Change JS error for page \(page.pageNumber ?? 0): \(message)")
                        case .unknown(let returnValue):
                            print("Font Change JS returned unknown value for page \(page.pageNumber ?? 0): \(String(describing: returnValue))")
                        }
                    }
                }
            }
        }
    }
    
    private func applyScrollDirectionChange(_ direction: Int) {
        self.folioReader.currentScrollDirection = direction
        // Info: setScrollDirection handles the full reload internally
        // Info: We could apply the result handling etc. here, too.
    }
    
    /// Update all visible pages in the collection view, not just currentPage
    private func updateAllVisiblePages(_ updateBlock: @escaping (FolioReaderPage) -> Void) {
        guard let readerCenter = self.folioReader.readerCenter else { return }
        
        let visibleCells = readerCenter.collectionView.visibleCells
        
        for case let page as FolioReaderPage in visibleCells {
            // Only update if WebView is loaded and ready
            guard let webView = page.webView,
                  !webView.isLoading else {
                print("Skipping page \(page.pageNumber ?? 0) - WebView not ready.")
                continue
            }
            
            updateBlock(page)
        }
        
        // Also trigger UI refresh for page indicators etc.
        readerCenter.pageIndicatorView?.reloadColors()
        readerCenter.scrollScrubber?.reloadColors()
        NotificationCenter.default.post(name: Notification.Name(rawValue: "needRefreshPageMode"), object: nil)
    }
    
    // MARK: - Font slider changed
    
    @objc func sliderValueChanged(_ sender: HADiscreteSlider) {
        let fontSizeValue = Int(sender.value)
        
        // Store the pending value
        pendingFontSizeValue = fontSizeValue
        
        // Cancel any existing timer
        fontSizeDebounceTimer?.invalidate()
        
        // Create a new timer to apply the change after a delay
        fontSizeDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.applyPendingFontSizeChange()
        }
    }
    
    private func applyPendingFontSizeChange() {
        guard let fontSizeValue = pendingFontSizeValue,
              let fontSize = FolioReaderFontSize(rawValue: fontSizeValue),
              fontSize != self.folioReader.currentFontSize else {
            return
        }
        
        // Clear the pending value
        pendingFontSizeValue = nil
        
        // Update state
        self.folioReader.currentFontSize = fontSize
        
        // Queue WebView updates
        operationQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateAllVisiblePages { page in
                    page.webView?.js("setFontSize('\(fontSize.cssIdentifier)')") { result in
                        switch CommonJSResult.from(jsReturn: result) {
                        case .ok:
                            print("Font size changed on page \(page.pageNumber ?? 0)")
                            break
                        case .error(let message):
                            print("Font size JS error for page \(page.pageNumber ?? 0): \(message)")
                        case .unknown(let returnValue):
                            print("Font size JS returned unknown value for page \(page.pageNumber ?? 0): \(String(describing: returnValue))")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Gestures
    
    @objc func closeFontMenuTapGesture() {
        // Cancel any pending font size changes
        fontSizeDebounceTimer?.invalidate()
        fontSizeDebounceTimer = nil
        
        dismiss()
        
        if (self.readerConfig.shouldHideNavigationOnTap == false) {
            self.folioReader.readerCenter?.showBars()
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer && touch.view == view {
            return true
        }
        return false
    }
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden : Bool {
        return false
    }
}

