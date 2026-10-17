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

    /// Live change (preview only): aspect and subject scale 0.5…1.
    var onChange: ((CanvasAspect, Double) -> Void)?

    private var aspect: CanvasAspect = .original

    override func awakeFromNib() {
        super.awakeFromNib()
        segRatio.applyEditorStyle()
        segRatio.removeAllSegments()
        for (index, option) in CanvasAspect.allCases.enumerated() {
            segRatio.insertSegment(withTitle: option.title, at: index, animated: false)
        }
        segRatio.selectedSegmentIndex = 0
        sliderScale.minimumValue = 50
        sliderScale.maximumValue = 100
    }

    func configure(aspect: CanvasAspect, subjectScale: Double) {
        self.aspect = aspect
        segRatio.selectedSegmentIndex = CanvasAspect.allCases.firstIndex(of: aspect) ?? 0
        sliderScale.value = Float(subjectScale * 100)
        lblScaleValue.text = "\(Int((subjectScale * 100).rounded()))%"
    }

    @IBAction func segRatioChanged(_ sender: UISegmentedControl) {
        aspect = CanvasAspect.allCases[max(0, sender.selectedSegmentIndex)]
        onChange?(aspect, Double(sliderScale.value.rounded()) / 100)
    }

    @IBAction func sliderScaleChanged(_ sender: UISlider) {
        let value = sender.value.rounded()
        lblScaleValue.text = "\(Int(value))%"
        onChange?(aspect, Double(value) / 100)
    }
}
