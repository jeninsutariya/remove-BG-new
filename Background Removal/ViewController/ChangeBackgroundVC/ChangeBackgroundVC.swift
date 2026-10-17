//
//  ChangeBackgroundVC.swift
//  Background Removal
//
//  Choose a background for one image: Images (remote gallery via SDWebImage + your own photo)
//  or Colors. The preview uses the same compositing service as export. Changes are applied
//  with Done; Back discards them.
//

import UIKit
import PhotosUI

class ChangeBackgroundVC: UIViewController {

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnDone: UIButton!
    @IBOutlet weak var vwPreviewContainer: UIView!
    @IBOutlet weak var vwPreviewCard: UIView!
    @IBOutlet weak var vwChecker: CheckerboardView!
    @IBOutlet weak var imgPreview: UIImageView!
    @IBOutlet weak var previewWidth: NSLayoutConstraint!
    @IBOutlet weak var previewHeight: NSLayoutConstraint!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var vwPanel: UIView!
    @IBOutlet weak var segCategory: UISegmentedControl!
    @IBOutlet weak var clvImages: UICollectionView!
    @IBOutlet weak var clvColors: UICollectionView!
    @IBOutlet weak var lblEmpty: UILabel!

    var viewModel: BackgroundRemovalViewModel!
    var itemID: UUID!

    private enum ImageEntry {
        case add
        case custom(fileName: String)
        case remote(BackgroundImage)
    }

    private var draft: BackgroundSelection = .none
    private var originalSelection: BackgroundSelection = .none
    private var customFiles: [String] = []
    /// Custom backgrounds added on this screen (deleted again if not kept).
    private var addedCustom: [BackgroundSelection] = []
    private var catalog: [BackgroundImage] = []
    private var customColor: UIColor?
    private var previewTask: Task<Void, Never>?
    private var previewSize: CGSize?
    private var observers: [NSObjectProtocol] = []
    private var processingHUD: ProgressHUD?
    private var didApply = false

    private var imageEntries: [ImageEntry] {
        [.add] + customFiles.map { .custom(fileName: $0) } + catalog.map { .remote($0) }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        guard let item = viewModel.item(itemID) else {
            navigationController?.popViewController(animated: true)
            return
        }
        originalSelection = item.background
        draft = item.background
        if case .color(let hex) = draft, !BackgroundColorOption.presetHexes.contains(hex) {
            customColor = UIColor(hexRGB: hex)
        }
        customFiles = collectCustomFiles()
        loadCatalog()
        observe()
        if case .color = draft { segCategory.selectedSegmentIndex = 1 } else { segCategory.selectedSegmentIndex = 0 }
        updateCategory()
        ensureForeground()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitPreview()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || navigationController == nil else { return }
        discardUnusedCustomBackgrounds()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        previewTask?.cancel()
    }

    // MARK: - Setup

