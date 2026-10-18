//
//  ShadowEditorView.swift
//  Background Removal
//
//  Shadow tool for the selected text layer or the subject: on/off, presets, colour,
//  opacity, blur and offset. Shadows are rendered once per layer, separately from the fill.
//

import UIKit

final class ShadowEditorView: TBPanelView {

    private enum Target: Int { case text, subject }

    override var preferredHeight: CGFloat { 340 }

    private let targetControl = TBStyle.segmented(["Text", "Subject"])
    private let messageLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let enabledRow = TBSwitchRow("Shadow")
    private let presets = TBChipStrip(ShadowStyle.presets.map { $0.name })
    private let colors = TBColorStrip(presets: ["000000", "1E2A4A", "4B5563", "FFFFFF", "1677FF", "EF4444", "FACC15"],
                                      showsHexField: false)
    private let opacityRow = TBSliderRow("Opacity", min: 0, max: 100) { "\(Int($0.rounded()))%" }
    private let blurRow = TBSliderRow("Blur", min: 0, max: 60)
    private let xRow = TBSliderRow("Horizontal offset", min: -60, max: 60)
    private let yRow = TBSliderRow("Vertical offset", min: -60, max: 60)
    private let controls = UIStackView()

    init(host: TBPanelHost, subjectAvailable: Bool) {
        self.subjectAvailable = subjectAvailable
        super.init(title: "Shadow", host: host)
        build()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private let subjectAvailable: Bool
    private var target: Target { Target(rawValue: targetControl.selectedSegmentIndex) ?? .text }

    private var style: ShadowStyle? {
        guard let session else { return nil }
        switch target {
        case .text: return session.selectedText?.shadow
        case .subject: return subjectAvailable ? session.document.subjectShadow : nil
        }
    }

    private func update(commit: Bool = true, _ mutation: @escaping (inout ShadowStyle) -> Void) {
        switch target {
        case .text: session?.changeSelectedText(commit: commit) { mutation(&$0.shadow) }
        case .subject: session?.change(commit: commit) { mutation(&$0.subjectShadow) }
        }
    }

    private func build() {
        messageLabel.numberOfLines = 0
        targetControl.addTarget(self, action: #selector(targetChanged), for: .valueChanged)
        if session?.selectedText == nil, subjectAvailable { targetControl.selectedSegmentIndex = Target.subject.rawValue }
        enabledRow.onChange = { [weak self] on in
            self?.update { $0.isOn = on }
            self?.refresh()
        }
        presets.onSelect = { [weak self] index in
            let preset = ShadowStyle.presets[index].style
            self?.update { $0 = preset }
            self?.refresh()
        }
        colors.onSelect = { [weak self] hex in
            self?.update { $0.hex = hex; $0.isOn = true }
            self?.refresh()
        }
        colors.onCustom = { [weak self] in
            self?.host?.presentColorPicker(initial: .black) { self?.colors.pickCustom($0) }
        }
        opacityRow.onChange = { [weak self] value, finished in self?.update(commit: finished) { $0.opacity = Double(value) / 100 } }
        blurRow.onChange = { [weak self] value, finished in self?.update(commit: finished) { $0.blur = Double(value) } }
        xRow.onChange = { [weak self] value, finished in self?.update(commit: finished) { $0.offsetX = Double(value) } }
        yRow.onChange = { [weak self] value, finished in self?.update(commit: finished) { $0.offsetY = Double(value) } }
        controls.axis = .vertical
        controls.spacing = 10
        [enabledRow, presets, colors, opacityRow, blurRow, xRow, yRow].forEach { controls.addArrangedSubview($0) }
        [targetControl, messageLabel, controls].forEach { content.addArrangedSubview($0) }
    }

    @objc private func targetChanged() { refresh() }

    override func refresh() {
        guard let style else {
            controls.isHidden = true
            messageLabel.isHidden = false
            messageLabel.text = target == .text ? "Select a text layer on the canvas to edit its shadow."
                                                : "A subject shadow isn't available because no subject was found in this photo."
            return
        }
        let locked = target == .text && (session?.selectedText?.isLocked ?? false)
        messageLabel.isHidden = !locked
        messageLabel.text = locked ? "This text layer is locked. Unlock it in Text › Layers." : nil
        controls.isHidden = false
        controls.isUserInteractionEnabled = !locked
        controls.alpha = locked ? 0.45 : 1
        enabledRow.toggle.isOn = style.isOn
        colors.setSelected(style.hex)
        opacityRow.value = Float(style.opacity * 100)
        blurRow.value = Float(style.blur)
        xRow.value = Float(style.offsetX)
        yRow.value = Float(style.offsetY)
        for row in [opacityRow, blurRow, xRow, yRow] { row.alpha = style.isOn ? 1 : 0.5 }
    }
}
