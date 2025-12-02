//
//  ScrollScrubber.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 7/14/16.
//  Copyright © 2016 FolioReader. All rights reserved.
//

import UIKit

func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

enum ScrollType: Int {
    case page
    // `chapter` is only for the collection view if vertical with horizontal content is used
    case chapter
}

enum ScrollDirection: Int {
    case none
    case right
    case left
    case up
    case down

    init() {
        self = .none
    }
}

class ScrollScrubber: NSObject, UIScrollViewDelegate {
    weak var delegate: FolioReaderCenter?
    var showSpeed = 0.6
    var hideSpeed = 0.6
    var hideDelay = 3.0

    var visible = false
    var usingSlider = false
    var slider: UISlider!
    var hideTimer: Timer!
    var scrollStart: CGFloat!
    var scrollDelta: CGFloat!
    var scrollDeltaTimer: Timer!

    fileprivate weak var readerContainer: FolioReaderContainer?

    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }

    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }

    var frame: CGRect {
        didSet {
            self.slider.frame = frame
        }
    }

    init(frame:CGRect, withReaderContainer readerContainer: FolioReaderContainer) {
        self.frame = frame
        self.readerContainer = readerContainer

        super.init()

        slider = UISlider()
        slider.layer.anchorPoint = CGPoint(x: 0, y: 0)
        slider.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
        slider.alpha = 0
        self.reloadColors()

        // less obtrusive knob and fixes jump: http://stackoverflow.com/a/22301039/484780
        let thumbImg = UIImage(readerImageNamed: "knob")
        let thumbImgColor = thumbImg?.imageTintColor(readerConfig.tintColor)?.withRenderingMode(.alwaysOriginal)
        slider.setThumbImage(thumbImgColor, for: UIControlState())
        slider.setThumbImage(thumbImgColor, for: .selected)
        slider.setThumbImage(thumbImgColor, for: .highlighted)

        slider.addTarget(self, action: #selector(ScrollScrubber.sliderChange(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchDown(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpOutside)
    }

    func reloadColors() {
        slider.minimumTrackTintColor = readerConfig.tintColor
        slider.maximumTrackTintColor = folioReader.isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
    }

    // MARK: - slider events

    @objc func sliderTouchDown(_ slider:UISlider) {
        usingSlider = true
        show()
    }

    @objc func sliderTouchUp(_ slider:UISlider) {
        usingSlider = false
        hideAfterDelay()
    }

    @objc func sliderChange(_ slider:UISlider) {
        guard let readerCenter = delegate else {
            return
        }

        let totalChapters = readerCenter.totalPages
        guard totalChapters > 0 else {
            return
        }

        let targetChapter = max(1, min(totalChapters, Int(round(slider.value * Float(totalChapters))) + 1))
        readerCenter.changePageWith(page: targetChapter, animated: false)
    }

    // MARK: - show / hide

    func show() {
        cancelHide()

        visible = true

        if slider.alpha <= 0 {
            UIView.animate(withDuration: showSpeed, animations: {

                self.slider.alpha = 1

            }, completion: { (Bool) -> Void in
                self.hideAfterDelay()
            })
        } else {
            slider.alpha = 1
            if usingSlider == false {
                hideAfterDelay()
            }
        }
    }


    @objc func hide() {
        visible = false
        resetScrollDelta()
        UIView.animate(withDuration: hideSpeed, animations: {
            self.slider.alpha = 0
        })
    }

    func hideAfterDelay() {
        cancelHide()
        hideTimer = Timer.scheduledTimer(timeInterval: hideDelay, target: self, selector: #selector(ScrollScrubber.hide), userInfo: nil, repeats: false)
    }

    func cancelHide() {

        if hideTimer != nil {
            hideTimer.invalidate()
            hideTimer = nil
        }

        if visible == false {
            slider.layer.removeAllAnimations()
        }

        visible = true
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }

        if scrollStart == nil {
            scrollStart = scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard (readerConfig.scrollDirection == .vertical ||
            readerConfig.scrollDirection == .defaultVertical ||
            readerConfig.scrollDirection == .horizontalWithVerticalContent) else {
                return
        }

        // Show the scrubber on any scroll
        if !visible || slider.alpha < 1 {
            show()
        }

        // Don't update slider during scroll - wait until scrolling ends
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resetScrollDelta()

        // Update slider position when scrolling has finished (only for collectionView = chapter changes)
        if scrollView is UICollectionView && !usingSlider {
            setSliderVal()
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollDeltaTimer = Timer(timeInterval:0.5, target: self, selector: #selector(ScrollScrubber.resetScrollDelta), userInfo: nil, repeats: false)
        RunLoop.current.add(scrollDeltaTimer, forMode: RunLoopMode.commonModes)

        // Update slider position when programmatic scrolling has finished (like from scrubbing)
        if scrollView is UICollectionView && !usingSlider {
            setSliderVal()
        }
    }

    @objc func resetScrollDelta() {
        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }

        scrollStart = (scrollView()?.contentOffset.forDirection(withConfiguration: readerConfig) ?? 0)
        scrollDelta = 0
    }

    func setSliderVal() {
        guard let readerCenter = delegate else {
            slider.value = 0
            return
        }

        let totalChapters = readerCenter.totalPages
        guard totalChapters > 0 else {
            slider.value = 0
            return
        }

        let currentChapter = readerCenter.currentPageNumber
        slider.value = Float(currentChapter - 1) / Float(totalChapters)
    }

    // MARK: - utility methods

    fileprivate func scrollView() -> UIScrollView? {
        return delegate?.currentPage?.webView?.scrollView
    }

    fileprivate func height() -> CGFloat {
        guard let currentPage = delegate?.currentPage,
            let pageHeight = folioReader.readerCenter?.pageHeight,
            let webView = currentPage.webView else {
                return 0
        }

        return max(0, webView.scrollView.contentSize.height - pageHeight)
    }
    
    fileprivate func scrollTop() -> CGFloat {
        guard let currentPage = delegate?.currentPage, let webView = currentPage.webView else {
            return 0
        }
        return webView.scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
    }
}
