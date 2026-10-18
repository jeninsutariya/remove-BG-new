//
//  BackgroundImageCell.swift
//  Background Removal
//
//  Background thumbnail (remote via SDWebImage, or a custom photo) and the "Add Image" tile.
//

import UIKit

class BackgroundImageCell: UICollectionViewCell {

    @IBOutlet weak var vwContainer: UIView!
    @IBOutlet weak var imgThumb: UIImageView!
    @IBOutlet weak var imgIcon: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!

    /// True when the last remote load failed (tapping the cell retries).
    private(set) var loadFailed = false
    private var remoteID: Int?
    /// Custom background file shown by this cell (async thumbnail loads check it).
    var customFileName: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        vwContainer.layer.cornerRadius = 14
        vwContainer.layer.cornerCurve = .continuous
        vwContainer.clipsToBounds = true
        imgThumb.contentMode = .scaleAspectFill
        imgIcon.tintColor = UIColor(named: "PrimaryText")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        BackgroundImageService.shared.cancelThumbnail(on: imgThumb)
        imgThumb.image = nil
        remoteID = nil
        customFileName = nil
        loadFailed = false
    }

    /// Updates only the selected look (no image reload) – used while the list is scrolled.
    func setSelectionState(_ selected: Bool) {
        setSelectedBorder(selected)
    }

    private func setSelectedBorder(_ selected: Bool) {
        vwContainer.layer.borderWidth = selected ? 3 : 1
        vwContainer.layer.borderColor = (selected ? UIColor(named: "AccentColor") : UIColor(named: "Border Color"))?.cgColor
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    func configureAddButton() {
        imgThumb.image = nil
        imgIcon.isHidden = false
        imgIcon.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
        lblTitle.isHidden = false
        lblTitle.text = "Add Image"
        vwContainer.backgroundColor = UIColor(named: "Ultra Light Blue")
        setSelectedBorder(false)
        isAccessibilityElement = true
        accessibilityLabel = "Add your own background image"
    }

    func configure(custom image: UIImage?, selected: Bool) {
        imgThumb.image = image
        imgIcon.isHidden = true
        lblTitle.isHidden = true
        vwContainer.backgroundColor = UIColor(named: "Ultra Light Blue")
        setSelectedBorder(selected)
        isAccessibilityElement = true
        accessibilityLabel = "Your background image"
    }

    func configure(remote background: BackgroundImage, selected: Bool) {
        imgIcon.isHidden = true
        lblTitle.isHidden = true
        vwContainer.backgroundColor = UIColor(named: "Ultra Light Blue")
        setSelectedBorder(selected)
        isAccessibilityElement = true
        accessibilityLabel = "Background \(background.id)"
        guard remoteID != background.id || loadFailed || imgThumb.image == nil else { return }
        remoteID = background.id
        loadFailed = false
        BackgroundImageService.shared.setThumbnail(background, on: imgThumb) { [weak self] success in
            guard let self, self.remoteID == background.id else { return }
            self.loadFailed = !success
            self.imgIcon.isHidden = success
            if !success {
                self.imgIcon.image = UIImage(systemName: "arrow.clockwise",
                                             withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
                self.accessibilityLabel = "Background failed to load. Double tap to retry"
            }
        }
    }
}