    private func setupViews() {
        btnBack.setImage(UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        btnBack.setTitle(nil, for: .normal)
        btnBack.layer.cornerRadius = 22
        btnBack.accessibilityLabel = "Back"
        btnDone.layer.cornerRadius = 22

        vwPreviewCard.layer.cornerRadius = 22
        vwPreviewCard.layer.cornerCurve = .continuous
        vwPreviewCard.clipsToBounds = true
        vwPreviewCard.layer.borderWidth = 1
        vwPreviewCard.layer.borderColor = UIColor(named: "Border Color")?.cgColor
        imgPreview.contentMode = .scaleAspectFit

        vwPanel.layer.cornerRadius = 26
        vwPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        vwPanel.layer.shadowColor = UIColor.black.cgColor
        vwPanel.layer.shadowOpacity = 0.06
        vwPanel.layer.shadowRadius = 16
        vwPanel.layer.shadowOffset = CGSize(width: 0, height: -4)

        let font = UIFont(name: "Figtree-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        segCategory.setTitleTextAttributes([.font: font], for: .normal)
        segCategory.setTitleTextAttributes([.font: font, .foregroundColor: UIColor.white], for: .selected)
        segCategory.selectedSegmentTintColor = UIColor(named: "AccentColor")

        clvImages.register(UINib(nibName: "BackgroundImageCell", bundle: nil), forCellWithReuseIdentifier: "BackgroundImageCell")
        clvColors.register(UINib(nibName: "BackgroundColorCell", bundle: nil), forCellWithReuseIdentifier: "BackgroundColorCell")
        for collection in [clvImages!, clvColors!] {
            collection.dataSource = self
            collection.delegate = self
            collection.contentInset = UIEdgeInsets(top: 4, left: 16, bottom: 16, right: 16)
        }
    }

    private func observe() {
        observers.append(NotificationCenter.default.addObserver(forName: BackgroundRemovalViewModel.itemDidChangeNotification,
                                                                object: viewModel, queue: .main) { [weak self] note in
            let id = note.userInfo?[BackgroundRemovalViewModel.itemIDKey] as? UUID
            MainActor.assumeIsolated {
                guard let self, id == self.itemID else { return }
                self.foregroundStateChanged()
            }
        })
    }

    private func collectCustomFiles() -> [String] {
        var seen = Set<String>()
        return viewModel.items.compactMap { $0.background.customFileName }.filter { seen.insert($0).inserted }
    }

    private func loadCatalog() {
        do {
            catalog = try BackgroundImageService.shared.catalog()
            lblEmpty.isHidden = true
        } catch {
            catalog = []
            lblEmpty.text = error.localizedDescription
            lblEmpty.isHidden = false
        }
    }

    // MARK: - Foreground

    /// Removes the background first when this image hasn't been processed yet.
    private func ensureForeground() {
        guard let item = viewModel.item(itemID) else { return }
        if item.isCompleted {
            updatePreview()
            return
        }
        setControlsEnabled(false)
        Task { [weak self] in
            guard let self else { return }
            let original = await self.viewModel.originalPreview(for: self.itemID, maxPixel: 1400)
            self.setPreview(original)
        }
        // Shown over the preview only, so Back stays available.
        processingHUD = ProgressHUD.show(in: vwPreviewContainer, message: "Removing background…")
        viewModel.startProcessing([item.id])
    }

    private func foregroundStateChanged() {
        guard let item = viewModel.item(itemID), processingHUD != nil else { return }
        switch item.status {
        case .completed where item.isCompleted:
            processingHUD?.dismiss()
            processingHUD = nil
            setControlsEnabled(true)
            updatePreview()
        case .failed:
            processingHUD?.dismiss()
            processingHUD = nil
            presentErrorAlert(title: "Background removal failed",
                              message: item.errorMessage ?? "Please try again.",
                              retry: { [weak self] in self?.ensureForeground() })
        case .waiting where !viewModel.isProcessing:
            // Queue was cancelled elsewhere – start again.
            viewModel.startProcessing([item.id])
        default:
            break
        }
    }

    private func setControlsEnabled(_ enabled: Bool) {
        btnDone.isEnabled = enabled
        segCategory.isEnabled = enabled
        clvImages.isUserInteractionEnabled = enabled
        clvColors.isUserInteractionEnabled = enabled
        vwPanel.alpha = enabled ? 1 : 0.5
    }

    // MARK: - Preview

    private func updatePreview() {
        previewTask?.cancel()
        guard viewModel.item(itemID)?.isCompleted == true else { return }
        let selection = draft
        let id: UUID = itemID
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        vwChecker.isHidden = !selection.isTransparent
        spinner.startAnimating()
        previewTask = Task { [weak self] in
            do {
                let image = try await viewModel.compositePreview(for: id, background: selection)
                guard let self, !Task.isCancelled, self.draft == selection else { return }
                self.spinner.stopAnimating()
                self.setPreview(image)
            } catch {
                guard let self, !Task.isCancelled, self.draft == selection else { return }
                self.spinner.stopAnimating()
                self.presentErrorAlert(title: "Background unavailable",
                                       message: error.localizedDescription,
                                       retry: { [weak self] in self?.updatePreview() })
            }
        }
    }

    private func setPreview(_ image: UIImage?) {
        previewSize = image?.size
        fitPreview()
        UIView.transition(with: imgPreview, duration: 0.2, options: .transitionCrossDissolve) {
            self.imgPreview.image = image
        }
    }

    private func fitPreview() {
        let bounds = vwPreviewContainer.bounds.insetBy(dx: 16, dy: 8)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let size = previewSize ?? CGSize(width: 1, height: 1)
        let scale = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1))
        previewWidth.constant = floor(size.width * scale)
        previewHeight.constant = floor(size.height * scale)
    }

    private func select(_ selection: BackgroundSelection) {
        guard selection != draft else { return }
        draft = selection
        clvImages.reloadData()
        clvColors.reloadData()
        updatePreview()
    }

