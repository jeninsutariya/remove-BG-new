//
//  ProcessedImageCell.swift
//  Background Removal
//
//  Thumbnail in the editor's horizontal strip, with processing status and selection.
//

import UIKit

class ProcessedImageCell: UICollectionViewCell {

    @IBOutlet weak var vwContainer: UIView!
    @IBOutlet weak var vwChecker: CheckerboardView!
    @IBOutlet weak var imgThumb: UIImageView!
    @IBOutlet weak var vwDim: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var imgStatus: UIImageView!
    @IBOutlet weak var imgCheck: UIImageView!

    /// Identifies the item this cell currently shows (async thumbnail loads check it).
    var representedItemID: UUID?

    override func awakeFromNib() {
        super.awakeFromNib()
        vwContainer.layer.cornerRadius = 14
        vwContainer.layer.cornerCurve = .continuous
        vwContainer.clipsToBounds = true
        vwChecker.cellSize = 6
        imgStatus.tintColor = .white
        imgCheck.tintColor = UIColor(named: "AccentColor")
        imgCheck.backgroundColor = .white
        imgCheck.layer.cornerRadius = 11
        imgCheck.clipsToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imgThumb.image = nil
        representedItemID = nil
    }

    func configure(item: BackgroundRemovalItem, isCurrent: Bool, selectionMode: Bool, isChecked: Bool) {
        representedItemID = item.id
        vwChecker.isHidden = !item.isCompleted || !item.background.isTransparent
        vwContainer.layer.borderWidth = isCurrent ? 2.5 : 1
        vwContainer.layer.borderColor = (isCurrent ? UIColor(named: "AccentColor") : UIColor(named: "Border Color"))?.cgColor

        switch item.status {
        case .completed:
            vwDim.isHidden = true
            spinner.stopAnimating()
            imgStatus.isHidden = true
        case .processing:
            vwDim.isHidden = false
            spinner.startAnimating()
            imgStatus.isHidden = true
        case .waiting:
            vwDim.isHidden = false
            spinner.stopAnimating()
            imgStatus.isHidden = false
            imgStatus.image = UIImage(systemName: "clock")
        case .failed:
            vwDim.isHidden = false
            spinner.stopAnimating()
            imgStatus.isHidden = false
            imgStatus.image = UIImage(systemName: "exclamationmark.triangle.fill")
        }

        imgCheck.isHidden = !selectionMode
        imgCheck.image = UIImage(systemName: isChecked ? "checkmark.circle.fill" : "circle")
        imgCheck.tintColor = isChecked ? UIColor(named: "AccentColor") : UIColor(named: "SecondaryText")

        isAccessibilityElement = true
        accessibilityTraits = isCurrent ? [.button, .selected] : .button
        accessibilityLabel = "\(item.sourceName ?? "Image"), \(item.status.displayName)"
    }

    func setThumbnail(_ image: UIImage?, for itemID: UUID) {
        guard representedItemID == itemID else { return }
        imgThumb.image = image
    }
}
