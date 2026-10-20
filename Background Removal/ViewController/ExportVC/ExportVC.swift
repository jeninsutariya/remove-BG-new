//
//  ExportVC.swift
//  Background Removal
//
//  The one Export screen for every feature (Remove Background, Batch Remove, Change Background
//  and Text Behind Subject), with the Text Behind export layout: preview, file name and size,
//  Format (PNG keeps transparency / JPG with a quality slider), HD / Pro, Save project,
//  and Save to Photos / Share fixed at the bottom.
//
//  • Cutout projects render through ImageExportService (same compositor as the editor) and
//    also offer Size and Background; batch projects can export this image or all images
//    (Share then creates BackgroundRemoval_Export.zip).
//  • Text Behind Subject (`textBehind` set) renders the text design at the canvas size with
//    the same renderer as the editor preview.
//

import UIKit

class ExportVC: UIViewController {

    /// What Text Behind Subject passes in; the screen then exports the text design.
    struct TextBehindExport {
        var document: TextBehindDocument
        var previewImage: UIImage?
        /// Full-resolution photo size (pixels).
        var photoSize: CGSize
        /// The editor keeps the chosen format / JPEG quality in its document.
        var onFormatChange: ((ExportFormat, Double) -> Void)?
    }

    // MARK: - Input

    var viewModel: BackgroundRemovalViewModel!
    /// Image shown in the preview (and exported with "This image").
    var itemID: UUID?
    /// Set by Text Behind Subject.
    var textBehind: TextBehindExport?

    /// Builds the Export screen and pushes it. Every feature opens it through here;
    /// pass `textBehind` only from Text Behind Subject.
    static func push(from navigationController: UINavigationController?,
                     viewModel: BackgroundRemovalViewModel,
                     itemID: UUID?,
                     textBehind: TextBehindExport? = nil) {
        let vc = ExportVC()
        vc.viewModel = viewModel
        vc.itemID = itemID
        vc.textBehind = textBehind
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Options
    
    var modelNameKey: String?

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
    private var previewKey: (UUID, BackgroundSelection)?
    private var task: Task<Void, Never>?
    private var observer: NSObjectProtocol?
    /// The free size limit reduces the current export (the HD card then opens Pro).
    private var isCapped = false
    /// Cutout projects use the quality's JPEG default until the slider is moved.
    private var jpegQualityChosen = false

    private var quality: ExportQuality { ExportQuality.current }
    private var isTextBehind: Bool { textBehind != nil }
    private var jpegQuality: CGFloat { CGFloat(qualityRow.value) / 100 }

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
        return ExportOptions(format: format, maxDimension: size.maxDimension, backgroundOverride: override,
                             jpegQuality: format == .jpg && jpegQualityChosen ? jpegQuality : nil)
    }

    // MARK: - Views