    // MARK: - Actions

    @IBAction func segCategoryChanged(_ sender: UISegmentedControl) {
        updateCategory()
    }

    private func updateCategory() {
        let showImages = segCategory.selectedSegmentIndex == 0
        clvImages.isHidden = !showImages
        clvColors.isHidden = showImages
        lblEmpty.isHidden = !showImages || !catalog.isEmpty || lblEmpty.text?.isEmpty != false
        (showImages ? clvImages : clvColors)?.reloadData()
    }

    @IBAction func btnBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func btnDone(_ sender: UIButton) {
        guard viewModel.item(itemID)?.isCompleted == true else { return }
        didApply = true
        viewModel.setBackground(draft, for: itemID)
        navigationController?.popViewController(animated: true)
    }

    private func discardUnusedCustomBackgrounds() {
        for selection in addedCustom where !(didApply && selection == draft) {
            viewModel.discardCustomBackgroundIfUnused(selection)
        }
        addedCustom.removeAll()
    }

    private func pickCustomImage() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickCustomColor() {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = customColor ?? .white
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - Collections

extension ChangeBackgroundVC: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == clvImages ? imageEntries.count : BackgroundColorOption.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == clvImages {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BackgroundImageCell", for: indexPath) as! BackgroundImageCell
            switch imageEntries[indexPath.item] {
            case .add:
                cell.configureAddButton()
            case .custom(let fileName):
                cell.configure(custom: nil, selected: draft == .customImage(fileName: fileName))
                let viewModel: BackgroundRemovalViewModel = self.viewModel
                Task { [weak cell] in
                    if case .image(let image)? = try? await viewModel.resolveBackground(.customImage(fileName: fileName), maxPixel: 320) {
                        cell?.imgThumb.image = image
                    }
                }
            case .remote(let background):
                cell.configure(remote: background, selected: draft == .remoteImage(id: background.id, url: background.image))
            }
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BackgroundColorCell", for: indexPath) as! BackgroundColorCell
        let option = BackgroundColorOption.allCases[indexPath.item]
        cell.configure(option: option, customColor: customColor, selected: isSelected(option))
        return cell
    }

    private func isSelected(_ option: BackgroundColorOption) -> Bool {
        switch (option, draft) {
        case (.transparent, .none): return true
        case (.custom, .color(let hex)): return !BackgroundColorOption.presetHexes.contains(hex)
        case (_, .color(let hex)): return option.hex == hex
        default: return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
        if collectionView == clvImages {
            let side = floor((width - 2 * 10) / 3)
            return CGSize(width: max(side, 60), height: max(side, 60))
        }
        let side = floor((width - 5 * 12) / 6)
        return CGSize(width: max(side, 40), height: max(side, 40))
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvImages ? 10 : 14
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvImages ? 10 : 12
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == clvImages {
            switch imageEntries[indexPath.item] {
            case .add:
                pickCustomImage()
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
            return
        }
        let option = BackgroundColorOption.allCases[indexPath.item]
        switch option {
        case .transparent:
            select(.none)
        case .custom:
            pickCustomColor()
        default:
            if let hex = option.hex { select(.color(hex: hex)) }
        }
    }
}

// MARK: - Custom image

extension ChangeBackgroundVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        let hud = ProgressHUD.show(in: view, message: "Adding background…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak self] in
            let picked = await PhotoPickerLoader.load(results)
            guard let photo = picked.first else {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't add image", message: "The selected photo couldn't be read.")
                return
            }
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                defer { photo.discardTemporaryFile() }
                return photo.loadImage(maxPixel: BackgroundRemovalService.maxProcessingDimension)
            }.value
            do {
                guard let image else { throw BackgroundRemovalError.invalidImage }
                let selection = try await viewModel.addCustomBackground(image)
                hud.dismiss()
                guard let self, let fileName = selection.customFileName else { return }
                self.addedCustom.append(selection)
                if !self.customFiles.contains(fileName) { self.customFiles.insert(fileName, at: 0) }
                self.select(selection)
                self.clvImages.reloadData()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't add image", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Custom colour

extension ChangeBackgroundVC: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        applyPickedColor(viewController.selectedColor)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard !continuously else { return }
        applyPickedColor(color)
    }

    private func applyPickedColor(_ color: UIColor) {
        customColor = color
        select(.color(hex: color.hexRGB))
        clvColors.reloadData()
    }
}
