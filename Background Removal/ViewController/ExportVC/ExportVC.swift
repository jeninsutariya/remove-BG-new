//
//  ExportVC.swift
//  Background Removal
//
//  11 Export (Editor.storyboard): format, size, background, HD export (premium),
//  Save to Photos and Share. Batch projects can export this image or all images
//  (Share then creates BackgroundRemoval_Export.zip). Rendering goes through
//  ImageExportService, so the result matches the editor preview.
//

import UIKit

class ExportVC: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var vwPreviewChecker: CheckerboardView!
    @IBOutlet weak var imgPreview: UIImageView!
    @IBOutlet weak var previewWidth: NSLayoutConstraint!
    @IBOutlet weak var lblFileName: UILabel!
    @IBOutlet weak var lblDimensions: UILabel!
    @IBOutlet weak var segScope: UISegmentedControl!
    @IBOutlet weak var scopeHeight: NSLayoutConstraint!
    @IBOutlet weak var vwOptions: UIView!
    @IBOutlet weak var segFormat: UISegmentedControl!
    @IBOutlet weak var btnSize: UIButton!
    @IBOutlet weak var btnBackground: UIButton!
    @IBOutlet weak var lblNote: UILabel!
    @IBOutlet weak var vwHD: UIView!
    @IBOutlet weak var lblHDSubtitle: UILabel!
    @IBOutlet weak var vwProBadge: UIView!
    @IBOutlet weak var imgHDChevron: UIImageView!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var btnShare: UIButton!

    // MARK: - Input

    var viewModel: BackgroundRemovalViewModel!
    /// Image shown in the preview (and exported with "This image").
    var itemID: UUID?

    // MARK: - Options

    private enum SizeOption: CaseIterable {
        case original, large, medium, small

        var title: String {
            switch self {
            case .original: return "Original"
            case .large: return "Large"
            case .medium: return "Medium"
            case .small: return "Small"
            }
        }

        var maxDimension: CGFloat? {
            switch self {
            case .original: return nil
            case .large: return 1600
            case .medium: return 1080
            case .small: return 720
            }
        }
    }

    private enum BackgroundOption: CaseIterable {
        case edited, transparent, white
    }

    private var format: ExportFormat = .png
    private var size: SizeOption = .original
    private var background: BackgroundOption = .edited
    private var exportAll = false
    private var previewTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    private var quality: ExportQuality { ExportQuality.current }

    private var item: BackgroundRemovalItem? {
        itemID.flatMap { viewModel.item($0) } ?? viewModel.project.completedItems.first
    }

    private var exportItems: [BackgroundRemovalItem] {
        exportAll ? viewModel.project.completedItems : (item.map { [$0] } ?? [])
    }

    private var options: ExportOptions {
        let override: BackgroundSelection?
        switch background {
        case .edited: override = nil
        case .transparent: override = BackgroundSelection.none
        case .white: override = .color(hex: "FFFFFF")
        }
        return ExportOptions(format: format, maxDimension: size.maxDimension, backgroundOverride: override)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        if let item { format = item.background.isTransparent ? .png : .jpg }
        setupUI()
        observers.append(NotificationCenter.default.addObserver(forName: .refreshPremiumLog,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()   // the user may have upgraded on the Pro screen
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { applyBorders() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        previewTask?.cancel()
    }

    private func setupUI() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnBack.layer.cornerRadius = 22
        btnBack.accessibilityLabel = "Back"
        vwPreviewChecker.layer.cornerRadius = 26
        vwPreviewChecker.clipsToBounds = true
        vwPreviewChecker.cellSize = 12.5
        imgPreview.contentMode = .scaleAspectFit
        vwOptions.layer.cornerRadius = 24
        vwHD.layer.cornerRadius = 24
        vwProBadge.layer.cornerRadius = 12
        btnSave.layer.cornerRadius = 29
        btnShare.layer.cornerRadius = 27
        segFormat.applyEditorStyle()
        segScope.applyEditorStyle()
        btnSave.setSymbol("arrow.down.to.line", size: 17, weight: .bold)
        btnSave.tintColor = .white
        btnShare.setSymbol("square.and.arrow.up", size: 16, weight: .bold)
        btnShare.tintColor = UIColor(named: "AccentColor")
        imgHDChevron.image = UIImage(systemName: "chevron.right",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        imgHDChevron.tintColor = UIColor(named: "PrimaryText")
        for button in [btnSave!, btnShare!] {
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        }
        let count = viewModel.project.completedItems.count
        segScope.setTitle("This image", forSegmentAt: 0)
        segScope.setTitle("All \(count) images", forSegmentAt: 1)
        segScope.selectedSegmentIndex = 0
        let multiple = count > 1
        segScope.isHidden = !multiple
        scopeHeight.constant = multiple ? 44 : 0
        applyBorders()
    }

    private func applyBorders() {
        let border = (UIColor(named: "Border Color") ?? .lightGray).cgColor
        for view in [btnBack!, vwOptions!, vwHD!] {
            view.layer.borderWidth = 1
            view.layer.borderColor = border
        }
        btnShare.layer.borderWidth = 1
        btnShare.layer.borderColor = (UIColor(named: "BrandPrimary") ?? .lightGray).cgColor
    }

    // MARK: - Display

    private func backgroundTitle(_ option: BackgroundOption) -> String {
        switch option {
        case .edited:
            switch item?.background {
            case .color?: return "Color"
            case .remoteImage?, .customImage?: return "Photo"
            default: return "Transparent"
            }
        case .transparent: return "Transparent"
        case .white: return "White"
        }
    }

    private var fileName: String {
        if exportAll { return "BackgroundRemoval_Export.zip" }
        var namer = UniqueFileNamer()
        return namer.name(for: item?.sourceName, index: 1, fileExtension: format.fileExtension)
    }

    private func refresh() {
        guard isViewLoaded, let item else { return }
        segFormat.selectedSegmentIndex = format.rawValue
        lblFileName.text = fileName
        btnSize.setTitle("\(size.title)  ›", for: .normal)
        btnBackground.setTitle("\(backgroundTitle(background))  ›", for: .normal)

        let options = self.options
        let effective = options.background(for: item)
        if format == .jpg {
            lblNote.text = "JPG files are smaller. Transparent areas become white."
        } else {
            lblNote.text = effective.isTransparent ? "PNG keeps the transparent background." : "PNG keeps full quality."
        }
        let premium = UserDefaults.isPremiumUser
        vwProBadge.isHidden = premium
        imgHDChevron.isHidden = premium
        lblHDSubtitle.text = premium ? "Full resolution is on" :
            "Free exports up to \(Int(ExportQuality.standardMaxPixelDimension)) px · Full resolution with Pro"
        vwHD.accessibilityLabel = "HD export. \(lblHDSubtitle.text ?? "")"

        updateDimensions(for: item, options: options)
        renderPreview(for: item, background: effective)
    }

    private func updateDimensions(for item: BackgroundRemovalItem, options: ExportOptions) {
        guard let name = item.foregroundFileName else { return }
        let url = ProjectStorageService.shared.fileURL(name, projectID: viewModel.project.id)
        guard let pixel = ImageUtilities.pixelSize(at: url) else { return }
        let output = ImageCompositingService.shared.outputSize(for: pixel, edits: item.edits,
                                                               maxDimension: options.maxDimension(for: quality))
        let text = "\(Int(output.width)) × \(Int(output.height)) px"
        lblDimensions.text = exportAll ? "\(viewModel.project.completedItems.count) images · this one \(text)" : text
    }

    private func renderPreview(for item: BackgroundRemovalItem, background: BackgroundSelection) {
        previewTask?.cancel()
        vwPreviewChecker.isHidden = !background.isTransparent
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let id = item.id
        let edits = item.edits
        previewTask = Task { [weak self] in
            let image = try? await viewModel.compositePreview(for: id, background: background, edits: edits, maxPixel: 600)
            guard let self, !Task.isCancelled else { return }
            self.imgPreview.image = image
            if let size = image?.size, size.height > 0 {
                // Card keeps the export's aspect ratio (height fixed in the storyboard).
                let height = self.vwPreviewChecker.bounds.height > 0 ? self.vwPreviewChecker.bounds.height : 180
                self.previewWidth.constant = min(300, max(90, height * size.width / size.height))
            }
        }
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) {
        exportTask?.cancel()
        navigationController?.popViewController(animated: true)
    }

    @IBAction func segScopeChanged(_ sender: UISegmentedControl) {
        exportAll = sender.selectedSegmentIndex == 1
        refresh()
    }

    @IBAction func segFormatChanged(_ sender: UISegmentedControl) {
        format = ExportFormat(rawValue: sender.selectedSegmentIndex) ?? .png
        refresh()
    }

    @IBAction func btnSize(_ sender: UIButton) {
        let cap = quality.maxPixelDimension
        let message = cap.map { "Free exports are limited to \(Int($0)) px. Upgrade to Pro for full resolution." }
        let sheet = UIAlertController(title: "Export size", message: message, preferredStyle: .actionSheet)
        for option in SizeOption.allCases {
            var title = option.title
            if let limit = option.maxDimension { title += " · up to \(Int(limit)) px" }
            if option == size { title += "  ✓" }
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.size = option
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds
        present(sheet, animated: true)
    }

    @IBAction func btnBackground(_ sender: UIButton) {
        let sheet = UIAlertController(title: "Background", message: nil, preferredStyle: .actionSheet)
        for option in BackgroundOption.allCases {
            let base = option == .edited ? "As edited (\(backgroundTitle(.edited)))" : backgroundTitle(option)
            sheet.addAction(UIAlertAction(title: base + (option == background ? "  ✓" : ""), style: .default) { [weak self] _ in
                self?.background = option
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds
        present(sheet, animated: true)
    }

    @IBAction func btnHD(_ sender: UIButton) {
        guard !UserDefaults.isPremiumUser else { return }
        let vc = ProUpgradeVC.fatchInstance()
        present(vc, animated: true)
    }

    @IBAction func btnSave(_ sender: UIButton) {
        let items = exportItems
        guard exportTask == nil, !items.isEmpty, !ImageExportService.shared.isBusy else { return }
        let hud = ProgressHUD.show(in: view, message: items.count > 1 ? "Saving \(items.count) images…" : "Saving…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let options = self.options
        exportTask = Task { [weak self] in
            defer { self?.exportTask = nil }
            do {
                let count = try await ImageExportService.shared.saveToPhotos(items: items, in: viewModel, options: options) { value in
                    hud.update(progress: value)
                }
                hud.dismiss()
                if count > 0 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showToast(message: count > 1 ? "\(count) images saved to Photos" : "Saved to Photos")
                }
            } catch ImageExportError.photosAccessDenied {
                hud.dismiss()
                self?.showPhotosSettingsAlert(message: ImageExportError.photosAccessDenied.errorDescription ?? "")
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't save", message: error.localizedDescription,
                                        retry: { self?.btnSave(sender) })
            }
        }
    }

    @IBAction func btnShare(_ sender: UIButton) {
        let items = exportItems
        guard exportTask == nil, !items.isEmpty else { return }
        let hud = ProgressHUD.show(in: view, message: items.count > 1 ? "Preparing \(items.count) images…" : "Preparing…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let options = self.options
        let quality = self.quality
        let zip = exportAll
        exportTask = Task { [weak self] in
            defer { self?.exportTask = nil }
            do {
                let outputs = try await ImageExportService.shared.renderOutputs(for: items, in: viewModel, quality: quality,
                                                                                options: options) { value in
                    hud.update(progress: value * 0.9)
                }
                let fileURL: URL
                if !zip, let output = outputs.first {
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
                hud.dismiss()
                viewModel.recordExport(quality: quality)
                self?.share(fileURL, sourceView: sender)
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Export failed", message: error.localizedDescription,
                                        retry: { self?.btnShare(sender) })
            }
        }
    }

    private func share(_ url: URL, sourceView: UIView) {
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = sourceView
        activity.popoverPresentationController?.sourceRect = sourceView.bounds
        activity.completionWithItemsHandler = { _, _, _, _ in
            ZIPExportService.shared.cleanUp(url)
        }
        present(activity, animated: true)
    }
}
