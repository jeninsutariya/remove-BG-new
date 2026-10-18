//
//  TextBehindExportVC.swift
//  Background Removal
//
//  Export screen for Text Behind Subject (same layout as ExportVC): PNG (keeps transparency) or JPEG (quality slider),
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

    // Same structure and styling as ExportVC (11 Export): top bar, scrolling settings,
    // Save to Photos / Share fixed at the bottom.
    private let backButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let previewView = UIImageView()
    private let checker = CheckerboardView(frame: .zero)
    private let fileLabel = TBStyle.label("", size: 15, weight: .bold)
    private let sizeLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let formatControl = UISegmentedControl(items: ["PNG", "JPG"])
    private let qualityRow = TBSliderRow("JPEG quality", min: 50, max: 100) { "\(Int($0.rounded()))%" }
    private let noteLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let hdView = UIView()
    private let hdSubtitle = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let proBadge = UIView()
    private let hdChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let saveButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let projectButton = UIButton(type: .system)
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the last settings reachable above the fixed buttons on every screen size.
        scrollView.contentInset.bottom = 12
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        task?.cancel()
    }

    private func card(_ view: UIView) -> UIView {
        view.backgroundColor = TBStyle.surface
        view.layer.cornerRadius = 24
        view.layer.borderWidth = 1
        view.layer.borderColor = TBStyle.border.cgColor
        return view
    }

    private func build() {
        // Top bar
        backButton.setSymbol("chevron.left", size: 17, weight: .bold)
        backButton.tintColor = TBStyle.text
        backButton.backgroundColor = TBStyle.surface
        backButton.layer.cornerRadius = 22
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = TBStyle.border.cgColor
        backButton.accessibilityLabel = "Back"
        backButton.addAction(UIAction { [weak self] _ in
            self?.task?.cancel()
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        let title = TBStyle.label("Export", size: 18, weight: .bold)
        title.textAlignment = .center

        // Preview card
        checker.cellSize = 12.5
        checker.layer.cornerRadius = 26
        checker.clipsToBounds = true
        previewView.image = previewImage
        previewView.contentMode = .scaleAspectFit
        previewView.layer.cornerRadius = 26
        previewView.clipsToBounds = true
        previewView.accessibilityLabel = "Export preview"
        let previewBox = UIView()
        [checker, previewView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            previewBox.addSubview($0)
        }
        let aspect = (previewImage?.size.width ?? 3) / max(previewImage?.size.height ?? 4, 1)
        let fillHeight = previewView.heightAnchor.constraint(equalTo: previewBox.heightAnchor)
        fillHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            previewBox.heightAnchor.constraint(equalToConstant: 200),
            previewView.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor),
            previewView.heightAnchor.constraint(lessThanOrEqualTo: previewBox.heightAnchor),
            previewView.widthAnchor.constraint(lessThanOrEqualTo: previewBox.widthAnchor),
            previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: aspect),
            fillHeight,
            checker.topAnchor.constraint(equalTo: previewView.topAnchor),
            checker.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            checker.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            checker.trailingAnchor.constraint(equalTo: previewView.trailingAnchor)
        ])
        fileLabel.textAlignment = .center
        sizeLabel.textAlignment = .center

        // Options card: Format, Quality
        formatControl.applyEditorStyle()
        formatControl.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        formatControl.translatesAutoresizingMaskIntoConstraints = false
        formatControl.widthAnchor.constraint(equalToConstant: 132).isActive = true
        formatControl.heightAnchor.constraint(equalToConstant: 40).isActive = true
        qualityRow.onChange = { [weak self] _, finished in
            if finished { self?.formatChanged() }
        }
        let formatRow = TBStyle.hStack([TBStyle.label("Format", size: 16), UIView(), formatControl])
        let separator = UIView()
        separator.backgroundColor = TBStyle.border
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let optionsStack = TBStyle.vStack([formatRow, separator, qualityRow], spacing: 12)
        let options = card(UIView())
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        options.addSubview(optionsStack)
        NSLayoutConstraint.activate([
            optionsStack.topAnchor.constraint(equalTo: options.topAnchor, constant: 12),
            optionsStack.leadingAnchor.constraint(equalTo: options.leadingAnchor, constant: 18),
            optionsStack.trailingAnchor.constraint(equalTo: options.trailingAnchor, constant: -14),
            optionsStack.bottomAnchor.constraint(equalTo: options.bottomAnchor, constant: -14)
        ])
        noteLabel.numberOfLines = 0

        // HD export card (opens Pro when the export is size-limited)
        let hdTitle = TBStyle.label("HD export", size: 16)
        hdSubtitle.numberOfLines = 2
        proBadge.backgroundColor = UIColor(named: "Badge Color") ?? TBStyle.field
        proBadge.layer.cornerRadius = 12
        let badgeLabel = TBStyle.label("PRO", size: 12, weight: .bold, color: UIColor(named: "Link Color") ?? TBStyle.accent)
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        proBadge.addSubview(badgeLabel)
        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: proBadge.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: proBadge.trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: proBadge.centerYAnchor),
            proBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
        hdChevron.tintColor = TBStyle.text
        hdChevron.contentMode = .scaleAspectFit
        hdChevron.widthAnchor.constraint(equalToConstant: 14).isActive = true
        let hdText = TBStyle.vStack([hdTitle, hdSubtitle], spacing: 2)
        let hdRow = TBStyle.hStack([hdText, UIView(), proBadge, hdChevron], spacing: 6)
        hdRow.translatesAutoresizingMaskIntoConstraints = false
        _ = card(hdView)
        hdView.addSubview(hdRow)
        NSLayoutConstraint.activate([
            hdRow.topAnchor.constraint(equalTo: hdView.topAnchor, constant: 11),
            hdRow.leadingAnchor.constraint(equalTo: hdView.leadingAnchor, constant: 18),
            hdRow.trailingAnchor.constraint(equalTo: hdView.trailingAnchor, constant: -14),
            hdRow.bottomAnchor.constraint(equalTo: hdView.bottomAnchor, constant: -11)
        ])
        hdView.isAccessibilityElement = true
        hdView.accessibilityTraits = .button
        hdView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hdTapped)))

        projectButton.setTitle("Save project for later", for: .normal)
        projectButton.titleLabel?.font = TBStyle.font(14, .semibold)
        projectButton.setTitleColor(TBStyle.accent, for: .normal)
        projectButton.addAction(UIAction { [weak self] _ in self?.saveProject() }, for: .touchUpInside)

        // Scrolling settings
        let content = TBStyle.vStack([previewBox, fileLabel, sizeLabel, options, noteLabel, hdView, projectButton], spacing: 12)
        content.setCustomSpacing(2, after: fileLabel)
        content.setCustomSpacing(20, after: sizeLabel)
        content.setCustomSpacing(20, after: noteLabel)

        // Fixed buttons
        saveButton.setTitle("  Save to Photos", for: .normal)
        saveButton.setSymbol("arrow.down.to.line", size: 17, weight: .bold)
        saveButton.titleLabel?.font = TBStyle.font(18, .bold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.tintColor = .white
        saveButton.backgroundColor = TBStyle.accent
        saveButton.layer.cornerRadius = 29
        saveButton.addAction(UIAction { [weak self] _ in self?.save() }, for: .touchUpInside)
        shareButton.setTitle("  Share", for: .normal)
        shareButton.setSymbol("square.and.arrow.up", size: 16, weight: .bold)
        shareButton.titleLabel?.font = TBStyle.font(17, .bold)
        shareButton.setTitleColor(TBStyle.accent, for: .normal)
        shareButton.tintColor = TBStyle.accent
        shareButton.backgroundColor = TBStyle.surface
        shareButton.layer.cornerRadius = 27
        shareButton.layer.borderWidth = 1
        shareButton.layer.borderColor = (UIColor(named: "BrandPrimary") ?? TBStyle.border).cgColor
        shareButton.addAction(UIAction { [weak self] _ in self?.share() }, for: .touchUpInside)

        [backButton, title, scrollView, saveButton, shareButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        scrollView.alwaysBounceVertical = true
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -12),
            // Vertical scrolling: content pinned to the content guide, width to the frame guide.
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            saveButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 58),
            shareButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 10),
            shareButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            shareButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            shareButton.heightAnchor.constraint(equalToConstant: 54),
            shareButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8)
        ])
    }

    private func refresh() {
        let size = outputSize
        let full = TextBehindGeometry.canvasPixelSize(photo: photoSize, canvas: document.canvas)
        fileLabel.text = exportFileName(format: format)
        sizeLabel.text = "\(Int(size.width)) × \(Int(size.height)) px"
        qualityRow.isUserInteractionEnabled = format == .jpg
        qualityRow.alpha = format == .jpg ? 1 : 0.4
        let transparent = document.background.isTransparent
        switch format {
        case .png:
            noteLabel.text = transparent ? "PNG keeps the transparent background around the text and subject."
                                         : "PNG keeps full quality (larger file)."
        case .jpg:
            noteLabel.text = transparent ? "JPG has no transparency – transparent areas become white. Choose PNG to keep them."
                                         : "JPG makes a smaller file for a fully composed image."
        }
        let capped = size != full
        proBadge.isHidden = !capped
        hdChevron.isHidden = !capped
        hdSubtitle.text = capped ? "Free exports up to \(Int(ExportQuality.standardMaxPixelDimension)) px · Full resolution with Pro"
                                 : "Full resolution"
        hdView.accessibilityLabel = "HD export. \(hdSubtitle.text ?? "")"
        checker.isHidden = !(transparent && format == .png)
    }

    private func exportFileName(format: ExportFormat) -> String {
        let base = (viewModel.item(itemID)?.sourceName.map { ($0 as NSString).deletingPathExtension } ?? "TextBehind")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        return "\(base.isEmpty ? "TextBehind" : base)_text.\(format.fileExtension)"
    }

    @objc private func hdTapped() {
        guard outputSize != TextBehindGeometry.canvasPixelSize(photo: photoSize, canvas: document.canvas) else { return }
        present(ProUpgradeVC.fatchInstance(), animated: true)
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
        return (data, exportFileName(format: format))
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
