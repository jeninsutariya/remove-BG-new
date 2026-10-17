//
//  ProUpgradeTVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 13/10/26.
//

import UIKit

class ProUpgradeTVC: UITableViewCell {

    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var veBestValue: UIView!
    @IBOutlet weak var imgSelected: UIImageView!
    @IBOutlet weak var vwBackground: UIView!
    var isSelectedCell: Bool = false
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
     
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.vwBackground.layer.borderWidth = self.isSelectedCell ? 2 : 1
            self.vwBackground.layer.borderColor = self.isSelectedCell ? AppColor.accent.cgColor : AppColor.borderColor.cgColor
        }
    }
    func setSata(isSelected: Bool){
        self.vwBackground.backgroundColor = isSelected ? AppColor.selected : AppColor.surfaceColor
        self.vwBackground.layer.borderWidth = isSelected ? 2 : 1
        self.vwBackground.layer.borderColor = isSelected ? AppColor.accent.cgColor : AppColor.borderColor.cgColor
        self.vwBackground.layer.cornerRadius = 20
        self.isSelectedCell = isSelected
        self.imgSelected.image = UIImage(named: isSelected ? "ic_check" : "ic_uncheck")
    }
    
    
}
