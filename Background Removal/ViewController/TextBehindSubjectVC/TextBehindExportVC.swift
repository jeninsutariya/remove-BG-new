//
//  TextBehindExportVC.swift
//  Background Removal
//
//  Export sheet for Text Behind Subject: PNG (keeps transparency) or JPEG (quality slider),
//  final size, HD / Pro, Save to Photos, Share and Save project. The image is rendered at
//  the selected canvas size with the same renderer as the editor preview.
//

import UIKit

final class TextBehindExportVC: UIViewController {

    var viewModel: BackgroundRemovalViewModel!
    var itemID: UUID!
    var document = TextBehindDocument()
    var previewImage: UIImage?
    /// Full-resolution photo size (pixels).
    var photoSize = CGSize(width: 1, height: 1)
    var onFormatChange: ((ExportFormat, Double) -> Void)?

    private let previewView = UIImageView()
    private let checker = CheckerboardView(frame: .zero)
    private let sizeLabel = TBStyle.label("", size: 14, weight: .semibold)
    private let formatControl = TBStyle.segmented(["PNG", "JPEG"])
    private let qualityRow = TBSliderRow("JPEG quality", min: 50, max: 100) { "\(Int($0.rounded()))%" }
    private let noteLabel = TBStyle.label("", size: 12, weight: .regular, color: TBStyle.secondary)
    private let hdButton = TBStyle.button("Unlock full resolution with Pro", symbol: "crown.fill")
    private let saveButton = TBStyle.button("Save to Photos", symbol: "arrow.down.to.line", filled: true)
    private let shareButton = TBStyle.button("Share", symbol: "square.and.arrow.up")
    private let projectButton = TBStyle.button("Save project", symbol: "folder")
    private var task: Task<Void, Never>?
    private var observer: NSObjectProtocol?

    private var format: ExportFormat { formatControl.selectedSegmentIndex == 0 ? .png : .jpg }
    private var quality: ExportQuality { PremiumManager.shared.exportQuality }
    private var outputSize: CGSize {
        TextBehindGeometry.outputSize(photo: photoSize, canvas: document.canvas, maxDimension: quality.maxPixelDimension)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        build()
        formatControl.selectedSegmentIndex = document.exportFormat == .png ? 0 : 1
        qualityRow.value = Float(document.jpegQuality * 100)
        observer = NotificationCenter.default.addObserver(forName: PremiumManager.didChangeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        task?.cancel()
    }

    private func build() {
        let title = TBStyle.label("Export", size: 20, weight: .bold)
        title.textAlignment = .center
        checker.cellSize = 10
        checker.layer.cornerRadius = 18
        checker.clipsToBounds = true
        previewView.image = previewImage
        previewView.contentMode = .scaleAspectFit
        previewView.accessibilityLabel = "Export preview"
        let previewBox = UIView()
        previewBox.translatesAutoresizingMaskIntoConstraints = false
        [checker, previewView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            previewBox.addSubview($0)
        }
        let aspect = (previewImage?.size.width ?? 3) / max(previewImage?.size.height ?? 4, 1)
        NSLayoutConstraint.activate([
            previewBox.heightAnchor.constraint(equalToConstant: 220),
            previewView.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            previewView.topAnchor.constraint(equalTo: previewBox.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: previewBox.bottomAnchor),
            previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: aspect),
            checker.topAnchor.constraint(equalTo: previewView.topAnchor),
            checker.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            checker.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            checker.trailingAnchor.constraint(equalTo: previewView.trailingAnchor)
        ])
        sizeLabel.textAlignment = .center
        noteLabel.numberOfLines = 0
        formatControl.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        qualityRow.onChange = { [weak self] _, finished in
            if finished { self?.formatChanged() }
        }
        hdButton.addAction(UIAction { [weak self] _ in
            self?.present(ProUpgradeVC.fatchInstance(), animated: true)
        }, for: .touchUpInside)
        saveButton.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        shareButton.addAction(UIAction { [weak self] _ in self?.share() }, for: .touchUpInside)
        projectButton.addAction(UIAction { [weak self] _ in self?.saveProject() }, for: .touchUpInside)
        for button in [saveButton, shareButton, projectButton] {
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }

        let stack = TBStyle.vStack([title, previewBox, sizeLabel, TBStyle.label("Format", size: 14), formatControl,
                                    qualityRow, noteLabel, hdButton, saveButton, shareButton, projectButton], spacing: 12)
        stack.setCustomSpacing(18, after: sizeLabel)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func refresh() {
        let size = outputSize
        let full = TextBehindGeometry.canvasPixelSize(photo: photoSize, canvas: document.canvas)
        sizeLabel.text = "\(Int(size.width)) × \(Int(size.height)) px · \(format == .png ? "PNG" : "JPEG")"
        qualityRow.isHidden = format == .png
        let transparent = document.background.isTransparent
        switch format {
        case .png:
            noteLabel.text = transparent ? "PNG keeps the transparent background around the text and subject."
                                         : "PNG keeps full quality (larger file)."
        case .jpg:
            noteLabel.text = transparent ? "JPEG has no transparency – transparent areas become white. Choose PNG to keep them."
                                         : "JPEG makes a smaller file for a fully composed image."
        }
        let capped = size != full
        hdButton.isHidden = !capped
        checker.isHidden = !(transparent && format == .png)
    }

    @objc private func formatChanged() {
        onFormatChange?(format, Double(qualityRow.value) / 100)
        document.exportFormat = format
        document.jpegQuality = Double(qualityRow.value) / 100
        refresh()
    }

    // MARK: - Rendering

    /// Full-size render (the same renderer as the preview) and encoded data.
    private func renderExport() async throws -> (data: Data, fileName: String) {
        let id: UUID = itemID
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let document = self.document
        guard let original = await viewModel.fullOriginal(for: id),
              let originalCG = original.cgImage,
              let mask = await viewModel.subjectMask(for: id, settings: document.mask) else {
            throw ImageExportError.renderFailed("The photo")
        }
        var background: UIImage?
        if case .image(let selection, _) = document.background,
           case .image(let image) = try await viewModel.resolveBackground(selection) {
            background = image
        }
        let backgroundImage = background
        let format = self.format
        let jpegQuality = CGFloat(qualityRow.value) / 100
        let maxDimension = quality.maxPixelDimension
        let photo = CGSize(width: originalCG.width, height: originalCG.height)
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            autoreleasepool { () -> Data? in
                let scale = CGFloat(originalCG.width) / 1000
                let cutout = MaskRefineService.subjectCutout(original: originalCG, mask: mask,
                                                             feather: CGFloat(document.mask.feather) * scale,
                                                             smoothing: CGFloat(document.mask.edgeSmoothing) * scale)
                    .map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
                let sources = TBRenderSources(original: UIImage(cgImage: originalCG, scale: 1, orientation: .up),
                                              cutout: cutout, backgroundImage: backgroundImage, mask: nil)
                let size = TextBehindGeometry.outputSize(photo: photo, canvas: document.canvas, maxDimension: maxDimension)
                let image = TextBehindSubjectRenderer.render(document, sources: sources, size: size, opaque: format == .jpg)
                return TextBehindSubjectRenderer.encode(image, format: format, jpegQuality: jpegQuality)
            }
        }.value
        guard let data else { throw ImageExportError.renderFailed("The image") }
        let base = (viewModel.item(id)?.sourceName.map { ($0 as NSString).deletingPathExtension } ?? "TextBehind")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        return (data, "\(base.isEmpty ? "TextBehind" : base)_text.\(format.fileExtension)")
    }

