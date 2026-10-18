//
//  CanvasResizeView.swift
//  Background Removal
//
//  Resize tool: aspect presets (Original, 1:1, 4:5, 3:4, 9:16, 16:9, Custom), custom
//  width / height with an aspect lock, Fit / Fill, zoom, position, centre and reset.
//  Texts are positioned relative to the canvas, so nothing is stretched.
//

import UIKit

final class CanvasResizeView: TBPanelView, UITextFieldDelegate {

    override var preferredHeight: CGFloat { 340 }

    private let presets = TBChipStrip(CanvasPreset.allCases.map(\.title))
    private let widthField = UITextField()
    private let heightField = UITextField()
    private let lockButton = UIButton(type: .system)
    private let customRow = UIStackView()
    private let modeControl = TBStyle.segmented(ContentFitMode.allCases.map(\.title))
    private let zoomRow = TBSliderRow("Photo zoom", min: 0.5, max: 3) { String(format: "%.2f×", $0) }
    private let xRow = TBSliderRow("Horizontal position", min: -1, max: 1) { "\(Int(($0 * 100).rounded()))" }
    private let yRow = TBSliderRow("Vertical position", min: -1, max: 1) { "\(Int(($0 * 100).rounded()))" }
    private let sizeLabel = TBStyle.label("", size: 13, weight: .semibold, color: TBStyle.accent)
    private var aspectLocked = true
    /// Full-resolution photo size (pixels).
    private let photoSize: CGSize

    init(host: TBPanelHost, photoSize: CGSize) {
        self.photoSize = photoSize
        super.init(title: "Resize", host: host)
        build()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        presets.onSelect = { [weak self] index in
            guard let self else { return }
            let preset = CanvasPreset.allCases[index]
            self.session?.change {
                if preset == .custom, $0.canvas.preset != .custom {
                    let size = TextBehindGeometry.canvasPixelSize(photo: self.photoSize, canvas: $0.canvas)
                    $0.canvas.customWidth = Int(size.width)
                    $0.canvas.customHeight = Int(size.height)
                }
                $0.canvas.preset = preset
            }
            self.refresh()
        }
        for field in [widthField, heightField] {
            field.keyboardType = .numberPad
            field.font = TBStyle.font(15, .semibold)
            field.backgroundColor = TBStyle.field
            field.layer.cornerRadius = 10
            field.textAlignment = .center
            field.delegate = self
            field.widthAnchor.constraint(equalToConstant: 86).isActive = true
            field.heightAnchor.constraint(equalToConstant: 36).isActive = true
            let bar = UIToolbar()
            bar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
                         UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneEditing))]
            bar.sizeToFit()
            field.inputAccessoryView = bar
        }
        widthField.accessibilityLabel = "Canvas width in pixels"
        heightField.accessibilityLabel = "Canvas height in pixels"
        lockButton.tintColor = TBStyle.text
        lockButton.accessibilityLabel = "Lock aspect ratio"
        lockButton.addAction(UIAction { [weak self] _ in
            self?.aspectLocked.toggle()
            self?.refresh()
        }, for: .touchUpInside)
        customRow.axis = .horizontal
        customRow.spacing = 8
        customRow.alignment = .center
        [TBStyle.label("W", size: 13), widthField, lockButton, TBStyle.label("H", size: 13), heightField, UIView()]
            .forEach { customRow.addArrangedSubview($0) }

        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        zoomRow.onChange = { [weak self] value, finished in
            self?.session?.change(commit: finished) { $0.canvas.contentZoom = Double(value) }
        }
        xRow.onChange = { [weak self] value, finished in
            self?.session?.change(commit: finished) { $0.canvas.contentOffsetX = Double(value) }
        }
        yRow.onChange = { [weak self] value, finished in
            self?.session?.change(commit: finished) { $0.canvas.contentOffsetY = Double(value) }
        }
        let center = TBStyle.button("Center", symbol: "align.horizontal.center")
        center.addAction(UIAction { [weak self] _ in
            self?.session?.change { $0.canvas.contentOffsetX = 0; $0.canvas.contentOffsetY = 0 }
            self?.refresh()
        }, for: .touchUpInside)
        let reset = TBStyle.button("Reset", symbol: "arrow.counterclockwise")
        reset.addAction(UIAction { [weak self] _ in
            self?.session?.change {
                $0.canvas.contentMode = .fit
                $0.canvas.contentZoom = 1
                $0.canvas.contentOffsetX = 0
                $0.canvas.contentOffsetY = 0
            }
            self?.refresh()
        }, for: .touchUpInside)
        [presets, customRow, modeControl, zoomRow, xRow, yRow, TBStyle.hStack([center, reset, UIView()]), sizeLabel]
            .forEach { content.addArrangedSubview($0) }
    }

    override func refresh() {
        guard let canvas = session?.document.canvas else { return }
        presets.setSelected([CanvasPreset.allCases.firstIndex(of: canvas.preset) ?? 0])
        customRow.isHidden = canvas.preset != .custom
        if !widthField.isFirstResponder { widthField.text = "\(canvas.customWidth)" }
        if !heightField.isFirstResponder { heightField.text = "\(canvas.customHeight)" }
        lockButton.setImage(UIImage(systemName: aspectLocked ? "lock.fill" : "lock.open"), for: .normal)
        modeControl.selectedSegmentIndex = ContentFitMode.allCases.firstIndex(of: canvas.contentMode) ?? 0
        zoomRow.value = Float(canvas.contentZoom)
        xRow.value = Float(canvas.contentOffsetX)
        yRow.value = Float(canvas.contentOffsetY)
        let full = TextBehindGeometry.canvasPixelSize(photo: photoSize, canvas: canvas)
        let quality = PremiumManager.shared.exportQuality
        let output = TextBehindGeometry.outputSize(photo: photoSize, canvas: canvas, maxDimension: quality.maxPixelDimension)
        var text = "Canvas \(Int(full.width)) × \(Int(full.height)) px"
        if output != full { text += " · export \(Int(output.width)) × \(Int(output.height)) px (Standard)" }
        sizeLabel.text = text
        sizeLabel.numberOfLines = 0
    }

    @objc private func modeChanged() {
        let mode = ContentFitMode.allCases[max(0, modeControl.selectedSegmentIndex)]
        session?.change { $0.canvas.contentMode = mode }
        refresh()
    }

    @objc private func doneEditing() {
        endEditing(true)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let canvas = session?.document.canvas else { return }
        let value = min(max(Int(textField.text ?? "") ?? 0, 64), 8000)
        var width = canvas.customWidth
        var height = canvas.customHeight
        let ratio = Double(width) / Double(max(height, 1))
        if textField == widthField {
            width = value
            if aspectLocked { height = Int((Double(value) / ratio).rounded()) }
        } else {
            height = value
            if aspectLocked { width = Int((Double(value) * ratio).rounded()) }
        }
        session?.change {
            $0.canvas.customWidth = min(max(width, 64), 8000)
            $0.canvas.customHeight = min(max(height, 64), 8000)
        }
        refresh()
    }
}
