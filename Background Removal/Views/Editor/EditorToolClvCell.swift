//
//  EditorToolClvCell.swift
//  Background Removal
//
//  Tool button in the editor toolbar (round icon + title).
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

    func setData(tool: EditorTool, enabled: Bool) {
        lblTitle.text = tool.title
        imgIcon.image = UIImage(systemName: tool.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        contentView.alpha = enabled ? 1 : 0.4
        isAccessibilityElement = true
        accessibilityLabel = tool.title
        accessibilityTraits = enabled ? .button : [.button, .notEnabled]
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.vwCircle.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            }
        }
    }
}