    private let backButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let previewView = UIImageView()
    private let checker = CheckerboardView(frame: .zero)
    private var previewAspect: NSLayoutConstraint?
    /// The clean preview (never watermarked) and what is currently shown from it.
    private var previewSource: UIImage?
    private var previewShownSource: UIImage?
    private var previewShownPremium: Bool?
    private let fileLabel = TBStyle.label("", size: 15, weight: .bold)
    private let sizeLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let scopeControl = UISegmentedControl(items: ["This image", "All images"])
    private let formatControl = UISegmentedControl(items: ["PNG", "JPG"])
    private let sizeButton = UIButton(type: .system)
    private let backgroundButton = UIButton(type: .system)
    private let qualityRow = TBSliderRow("JPEG quality", min: 50, max: 100) { "\(Int($0.rounded()))%" }
    private let noteLabel = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    /// Bulk Remove: tells free users about the daily limit when the project has more images than it.
    private let limitLabel = TBStyle.label("", size: 13, weight: .semibold, color: TBStyle.accent)
    private let hdView = UIView()
    private let hdSubtitle = TBStyle.label("", size: 13, weight: .regular, color: TBStyle.secondary)
    private let proBadge = UIView()
    private let hdChevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let saveButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let projectButton = UIButton(type: .system)
    /// Views with a border colour (updated for Dark Mode).
    private var bordered: [UIView] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "Background") ?? .systemBackground
        printEntryFeature()
        if let textBehind {
            format = textBehind.document.exportFormat
            qualityRow.value = Float(textBehind.document.jpegQuality * 100)
        } else {
            if let item { format = item.background.isTransparent ? .png : .jpg }
            qualityRow.value = Float(quality.jpegQuality * 100)
        }
        build()
        formatControl.selectedSegmentIndex = format.rawValue
        if let image = textBehind?.previewImage { setPreview(image) }
        observer = NotificationCenter.default.addObserver(forName: .refreshPremiumLog, object: nil,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    /// Logs which feature opened the Export screen.
    private func printEntryFeature() {
        let feature: String
        if textBehind != nil {
            feature = "TextBehind"
        } else {
            switch viewModel.project.mode {
            case .changeBackground: feature = "ChangeBG"
            case .textBehind: feature = "TextBehind"
            case .removeBackground: feature = viewModel.project.items.count > 1 ? "BulkRemove" : "RemoveBG"
            }
        }
        print("ExportVC opened from: \(feature)")
        self.modelNameKey = feature
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()   // the user may have upgraded on the Pro screen
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the last settings reachable above the fixed buttons on every screen size.
        scrollView.contentInset.bottom = 12
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { applyBorders() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        previewTask?.cancel()
        task?.cancel()
    }

    // MARK: - Layout

    private func card(_ view: UIView) -> UIView {
        view.backgroundColor = TBStyle.surface
        view.layer.cornerRadius = 24
        bordered.append(view)
        return view
    }

    private func applyBorders() {
        for view in bordered {
            view.layer.borderWidth = 1
            view.layer.borderColor = TBStyle.border.resolvedColor(with: traitCollection).cgColor
        }
        shareButton.layer.borderWidth = 1
        shareButton.layer.borderColor = (UIColor(named: "BrandPrimary") ?? TBStyle.border)
            .resolvedColor(with: traitCollection).cgColor
    }

    private func optionButton(_ button: UIButton, action: Selector) -> UIButton {
        button.titleLabel?.font = TBStyle.font(15, .semibold)
        button.setTitleColor(TBStyle.accent, for: .normal)
        button.contentHorizontalAlignment = .trailing
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func separator() -> UIView {
        let line = UIView()
        line.backgroundColor = TBStyle.border
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func build() {
        // Top bar
        backButton.setSymbol("chevron.left", size: 17, weight: .bold)
        backButton.tintColor = TBStyle.text
        backButton.backgroundColor = TBStyle.surface
        backButton.layer.cornerRadius = 22
        bordered.append(backButton)
        backButton.accessibilityLabel = "Back"
        backButton.addAction(UIAction { [weak self] _ in
            self?.task?.cancel()
            self?.navigationController?.popViewController(animated: true)
        }, for: .touchUpInside)
        let title = TBStyle.label("Export", size: 18, weight: .bold)
        title.textAlignment = .center

        // Preview card (keeps the export's aspect ratio)
        checker.cellSize = 12.5
        checker.layer.cornerRadius = 26
        checker.clipsToBounds = true
        previewView.contentMode = .scaleAspectFit
        previewView.layer.cornerRadius = 26
        previewView.clipsToBounds = true
        previewView.accessibilityLabel = "Export preview"
        let previewBox = UIView()
        [checker, previewView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            previewBox.addSubview($0)
        }
        let fillHeight = previewView.heightAnchor.constraint(equalTo: previewBox.heightAnchor)
        fillHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            previewBox.heightAnchor.constraint(equalToConstant: 200),
            previewView.centerXAnchor.constraint(equalTo: previewBox.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: previewBox.centerYAnchor),
            previewView.heightAnchor.constraint(lessThanOrEqualTo: previewBox.heightAnchor),
            previewView.widthAnchor.constraint(lessThanOrEqualTo: previewBox.widthAnchor),
            fillHeight,
            checker.topAnchor.constraint(equalTo: previewView.topAnchor),
            checker.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            checker.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            checker.trailingAnchor.constraint(equalTo: previewView.trailingAnchor)
        ])
        setPreviewAspect(3.0 / 4.0)
        fileLabel.textAlignment = .center
        sizeLabel.textAlignment = .center

        // Batch projects: this image or all images
        let completedCount = viewModel.project.completedItems.count
        scopeControl.setTitle("All \(completedCount) images", forSegmentAt: 1)
        scopeControl.selectedSegmentIndex = 0
        scopeControl.applyEditorStyle()
        // Below required: the stack view collapses it to 0 while hidden.
        let scopeHeight = scopeControl.heightAnchor.constraint(equalToConstant: 40)
        scopeHeight.priority = UILayoutPriority(999)
        scopeHeight.isActive = true
        scopeControl.addTarget(self, action: #selector(scopeChanged), for: .valueChanged)
        scopeControl.isHidden = isTextBehind || completedCount < 2

        // Options card: Format, (Size, Background,) JPEG quality
        formatControl.applyEditorStyle()
        formatControl.addTarget(self, action: #selector(formatChanged), for: .valueChanged)
        formatControl.translatesAutoresizingMaskIntoConstraints = false
        formatControl.widthAnchor.constraint(equalToConstant: 132).isActive = true
        formatControl.heightAnchor.constraint(equalToConstant: 40).isActive = true
        qualityRow.onChange = { [weak self] _, finished in
            self?.jpegQualityChosen = true
            if finished { self?.formatChanged() }
        }
        var rows: [UIView] = [TBStyle.hStack([TBStyle.label("Format", size: 16), UIView(), formatControl])]
        if !isTextBehind {
            rows += [separator(),
                     TBStyle.hStack([TBStyle.label("Size", size: 16), UIView(),
                                     optionButton(sizeButton, action: #selector(sizeTapped))]),
                     separator(),
                     TBStyle.hStack([TBStyle.label("Background", size: 16), UIView(),
                                     optionButton(backgroundButton, action: #selector(backgroundTapped))])]
        }
        rows += [separator(), qualityRow]
        let optionsStack = TBStyle.vStack(rows, spacing: 12)
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
        limitLabel.numberOfLines = 0
        limitLabel.isUserInteractionEnabled = true
        limitLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(limitTapped)))

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
        let content = TBStyle.vStack([previewBox, fileLabel, sizeLabel, scopeControl, limitLabel, options, noteLabel, hdView,
                                      projectButton], spacing: 12)
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
        shareButton.addAction(UIAction { [weak self] _ in self?.share() }, for: .touchUpInside)
        applyBorders()

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

    private func setPreviewAspect(_ aspect: CGFloat) {
        previewAspect?.isActive = false
        previewAspect = previewView.widthAnchor.constraint(equalTo: previewView.heightAnchor, multiplier: aspect)
        previewAspect?.isActive = true
    }

    private func setPreview(_ image: UIImage?) {
        previewSource = image
        showPreview()
        if let size = image?.size, size.width > 0, size.height > 0 {
            setPreviewAspect(size.width / size.height)
        }
    }

    /// Shows the clean preview with the watermark on top for free users, drawn the same way as
    /// on the exported file (the clean image is kept, so it is never watermarked twice).
    private func showPreview() {
        let premium = UserDefaults.isPremiumUser
        guard previewShownPremium != premium || previewShownSource !== previewSource else { return }
        previewShownPremium = premium
        previewShownSource = previewSource
        guard let source = previewSource else {
            previewView.image = nil
            return
        }
        let watermark = try? ExportWatermark.forCurrentUser()
        previewView.image = ExportWatermark.applying(watermark, to: source) ?? source
    }

    // MARK: - Display

    private func refresh() {
        guard isViewLoaded else { return }
        formatControl.selectedSegmentIndex = format.rawValue
        qualityRow.isUserInteractionEnabled = format == .jpg
        qualityRow.alpha = format == .jpg ? 1 : 0.4
        if textBehind == nil, !jpegQualityChosen {
            // Follows the quality (e.g. after upgrading on the Pro screen).
            qualityRow.value = Float(quality.jpegQuality * 100)
        }
        let capped = textBehind != nil ? refreshTextBehind() : refreshCutout()
        isCapped = capped
        showPreview()   // adds / removes the watermark when the premium state changed
        let premium = UserDefaults.isPremiumUser
        proBadge.isHidden = premium || !capped
        hdChevron.isHidden = premium || !capped
        hdSubtitle.text = capped && !premium
            ? "Free exports up to \(Int(ExportQuality.standardMaxPixelDimension)) px · Full resolution with Pro"
            : "Full resolution"
        refreshBulkLimit()
        hdView.accessibilityLabel = "HD export. \(hdSubtitle.text ?? "")"
    }

    /// Shows the free daily limit text when a Bulk Remove project has more images than the limit.
    private func refreshBulkLimit() {
        let total = viewModel.project.completedItems.count
        let limit = PaywallManager.bulkDailyLimit
        let show = isBulk && !UserDefaults.isPremiumUser && !isTextBehind && total > limit
        limitLabel.isHidden = !show
        limitLabel.text = "Free users can save up to \(limit) images per day. Get Premium to save all \(total) images."
    }

    @objc private func limitTapped() {
        present(ProUpgradeVC.fatchInstance(), animated: true)
    }

    /// Text Behind Subject. Returns whether the free size limit reduces the export.
    private func refreshTextBehind() -> Bool {
        guard let textBehind else { return false }
        let size = textBehindOutputSize(maxDimension: quality.maxPixelDimension)
        fileLabel.text = textBehindFileName(format: format)
        sizeLabel.text = "\(Int(size.width)) × \(Int(size.height)) px"
        let transparent = textBehind.document.background.isTransparent
        switch format {
        case .png:
            noteLabel.text = transparent ? "PNG keeps the transparent background around the text and subject."
                                         : "PNG keeps full quality (larger file)."
        case .jpg:
            noteLabel.text = transparent ? "JPG has no transparency – transparent areas become white. Choose PNG to keep them."
                                         : "JPG makes a smaller file for a fully composed image."
        }
        checker.isHidden = !(transparent && format == .png)
        return size != textBehindOutputSize(maxDimension: nil)
    }

    /// Cutout projects (Remove Background, Batch, Change Background). Returns whether the
    /// free size limit reduces the export.
    private func refreshCutout() -> Bool {
        guard let item else {
            fileLabel.text = nil
            sizeLabel.text = "Nothing to export yet"
            return false
        }
        fileLabel.text = cutoutFileName
        sizeButton.setTitle("\(size.title)  ›", for: .normal)
        backgroundButton.setTitle("\(backgroundTitle(background))  ›", for: .normal)
        let options = self.options
        let effective = options.background(for: item)
        if format == .jpg {
            noteLabel.text = "JPG files are smaller. Transparent areas become white."
        } else {
            noteLabel.text = effective.isTransparent ? "PNG keeps the transparent background." : "PNG keeps full quality."
        }
        renderPreview(for: item, background: effective)

        guard let name = item.foregroundFileName,
              let pixel = ImageUtilities.pixelSize(at: ProjectStorageService.shared.fileURL(name, projectID: viewModel.project.id))
        else { return quality.maxPixelDimension != nil }
        let compositor = ImageCompositingService.shared
        let output = compositor.outputSize(for: pixel, edits: item.edits, maxDimension: options.maxDimension(for: quality))
        let text = "\(Int(output.width)) × \(Int(output.height)) px"
        sizeLabel.text = exportAll ? "\(viewModel.project.completedItems.count) images · this one \(text)" : text
        return output != compositor.outputSize(for: pixel, edits: item.edits, maxDimension: options.maxDimension(for: .full))
    }

    private func renderPreview(for item: BackgroundRemovalItem, background: BackgroundSelection) {
        if let key = previewKey, key.0 == item.id, key.1 == background { return }
        previewKey = (item.id, background)
        previewTask?.cancel()
        checker.isHidden = !background.isTransparent
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let id = item.id
        let edits = item.edits
        previewTask = Task { [weak self] in
            let image = try? await viewModel.compositePreview(for: id, background: background, edits: edits, maxPixel: 600)
            guard let self, !Task.isCancelled else { return }
            self.setPreview(image)
        }
    }

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

    private var cutoutFileName: String {
        if exportAll { return "BackgroundRemoval_Export.zip" }
        var namer = UniqueFileNamer()
        return namer.name(for: item?.sourceName, index: 1, fileExtension: format.fileExtension)
    }

    private func textBehindOutputSize(maxDimension: CGFloat?) -> CGSize {
        guard let textBehind else { return .zero }
        return TextBehindGeometry.outputSize(photo: textBehind.photoSize, canvas: textBehind.document.canvas,
                                             maxDimension: maxDimension)
    }

    private func textBehindFileName(format: ExportFormat) -> String {
        let base = (item?.sourceName.map { ($0 as NSString).deletingPathExtension } ?? "TextBehind")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        return "\(base.isEmpty ? "TextBehind" : base)_text.\(format.fileExtension)"
    }

    // MARK: - Actions

    @objc private func scopeChanged() {
        exportAll = scopeControl.selectedSegmentIndex == 1
        refresh()
    }

    @objc private func formatChanged() {
        format = ExportFormat(rawValue: formatControl.selectedSegmentIndex) ?? .png
        if textBehind != nil {
            textBehind?.document.exportFormat = format
            textBehind?.document.jpegQuality = Double(qualityRow.value) / 100
            textBehind?.onFormatChange?(format, Double(qualityRow.value) / 100)
        }
        refresh()
    }

    @objc private func sizeTapped() {
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
        sheet.popoverPresentationController?.sourceView = sizeButton
        sheet.popoverPresentationController?.sourceRect = sizeButton.bounds
        present(sheet, animated: true)
    }

    @objc private func backgroundTapped() {
        let sheet = UIAlertController(title: "Background", message: nil, preferredStyle: .actionSheet)
        for option in BackgroundOption.allCases {
            let base = option == .edited ? "As edited (\(backgroundTitle(.edited)))" : backgroundTitle(option)
            sheet.addAction(UIAlertAction(title: base + (option == background ? "  ✓" : ""), style: .default) { [weak self] _ in
                self?.background = option
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = backgroundButton
        sheet.popoverPresentationController?.sourceRect = backgroundButton.bounds
        present(sheet, animated: true)
    }

    @objc private func hdTapped() {
        guard !UserDefaults.isPremiumUser, isCapped else { return }
        present(ProUpgradeVC.fatchInstance(), animated: true)
    }

    private func saveProject() {
        if let textBehind, let id = item?.id {
            viewModel.setTextBehind(textBehind.document, for: id)
        }
        viewModel.save()
        showToast(message: "Project saved – find it in Projects")
    }

    private func setBusy(_ busy: Bool) {
        [saveButton, shareButton, projectButton, formatControl, scopeControl, sizeButton, backgroundButton]
            .forEach { ($0 as UIControl).isEnabled = !busy }
    }

    // MARK: - Save / Share

    /// Renders the export files: the text design, or the cutout(s) of this image / all images.
    private func renderFiles(progress: @escaping (Double) -> Void) async throws -> [(name: String, data: Data)] {
        if textBehind != nil {
            let output = try await renderTextBehind()
            return [(output.fileName, output.data)]
        }
        let outputs = try await ImageExportService.shared.renderOutputs(for: exportItems, in: viewModel, quality: quality,
                                                                        options: options, progress: progress)
        if exportAll {
            // Archive entries are numbered in project order: Image_001.png, Image_002.jpg…
            return outputs.enumerated().map { index, output in
                (name: String(format: "Image_%03d.%@", index + 1, output.isPNG ? "png" : "jpg"), data: output.data)
            }
        }
        return outputs.map { (name: $0.fileName, data: $0.data) }
    }

    private var isBulk: Bool { modelNameKey == "BulkRemove" }

    /// Bulk Remove counts exported images per day (3 free); every other feature keeps its tap limit.
    private func allowExport(items: [BackgroundRemovalItem]) -> Bool {
        guard task == nil, !ImageExportService.shared.isBusy else { return false }
        if isBulk { return PaywallManager.shared.shouldAllowBulkExport(from: self, itemIDs: items.map(\.id)) }
        return PaywallManager.shared.shouldAllowAction(from: self, key: self.modelNameKey ?? "RemoveBG")
    }

    private func save() {
        if allowExport(items: exportItems) {
            let items = exportItems
            guard task == nil, !ImageExportService.shared.isBusy, isTextBehind || !items.isEmpty else { return }
            setBusy(true)
            let hud = ProgressHUD.show(in: view, message: isTextBehind ? "Rendering…" :
                                        (items.count > 1 ? "Saving \(items.count) images…" : "Saving…"))
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            let options = self.options
            task = Task { [weak self] in
                defer {
                    self?.task = nil
                    self?.setBusy(false)
                }
                do {
                    guard let self else { return }
                    let count: Int
                    if self.isTextBehind {
                        let output = try await self.renderTextBehind()
                        hud.update(progress: 0.7, message: "Saving to Photos…")
                        try await ImageExportService.shared.savePhotoData(output.data, fileName: output.fileName)
                        viewModel.recordExport(quality: self.quality)
                        count = 1
                    } else {
                        count = try await ImageExportService.shared.saveToPhotos(items: items, in: viewModel,
                                                                                 options: options) { value in
                            hud.update(progress: value)
                        }
                    }
                    hud.dismiss()
                    if count > 0 {
                        if self.isBulk { PaywallManager.shared.recordBulkExport(itemIDs: items.map(\.id)) }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showToast(message: count > 1 ? "\(count) images saved to Photos" : "Saved to Photos")
                    }
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
    }

    private func share() {
        if allowExport(items: exportItems) {
            let items = exportItems
            guard task == nil, isTextBehind || !items.isEmpty else { return }
            setBusy(true)
            let hud = ProgressHUD.show(in: view, message: isTextBehind ? "Rendering…" :
                                        (items.count > 1 ? "Preparing \(items.count) images…" : "Preparing…"))
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            let quality = self.quality
            let zip = exportAll && !isTextBehind
            task = Task { [weak self] in
                defer {
                    self?.task = nil
                    self?.setBusy(false)
                }
                do {
                    guard let self else { return }
                    let files = try await self.renderFiles { value in hud.update(progress: value * 0.9) }
                    let url: URL
                    if !zip, let file = files.first {
                        let name = file.name
                        let data = file.data
                        url = try await Task.detached { try ZIPExportService.shared.writeSingleFile(name: name, data: data) }.value
                    } else {
                        url = try await Task.detached { try ZIPExportService.shared.createArchive(files: files) }.value
                    }
                    hud.dismiss()
                    viewModel.recordExport(quality: quality)
                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    activity.popoverPresentationController?.sourceView = self.shareButton
                    activity.popoverPresentationController?.sourceRect = self.shareButton.bounds
                    let bulkIDs = self.isBulk ? items.map(\.id) : []
                    activity.completionWithItemsHandler = { _, completed, _, _ in
                        ZIPExportService.shared.cleanUp(url)
                        // Only a completed share (not a cancelled sheet) uses up the daily limit.
                        if completed, !bulkIDs.isEmpty { PaywallManager.shared.recordBulkExport(itemIDs: bulkIDs) }
                    }
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
    }

    /// Text Behind Subject: full-size render (the same renderer as the preview) and encoded data.
    private func renderTextBehind() async throws -> (data: Data, fileName: String) {
        guard let textBehind, let id = item?.id else { throw ImageExportError.nothingToExport }
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let document = textBehind.document
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
        let jpegQuality = self.jpegQuality
        let maxDimension = quality.maxPixelDimension
        let photo = CGSize(width: originalCG.width, height: originalCG.height)
        // Read when the export is rendered (free users only; drawn onto the final composition).
        let watermark = try ExportWatermark.forCurrentUser()
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
                let composed = TextBehindSubjectRenderer.render(document, sources: sources, size: size, opaque: format == .jpg)
                guard let image = ExportWatermark.applying(watermark, to: composed) else { return nil }
                return TextBehindSubjectRenderer.encode(image, format: format, jpegQuality: jpegQuality)
            }
        }.value
        guard let data else { throw ImageExportError.renderFailed("The image") }
        return (data, textBehindFileName(format: format))
    }
}
