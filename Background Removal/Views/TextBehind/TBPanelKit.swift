//
//  TBPanelKit.swift
//  Background Removal
//
//  Building blocks for the Text Behind tool panels: the panel shell (✕ title ✓ with a
//  scrolling content stack), slider rows, switch rows, chip strips, colour strips with
//  presets / recents / custom picker / hex input, and a gradient editor.
//

import UIKit

enum TBStyle {
    static let accent = UIColor(named: "AccentColor") ?? .systemBlue
    static let text = UIColor(named: "PrimaryText") ?? .label
    static let secondary = UIColor(named: "SecondaryText") ?? .secondaryLabel
    static let surface = UIColor(named: "Surface Color") ?? .systemBackground
    static let field = UIColor(named: "Ultra Light Blue") ?? .secondarySystemBackground
    static let border = UIColor(named: "Border Color") ?? .separator

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Figtree-Bold"
        case .semibold: name = "Figtree-SemiBold"
        case .medium: name = "Figtree-Medium"
        default: name = "Figtree-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func label(_ text: String, size: CGFloat = 14, weight: UIFont.Weight = .semibold,
                      color: UIColor = TBStyle.text) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font(size, weight)
        label.textColor = color
        label.adjustsFontForContentSizeCategory = false
        return label
    }

    static func button(_ title: String, symbol: String? = nil, filled: Bool = false) -> UIButton {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.cornerStyle = .capsule
        config.baseBackgroundColor = filled ? accent : field
        config.baseForegroundColor = filled ? .white : text
        if let symbol {
            config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
            config.imagePadding = 5
        }
        var attributes = AttributeContainer()
        attributes.font = font(13, .semibold)
        config.attributedTitle = AttributedString(title, attributes: attributes)
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 12, bottom: 7, trailing: 12)
        let button = UIButton(configuration: config)
        return button
    }

    static func segmented(_ titles: [String]) -> UISegmentedControl {
        let control = UISegmentedControl(items: titles)
        control.applyEditorStyle()
        control.selectedSegmentIndex = 0
        control.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return control
    }

    static func hStack(_ views: [UIView], spacing: CGFloat = 8, distribution: UIStackView.Distribution = .fill) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = spacing
        stack.alignment = .center
        stack.distribution = distribution
        return stack
    }

    static func vStack(_ views: [UIView], spacing: CGFloat = 10) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = spacing
        return stack
    }
}

// MARK: - Panel shell

/// Bottom panel with a ✕ / title / ✓ header and scrolling content.
class TBPanelView: UIView {

    let titleLabel = TBStyle.label("", size: 17, weight: .bold)
    let cancelButton = UIButton(type: .system)
    let applyButton = UIButton(type: .system)
    let scrollView = UIScrollView()
    /// Arranged content of the panel.
    let content = UIStackView()
    /// Height the editor gives this panel (it shrinks on small screens / with the keyboard).
    var preferredHeight: CGFloat { 300 }

    var onCancel: (() -> Void)?
    var onApply: (() -> Void)?

    weak var host: TBPanelHost?
    var session: TBEditorSession? { host?.session }

    init(title: String, host: TBPanelHost) {
        self.host = host
        super.init(frame: .zero)
        titleLabel.text = title
        setupShell()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupShell() {
        backgroundColor = TBStyle.surface
        layer.cornerRadius = 28
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: -4)

        cancelButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)), for: .normal)
        cancelButton.tintColor = TBStyle.text
        cancelButton.backgroundColor = TBStyle.field
        cancelButton.layer.cornerRadius = 18
        cancelButton.accessibilityLabel = "Cancel changes"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        applyButton.setImage(UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)), for: .normal)
        applyButton.tintColor = .white
        applyButton.backgroundColor = TBStyle.accent
        applyButton.layer.cornerRadius = 18
        applyButton.accessibilityLabel = "Done"
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        titleLabel.textAlignment = .center

        content.axis = .vertical
        content.spacing = 12
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.keyboardDismissMode = .interactive

        [cancelButton, applyButton, titleLabel, scrollView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            cancelButton.widthAnchor.constraint(equalToConstant: 36),
            cancelButton.heightAnchor.constraint(equalToConstant: 36),
            applyButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            applyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            applyButton.widthAnchor.constraint(equalToConstant: 36),
            applyButton.heightAnchor.constraint(equalToConstant: 36),
            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: cancelButton.trailingAnchor, constant: 8),
            scrollView.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 2),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    @objc private func cancelTapped() {
        endEditing(true)
        onCancel?()
    }

    @objc private func applyTapped() {
        endEditing(true)
        onApply?()
    }

    /// Called by the editor when the document changed from outside (undo, canvas gestures).
    func refresh() {}
}