    private func setBusy(_ busy: Bool) {
        [saveButton, shareButton, projectButton, formatControl].forEach { ($0 as UIControl).isEnabled = !busy }
    }

    private func save() {
        guard task == nil else { return }
        setBusy(true)
        let hud = ProgressHUD.show(in: view, message: "Rendering…")
        task = Task { [weak self] in
            defer {
                self?.task = nil
                self?.setBusy(false)
            }
            do {
                guard let self else { return }
                let output = try await self.renderExport()
                hud.update(progress: 0.7, message: "Saving to Photos…")
                try await ImageExportService.shared.savePhotoData(output.data, fileName: output.fileName)
                hud.dismiss()
                self.viewModel.recordExport(quality: self.quality)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast(message: "Saved to Photos")
            } catch ImageExportError.photosAccessDenied {
                hud.dismiss()
                self?.showPhotosSettingsAlert(message: "Allow \"Add Photos Only\" access in Settings, or use Share › Save Image / Save to Files instead.")
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't save", message: error.localizedDescription,
                                        retry: { self?.save() })
            }
        }
    }

    private func share() {
        guard task == nil else { return }
        setBusy(true)
        let hud = ProgressHUD.show(in: view, message: "Rendering…")
        task = Task { [weak self] in
            defer {
                self?.task = nil
                self?.setBusy(false)
            }
            do {
                guard let self else { return }
                let output = try await self.renderExport()
                let name = output.fileName
                let data = output.data
                let url = try await Task.detached { try ZIPExportService.shared.writeSingleFile(name: name, data: data) }.value
                hud.dismiss()
                let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                activity.popoverPresentationController?.sourceView = self.shareButton
                activity.completionWithItemsHandler = { _, _, _, _ in ZIPExportService.shared.cleanUp(url) }
                self.present(activity, animated: true)
            } catch is CancellationError {
                hud.dismiss()
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Export failed", message: error.localizedDescription,
                                        retry: { self?.share() })
            }
        }
    }

    private func saveProject() {
        viewModel.setTextBehind(document, for: itemID)
        viewModel.save()
        showToast(message: "Project saved – find it in Projects")
    }
}
