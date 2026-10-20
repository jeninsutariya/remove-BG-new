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

    /// Shows the project's edited result (its saved thumbnail).
    func setData(project: BackgroundRemovalProject) {
        // Keep the current image while the same project reloads (no flicker after saves).
        if representedProjectID != project.id { imgRecent.image = nil }
        representedProjectID = project.id
        isAccessibilityElement = true
        accessibilityLabel = "\(project.name), \(project.subtitle)"
        accessibilityTraits = .button
        guard let item = project.coverItem else { return }
        let projectID = project.id
        // The edited result (thumbnail) first; older projects fall back to the cutout / original
        // until their editor is opened once and the thumbnail is generated.
        let thumbnail = project.thumbnailFileName
        let fallback = item.foregroundFileName ?? item.originalFileName
        let fallbackFills = item.foregroundFileName == nil
        Task { [weak self] in
            // Edited thumbnail first; if it is missing, the cutout / original.
            let result = await Task.detached(priority: .utility) { () -> (UIImage?, Bool) in
                let storage = ProjectStorageService.shared
                if let thumbnail, let image = storage.loadImage(thumbnail, projectID: projectID, maxPixel: 600) {
                    return (image, false)
                }
                return (storage.loadImage(fallback, projectID: projectID, maxPixel: 600), fallbackFills)
            }.value
            guard let self, self.representedProjectID == projectID else { return }
            self.imgRecent.contentMode = result.1 ? .scaleAspectFill : .scaleAspectFill
            self.imgRecent.image = result.0 ?? UIImage(named: "Remove BG Image")
        }
    }
}
