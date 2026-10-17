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

    /// Live change while dragging (preview only).
    var onChange: ((ShadowSettings) -> Void)?

    private(set) var settings = ShadowSettings()

    override func awakeFromNib() {
        super.awakeFromNib()
        for slider in [sliderOpacity!, sliderSoftness!, sliderDistance!] {
            slider.minimumValue = 0
            slider.maximumValue = 100
        }
        sliderOpacity.minimumValue = 5
    }

    func configure(_ settings: ShadowSettings) {
        self.settings = settings
        switchShadow.isOn = settings.isOn
        sliderOpacity.value = Float(settings.opacity)
        sliderSoftness.value = Float(settings.softness)
        sliderDistance.value = Float(settings.distance)
        refresh()
    }

    private func refresh() {
        lblOpacityValue.text = "\(Int(settings.opacity))"
        lblSoftnessValue.text = "\(Int(settings.softness))"
        lblDistanceValue.text = "\(Int(settings.distance))"
        for slider in [sliderOpacity!, sliderSoftness!, sliderDistance!] {
            slider.isEnabled = settings.isOn
            slider.alpha = settings.isOn ? 1 : 0.4
        }
    }

    @IBAction func switchShadowChanged(_ sender: UISwitch) {
        settings.isOn = sender.isOn
        refresh()
        onChange?(settings)
    }

    @IBAction func sliderChanged(_ sender: UISlider) {
        settings.opacity = Double(sliderOpacity.value.rounded())
        settings.softness = Double(sliderSoftness.value.rounded())
        settings.distance = Double(sliderDistance.value.rounded())
        refresh()
        onChange?(settings)
    }
}
