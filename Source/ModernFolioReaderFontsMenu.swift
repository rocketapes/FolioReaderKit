import UIKit

class ModernFolioReaderFontsMenu: UIViewController {
    
    
    private var menuView: UIView!
    private var dayNightSegmentedControl: UISegmentedControl!
    private var fontFamilyButtons: [UIButton] = []
    private var fontSizeSlider: DiscreteSlider!
    private var layoutDirectionSegmentedControl: UISegmentedControl!
    private var closeButton: UIButton!
    
    private let readerConfig: FolioReaderConfig
    private let folioReader: FolioReader
    
    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        self.readerConfig = readerConfig
        self.folioReader = folioReader
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupMenuView()
        setupCloseButton()
        setupDayNightControl()
        setupFontFamilyButtons()
        setupFontSizeSlider()
        if readerConfig.canChangeScrollDirection {
            setupLayoutDirectionControl()
        }
        setupAccessibility()
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Notify accessibility that the screen has changed
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, menuView)
        
        // For keyboard navigation
        DispatchQueue.main.async {
            self.setNeedsFocusUpdate()
            self.updateFocusIfNeeded()
        }
        
        // Enable key commands
        becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }
    
    private func setupView() {
        view.backgroundColor = UIColor.clear
        
        // Background tap gesture (only on clear background)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupMenuView() {
        let visibleHeight: CGFloat = readerConfig.canChangeScrollDirection ? 280 : 220
        
        menuView = UIView()
        menuView.translatesAutoresizingMaskIntoConstraints = false
        menuView.backgroundColor = folioReader.isNight(readerConfig.nightModeMenuBackground, UIColor.white)
        menuView.layer.cornerRadius = 12
        menuView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        menuView.layer.shadowColor = UIColor.black.cgColor
        menuView.layer.shadowOffset = CGSize(width: 0, height: -2)
        menuView.layer.shadowOpacity = 0.15
        menuView.layer.shadowRadius = 8
        
        view.addSubview(menuView)
        
        NSLayoutConstraint.activate([
            menuView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menuView.heightAnchor.constraint(equalToConstant: visibleHeight)
        ])
    }
    
    private func setupCloseButton() {
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        // Styling
        let blueColor = UIColor(red: 12/255.0, green: 88/255.0, blue: 165/255.0, alpha: 1.0)
        closeButton.backgroundColor = UIColor.white
        closeButton.setTitleColor(blueColor, for: .normal)
        closeButton.setTitleColor(blueColor.withAlphaComponent(0.7), for: .highlighted)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.borderWidth = 2
        closeButton.layer.borderColor = blueColor.cgColor
        
        // Accessibility
        closeButton.isAccessibilityElement = true
        closeButton.accessibilityLabel = NSLocalizedString("close_font_menu", comment: "close font menu")
        closeButton.accessibilityTraits = UIAccessibilityTraitButton
        
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: menuView.topAnchor, constant: 15),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    private func setupDayNightControl() {
        dayNightSegmentedControl = UISegmentedControl(items: [
            NSLocalizedString("day_button", comment: "Day or bright mode"),
            NSLocalizedString("night_button", comment: "dark/night mode")
        ])
        
        dayNightSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        dayNightSegmentedControl.selectedSegmentIndex = folioReader.nightMode ? 1 : 0
        dayNightSegmentedControl.addTarget(self, action: #selector(dayNightChanged), for: .valueChanged)
        
        // Styling
        dayNightSegmentedControl.backgroundColor = UIColor.clear
        dayNightSegmentedControl.tintColor = readerConfig.tintColor
        dayNightSegmentedControl.setTitleTextAttributes([
            NSAttributedStringKey.foregroundColor: folioReader.isNight(UIColor.white, UIColor.darkGray)
        ], for: .normal)
        dayNightSegmentedControl.setTitleTextAttributes([
            NSAttributedStringKey.foregroundColor: UIColor(red: 12/255.0, green: 88/255.0, blue: 165/255.0, alpha: 1.0)  // #0C58A5
        ], for: .selected)
        
        // Accessibility
        dayNightSegmentedControl.isAccessibilityElement = true
        dayNightSegmentedControl.accessibilityLabel = NSLocalizedString("darkmode_on_off", comment: "This segment control handles the day/night mode")
        
        menuView.addSubview(dayNightSegmentedControl)
        
        NSLayoutConstraint.activate([
            dayNightSegmentedControl.topAnchor.constraint(equalTo: menuView.topAnchor, constant: 20),
            dayNightSegmentedControl.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 20),
            dayNightSegmentedControl.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -20),
            dayNightSegmentedControl.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupFontFamilyButtons() {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        
        let fontNames = ["Andada", "Lato", "Lora", "Raleway"]
        let fontFamilies = ["Andada-Regular", "Lato-Regular", "Lora-Regular", "Raleway-Regular"]
        
        for (index, fontName) in fontNames.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(fontName, for: .normal)
            button.titleLabel?.font = UIFont(name: fontFamilies[index], size: 16) ?? UIFont.systemFont(ofSize: 16)
            button.tag = index
            button.addTarget(self, action: #selector(fontFamilyChanged(_:)), for: .touchUpInside)
            
            // Styling
            button.setTitleColor(folioReader.isNight(UIColor.lightGray, UIColor.darkGray), for: .normal)
            button.setTitleColor(readerConfig.tintColor, for: .selected)
            button.backgroundColor = UIColor.clear
            
            // Accessibility
            button.isAccessibilityElement = true
            button.accessibilityLabel =  String(format: NSLocalizedString("which_font", comment: "which font is selected"),fontName)
            button.accessibilityTraits = UIAccessibilityTraitButton
            button.accessibilityHint = NSLocalizedString("font_accessibility_hint", comment: "description of the font family button")
            
            fontFamilyButtons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        // Set initial selection
        updateFontFamilySelection()
        
        menuView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: dayNightSegmentedControl.bottomAnchor, constant: 30),
            stackView.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -20),
            stackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupFontSizeSlider() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Small font icon (left) touchable?
        let smallFontLabel = UILabel()
        smallFontLabel.translatesAutoresizingMaskIntoConstraints = false
        smallFontLabel.text = "Aa"
        smallFontLabel.font = UIFont.systemFont(ofSize: 14)
        smallFontLabel.textColor = folioReader.isNight(UIColor.lightGray, UIColor.gray)
        smallFontLabel.textAlignment = .center
        smallFontLabel.isAccessibilityElement = true
        smallFontLabel.accessibilityLabel = NSLocalizedString("Small font size", comment: "")
        smallFontLabel.accessibilityTraits = UIAccessibilityTraitStaticText
        
        // Large font icon (right) touchable?
        let largeFontLabel = UILabel()
        largeFontLabel.translatesAutoresizingMaskIntoConstraints = false
        largeFontLabel.text = "Aa"
        largeFontLabel.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        largeFontLabel.textColor = folioReader.isNight(UIColor.lightGray, UIColor.gray)
        largeFontLabel.textAlignment = .center
        largeFontLabel.isAccessibilityElement = true
        largeFontLabel.accessibilityLabel = NSLocalizedString("Large font size", comment: "")
        largeFontLabel.accessibilityTraits = UIAccessibilityTraitStaticText
        
        // Font size slider
        fontSizeSlider = DiscreteSlider()
        fontSizeSlider.accessibilityTraits = UIAccessibilityTraitAdjustable
        fontSizeSlider.translatesAutoresizingMaskIntoConstraints = false
        fontSizeSlider.minimumValue = 0
        fontSizeSlider.maximumValue = 4
        fontSizeSlider.value = Float(folioReader.currentFontSize.rawValue)
        fontSizeSlider.addTarget(self, action: #selector(fontSizeSliderMoved), for: .valueChanged)
        
        fontSizeSlider.onDiscreteStep = { [weak self] newValue in
            guard let self = self, let fontSize = FolioReaderFontSize(rawValue: newValue) else { return }
            self.folioReader.currentFontSize = fontSize
            print("VoiceOver/Keyboard changed font to: \(fontSize)")
        }
        
        // Styling
        fontSizeSlider.thumbTintColor = readerConfig.tintColor
        fontSizeSlider.minimumTrackTintColor = readerConfig.tintColor
        fontSizeSlider.maximumTrackTintColor = folioReader.isNight(UIColor.darkGray, UIColor.lightGray)
        
        // Accessibility
        fontSizeSlider.isAccessibilityElement = true
        fontSizeSlider.accessibilityLabel = NSLocalizedString("font_size_adjustable", comment: "Adjust the font size")
        
        containerView.addSubview(smallFontLabel)
        containerView.addSubview(fontSizeSlider)
        containerView.addSubview(largeFontLabel)
        menuView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: fontFamilyButtons.first!.superview!.bottomAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -20),
            containerView.heightAnchor.constraint(equalToConstant: 44),
            
            smallFontLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            smallFontLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            smallFontLabel.widthAnchor.constraint(equalToConstant: 30),
            
            fontSizeSlider.leadingAnchor.constraint(equalTo: smallFontLabel.trailingAnchor, constant: 15),
            fontSizeSlider.trailingAnchor.constraint(equalTo: largeFontLabel.leadingAnchor, constant: -15),
            fontSizeSlider.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            largeFontLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            largeFontLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            largeFontLabel.widthAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupLayoutDirectionControl() {
        layoutDirectionSegmentedControl = UISegmentedControl(items: [
            NSLocalizedString("vertical_button", comment: "changes the layout scroll direction of the pages to vertical"),
            NSLocalizedString("horizontal_button", comment: "changes the layout scroll direction of the pages to horizontal")
        ])
        layoutDirectionSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Set current selection
        let currentDirection = FolioReaderScrollDirection(rawValue: folioReader.currentScrollDirection) ?? .defaultVertical
        switch currentDirection {
        case .vertical, .defaultVertical:
            layoutDirectionSegmentedControl.selectedSegmentIndex = 0
        case .horizontal, .horizontalWithVerticalContent:
            layoutDirectionSegmentedControl.selectedSegmentIndex = 1
        }
        
        layoutDirectionSegmentedControl.addTarget(self, action: #selector(layoutDirectionChanged), for: .valueChanged)
        
        // Styling
        layoutDirectionSegmentedControl.backgroundColor = UIColor.clear
        layoutDirectionSegmentedControl.tintColor = readerConfig.tintColor
        layoutDirectionSegmentedControl.setTitleTextAttributes([
            NSAttributedStringKey.foregroundColor: folioReader.isNight(UIColor.white, UIColor.darkGray)
        ], for: .normal)
        layoutDirectionSegmentedControl.setTitleTextAttributes([
            NSAttributedStringKey.foregroundColor: UIColor(red: 12/255.0, green: 88/255.0, blue: 165/255.0, alpha: 1.0)  // #0C58A5
        ], for: .selected)
        
        menuView.addSubview(layoutDirectionSegmentedControl)
        
        NSLayoutConstraint.activate([
            layoutDirectionSegmentedControl.topAnchor.constraint(equalTo: fontSizeSlider.superview!.bottomAnchor, constant: 30),
            layoutDirectionSegmentedControl.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 20),
            layoutDirectionSegmentedControl.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -20),
            layoutDirectionSegmentedControl.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupAccessibility() {
        // Modal behavior - focus stays within menu
        view.accessibilityViewIsModal = true
        
        // Menu container
        menuView.isAccessibilityElement = false
        menuView.accessibilityLabel = NSLocalizedString("Font settings menu", comment: "")
    }
    
    @objc private func fontSizeSliderMoved() {
        // Snap to nearest discrete value immediately
        let discreteValue = round(fontSizeSlider.value)
        fontSizeSlider.setValue(discreteValue, animated: false)
        
        // Update font size
        let value = Int(discreteValue)
        guard let fontSize = FolioReaderFontSize(rawValue: value) else { return }
        folioReader.currentFontSize = fontSize
    }
    
    @objc private func closeButtonTapped() {
        dismiss()
    }
    
    @objc private func backgroundTapped() {
        dismiss()
    }
    
    @objc private func dayNightChanged() {
        let isNightMode = dayNightSegmentedControl.selectedSegmentIndex == 1
        folioReader.nightMode = isNightMode
        
        UIView.animate(withDuration: 0.3) {
            self.updateUI()
        }
    }
    
    @objc private func fontFamilyChanged(_ sender: UIButton) {
        guard let font = FolioReaderFont(rawValue: sender.tag) else { return }
        folioReader.currentFont = font
        updateFontFamilySelection()
    }
    
    @objc private func layoutDirectionChanged() {
        let newDirection = layoutDirectionSegmentedControl.selectedSegmentIndex
        folioReader.currentScrollDirection = newDirection
    }
    
    // MARK: - Helper Methods
    
    private func updateUI() {
        // Update menu background
        menuView.backgroundColor = folioReader.isNight(readerConfig.nightModeMenuBackground, UIColor.white)
        
        // Update segmented controls colors
        let normalColor = folioReader.isNight(UIColor.white, UIColor.darkGray)
        
        dayNightSegmentedControl.setTitleTextAttributes([NSAttributedStringKey.foregroundColor: normalColor], for: .normal)
        if let layoutControl = layoutDirectionSegmentedControl {
            layoutControl.setTitleTextAttributes([NSAttributedStringKey.foregroundColor: normalColor], for: .normal)
        }
        
        // Update font family buttons
        for button in fontFamilyButtons {
            button.setTitleColor(folioReader.isNight(UIColor.lightGray, UIColor.darkGray), for: .normal)
        }
        updateFontFamilySelection()
    }
    
    private func updateFontFamilySelection() {
        for (index, button) in fontFamilyButtons.enumerated() {
            let isSelected = index == folioReader.currentFont.rawValue
            button.setTitleColor(isSelected ? readerConfig.tintColor : folioReader.isNight(UIColor.lightGray, UIColor.darkGray), for: .normal)
            button.titleLabel?.font = button.titleLabel?.font.withSize(isSelected ? 18 : 16)
        }
    }
    
    override func dismiss() {
        DispatchQueue.main.async {
            self.dismiss(animated: true) {
                if !self.readerConfig.shouldHideNavigationOnTap {
                    self.folioReader.readerCenter?.showBars()
                }
            }
        }
    }
    
    override open var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyInputEscape, modifierFlags: [], action: #selector(closeButtonTapped))
        ]
    }
}

extension ModernFolioReaderFontsMenu: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only allow gesture on the clear background, not on menu or its subviews
        return touch.view == view
    }
}


