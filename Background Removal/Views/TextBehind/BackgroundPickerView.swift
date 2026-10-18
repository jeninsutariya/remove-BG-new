//
//  BackgroundPickerView.swift
//  Background Removal
//
//  Background tool: Original photo, Transparent, Color (presets, recents, custom picker,
//  hex), Gradient (presets, 2–3 stops, direction) and Image (image_urls.json via
//  SDWebImage, your own photos, Fit / Fill / Crop with zoom and position).
//  Background images are decorative only; background removal never runs on them.
//

import UIKit

final class BackgroundPickerView: TBPanelView, UICollectionViewDataSource, UICollectionViewDelegate,
                                  UICollectionViewDelegateFlowLayout {

    private enum Tab: Int, CaseIterable {
        case original, transparent, color, gradient, image
        var title: String {
            switch self {
            case .original: return "Original"
            case .transparent: return "None"
            case .color: return "Color"
            case .gradient: return "Gradient"
            case .image: return "Image"
            }
        }
    }

    private enum ImageEntry {
        case add
        case custom(String)
        case remote(BackgroundImage)
    }

    override var preferredHeight: CGFloat { 330 }

    private let tabs = TBStyle.segmented(Tab.allCases.map(\.title))
    private let infoLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let colorStrip = TBColorStrip()
    private let gradientEditor = TBGradientEditor()
    private let imageSection = UIStackView()
    private lazy var imageCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 72, height: 72)
        layout.minimumLineSpacing = 8
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.register(UINib(nibName: "BackgroundImageCell", bundle: nil), forCellWithReuseIdentifier: "BackgroundImageCell")
        collection.dataSource = self
        collection.delegate = self
        collection.heightAnchor.constraint(equalToConstant: 72).isActive = true
        return collection
    }()
    private let placementControl = TBStyle.segmented(ImageFitMode.allCases.map(\.title))
    private let zoomRow = TBSliderRow("Zoom", min: 1, max: 4) { String(format: "%.1f×", $0) }
    private let positionXRow = TBSliderRow("Horizontal position", min: -1, max: 1) { "\(Int(($0 * 100).rounded()))" }
    private let positionYRow = TBSliderRow("Vertical position", min: -1, max: 1) { "\(Int(($0 * 100).rounded()))" }

    private var catalog: [BackgroundImage] = []
    private var customFiles: [String] = []
    private var lastColorHex = "FFFFFF"
    private var lastGradient = GradientSpec.presets[1]

    init(host: TBPanelHost) {
        super.init(title: "Background", host: host)
        build()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var background: TBBackground { session?.document.background ?? .original }

    private func build() {
        tabs.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        infoLabel.numberOfLines = 0

        colorStrip.onSelect = { [weak self] hex in
            self?.lastColorHex = hex
            self?.session?.change { $0.background = .color(hex: hex) }
        }
        colorStrip.onCustom = { [weak self] in
            guard let self else { return }
            self.host?.presentColorPicker(initial: UIColor(hexRGB: self.lastColorHex) ?? .white) { color in
                self.colorStrip.pickCustom(color)
            }
        }
        gradientEditor.onChange = { [weak self] spec, finished in
            self?.lastGradient = spec
            self?.session?.change(commit: finished) { $0.background = .gradient(spec) }
        }
        gradientEditor.onPickStop = { [weak self] index, color in
            self?.host?.presentColorPicker(initial: color) { picked in
                self?.gradientEditor.setStop(index, color: picked)
            }
        }

        placementControl.addTarget(self, action: #selector(placementChanged), for: .valueChanged)
        for row in [zoomRow, positionXRow, positionYRow] {
            row.onChange = { [weak self] _, finished in self?.placementSlidersChanged(finished: finished) }
        }
        let resetButton = TBStyle.button("Reset position", symbol: "arrow.counterclockwise")
        resetButton.addAction(UIAction { [weak self] _ in self?.resetPlacement() }, for: .touchUpInside)
        imageSection.axis = .vertical
        imageSection.spacing = 10
        [imageCollection, placementControl, zoomRow, positionXRow, positionYRow,
         TBStyle.hStack([resetButton, UIView()])].forEach { imageSection.addArrangedSubview($0) }

        [tabs, infoLabel, colorStrip, gradientEditor, imageSection].forEach { content.addArrangedSubview($0) }

        if let viewModel = host?.viewModel {
            var seen = Set<String>()
            customFiles = viewModel.items.compactMap { item -> String? in
                if case .image(let selection, _)? = item.textBehind?.background { return selection.customFileName }
                return item.background.customFileName
            }.filter { seen.insert($0).inserted }
        }
        do {
            catalog = try BackgroundImageService.shared.catalog()
        } catch {
            catalog = []
        }
    }

    override func refresh() {
        let tab: Tab
        switch background {
        case .original:
            tab = .original
        case .transparent:
            tab = .transparent
        case .color(let hex):
            tab = .color
            lastColorHex = hex
            colorStrip.setSelected(hex)
        case .gradient(let spec):
            tab = .gradient
            lastGradient = spec
            gradientEditor.configure(spec)
        case .image(_, let placement):
            tab = .image
            placementControl.selectedSegmentIndex = ImageFitMode.allCases.firstIndex(of: placement.mode) ?? 1
            zoomRow.value = Float(placement.zoom)
            positionXRow.value = Float(placement.offsetX)
            positionYRow.value = Float(placement.offsetY)
        }
        tabs.selectedSegmentIndex = tab.rawValue
        showTab(tab)
    }

    private func showTab(_ tab: Tab) {
        colorStrip.isHidden = tab != .color
        gradientEditor.isHidden = tab != .gradient
        imageSection.isHidden = tab != .image
        switch tab {
        case .original:
            infoLabel.text = "The unchanged original photo stays behind your text. The subject is drawn over the text."
        case .transparent:
            infoLabel.text = "No background. Export as PNG to keep transparency (the checkerboard is only shown in the editor)."
        case .image:
            infoLabel.text = catalog.isEmpty ? "Add your own photo, or check image_urls.json for gallery images." : nil
        default:
            infoLabel.text = nil
        }
        infoLabel.isHidden = infoLabel.text == nil
        let crop = currentPlacement?.mode == .crop
        zoomRow.isHidden = !crop
        positionXRow.isHidden = !crop
        positionYRow.isHidden = !crop
        imageCollection.reloadData()
    }

    @objc private func tabChanged() {
        guard let tab = Tab(rawValue: tabs.selectedSegmentIndex) else { return }
        switch tab {
        case .original: session?.change { $0.background = .original }
        case .transparent: session?.change { $0.background = .transparent }
        case .color: session?.change { $0.background = .color(hex: lastColorHex) }
        case .gradient: session?.change { $0.background = .gradient(lastGradient) }
        case .image:
            // The background changes when an image is picked below.
            showTab(.image)
            return
        }
        refresh()
    }

    // MARK: - Image placement

    private var currentPlacement: ImagePlacement? {
        if case .image(_, let placement) = background { return placement }
        return nil
    }

    private var currentSelection: BackgroundSelection? {
        if case .image(let selection, _) = background { return selection }
        return nil
    }

    @objc private func placementChanged() {
        guard let selection = currentSelection, var placement = currentPlacement else { return }
        placement.mode = ImageFitMode.allCases[max(0, placementControl.selectedSegmentIndex)]
        session?.change { $0.background = .image(selection, placement) }
        showTab(.image)
    }

    private func placementSlidersChanged(finished: Bool) {
        guard let selection = currentSelection, var placement = currentPlacement else { return }
        placement.zoom = Double(zoomRow.value)
        placement.offsetX = Double(positionXRow.value)
        placement.offsetY = Double(positionYRow.value)
        session?.change(commit: finished) { $0.background = .image(selection, placement) }
    }

    private func resetPlacement() {
        guard let selection = currentSelection else { return }
        session?.change { $0.background = .image(selection, ImagePlacement()) }
        refresh()
    }

    /// Called by the editor after the user added a photo to the project.
    func addCustomImage(_ fileName: String) {
        if !customFiles.contains(fileName) { customFiles.insert(fileName, at: 0) }
        select(.customImage(fileName: fileName))
    }

    private func select(_ selection: BackgroundSelection) {
        let placement = currentPlacement ?? ImagePlacement()
        session?.change { $0.background = .image(selection, placement) }
        refresh()
    }

    // MARK: - Image collection

    private var entries: [ImageEntry] {
        var list: [ImageEntry] = [.add]
        list += customFiles.map { ImageEntry.custom($0) }
        list += catalog.map { ImageEntry.remote($0) }
        return list
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BackgroundImageCell", for: indexPath) as! BackgroundImageCell
        switch entries[indexPath.item] {
        case .add:
            cell.configureAddButton()
        case .custom(let fileName):
            cell.configure(custom: nil, selected: currentSelection == .customImage(fileName: fileName))
            cell.customFileName = fileName
            if let viewModel = host?.viewModel {
                Task { [weak cell] in
                    if case .image(let image)? = try? await viewModel.resolveBackground(.customImage(fileName: fileName), maxPixel: 240) {
                        guard let cell, cell.customFileName == fileName else { return }
                        cell.imgThumb.image = image
                    }
                }
            }
        case .remote(let item):
            cell.configure(remote: item, selected: currentSelection == .remoteImage(id: item.id, url: item.image))
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch entries[indexPath.item] {
        case .add:
            host?.presentBackgroundPhotoPicker()
        case .custom(let fileName):
            select(.customImage(fileName: fileName))
        case .remote(let item):
            if let cell = collectionView.cellForItem(at: indexPath) as? BackgroundImageCell, cell.loadFailed {
                collectionView.reloadItems(at: [indexPath])   // retry the thumbnail
                return
            }
            select(.remoteImage(id: item.id, url: item.image))
        }
    }
}
