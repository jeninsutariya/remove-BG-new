//
//  TextToolView.swift
//  Background Removal
//
//  09 Text Behind – text, style, colour and size (TextToolView.xib).
//

import UIKit

class TextToolView: EditorToolPanel, UITextFieldDelegate {

    @IBOutlet weak var vwField: UIView!
    @IBOutlet weak var txtText: UITextField!
    @IBOutlet var btnStyles: [UIButton]!
    @IBOutlet weak var clvColors: UICollectionView!
    @IBOutlet weak var lblSizeValue: UILabel!
    @IBOutlet weak var sliderSize: UISlider!

    /// Live changes (typing, slider dragging).
    var onChange: ((TextSpec) -> Void)?
    /// A change is finished (end of typing / slider release / tap) – becomes one undo step.
    var onCommit: (() -> Void)?

    private(set) var spec = TextSpec()

    override func awakeFromNib() {
        super.awakeFromNib()
        vwField.layer.cornerRadius = 24
        txtText.delegate = self
        txtText.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        txtText.addTarget(self, action: #selector(textEnded), for: .editingDidEnd)
        clvColors.register(UINib(nibName: "ColorSwatchClvCell", bundle: nil), forCellWithReuseIdentifier: "ColorSwatchClvCell")
        clvColors.dataSource = self
        clvColors.delegate = self
        clvColors.backgroundColor = .clear
        for button in btnStyles {
            button.layer.cornerRadius = 22
            button.layer.borderWidth = 1
            let style = TextFontStyle(rawValue: button.tag) ?? .bold
            button.titleLabel?.font = style == .serif ? UIFont(name: "InstrumentSerif-Italic", size: 19)
                : UIFont(name: style == .light ? "Figtree-Medium" : (style == .bold ? "Figtree-ExtraBold" : "Figtree-Bold"), size: 15)
        }
        sliderSize.minimumValue = 20
        sliderSize.maximumValue = 160
        sliderSize.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        refresh()
    }

    func configure(_ spec: TextSpec) {
        self.spec = spec
        txtText.text = spec.text
        sliderSize.value = Float(spec.size)
        refresh()
    }

    /// Text dragged on the canvas.
    func updateCenter(_ point: CGPoint) {
        spec.center = point
    }

    private func refresh() {
        lblSizeValue.text = "\(Int(spec.size))"
        let accent = UIColor(named: "AccentColor") ?? .systemBlue
        for button in btnStyles {
            let selected = button.tag == spec.style.rawValue
            button.backgroundColor = selected ? accent : UIColor(named: "Surface Color")
            button.setTitleColor(selected ? .white : UIColor(named: "PrimaryText"), for: .normal)
            button.layer.borderColor = selected ? UIColor.clear.cgColor : (UIColor(named: "BrandPrimary") ?? .lightGray).cgColor
        }
        clvColors.reloadData()
    }

    @objc private func textChanged() {
        spec.text = String((txtText.text ?? "").prefix(24))
        onChange?(spec)
    }

    @objc private func textEnded() {
        onCommit?()
    }

    @objc private func sliderEnded() {
        onCommit?()
    }

    @IBAction func btnStyle(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        spec.style = TextFontStyle(rawValue: sender.tag) ?? .bold
        refresh()
        onChange?(spec)
        onCommit?()
    }

    @IBAction func sliderSizeChanged(_ sender: UISlider) {
        spec.size = CGFloat(sender.value.rounded())
        lblSizeValue.text = "\(Int(spec.size))"
        onChange?(spec)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
}

extension TextToolView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        EditorSwatches.text.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorSwatchClvCell", for: indexPath) as! ColorSwatchClvCell
        let color = EditorSwatches.text[indexPath.item]
        cell.setData(.color(color), selected: color.isEqual(spec.color))
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        spec.color = EditorSwatches.text[indexPath.item]
        refresh()
        onChange?(spec)
        onCommit?()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 54, height: 54)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        4
    }
}
