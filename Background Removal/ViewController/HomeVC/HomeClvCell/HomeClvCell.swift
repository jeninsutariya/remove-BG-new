//
//  HomeClvCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 06/10/26.
//

import UIKit

class HomeClvCell: UICollectionViewCell {
    @IBOutlet weak var lblSubTitle: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var imgBottom: UIImageView!
    @IBOutlet weak var imgTop: UIImageView!
    @IBOutlet weak var vwBottomImage: UIView!
    @IBOutlet weak var vwTopImage: UIView!
    let topDegrees: CGFloat = 7.0
    let bottomDegrees: CGFloat = -7
   
    override func awakeFromNib() {
        super.awakeFromNib()
        setUI()
    }
    func setUI(){
        let topRadians = topDegrees * (.pi / 180.0)
        vwTopImage.transform = CGAffineTransform(rotationAngle: topRadians)
        let bottomRadians = bottomDegrees * (.pi / 180.0)
        vwBottomImage.transform = CGAffineTransform(rotationAngle: bottomRadians)
    }
    func setData(data: HomeCardModel){
        self.imgTop.image = UIImage(named: data.topImage)
        self.imgBottom.image = UIImage(named: data.bottomImage)
        self.lblTitle.text = data.title
        self.lblSubTitle.text = data.subtitle
    }

}
