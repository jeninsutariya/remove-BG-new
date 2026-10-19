//
//  BackgroundToolView.swift
//  Background Removal
//
//  Background sheet (BackgroundToolView.xib): Color (presets, transparent, custom) and
//  Photo (Add Image, your photos, the remote gallery loaded with SDWebImage).
//

import UIKit

class BackgroundToolView: EditorToolPanel {

    @IBOutlet weak var segColorPhoto: UISegmentedControl!
    @IBOutlet weak var clvColors: UICollectionView!
    @IBOutlet weak var clvPhotos: UICollectionView!
    @IBOutlet weak var lblEmpty: UILabel!

    /// Live selection change (preview only until ✓).
    var onChange: ((BackgroundSelection) -> Void)?
    /// The editor presents the photo picker / colour picker.
    var onAddPhoto: (() -> Void)?
    var onPickColor: ((UIColor?) -> Void)?

    private enum PhotoEntry {
        case add
        case custom(fileName: String)
        case remote(BackgroundImage)
    }

    private weak var viewModel: BackgroundRemovalViewModel?
    private(set) var selection: BackgroundSelection = .none
    private var customColor: UIColor?
    private var customFiles: [String] = []
    private var catalog: [BackgroundImage] = []

    private var photoEntries: [PhotoEntry] {
        var entries: [PhotoEntry] = [.add]
        entries += customFiles.map { PhotoEntry.custom(fileName: $0) }
        entries += catalog.map { PhotoEntry.remote($0) }
        return entries
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        segColorPhoto.applyEditorStyle()
        clvColors.register(UINib(nibName: "BackgroundColorCell", bundle: nil), forCellWithReuseIdentifier: "BackgroundColorCell")
        clvPhotos.register(UINib(nibName: "BackgroundImageCell", bundle: nil), forCellWithReuseIdentifier: "BackgroundImageCell")
        for collection in [clvColors!, clvPhotos!] {
            collection.dataSource = self
            collection.delegate = self
        }
        clvPhotos.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
    }

    func configure(viewModel: BackgroundRemovalViewModel, selection: BackgroundSelection) {
        self.viewModel = viewModel
        self.selection = selection
        if case .color(let hex) = selection, !BackgroundColorOption.presetHexes.contains(hex) {
            customColor = UIColor(hexRGB: hex)
        }
        var seen = Set<String>()
        customFiles = viewModel.items.compactMap { $0.background.customFileName }.filter { seen.insert($0).inserted }
        do {
            catalog = try BackgroundImageService.shared.catalog()
            lblEmpty.text = nil
        } catch {
            catalog = []
            lblEmpty.text = error.localizedDescription
        }
        switch selection {
        case .remoteImage, .customImage: segColorPhoto.selectedSegmentIndex = 1
        default: segColorPhoto.selectedSegmentIndex = 0
        }
        updateTab()
    }

    /// Called by the editor after a photo was added to the project.
    func addCustomFile(_ fileName: String) {
        if !customFiles.contains(fileName) {
            // Count with the old data first, so the insert below stays consistent.
            let countBefore = clvPhotos.numberOfItems(inSection: 0)
            customFiles.insert(fileName, at: 0)
            if countBefore == photoEntries.count - 1 {
                // Insert after the "Add Image" tile instead of reloading everything.
                clvPhotos.insertItems(at: [IndexPath(item: 1, section: 0)])
            } else {
                clvPhotos.reloadData()
            }
        }
        select(.customImage(fileName: fileName))
    }

    /// Called by the editor with the colour from UIColorPickerViewController.
    func applyCustomColor(_ color: UIColor) {
        customColor = color
        select(.color(hex: color.hexRGB))
    }

    private func select(_ newSelection: BackgroundSelection) {
        selection = newSelection
        updateVisibleSelection()
        onChange?(newSelection)
    }

