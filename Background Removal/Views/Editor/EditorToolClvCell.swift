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
        setData(title: tool.title, symbol: tool.symbol, enabled: enabled)
    }

    func setData(title: String, symbol: String, enabled: Bool, selected: Bool = false) {
        lblTitle.text = title
        imgIcon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        vwCircle.backgroundColor = selected ? UIColor(named: "AccentColor") : UIColor(named: "Ultra Light Blue")
        imgIcon.tintColor = selected ? .white : UIColor(named: "PrimaryText")
        contentView.alpha = enabled ? 1 : 0.4
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : (enabled ? .button : [.button, .notEnabled])
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.vwCircle.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.9, y: 0.9) : .identity
            }
        }
    }
}
