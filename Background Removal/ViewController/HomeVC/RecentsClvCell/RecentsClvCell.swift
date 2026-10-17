//
//  RecentsClvCell.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 07/10/26.
//

import UIKit

class RecentsClvCell: UICollectionViewCell {

    @IBOutlet weak var imgRecent: UIImageView!

    /// Project shown by this cell (async thumbnail loads check it).
    var representedProjectID: UUID?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        representedProjectID = nil
        imgRecent.image = UIImage(named: "Remove BG Image")
        imgRecent.contentMode = .scaleAspectFill
    }

    /// Shows the project's cutout (or original while it is still processing).
    func setData(project: BackgroundRemovalProject) {
        representedProjectID = project.id
        isAccessibilityElement = true
        accessibilityLabel = "\(project.name), \(project.subtitle)"
        accessibilityTraits = .button
        guard let item = project.coverItem else { return }
        let projectID = project.id
        let fileName = item.foregroundFileName ?? item.originalFileName
        Task { [weak self] in
            let image = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadImage(fileName, projectID: projectID, maxPixel: 600)
            }.value
            guard let self, self.representedProjectID == projectID, let image else { return }
            self.imgRecent.contentMode = item.foregroundFileName == nil ? .scaleAspectFill : .scaleAspectFit
            self.imgRecent.image = image
        }
    }
}
