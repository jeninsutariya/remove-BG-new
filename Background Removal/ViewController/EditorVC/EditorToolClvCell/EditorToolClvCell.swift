//
//  EditorToolClvCell.swift
//  Background Removal
//

import UIKit

class EditorToolClvCell: UICollectionViewCell {

    @IBOutlet weak var vwCircle: UIView!
    @IBOutlet weak var imgIcon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        vwCircle.layer.cornerRadius = 24
        imgIcon.tintColor = UIColor(named: "PrimaryText")
    }

    func setData(title: String, symbol: String) {
        lblTitle.text = title
        imgIcon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        accessibilityLabel = title
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.vwCircle.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            }
        }
    }
}
