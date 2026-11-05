//
//  FolioReaderHighlightPalette.swift
//  FolioReaderKit
//
//  Highlight colour picker shown instead of the UIMenuController colour items on iOS 26+.
//  The liquid glass edit menu renders embedded images monochrome, so the colours are drawn
//  as plain views here (RHE-455).
//

import UIKit

@available(iOS 26, *)
final class FolioReaderHighlightPalette: UIView {
    private static let swatchSize: CGFloat = 30
    private static let spacing: CGFloat = 10
    private static let padding: CGFloat = 8

    private let onSelect: (HighlightStyle) -> Void

    init(onSelect: @escaping (HighlightStyle) -> Void) {
        self.onSelect = onSelect
        let styles: [HighlightStyle] = [.yellow, .green, .blue, .pink, .underline]
        let count = CGFloat(styles.count)
        let width = count * Self.swatchSize + (count - 1) * Self.spacing + 2 * Self.padding
        let height = Self.swatchSize + 2 * Self.padding
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: height))

        let glass = UIVisualEffectView(effect: UIGlassEffect())
        glass.frame = bounds
        glass.layer.cornerRadius = height / 2
        glass.clipsToBounds = true
        addSubview(glass)

        let stack = UIStackView(arrangedSubviews: styles.map(swatch(for:)))
        stack.axis = .horizontal
        stack.spacing = Self.spacing
        stack.distribution = .fillEqually
        stack.frame = bounds.insetBy(dx: Self.padding, dy: Self.padding)
        glass.contentView.addSubview(stack)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func swatch(for style: HighlightStyle) -> UIButton {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: Self.swatchSize, height: Self.swatchSize)
        button.layer.cornerRadius = Self.swatchSize / 2
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        button.tag = style.rawValue
        button.addTarget(self, action: #selector(swatchTapped(_:)), for: .touchUpInside)
        if style == .underline {
            button.backgroundColor = .clear
            button.setImage(UIImage(systemName: "underline", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
            button.tintColor = .label
        } else {
            button.backgroundColor = Self.color(for: style)
        }
        return button
    }

    @objc private func swatchTapped(_ sender: UIButton) {
        guard let style = HighlightStyle(rawValue: sender.tag) else { return }
        onSelect(style)
    }

    /// matches the highlight classes in Style.css
    private static func color(for style: HighlightStyle) -> UIColor {
        switch style {
        case .yellow: return UIColor(red: 255 / 255, green: 235 / 255, blue: 107 / 255, alpha: 1)
        case .green: return UIColor(red: 192 / 255, green: 237 / 255, blue: 114 / 255, alpha: 1)
        case .blue: return UIColor(red: 173 / 255, green: 216 / 255, blue: 255 / 255, alpha: 1)
        case .pink: return UIColor(red: 255 / 255, green: 176 / 255, blue: 202 / 255, alpha: 1)
        case .underline: return .clear
        }
    }

    /// places the palette above `rect` (in `container` coordinates), clamped to the container bounds
    func show(above rect: CGRect, in container: UIView) {
        let margin: CGFloat = 8
        var x = rect.midX - bounds.width / 2
        x = min(max(x, margin), container.bounds.width - bounds.width - margin)
        var y = rect.minY - bounds.height - margin
        if y < margin {
            y = rect.maxY + margin
        }
        frame.origin = CGPoint(x: x, y: y)
        alpha = 0
        container.addSubview(self)
        UIView.animate(withDuration: 0.15) { self.alpha = 1 }
    }
}
