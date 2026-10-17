//
//  RemovingBackgroundEditorVC.swift
//  Background Removal
//
//  Result screen: large preview (checkerboard behind transparent areas – UI only),
//  thumbnail strip for multi-image projects, and Background / Save / Export actions.
//

import UIKit

class RemovingBackgroundEditorVC: UIViewController {

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnSelect: UIButton!
    @IBOutlet weak var vwPreviewContainer: UIView!
    @IBOutlet weak var vwPreviewCard: UIView!
    @IBOutlet weak var vwChecker: CheckerboardView!
    @IBOutlet weak var imgPreview: UIImageView!
    @IBOutlet weak var previewWidth: NSLayoutConstraint!
    @IBOutlet weak var previewHeight: NSLayoutConstraint!
    @IBOutlet weak var vwStatusOverlay: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var btnRetry: UIButton!
    @IBOutlet weak var btnQuality: UIButton!
    @IBOutlet weak var clvThumbnails: UICollectionView!
    @IBOutlet weak var thumbnailsHeight: NSLayoutConstraint!
    @IBOutlet weak var btnBackground: UIButton!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var btnExport: UIButton!

    /// Set by the presenter before the screen appears.
    var viewModel: BackgroundRemovalViewModel!

    private var currentItemID: UUID?
    private var isSelecting = false
    private var selectedIDs = Set<UUID>()
    private var previewTask: Task<Void, Never>?
    private var previewSize: CGSize?
    private var observers: [NSObjectProtocol] = []
    private var exportTask: Task<Void, Never>?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        currentItemID = viewModel.project.completedItems.first?.id ?? viewModel.items.first?.id
        setupViews()
        observe()
        reloadAll()
        // Resume items that were not finished (e.g. after relaunch). Failed items wait for Retry.
        if viewModel.hasPendingItems { viewModel.startProcessing() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Background may have changed in ChangeBackgroundVC.
        refreshQuality()
        clvThumbnails.reloadData()
        showCurrentItem(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitPreview()
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

        vwPreviewCard.layer.cornerRadius = 22
        vwPreviewCard.layer.cornerCurve = .continuous
        vwPreviewCard.clipsToBounds = true
        vwPreviewCard.layer.borderWidth = 1
        vwPreviewCard.layer.borderColor = UIColor(named: "Border Color")?.cgColor
        imgPreview.contentMode = .scaleAspectFit
        imgPreview.isAccessibilityElement = true

        vwStatusOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        lblStatus.textColor = .white
        spinner.color = .white
        btnRetry.layer.cornerRadius = 18
        btnRetry.contentEdgeInsets = UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)

        configureAction(btnBackground, title: "Background", symbol: "photo.on.rectangle.angled", filled: false)
        configureAction(btnSave, title: "Save", symbol: "square.and.arrow.down", filled: false)
        configureAction(btnExport, title: "Export", symbol: "square.and.arrow.up", filled: true)

        clvThumbnails.register(UINib(nibName: "ProcessedImageCell", bundle: nil), forCellWithReuseIdentifier: "ProcessedImageCell")
        clvThumbnails.dataSource = self
        clvThumbnails.delegate = self
        clvThumbnails.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        if let layout = clvThumbnails.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 64, height: 64)
            layout.minimumLineSpacing = 10
        }
    }

    private func configureAction(_ button: UIButton, title: String, symbol: String, filled: Bool) {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.cornerStyle = .large
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        config.imagePadding = 6
        config.baseBackgroundColor = filled ? UIColor(named: "AccentColor") : UIColor(named: "Ultra Light Blue")
        config.baseForegroundColor = filled ? .white : UIColor(named: "PrimaryText")
        var attributes = AttributeContainer()
        attributes.font = UIFont(name: "Figtree-Bold", size: 15) ?? .systemFont(ofSize: 15, weight: .bold)
        config.attributedTitle = AttributedString(title, attributes: attributes)
        button.configuration = config
        button.backgroundColor = .clear
    }

    private func setActionTitle(_ button: UIButton, _ title: String) {
        guard var config = button.configuration else { return }
        var attributes = AttributeContainer()
        attributes.font = UIFont(name: "Figtree-Bold", size: 15) ?? .systemFont(ofSize: 15, weight: .bold)
        config.attributedTitle = AttributedString(title, attributes: attributes)
        button.configuration = config
    }

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: BackgroundRemovalViewModel.itemDidChangeNotification,
                                            object: viewModel, queue: .main) { [weak self] note in
            let id = note.userInfo?[BackgroundRemovalViewModel.itemIDKey] as? UUID
            MainActor.assumeIsolated { self?.itemDidChange(id) }
        })
        observers.append(center.addObserver(forName: PremiumManager.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshQuality() }
        })
    }

    // MARK: - State

    private var currentItem: BackgroundRemovalItem? {
        currentItemID.flatMap { viewModel.item($0) }
    }

    private func reloadAll() {
        let multiple = viewModel.items.count > 1
        thumbnailsHeight.constant = multiple ? 76 : 0
        clvThumbnails.isHidden = !multiple
        btnSelect.isHidden = !multiple
        lblTitle.text = viewModel.project.name
        refreshQuality()
        updateSelectionUI()
        clvThumbnails.reloadData()
        showCurrentItem(animated: false)
    }

    private func itemDidChange(_ id: UUID?) {
        guard let id, let index = viewModel.items.firstIndex(where: { $0.id == id }) else { return }
        if clvThumbnails.numberOfItems(inSection: 0) == viewModel.items.count {
            clvThumbnails.reloadItems(at: [IndexPath(item: index, section: 0)])
        } else {
            clvThumbnails.reloadData()
        }
        if id == currentItemID { showCurrentItem(animated: true) }
        updateActionAvailability()
    }

    private func refreshQuality() {
        let premium = PremiumManager.shared.isPremium
        let title = premium ? "Full quality" : "Standard quality · up to \(Int(ExportQuality.standardMaxPixelDimension)) px"
        let symbol = premium ? "checkmark.seal.fill" : "crown.fill"
        btnQuality.setTitle("  " + title, for: .normal)
        btnQuality.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        btnQuality.tintColor = premium ? UIColor(named: "AccentColor") : UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1)
        btnQuality.accessibilityHint = premium ? nil : "Opens the premium screen to unlock full-quality export"
    }

    private func updateSelectionUI() {
        btnSelect.setTitle(isSelecting ? "Done" : "Select", for: .normal)
        if isSelecting {
            setActionTitle(btnSave, selectedIDs.isEmpty ? "Save" : "Save (\(selectedIDs.count))")
            setActionTitle(btnExport, selectedIDs.isEmpty ? "Export" : "Export (\(selectedIDs.count))")
        } else {
            setActionTitle(btnSave, "Save")
            setActionTitle(btnExport, "Export")
        }
        updateActionAvailability()
    }

    private func updateActionAvailability() {
        let anyDone = !viewModel.project.completedItems.isEmpty
        let currentDone = currentItem?.isCompleted == true
        btnBackground.isEnabled = !isSelecting && currentItem != nil
        if isSelecting {
            let ready = viewModel.items.contains { selectedIDs.contains($0.id) && $0.isCompleted }
            btnSave.isEnabled = ready
            btnExport.isEnabled = ready
        } else {
            btnSave.isEnabled = anyDone || currentDone
            btnExport.isEnabled = anyDone
        }
    }

    // MARK: - Preview

    private func showCurrentItem(animated: Bool) {
        previewTask?.cancel()
        guard let item = currentItem else {
            imgPreview.image = nil
            vwStatusOverlay.isHidden = true
            return
        }
        updateActionAvailability()
        vwChecker.isHidden = !(item.isCompleted && item.background.isTransparent)
        imgPreview.accessibilityLabel = "\(item.sourceName ?? "Image"), \(item.status.displayName)"

        switch item.status {
        case .completed where item.isCompleted:
            vwStatusOverlay.isHidden = true
        case .failed:
            showOverlay(spinning: false, text: item.errorMessage ?? "Background removal failed.", retry: true)
        case .processing:
            showOverlay(spinning: true, text: "Removing background…", retry: false)
        default:
            showOverlay(spinning: false, text: "Waiting…", retry: false)
        }

        let id = item.id
        let viewModel = self.viewModel!
        previewTask = Task { [weak self] in
            var image: UIImage?
            var failure: Error?
            if item.isCompleted {
                do {
                    image = try await viewModel.compositePreview(for: id, background: item.background)
                } catch {
                    failure = error
                    image = await viewModel.foregroundPreview(for: id, maxPixel: 1400)
                }
            } else {
                image = await viewModel.originalPreview(for: id, maxPixel: 1400)
            }
            guard let self, !Task.isCancelled, self.currentItemID == id else { return }
            self.setPreview(image, animated: animated)
            if failure != nil {
                self.vwChecker.isHidden = false
                showToast(message: "Background couldn't be loaded. Check your connection.")
            }
        }
    }

    private func showOverlay(spinning: Bool, text: String, retry: Bool) {
        vwStatusOverlay.isHidden = false
        spinning ? spinner.startAnimating() : spinner.stopAnimating()
        lblStatus.text = text
        btnRetry.isHidden = !retry
    }

    private func setPreview(_ image: UIImage?, animated: Bool) {
        previewSize = image?.size
        fitPreview()
        if animated {
            UIView.transition(with: imgPreview, duration: 0.25, options: .transitionCrossDissolve) {
                self.imgPreview.image = image
            }
        } else {
            imgPreview.image = image
        }
    }

    /// Sizes the preview card to the image aspect ratio inside the available area.
    private func fitPreview() {
        let bounds = vwPreviewContainer.bounds.insetBy(dx: 16, dy: 8)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let size = previewSize ?? CGSize(width: 1, height: 1)
        let scale = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1))
        let width = floor(size.width * scale)
        let height = floor(size.height * scale)
        if previewWidth.constant != width || previewHeight.constant != height {
            previewWidth.constant = width
            previewHeight.constant = height
        }
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) {
        exportTask?.cancel()
        // Processing stops when the user leaves; unfinished items stay "Waiting" in the saved project.
        viewModel.cancelProcessing()
        navigationController?.popViewController(animated: true)
    }

    @IBAction func btnSelect(_ sender: UIButton) {
        isSelecting.toggle()
        if isSelecting {
            selectedIDs = Set(viewModel.project.completedItems.map(\.id))
        } else {
            selectedIDs.removeAll()
        }
        updateSelectionUI()
        clvThumbnails.reloadData()
    }

    @IBAction func btnRetry(_ sender: UIButton) {
        guard let id = currentItemID else { return }
        viewModel.retry(id)
    }

    @IBAction func btnQuality(_ sender: UIButton) {
        let premium = ProUpgradeVC.fatchInstance()
        present(premium, animated: true)
    }

    @IBAction func btnBackground(_ sender: UIButton) {
        guard let id = currentItemID else { return }
        let vc = ChangeBackgroundVC.fatchEditorInstance()
        vc.viewModel = viewModel
        vc.itemID = id
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func btnSave(_ sender: UIButton) {
        guard exportTask == nil else { return }
        if isSelecting {
            save(viewModel.items.filter { selectedIDs.contains($0.id) })
            return
        }
        let completed = viewModel.project.completedItems
        guard completed.count > 1 else {
            save(currentItem?.isCompleted == true ? [currentItem!] : completed)
            return
        }
        let sheet = UIAlertController(title: "Save to Photos", message: nil, preferredStyle: .actionSheet)
        if let current = currentItem, current.isCompleted {
            sheet.addAction(UIAlertAction(title: "Save this image", style: .default) { [weak self] _ in self?.save([current]) })
        }
        sheet.addAction(UIAlertAction(title: "Save all \(completed.count) images", style: .default) { [weak self] _ in
            self?.save(completed)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        present(sheet, animated: true)
    }

    @IBAction func btnExport(_ sender: UIButton) {
        guard exportTask == nil else { return }
        let items = isSelecting ? viewModel.items.filter { selectedIDs.contains($0.id) } : viewModel.project.completedItems
        export(items.filter(\.isCompleted), sourceView: sender)
    }

    // MARK: - Save / Export

    private func save(_ items: [BackgroundRemovalItem]) {
        guard !items.isEmpty, !ImageExportService.shared.isBusy else { return }
        let hud = ProgressHUD.show(in: view, message: items.count > 1 ? "Saving \(items.count) images…" : "Saving…")
        let viewModel = self.viewModel!
        exportTask = Task { [weak self] in
            defer { self?.exportTask = nil }
            do {
                let count = try await ImageExportService.shared.saveToPhotos(items: items, in: viewModel) { value in
                    hud.update(progress: value)
                }
                hud.dismiss()
                if count > 0 { showToast(message: count > 1 ? "\(count) images saved to Photos" : "Saved to Photos") }
            } catch ImageExportError.photosAccessDenied {
                hud.dismiss()
                self?.showPhotosSettingsAlert(message: ImageExportError.photosAccessDenied.errorDescription ?? "")
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't save", message: error.localizedDescription,
                                        retry: { self?.save(items) })
            }
        }
    }

    private func export(_ items: [BackgroundRemovalItem], sourceView: UIView) {
        guard !items.isEmpty else {
            presentErrorAlert(title: "Nothing to export", message: ImageExportError.nothingToExport.errorDescription ?? "")
            return
        }
        let hud = ProgressHUD.show(in: view, message: items.count > 1 ? "Preparing \(items.count) images…" : "Preparing…")
        let viewModel = self.viewModel!
        let quality = PremiumManager.shared.exportQuality
        exportTask = Task { [weak self] in
            defer { self?.exportTask = nil }
            do {
                let outputs = try await ImageExportService.shared.renderOutputs(for: items, in: viewModel, quality: quality) { value in
                    hud.update(progress: value * 0.9)
                }
                let fileURL: URL
                if outputs.count == 1, let output = outputs.first {
                    let name = output.fileName
                    let data = output.data
                    fileURL = try await Task.detached { try ZIPExportService.shared.writeSingleFile(name: name, data: data) }.value
                } else {
                    // Archive entries are numbered in project order: Image_001.png, Image_002.jpg…
                    let files = outputs.enumerated().map { index, output in
                        (name: String(format: "Image_%03d.%@", index + 1, output.isPNG ? "png" : "jpg"), data: output.data)
                    }
                    fileURL = try await Task.detached { try ZIPExportService.shared.createArchive(files: files) }.value
                }
                hud.update(progress: 1)
                hud.dismiss()
                viewModel.recordExport(quality: quality)
                self?.share(fileURL, sourceView: sourceView)
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Export failed", message: error.localizedDescription,
                                        retry: { self?.export(items, sourceView: sourceView) })
            }
        }
    }

    private func share(_ url: URL, sourceView: UIView) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = sourceView
        activity.completionWithItemsHandler = { _, _, _, _ in
            ZIPExportService.shared.cleanUp(url)
        }
        present(activity, animated: true)
    }
}

// MARK: - Thumbnail strip

extension RemovingBackgroundEditorVC: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProcessedImageCell", for: indexPath) as! ProcessedImageCell
        let item = viewModel.items[indexPath.item]
        cell.configure(item: item, isCurrent: item.id == currentItemID, selectionMode: isSelecting,
                       isChecked: selectedIDs.contains(item.id))
        let id = item.id
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak cell] in
            let image = await viewModel.thumbnail(for: id)
            cell?.setThumbnail(image, for: id)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = viewModel.items[indexPath.item]
        if isSelecting {
            guard item.isCompleted else {
                showToast(message: "Only finished images can be selected")
                return
            }
            if selectedIDs.contains(item.id) { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
            updateSelectionUI()
            collectionView.reloadItems(at: [indexPath])
            return
        }
        guard item.id != currentItemID else {
            if item.status == .failed { viewModel.retry(item.id) }
            return
        }
        currentItemID = item.id
        collectionView.reloadData()
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        showCurrentItem(animated: true)
    }
}
