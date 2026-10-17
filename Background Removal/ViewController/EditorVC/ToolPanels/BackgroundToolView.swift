//
//  BackgroundToolView.swift
//  Background Removal
//
//  08 Change Background – colour / photo backdrop sheet (BackgroundToolView.xib).
//

import UIKit

class BackgroundToolView: EditorToolPanel {

    @IBOutlet weak var segColorPhoto: UISegmentedControl!
    @IBOutlet weak var clvColors: UICollectionView!
    @IBOutlet weak var vwPhotoPanel: UIView!
    @IBOutlet weak var btnChoosePhoto: UIButton!
    @IBOutlet weak var clvPhotos: UICollectionView!

    /// Called whenever a background is picked.
    var onSelect: ((BackgroundSpec) -> Void)?
    /// Ask the editor to pick a photo from the library.
    var onChoosePhoto: (() -> Void)?
    /// Ask the editor to show the system colour picker.
    var onCustomColor: (() -> Void)?

    private var current: BackgroundSpec = .transparent
    private var customColor: UIColor?
    private var photos: [(id: String, image: UIImage)] = []

    private var colorItems: [SwatchItem] {
        [.transparent] + EditorSwatches.background.map { .color($0) } + [.custom(customColor)]
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        segColorPhoto.applyEditorStyle()
        btnChoosePhoto.layer.cornerRadius = 24
        btnChoosePhoto.setSymbol("photo.on.rectangle", size: 16)
        btnChoosePhoto.tintColor = UIColor(named: "PrimaryText")
        for collection in [clvColors!, clvPhotos!] {
            collection.register(UINib(nibName: "ColorSwatchClvCell", bundle: nil), forCellWithReuseIdentifier: "ColorSwatchClvCell")
            collection.dataSource = self
            collection.delegate = self
            collection.backgroundColor = .clear
        }
        showPage()
    }

    func configure(current: BackgroundSpec, photos: [(id: String, image: UIImage)]) {
        self.current = current
        self.photos = photos
        if case .color(let color) = current, !EditorSwatches.background.contains(where: { $0.isEqual(color) }) {
            customColor = color
        }
        if case .photo = current { segColorPhoto.selectedSegmentIndex = 1 }
        showPage()
        clvColors.reloadData()
        clvPhotos.reloadData()
    }

    /// Called by the editor after a colour was chosen in the system colour picker.
    func setCustomColor(_ color: UIColor) {
        customColor = color
        select(.color(color))
    }

    /// Called by the editor after a photo was picked.
    func addPhoto(id: String, image: UIImage) {
        photos.insert((id, image), at: 0)
        select(.photo(id: id))
    }

    private func select(_ spec: BackgroundSpec) {
        current = spec
        clvColors.reloadData()
        clvPhotos.reloadData()
        onSelect?(spec)
    }

    private func showPage() {
        let photoMode = segColorPhoto.selectedSegmentIndex == 1
        clvColors.isHidden = photoMode
        vwPhotoPanel.isHidden = !photoMode
    }

    @IBAction func segColorPhotoChanged(_ sender: UISegmentedControl) {
        showPage()
    }

    @IBAction func btnChoosePhoto(_ sender: UIButton) {
        onChoosePhoto?()
    }
}

extension BackgroundToolView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == clvColors ? colorItems.count : photos.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorSwatchClvCell", for: indexPath) as! ColorSwatchClvCell
        if collectionView == clvColors {
            let item = colorItems[indexPath.item]
            cell.setData(item, selected: isSelected(item))
        } else {
            let photo = photos[indexPath.item]
            cell.setData(.photo(photo.image), selected: current == .photo(id: photo.id))
        }
        return cell
    }

    private func isSelected(_ item: SwatchItem) -> Bool {
        switch (item, current) {
        case (.transparent, .transparent):
            return true
        case let (.color(a), .color(b)):
            return a.isEqual(b)
        case let (.custom(a), .color(b)):
            return a?.isEqual(b) ?? false
        default:
            return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if collectionView == clvPhotos {
            select(.photo(id: photos[indexPath.item].id))
            return
        }
        switch colorItems[indexPath.item] {
        case .transparent: select(.transparent)
        case .color(let color): select(.color(color))
        case .custom: onCustomColor?()
        case .photo: break
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 54, height: 54)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvColors ? max(0, (collectionView.bounds.width - 54 * 6) / 5 - 0.5) : 8
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvColors ? 6 : 8
    }
}
