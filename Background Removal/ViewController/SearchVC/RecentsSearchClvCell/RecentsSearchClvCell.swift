//
//  RecentsSearchClvCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 09/10/26.
//

import UIKit

class RecentsSearchClvCell: UICollectionViewCell {

    @IBOutlet weak var vwbackground: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        self.vwbackground.layer.borderWidth = 1
        self.vwbackground.layer.borderColor = AppColor.borderColor.cgColor
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
     
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.vwbackground.layer.borderWidth = 1
            self.vwbackground.layer.borderColor = AppColor.borderColor.cgColor
        }
    }
}