    /// Refreshes the selected state of the visible cells without reloading the collections,
    /// so the scroll position and loaded thumbnails stay as they are.
    private func updateVisibleSelection() {
        for indexPath in clvColors.indexPathsForVisibleItems {
            guard let cell = clvColors.cellForItem(at: indexPath) as? BackgroundColorCell else { continue }
            let option = BackgroundColorOption.allCases[indexPath.item]
            cell.configure(option: option, customColor: customColor, selected: isSelected(option))
        }
        let entries = photoEntries
        for indexPath in clvPhotos.indexPathsForVisibleItems where entries.indices.contains(indexPath.item) {
            guard let cell = clvPhotos.cellForItem(at: indexPath) as? BackgroundImageCell else { continue }
            switch entries[indexPath.item] {
            case .add: cell.setSelectionState(false)
            case .custom(let fileName): cell.setSelectionState(selection == .customImage(fileName: fileName))
            case .remote(let item): cell.setSelectionState(selection == .remoteImage(id: item.id, url: item.image))
            }
        }
    }

    private func updateTab() {
        let showPhotos = segColorPhoto.selectedSegmentIndex == 1
        clvColors.isHidden = showPhotos
        clvPhotos.isHidden = !showPhotos
        lblEmpty.isHidden = !showPhotos || lblEmpty.text?.isEmpty != false
        (showPhotos ? clvPhotos : clvColors)?.reloadData()
    }

    @IBAction func segColorPhotoChanged(_ sender: UISegmentedControl) {
        updateTab()
    }
}

extension BackgroundToolView: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == clvColors ? BackgroundColorOption.allCases.count : photoEntries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == clvColors {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BackgroundColorCell", for: indexPath) as! BackgroundColorCell
            let option = BackgroundColorOption.allCases[indexPath.item]
            cell.configure(option: option, customColor: customColor, selected: isSelected(option))
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BackgroundImageCell", for: indexPath) as! BackgroundImageCell
        switch photoEntries[indexPath.item] {
        case .add:
            cell.configureAddButton()
        case .custom(let fileName):
            cell.configure(custom: nil, selected: selection == .customImage(fileName: fileName))
            cell.customFileName = fileName
            if let viewModel {
                Task { [weak cell] in
                    if case .image(let image)? = try? await viewModel.resolveBackground(.customImage(fileName: fileName), maxPixel: 320) {
                        guard let cell, cell.customFileName == fileName else { return }
                        cell.imgThumb.image = image
                    }
                }
            }
        case .remote(let background):
            cell.configure(remote: background, selected: selection == .remoteImage(id: background.id, url: background.image))
        }
        return cell
    }

    private func isSelected(_ option: BackgroundColorOption) -> Bool {
        switch (option, selection) {
        case (.transparent, .none): return true
        case (.custom, .color(let hex)): return !BackgroundColorOption.presetHexes.contains(hex)
        case (_, .color(let hex)): return option.hex == hex
        default: return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
        if collectionView == clvColors {
            let side = floor((width - 6 * 6) / 7)
            return CGSize(width: max(side, 36), height: max(side, 36))
        }
        let side = floor((width - 3 * 8) / 4)
        return CGSize(width: max(side, 56), height: max(side, 56))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvColors ? 10 : 8
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvColors ? 6 : 8
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == clvColors {
            let option = BackgroundColorOption.allCases[indexPath.item]
            switch option {
            case .transparent:
                select(BackgroundSelection.none)
            case .custom:
                onPickColor?(customColor)
            default:
                if let hex = option.hex { select(.color(hex: hex)) }
            }
            return
        }
        switch photoEntries[indexPath.item] {
        case .add:
            onAddPhoto?()
        case .custom(let fileName):
            select(.customImage(fileName: fileName))
        case .remote(let background):
            if let cell = collectionView.cellForItem(at: indexPath) as? BackgroundImageCell, cell.loadFailed {
                // Retry the thumbnail instead of selecting a background that didn't load.
                collectionView.reloadItems(at: [indexPath])
                return
            }
            select(.remoteImage(id: background.id, url: background.image))
        }
    }
}
