//
//  MaskRefinementView.swift
//  Background Removal
//
//  Refine tool for the text-behind effect. The subject mask decides which parts of the
//  text are hidden (white = subject, black = background, gray = soft edge).
//  • Paint mask – brush on the mask: Erase (text shows) / Refine (subject covers text)
//  • Show mask  – preview the mask on the canvas
//  • Feather / Edge smoothing – non-destructive, applied when the cutout is built
//  • Restore original mask / Reset refinements
//  The original photo is never painted on.
//

import UIKit

final class MaskRefinementView: TBPanelView {

    override var preferredHeight: CGFloat { 330 }

    private let showMaskRow = TBSwitchRow("Show subject mask")
    private let featherRow = TBSliderRow("Mask feather", min: 0, max: 20) { String(format: "%.1f", $0) }
    private let smoothingRow = TBSliderRow("Edge refinement", min: 0, max: 6) { String(format: "%.1f", $0) }
    private let statusLabel = TBStyle.label("", size: 12, weight: .regular, color: TBStyle.secondary)

    init(host: TBPanelHost) {
        super.init(title: "Refine", host: host)
        build()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let explanation = TBStyle.label("White = subject (covers the text) · Black = background (text shows) · Gray = soft edge",
                                        size: 12, weight: .regular, color: TBStyle.secondary)
        explanation.numberOfLines = 0
        let brush = TBStyle.button("Paint mask with brush", symbol: "paintbrush.pointed", filled: true)
        brush.addAction(UIAction { [weak self] _ in self?.host?.openMaskBrush() }, for: .touchUpInside)
        showMaskRow.onChange = { [weak self] on in self?.host?.setMaskPreview(on) }
        featherRow.onChange = { [weak self] value, finished in
            self?.session?.change(commit: finished) { $0.mask.feather = Double(value) }
        }
        smoothingRow.onChange = { [weak self] value, finished in
            self?.session?.change(commit: finished) { $0.mask.edgeSmoothing = Double(value) }
        }
        let restore = TBStyle.button("Restore original mask", symbol: "arrow.uturn.backward")
        restore.addAction(UIAction { [weak self] _ in
            self?.session?.change { $0.mask.refinedMaskFileName = nil }
            self?.refresh()
        }, for: .touchUpInside)
        let reset = TBStyle.button("Reset refinements", symbol: "arrow.counterclockwise")
        reset.addAction(UIAction { [weak self] _ in
            self?.session?.change { $0.mask = MaskSettings() }
            self?.refresh()
        }, for: .touchUpInside)
        statusLabel.numberOfLines = 0
        [explanation, brush, showMaskRow, featherRow, smoothingRow, TBStyle.hStack([restore, reset, UIView()]), statusLabel]
            .forEach { content.addArrangedSubview($0) }
    }

    override func refresh() {
        guard let mask = session?.document.mask else { return }
        featherRow.value = Float(mask.feather)
        smoothingRow.value = Float(mask.edgeSmoothing)
        statusLabel.text = mask.refinedMaskFileName == nil ? "Using the mask detected by Apple Vision."
                                                           : "Using your painted mask. The Vision mask is kept unchanged."
    }

    func setMaskPreviewSwitch(_ on: Bool) {
        showMaskRow.toggle.isOn = on
    }
}