// MARK: - Rows

/// Title, value and slider. Reports live changes and the final value on release.
final class TBSliderRow: UIView {
    let slider = UISlider()
    private let valueLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let format: (Float) -> String
    var onChange: ((Float, _ finished: Bool) -> Void)?

    init(_ title: String, min: Float, max: Float, format: @escaping (Float) -> String = { "\(Int($0.rounded()))" }) {
        self.format = format
        super.init(frame: .zero)
        let titleLabel = TBStyle.label(title, size: 13)
        slider.minimumValue = min
        slider.maximumValue = max
        slider.minimumTrackTintColor = TBStyle.accent
        slider.maximumTrackTintColor = TBStyle.border
        slider.accessibilityLabel = title
        slider.addTarget(self, action: #selector(changed), for: .valueChanged)
        slider.addTarget(self, action: #selector(finished), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        valueLabel.textAlignment = .right
        let header = TBStyle.hStack([titleLabel, UIView(), valueLabel])
        let stack = TBStyle.vStack([header, slider], spacing: 2)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var value: Float {
        get { slider.value }
        set {
            slider.value = newValue
            valueLabel.text = format(newValue)
        }
    }

    @objc private func changed() {
        valueLabel.text = format(slider.value)
        onChange?(slider.value, false)
    }

    @objc private func finished() {
        onChange?(slider.value, true)
    }
}

/// Title and a switch.
final class TBSwitchRow: UIView {
    let toggle = UISwitch()
    var onChange: ((Bool) -> Void)?

    init(_ title: String) {
        super.init(frame: .zero)
        toggle.onTintColor = TBStyle.accent
        toggle.accessibilityLabel = title
        toggle.addTarget(self, action: #selector(changed), for: .valueChanged)
        let stack = TBStyle.hStack([TBStyle.label(title, size: 14), UIView(), toggle])
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func changed() { onChange?(toggle.isOn) }
}

/// Horizontally scrolling pill buttons. Single selection, or toggles when `multiSelect`.
final class TBChipStrip: UIView {
    private let stack = UIStackView()
    private(set) var buttons: [UIButton] = []
    var onSelect: ((Int) -> Void)?
    private let multiSelect: Bool

    init(_ titles: [String], multiSelect: Bool = false) {
        self.multiSelect = multiSelect
        super.init(frame: .zero)
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 8
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 34),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        setTitles(titles)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitles(_ titles: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = titles.enumerated().map { index, title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = TBStyle.font(13, .semibold)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 1
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            return button
        }
        setSelected([])
    }

    func setSelected(_ indices: Set<Int>) {
        for (index, button) in buttons.enumerated() {
            let selected = indices.contains(index)
            button.backgroundColor = selected ? TBStyle.accent : TBStyle.field
            button.setTitleColor(selected ? .white : TBStyle.text, for: .normal)
            button.layer.borderColor = (selected ? TBStyle.accent : TBStyle.border).cgColor
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        if !multiSelect { setSelected([sender.tag]) }
        onSelect?(sender.tag)
    }
}

/// Colour swatches: custom picker, recent colours, presets and a hex field.
final class TBColorStrip: UIView, UITextFieldDelegate {
    private let stack = UIStackView()
    private let hexField = UITextField()
    private var selectedHex: String?
    private let presets: [String]
    var onSelect: ((String) -> Void)?
    var onCustom: (() -> Void)?

    static let defaultPresets = ["FFFFFF", "000000", "D1D5DB", "4B5563", "EF4444", "F97316", "FACC15",
                                 "22C55E", "14B8A6", "1677FF", "8B5CF6", "EC4899", "FBDCC4", "1E2A4A"]

    init(presets: [String] = TBColorStrip.defaultPresets, showsHexField: Bool = true) {
        self.presets = presets
        super.init(frame: .zero)
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        hexField.placeholder = "Hex  #RRGGBB"
        hexField.font = TBStyle.font(13, .medium)
        hexField.backgroundColor = TBStyle.field
        hexField.layer.cornerRadius = 10
        hexField.autocapitalizationType = .allCharacters
        hexField.autocorrectionType = .no
        hexField.returnKeyType = .done
        hexField.delegate = self
        hexField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        hexField.leftViewMode = .always
        hexField.accessibilityLabel = "Hex colour"

        let column = UIStackView(arrangedSubviews: showsHexField ? [scroll, hexField] : [scroll])
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 40),
            hexField.heightAnchor.constraint(equalToConstant: 34),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ hex: String?) {
        selectedHex = hex
        hexField.text = hex.map { "#\($0)" }
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let custom = swatch(hex: nil, symbol: "eyedropper")
        custom.accessibilityLabel = "Custom colour"
        custom.addTarget(self, action: #selector(customTapped), for: .touchUpInside)
        stack.addArrangedSubview(custom)
        let recents = EditorRecents.colors.filter { !presets.contains($0) }.prefix(6)
        for hex in Array(recents) + presets {
            let button = swatch(hex: hex, symbol: nil)
            button.accessibilityLabel = "Colour #\(hex)"
            button.addAction(UIAction { [weak self] _ in self?.pick(hex) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }

    private func swatch(hex: String?, symbol: String?) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.layer.cornerRadius = 17
        button.layer.borderWidth = 1
        button.layer.borderColor = TBStyle.border.cgColor
        if let hex {
            button.backgroundColor = UIColor(hexRGB: hex)
            if hex == selectedHex {
                button.layer.borderWidth = 3
                button.layer.borderColor = TBStyle.accent.cgColor
                button.accessibilityTraits = [.button, .selected]
            }
        } else {
            button.backgroundColor = TBStyle.field
            button.setImage(UIImage(systemName: symbol ?? "plus"), for: .normal)
            button.tintColor = TBStyle.text
        }
        return button
    }

    private func pick(_ hex: String) {
        setSelected(hex)
        EditorRecents.add(color: hex)
        onSelect?(hex)
    }

    /// Colour chosen in the system colour picker.
    func pickCustom(_ color: UIColor) {
        pick(color.hexRGB)
    }

    @objc private func customTapped() { onCustom?() }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text, let color = UIColor(hexRGB: text) else {
            textField.text = selectedHex.map { "#\($0)" }
            return
        }
        pick(color.hexRGB)
    }
}

/// Preset gradients, 2–3 colour stops (tap a stop to change it) and the angle.
final class TBGradientEditor: UIView {
    private(set) var gradient = GradientSpec.presets[0]
    private let presetStack = UIStackView()
    private let stopStack = UIStackView()
    private let stopCountControl = TBStyle.segmented(["2 colours", "3 colours"])
    private let angleRow = TBSliderRow("Direction", min: 0, max: 360) { "\(Int($0.rounded()))°" }
    var onChange: ((GradientSpec, _ finished: Bool) -> Void)?
    var onPickStop: ((Int, UIColor) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let presetScroll = UIScrollView()
        presetScroll.showsHorizontalScrollIndicator = false
        presetStack.axis = .horizontal
        presetStack.spacing = 8
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        presetScroll.addSubview(presetStack)
        for (index, preset) in GradientSpec.presets.enumerated() {
            let button = GradientSwatchButton(gradient: preset)
            button.accessibilityLabel = "Gradient preset \(index + 1)"
            button.addAction(UIAction { [weak self] _ in self?.apply(preset) }, for: .touchUpInside)
            presetStack.addArrangedSubview(button)
        }
        stopStack.axis = .horizontal
        stopStack.spacing = 10
        stopCountControl.addTarget(self, action: #selector(stopCountChanged), for: .valueChanged)
        angleRow.onChange = { [weak self] value, finished in
            guard let self else { return }
            self.gradient.angle = Double(value)
            self.onChange?(self.gradient, finished)
        }
        let stopsRow = TBStyle.hStack([TBStyle.label("Colours", size: 13), stopStack, UIView()], spacing: 12)
        let column = TBStyle.vStack([presetScroll, stopCountControl, stopsRow, angleRow], spacing: 10)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            presetScroll.heightAnchor.constraint(equalToConstant: 40),
            presetStack.topAnchor.constraint(equalTo: presetScroll.contentLayoutGuide.topAnchor),
            presetStack.leadingAnchor.constraint(equalTo: presetScroll.contentLayoutGuide.leadingAnchor),
            presetStack.trailingAnchor.constraint(equalTo: presetScroll.contentLayoutGuide.trailingAnchor),
            presetStack.bottomAnchor.constraint(equalTo: presetScroll.contentLayoutGuide.bottomAnchor),
            presetStack.heightAnchor.constraint(equalTo: presetScroll.frameLayoutGuide.heightAnchor)
        ])
        configure(gradient)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ spec: GradientSpec) {
        gradient = spec
        stopCountControl.selectedSegmentIndex = spec.stops.count >= 3 ? 1 : 0
        angleRow.value = Float(spec.angle)
        stopStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (index, stop) in spec.stops.enumerated() {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 32).isActive = true
            button.heightAnchor.constraint(equalToConstant: 32).isActive = true
            button.layer.cornerRadius = 16
            button.layer.borderWidth = 2
            button.layer.borderColor = TBStyle.border.cgColor
            button.backgroundColor = UIColor(hexRGB: stop.hex)
            button.accessibilityLabel = "Gradient colour \(index + 1)"
            button.addAction(UIAction { [weak self] _ in
                self?.onPickStop?(index, UIColor(hexRGB: stop.hex) ?? .white)
            }, for: .touchUpInside)
            stopStack.addArrangedSubview(button)
        }
    }

    private func apply(_ spec: GradientSpec) {
        configure(spec)
        onChange?(spec, true)
    }

    /// Sets the colour of one stop (from the colour picker).
    func setStop(_ index: Int, color: UIColor) {
        guard gradient.stops.indices.contains(index) else { return }
        var spec = gradient
        spec.stops[index].hex = color.hexRGB
        EditorRecents.add(color: color.hexRGB)
        apply(spec)
    }

    @objc private func stopCountChanged() {
        let hexes = gradient.stops.map(\.hex)
        var spec: GradientSpec
        if stopCountControl.selectedSegmentIndex == 1 {
            let middle = hexes.count >= 3 ? hexes[1] : (hexes.last ?? "FFFFFF")
            spec = GradientSpec([hexes.first ?? "FFFFFF", middle, hexes.last ?? "000000"], angle: gradient.angle)
        } else {
            spec = GradientSpec([hexes.first ?? "FFFFFF", hexes.last ?? "000000"], angle: gradient.angle)
        }
        apply(spec)
    }
}

/// Round button showing a gradient.
final class GradientSwatchButton: UIButton {
    private let gradientLayer = CAGradientLayer()

    init(gradient: GradientSpec) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 34).isActive = true
        heightAnchor.constraint(equalToConstant: 34).isActive = true
        layer.cornerRadius = 17
        clipsToBounds = true
        layer.borderWidth = 1
        layer.borderColor = TBStyle.border.cgColor
        gradientLayer.colors = gradient.colors.map(\.cgColor)
        gradientLayer.locations = gradient.stops.map { NSNumber(value: $0.location) }
        let angle = CGFloat(gradient.angle) * .pi / 180
        gradientLayer.startPoint = CGPoint(x: 0.5 - cos(angle) / 2, y: 0.5 - sin(angle) / 2)
        gradientLayer.endPoint = CGPoint(x: 0.5 + cos(angle) / 2, y: 0.5 + sin(angle) / 2)
        layer.insertSublayer(gradientLayer, at: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
