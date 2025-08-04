//
//  DiscreteSlider.swift
//  FolioReaderKit
//
//  Created by Samuel Ullrich on 04.08.25.
//  Copyright © 2025 FolioReader. All rights reserved.
//
class DiscreteSlider: UISlider {
    var onKeyboardStep: ((Int) -> Void)?
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .leftArrow || press.type == .rightArrow {
                let currentValue = Int(self.value.rounded())
                let newValue: Int
                
                if press.type == .rightArrow {
                    newValue = min(currentValue + 1, 4)
                } else {
                    newValue = max(currentValue - 1, 0)
                }
                
                self.setValue(Float(newValue), animated: false)
                onKeyboardStep?(newValue)
        
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
    
    override func accessibilityIncrement() {
        let newValue = min(Int(value) + 1, 4)
        setValue(Float(newValue), animated: true)
        onKeyboardStep?(newValue)
    }

    override func accessibilityDecrement() {
        let newValue = max(Int(value) - 1, 0)
        setValue(Float(newValue), animated: true)
        onKeyboardStep?(newValue)
    }
}
