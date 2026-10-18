//
//  ProjectClvCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit

class ProjectClvCell: UICollectionViewCell {

    @IBOutlet weak var lbltype: UILabel!
    @IBOutlet weak var lblName: UILabel!
    @IBOutlet weak var imgThumb: UIImageView!

    /// Project shown by this cell (async thumbnail loads check it).
    var representedProjectID: UUID?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedProjectID = nil
        imgThumb.image = UIImage(named: "Remove BG Image")
        imgThumb.contentMode = .scaleAspectFill
    }

    func setData(project: BackgroundRemovalProject) {
        representedProjectID = project.id
        lblName.text = project.name
        lbltype.text = project.subtitle
        isAccessibilityElement = true
        accessibilityLabel = "\(project.name), \(project.subtitle)"
        accessibilityTraits = .button
        guard let item = project.coverItem else { return }
        let projectID = project.id
        // The edited result (thumbnail) first; older projects fall back to the cutout / original
        // until their editor is opened once and the thumbnail is generated.
        let thumbnail = project.thumbnailFileName
        let fileName = thumbnail ?? item.foregroundFileName ?? item.originalFileName
        let fill = thumbnail == nil && item.foregroundFileName == nil
        imgThumb.image = nil
        Task { [weak self] in
            let image = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadImage(fileName, projectID: projectID, maxPixel: 500)
            }.value
            guard let self, self.representedProjectID == projectID else { return }
            self.imgThumb.contentMode = fill ? .scaleAspectFill : .scaleAspectFit
            self.imgThumb.image = image ?? UIImage(named: "Remove BG Image")
        }
    }
}
