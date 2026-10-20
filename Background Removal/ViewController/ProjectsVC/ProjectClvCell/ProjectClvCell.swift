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
        // Keep the current image while the same project reloads (no flicker after saves).
        if representedProjectID != project.id { imgThumb.image = nil }
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
        let fallback = item.foregroundFileName ?? item.originalFileName
        let fallbackFills = item.foregroundFileName == nil
        Task { [weak self] in
            // Edited thumbnail first; if it is missing, the cutout / original.
            let result = await Task.detached(priority: .utility) { () -> (UIImage?, Bool) in
                let storage = ProjectStorageService.shared
                if let thumbnail, let image = storage.loadImage(thumbnail, projectID: projectID, maxPixel: 500) {
                    return (image, false)
                }
                return (storage.loadImage(fallback, projectID: projectID, maxPixel: 500), fallbackFills)
            }.value
            guard let self, self.representedProjectID == projectID else { return }
            self.imgThumb.contentMode = result.1 ? .scaleAspectFill : .scaleAspectFill
            self.imgThumb.image = result.0 ?? UIImage(named: "Remove BG Image")
        }
    }
}
