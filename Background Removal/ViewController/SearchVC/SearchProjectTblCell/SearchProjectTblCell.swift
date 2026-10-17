//
//  SearchProjectTblCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 09/10/26.
//

import UIKit

class SearchProjectTblCell: UITableViewCell {

    @IBOutlet weak var lblTypes: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var imgProjectthum: UIImageView!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setData(_ data: SearchProject){
        self.lblTitle.text = data.title
        let type = data.format.rawValue
        self.lblTypes.text = "\(data.dateText) · \(type.uppercased())"
    }
    
}
