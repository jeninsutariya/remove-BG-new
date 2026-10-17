//
//  SettingsTVCCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 10/10/26.
//

import UIKit

class SettingsTVCCell: UITableViewCell {
    
    @IBOutlet weak var vwPro: UIView!
    @IBOutlet weak var lbltypeText: UILabel!
    @IBOutlet weak var vwText: UIView!
    @IBOutlet weak var vwSwitch: UIView!
    @IBOutlet weak var vwNextArrow: UIView!
    @IBOutlet weak var sgmtAppaerance: UISegmentedControl!
    @IBOutlet weak var vwAppaerance: UIView!
    @IBOutlet weak var imgIcone: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
    }
    func setSegmentedControl(){
        self.vwAppaerance.isHidden = false
        self.vwNextArrow.isHidden = true
        self.vwSwitch.isHidden = true
        self.vwText.isHidden = true
        self.vwPro.isHidden = true
        let globalNormal: [NSAttributedString.Key: Any] = [
            .font: UIFont.figtree(.semiBold, size: 14) ,
            .foregroundColor: AppColor.textMuted
        ]
        
        let globalSelected: [NSAttributedString.Key: Any] = [
            .font: UIFont.figtree(.bold, size: 14),
            .foregroundColor: AppColor.primaryText
        ]
        
        UISegmentedControl.appearance().setTitleTextAttributes(globalNormal, for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes(globalSelected, for: .selected)
        UISegmentedControl.appearance().selectedSegmentTintColor = AppColor.surfaceRaised
        UISegmentedControl.appearance().backgroundColor = AppColor.ultraLightBlue
        
        self.sgmtAppaerance.removeAllSegments()
        for item in AppAppearance.allCases {
            self.sgmtAppaerance.insertSegment(withTitle: item.title, at: item.rawValue, animated: false)
        }
        self.sgmtAppaerance.selectedSegmentIndex = 0
        
    }
    func setArrow(){
        self.vwAppaerance.isHidden = true
        self.vwSwitch.isHidden = true
        self.vwNextArrow.isHidden = false
        self.vwText.isHidden = true
        self.vwPro.isHidden = true
    }
    
    func setSwitch(){
        self.vwAppaerance.isHidden = true
        self.vwNextArrow.isHidden = true
        self.vwSwitch.isHidden = false
        self.vwText.isHidden = true
        self.vwPro.isHidden = true
    }
    func setText(_ text: String){
        self.vwAppaerance.isHidden = true
        self.vwNextArrow.isHidden = false
        self.vwSwitch.isHidden = true
        self.vwText.isHidden = false
        self.vwPro.isHidden = true
        self.lbltypeText.text = text
    }
    func setPro(){
        self.vwAppaerance.isHidden = true
        self.vwNextArrow.isHidden = false
        self.vwSwitch.isHidden = true
        self.vwText.isHidden = true
        self.vwPro.isHidden = false
    }
}
