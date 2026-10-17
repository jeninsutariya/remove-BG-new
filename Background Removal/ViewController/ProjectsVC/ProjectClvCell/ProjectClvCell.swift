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
        let fileName = item.foregroundFileName ?? item.originalFileName
        Task { [weak self] in
            let image = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadImage(fileName, projectID: projectID, maxPixel: 500)
            }.value
            guard let self, self.representedProjectID == projectID, let image else { return }
            self.imgThumb.contentMode = item.foregroundFileName == nil ? .scaleAspectFill : .scaleAspectFit
            self.imgThumb.image = image
        }
    }
}
