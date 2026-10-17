//
//  ShadowToolView.swift
//  Background Removal
//
//  Drop shadow under the subject (ShadowToolView.xib).
//

import UIKit

class ShadowToolView: EditorToolPanel {

    @IBOutlet weak var switchShadow: UISwitch!
    @IBOutlet weak var sliderOpacity: UISlider!
    @IBOutlet weak var sliderSoftness: UISlider!
    @IBOutlet weak var sliderDistance: UISlider!
    @IBOutlet weak var lblOpacityValue: UILabel!
    @IBOutlet weak var lblSoftnessValue: UILabel!
    @IBOutlet weak var lblDistanceValue: UILabel!

    var onChange: ((ShadowSpec) -> Void)?
    var onCommit: (() -> Void)?

    private(set) var spec = ShadowSpec()

    override func awakeFromNib() {
        super.awakeFromNib()
        for slider in [sliderOpacity!, sliderSoftness!, sliderDistance!] {
            slider.minimumValue = 0
            slider.maximumValue = 100
            slider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        sliderOpacity.minimumValue = 5
    }

    func configure(_ spec: ShadowSpec) {
        self.spec = spec
        switchShadow.isOn = spec.isOn
        sliderOpacity.value = Float(spec.opacity)
        sliderSoftness.value = Float(spec.softness)
        sliderDistance.value = Float(spec.distance)
        refresh()
    }

    private func refresh() {
        lblOpacityValue.text = "\(Int(spec.opacity))"
        lblSoftnessValue.text = "\(Int(spec.softness))"
        lblDistanceValue.text = "\(Int(spec.distance))"
        for slider in [sliderOpacity!, sliderSoftness!, sliderDistance!] {
            slider.isEnabled = spec.isOn
            slider.alpha = spec.isOn ? 1 : 0.4
        }
    }

    @IBAction func switchShadowChanged(_ sender: UISwitch) {
        spec.isOn = sender.isOn
        refresh()
        onChange?(spec)
        onCommit?()
    }

    @IBAction func sliderChanged(_ sender: UISlider) {
        spec.opacity = CGFloat(sliderOpacity.value.rounded())
        spec.softness = CGFloat(sliderSoftness.value.rounded())
        spec.distance = CGFloat(sliderDistance.value.rounded())
        refresh()
        onChange?(spec)
    }

    @objc private func sliderEnded() {
        onCommit?()
    }
}
