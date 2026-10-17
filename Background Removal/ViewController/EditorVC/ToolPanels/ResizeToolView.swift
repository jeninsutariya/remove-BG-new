//
//  ResizeToolView.swift
//  Background Removal
//
//  Canvas aspect ratio + subject size (ResizeToolView.xib).
//

import UIKit

class ResizeToolView: EditorToolPanel {

    @IBOutlet weak var segRatio: UISegmentedControl!
    @IBOutlet weak var sliderScale: UISlider!
    @IBOutlet weak var lblScaleValue: UILabel!

    var onChange: ((AspectSpec, CGFloat) -> Void)?
    var onCommit: (() -> Void)?

    private var aspect: AspectSpec = .original

    override func awakeFromNib() {
        super.awakeFromNib()
        segRatio.applyEditorStyle()
        segRatio.removeAllSegments()
        for (index, option) in AspectSpec.allCases.enumerated() {
            segRatio.insertSegment(withTitle: option.title, at: index, animated: false)
        }
        segRatio.selectedSegmentIndex = 0
        sliderScale.minimumValue = 50
        sliderScale.maximumValue = 100
        sliderScale.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    func configure(aspect: AspectSpec, subjectScale: CGFloat) {
        self.aspect = aspect
        segRatio.selectedSegmentIndex = aspect.rawValue
        sliderScale.value = Float(subjectScale * 100)
        lblScaleValue.text = "\(Int(subjectScale * 100))%"
    }

    @IBAction func segRatioChanged(_ sender: UISegmentedControl) {
        aspect = AspectSpec(rawValue: sender.selectedSegmentIndex) ?? .original
        onChange?(aspect, CGFloat(sliderScale.value) / 100)
        onCommit?()
    }

    @IBAction func sliderScaleChanged(_ sender: UISlider) {
        let value = sender.value.rounded()
        lblScaleValue.text = "\(Int(value))%"
        onChange?(aspect, CGFloat(value) / 100)
    }

    @objc private func sliderEnded() {
        onCommit?()
    }
}
