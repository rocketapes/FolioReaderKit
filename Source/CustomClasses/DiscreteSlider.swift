//
//  DiscreteSlider.swift
//  FolioReaderKit
//
//  Created by Samuel Ullrich on 04.08.25.
//  Copyright © 2025 FolioReader. All rights reserved.
//
class DiscreteSlider: UISlider {
    var onDiscreteStep: ((Int) -> Void)?
    
    override func accessibilityIncrement() {
        let newValue = min(Int(value) + 1, 4)
        setValue(Float(newValue), animated: true)
        onDiscreteStep?(newValue)
        
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, "Font size \(newValue + 1)")
    }

    override func accessibilityDecrement() {
        let newValue = max(Int(value) - 1, 0)
        setValue(Float(newValue), animated: true)
        onDiscreteStep?(newValue)
        
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, "Font size \(newValue + 1)")
    }
}
