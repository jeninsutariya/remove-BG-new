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
    
    /// Project shown by this cell (async thumbnail loads check it).
    var representedProjectID: UUID?

    override func prepareForReuse() {
        super.prepareForReuse()
        representedProjectID = nil
        imgProjectthum.image = UIImage(named: "Remove BG Image")
    }

    func setData(_ project: BackgroundRemovalProject) {
        representedProjectID = project.id
        lblTitle.text = project.name
        lblTypes.text = project.subtitle
        guard let item = project.coverItem else { return }
        let projectID = project.id
        let thumbnail = project.thumbnailFileName
        let fallback = item.foregroundFileName ?? item.originalFileName
        Task { [weak self] in
            let image = await Task.detached(priority: .utility) { () -> UIImage? in
                let storage = ProjectStorageService.shared
                if let thumbnail, let image = storage.loadImage(thumbnail, projectID: projectID, maxPixel: 200) {
                    return image
                }
                return storage.loadImage(fallback, projectID: projectID, maxPixel: 200)
            }.value
            guard let self, self.representedProjectID == projectID else { return }
            self.imgProjectthum.image = image ?? UIImage(named: "Remove BG Image")
        }
    }
}
