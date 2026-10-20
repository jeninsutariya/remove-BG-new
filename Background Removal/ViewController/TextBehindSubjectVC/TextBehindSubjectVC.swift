//
//  TextBehindSubjectVC.swift
//  Background Removal
//
//  Text Behind Subject editor. Shows the original photo with text placed behind the person
//  (or any subject Vision finds): background → text → subject cutout → text in front.
//
//  • originalImage  – the user's photo, never modified (project file original_*.jpg)
//  • foregroundImage – the subject cut out of it with the Vision mask (+ Refine edits),
//                      cached and rebuilt only when the mask settings change
//
//  Tools: Background, Text, Refine, Shadow, Resize. Text can be selected, dragged, pinched
//  and rotated directly on the canvas. Undo / redo cover every edit. The preview and the
//  export use the same renderer.
//

import UIKit
import PhotosUI
import UIView_Shimmer
import GoogleMobileAds

class TextBehindSubjectVC: UIViewController, TBPanelHost {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var btnUndo: UIButton!
    @IBOutlet weak var btnRedo: UIButton!
    @IBOutlet weak var btnPreview: UIButton!
    @IBOutlet weak var btnExport: UIButton!
    @IBOutlet weak var vwCanvasArea: UIView!
    @IBOutlet weak var vwStatus: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var btnRetry: UIButton!
    @IBOutlet weak var vwToolbar: UIView!
    @IBOutlet weak var clvTools: UICollectionView!
    /// Strong: deactivated while a tool panel is open.
    @IBOutlet var canvasBottom: NSLayoutConstraint!
    
    // MARK: - Input
    
    var viewModel: BackgroundRemovalViewModel!
    var itemID: UUID!
    
    private(set) lazy var session: TBEditorSession = {
        let document = viewModel.item(itemID)?.textBehind ?? .starter()
        return TBEditorSession(document: document)
    }()
    
    // MARK: - Tools
    
    private enum Tool: Int, CaseIterable {
        case background, text, refine, shadow, resize
        var title: String {
            switch self {
            case .background: return "Background"
            case .text: return "Text"
            case .refine: return "Refine"
            case .shadow: return "Shadow"
            case .resize: return "Resize"
            }
        }
        var symbol: String {
            switch self {
            case .background: return "square.stack.3d.up"
            case .text: return "textformat"
            case .refine: return "wand.and.rays"
            case .shadow: return "circle.lefthalf.filled"
            case .resize: return "aspectratio"
            }
        }
    }
    
    // MARK: - Canvas views
    
    private let scrollView = UIScrollView()
    private let canvasView = UIView()
    private let checker = CheckerboardView(frame: .zero)
    private let imageView = UIImageView()
    private let overlay = TextSelectionOverlayView(frame: .zero)
    private var canvasSize = CGSize(width: 3, height: 4)
    
    // MARK: - Sources (preview resolution)
    
    private var fullPhotoSize = CGSize(width: 1, height: 1)
    private var previewOriginal: UIImage?
    private var previewMask: CGImage?
    private var previewMaskKey: String?
    private var previewCutout: UIImage?
    private var cutoutKey: String?
    private var backgroundImages: [String: UIImage] = [:]
    /// Background images that failed to load (not retried on every render).
    private var failedBackgroundKeys = Set<String>()
    private var sourcesReady = false
    
    // MARK: - State
    
    private var renderTask: Task<Void, Never>?
    private var renderGeneration = 0
    private var isMaskPreview = false
    private var isPreviewing = false
    private var activeTool: Tool?
    private var activePanel: TBPanelView?
    /// Shared tool-panel presentation (hides the tool bar while a panel is open).
    private lazy var panelPresenter = EditorPanelPresenter(rootView: view, toolbar: vwToolbar, canvas: vwCanvasArea,
                                                           normalCanvasBottom: canvasBottom, followsKeyboard: true)
    private var panelSnapshot: (document: TextBehindDocument, undoCount: Int)?
    private var gestureStart: TextLayerModel?
    private var observers: [NSObjectProtocol] = []
    private var exportTask: Task<Void, Never>?
    private var thumbnailTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bannerAd()
        setupChrome()
        setupCanvas()
        setupSession()
        observe()
        loadSources()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCanvas()
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        renderTask?.cancel()
        exportTask?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupChrome() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnBack.layer.cornerRadius = 22
        btnBack.layer.borderWidth = 1
        btnBack.layer.borderColor = UIColor(named: "Border Color")?.cgColor
        btnBack.accessibilityLabel = "Back"
        btnUndo.setSymbol("arrow.uturn.backward", size: 18)
        btnRedo.setSymbol("arrow.uturn.forward", size: 18)
        btnUndo.accessibilityLabel = "Undo"
        btnRedo.accessibilityLabel = "Redo"
        btnPreview.setSymbol("eye", size: 18)
        btnPreview.tintColor = UIColor(named: "PrimaryText")
        btnPreview.accessibilityLabel = "Preview"
        btnExport.layer.cornerRadius = 22
        btnRetry.layer.cornerRadius = 18
        vwStatus.layer.cornerRadius = 20
        vwToolbar.layer.cornerRadius = 28
        vwToolbar.layer.shadowColor = UIColor.black.cgColor
        vwToolbar.layer.shadowOpacity = 0.06
        vwToolbar.layer.shadowRadius = 14
        vwToolbar.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        clvTools.register(UINib(nibName: "EditorToolClvCell", bundle: nil), forCellWithReuseIdentifier: "EditorToolClvCell")
        clvTools.dataSource = self
        clvTools.delegate = self
        clvTools.isScrollEnabled = false
        updateUndoButtons()
    }
    
    private func setupCanvas() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2   // one finger moves text
        vwCanvasArea.insertSubview(scrollView, at: 0)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: vwCanvasArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: vwCanvasArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: vwCanvasArea.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: vwCanvasArea.bottomAnchor)
        ])
        // The canvas keeps a usable minimum height; tool panels shrink (and scroll) instead,
        // e.g. while the keyboard is up.
        let minimumHeight = vwCanvasArea.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        minimumHeight.priority = UILayoutPriority(999)
        minimumHeight.isActive = true
        canvasView.clipsToBounds = true
        canvasView.layer.cornerRadius = 4
        checker.cellSize = 12
        imageView.contentMode = .scaleToFill
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Text behind subject preview"
        [checker, imageView, overlay].forEach { canvasView.addSubview($0) }
        scrollView.addSubview(canvasView)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(canvasTapped(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(canvasDoubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(textPanned(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(textPinched(_:)))
        let rotate = UIRotationGestureRecognizer(target: self, action: #selector(textRotated(_:)))
        for gesture in [pan, pinch, rotate] as [UIGestureRecognizer] { gesture.delegate = self }
        [tap, doubleTap, pan, pinch, rotate].forEach { canvasView.addGestureRecognizer($0) }
    }
    
    private func setupSession() {
        session.onChange = { [weak self] final in
            self?.requestRender(final: final)
            self?.updateOverlay()
            self?.updateUndoButtons()
        }
        session.onSelectionChange = { [weak self] in
            self?.updateOverlay()
            self?.updateZoomGesture()
        }
        session.onCommit = { [weak self] document in
            guard let self else { return }
            self.viewModel.setTextBehind(document, for: self.itemID)
            self.scheduleThumbnail()
        }
        // Make sure a new project is saved with its starter text.
        if viewModel.item(itemID)?.textBehind == nil {
            viewModel.setTextBehind(session.document, for: itemID)
        }
    }
    
    private func observe() {
        observers.append(NotificationCenter.default.addObserver(forName: BackgroundRemovalViewModel.itemDidChangeNotification,
                                                                object: viewModel, queue: .main) { [weak self] note in
            let id = note.userInfo?[BackgroundRemovalViewModel.itemIDKey] as? UUID
            MainActor.assumeIsolated {
                guard let self, id == self.itemID, !self.sourcesReady else { return }
                self.loadSources()
            }
        })
    }
    
    // MARK: - Sources
    
    /// Loads the preview-size original, the subject mask and the cutout (never re-runs Vision
    /// for text or style changes).
    private func loadSources() {
        guard let item = viewModel.item(itemID) else { return }
        switch item.status {
        case .completed where item.isCompleted:
            break
        case .failed:
            showStatus(item.errorMessage ?? "No subject could be found in this photo.", busy: false, retry: true)
            return
        default:
            showStatus("Finding the subject…", busy: true, retry: false)
            if !viewModel.isProcessing { viewModel.startProcessing([item.id]) }
            return
        }
        showStatus("Preparing…", busy: true, retry: false)
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let id: UUID = itemID
        let originalName = item.originalFileName
        Task { [weak self] in
            let original = await viewModel.originalPreview(for: id, maxPixel: 1600)
            let url = ProjectStorageService.shared.fileURL(originalName, projectID: viewModel.project.id)
            let fullSize = ImageUtilities.pixelSize(at: url)
            guard let self else { return }
            guard let original else {
                self.showStatus("The original photo couldn't be opened.", busy: false, retry: false)
                return
            }
            self.previewOriginal = original
            self.fullPhotoSize = fullSize ?? original.size
            let cutout = await self.ensureCutout(for: self.session.document.mask)
            guard cutout != nil else {
                self.showStatus("No subject was found in this photo, so text can't go behind it. Try another photo or retry.",
                                busy: false, retry: true)
                return
            }
            self.sourcesReady = true
            self.hideStatus()
            // Also repairs projects saved before thumbnails showed the edited result.
            self.scheduleThumbnail(delay: 0)
            self.updateZoomGesture()
            self.clvTools.reloadData()
            self.requestRender(final: true)
            self.updateOverlay()
        }
    }
    
    /// Preview mask for the current settings (refined file or Vision), sized to the preview.
    private func ensureMask(for settings: MaskSettings) async -> CGImage? {
        let key = settings.refinedMaskFileName ?? "vision"
        if key == previewMaskKey, let previewMask { return previewMask }
        guard let original = previewOriginal,
              let full = await viewModel.subjectMask(for: itemID, settings: settings) else { return nil }
        let size = (Int(original.size.width * original.scale), Int(original.size.height * original.scale))
        let mask = await Task.detached(priority: .userInitiated) {
            MaskRefineService.resized(full, width: size.0, height: size.1)
        }.value
        previewMask = mask
        previewMaskKey = key
        return mask
    }
    
    /// Preview subject cutout, rebuilt only when the mask or its settings change.
    private func ensureCutout(for settings: MaskSettings) async -> UIImage? {
        let key = "\(settings.refinedMaskFileName ?? "vision")|\(settings.feather)|\(settings.edgeSmoothing)"
        if key == cutoutKey, let previewCutout { return previewCutout }
        guard let original = previewOriginal, let originalCG = original.cgImage,
              let mask = await ensureMask(for: settings) else { return nil }
        let scale = CGFloat(originalCG.width) / 1000
        let feather = CGFloat(settings.feather) * scale
        let smoothing = CGFloat(settings.edgeSmoothing) * scale
        let cutout = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            MaskRefineService.subjectCutout(original: originalCG, mask: mask, feather: feather, smoothing: smoothing)
                .map { UIImage(cgImage: $0, scale: 1, orientation: .up) }
        }.value
        if let cutout {
            previewCutout = cutout
            cutoutKey = key
        }
        return cutout
    }
    
    private func backgroundKey(_ selection: BackgroundSelection) -> String {
        switch selection {
        case .remoteImage(let id, _): return "remote-\(id)"
        case .customImage(let name): return "custom-\(name)"
        case .color(let hex): return "color-\(hex)"
        case .none: return "none"
        }
    }
    
    /// Picking a background again retries it after a failed download.
    func retryBackground(_ selection: BackgroundSelection) {
        failedBackgroundKeys.remove(backgroundKey(selection))
    }
    
    /// `quiet`: background work (thumbnails) never shows an error the user didn't trigger.
    private func ensureBackgroundImage(for background: TBBackground, quiet: Bool = false) async -> UIImage? {
        guard case .image(let selection, _) = background else { return nil }
        let key = backgroundKey(selection)
        if let cached = backgroundImages[key] { return cached }
        guard !failedBackgroundKeys.contains(key) else { return nil }
        do {
            if case .image(let image) = try await viewModel.resolveBackground(selection, maxPixel: 1800) {
                backgroundImages[key] = image
                return image
            }
        } catch {
            failedBackgroundKeys.insert(key)
            if !quiet { showToast(message: "This background image couldn't be loaded. Check your connection and pick it again.") }
        }
        return nil
    }
    
    // MARK: - Rendering
    
    /// Renders the preview. Live changes use a smaller size; the latest request always wins.
    private func requestRender(final: Bool) {
        guard sourcesReady, let original = previewOriginal else { return }
        renderGeneration += 1
        let generation = renderGeneration
        renderTask?.cancel()
        let document = session.document
        let maskPreview = isMaskPreview
        renderTask = Task { [weak self] in
            if !final {
                try? await Task.sleep(nanoseconds: 8_000_000)   // coalesce rapid slider / drag events
                if Task.isCancelled { return }
            }
            guard let self else { return }
            let cutout = await self.ensureCutout(for: document.mask)
            let background = await self.ensureBackgroundImage(for: document.background)
            var mask: UIImage?
            if maskPreview, let maskImage = await self.ensureMask(for: document.mask) {
                // Show the mask exactly as it is used: with feather and edge refinement.
                let scale = CGFloat(maskImage.width) / 1000
                let settings = document.mask
                let processed = await Task.detached(priority: .userInitiated) {
                    MaskRefineService.processedMask(maskImage, feather: CGFloat(settings.feather) * scale,
                                                    smoothing: CGFloat(settings.edgeSmoothing) * scale)
                }.value
                mask = UIImage(cgImage: processed ?? maskImage)
            }
            guard !Task.isCancelled, generation == self.renderGeneration else { return }
            let size = TextBehindGeometry.outputSize(photo: original.size, canvas: document.canvas,
                                                     maxDimension: final ? 1500 : 1000)
            let sources = TBRenderSources(original: original, cutout: cutout, backgroundImage: background, mask: mask)
            let image = await Task.detached(priority: .userInitiated) {
                TextBehindSubjectRenderer.render(document, sources: sources, size: size, maskPreview: maskPreview)
            }.value
            guard generation == self.renderGeneration else { return }
            self.imageView.image = image
            if abs(size.width / size.height - self.canvasSize.width / self.canvasSize.height) > 0.001 {
                self.canvasSize = size
                self.layoutCanvas()
            }
        }
    }
    
    /// Fits the canvas (rendered image aspect ratio) in the canvas area.
    private func layoutCanvas() {
        // viewDidLayoutSubviews runs before the canvas area lays out its own subviews, so the
        // scroll view can still have its previous (e.g. panel-reduced) frame here. Lay the area
        // out first and measure the area itself, so the canvas is always sized from the current
        // available space – never from an earlier, smaller layout.
        vwCanvasArea.layoutIfNeeded()
        let area = vwCanvasArea.bounds.insetBy(dx: 12, dy: 12)
        guard area.width > 0, area.height > 0 else { return }
        let scale = min(area.width / canvasSize.width, area.height / canvasSize.height)
        let size = CGSize(width: floor(canvasSize.width * scale), height: floor(canvasSize.height * scale))
        guard canvasView.bounds.size != size else {
            centerCanvas()
            return
        }
        if scrollView.zoomScale != 1 {
            // The available space changed while zoomed in: start again from the fitted size.
            scrollView.setZoomScale(1, animated: false)
        }
        if canvasView.bounds.size != size {
            canvasView.frame = CGRect(origin: .zero, size: size)
            [checker, imageView, overlay].forEach { $0.frame = canvasView.bounds }
            scrollView.contentSize = size
            updateOverlay()
        }
        centerCanvas()
    }
    
    /// Keeps the canvas centred in the scroll view at any zoom.
    private func centerCanvas() {
        let insetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let insetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
        if scrollView.zoomScale == 1 {
            // Changing the insets doesn't move the content: after the canvas area shrank and grew
            // again (keyboard, panels) a stale offset left the photo scrolled out of view.
            scrollView.contentOffset = CGPoint(x: -insetX, y: -insetY)
        }
    }
    
    private func updateOverlay() {
        guard !isPreviewing, !isMaskPreview, let text = session.selectedText, !text.isHidden else {
            overlay.layout = nil
            return
        }
        overlay.isLocked = text.isLocked
        overlay.layout = TextRenderingService.layout(for: text, canvasSize: canvasView.bounds.size)
    }
    
    private func updateUndoButtons() {
        let disabled = UIColor(red: 0.72, green: 0.79, blue: 0.87, alpha: 1)
        btnUndo.isEnabled = session.canUndo
        btnRedo.isEnabled = session.canRedo
        btnUndo.tintColor = session.canUndo ? UIColor(named: "PrimaryText") : disabled
        btnRedo.tintColor = session.canRedo ? UIColor(named: "PrimaryText") : disabled
    }
    
    private func updateZoomGesture() {
        // Pinch zooms the canvas only when no text is selected; otherwise it resizes the text.
        scrollView.pinchGestureRecognizer?.isEnabled = session.selectedText == nil
    }
    
    // MARK: - Status overlay
    
    private func showStatus(_ message: String, busy: Bool, retry: Bool) {
        vwStatus.isHidden = false
        lblStatus.text = message
        busy ? spinner.startAnimating() : spinner.stopAnimating()
        btnRetry.isHidden = !retry
        clvTools.isUserInteractionEnabled = false
        vwToolbar.alpha = 0.5
        btnExport.isEnabled = false
    }
    
    private func hideStatus() {
        vwStatus.isHidden = true
        spinner.stopAnimating()
        clvTools.isUserInteractionEnabled = true
        vwToolbar.alpha = 1
        btnExport.isEnabled = true
    }
    
    // MARK: - Hit testing
    
    /// Front-most visible text layer under `point` (canvas coordinates).
    private func textLayer(at point: CGPoint) -> TextLayerModel? {
        return session.textsFrontToBack.filter { !$0.isHidden }.first {
            TextRenderingService.layout(for: $0, canvasSize: canvasView.bounds.size).contains(point)
        }
    }
    
    // MARK: - Canvas gestures
    
    @objc private func canvasTapped(_ gesture: UITapGestureRecognizer) {
        guard !isPreviewing else { return }
        session.selectedTextID = textLayer(at: gesture.location(in: canvasView))?.id
        (activePanel as? TextStyleEditorView)?.refresh()
        (activePanel as? ShadowEditorView)?.refresh()
    }
    
    @objc private func canvasDoubleTapped(_ gesture: UITapGestureRecognizer) {
        guard !isPreviewing, let layer = textLayer(at: gesture.location(in: canvasView)) else { return }
        session.selectedTextID = layer.id
        openTool(.text)
    }
    
    @objc private func textPanned(_ gesture: UIPanGestureRecognizer) {
        let size = canvasView.bounds.size
        switch gesture.state {
        case .began:
            gestureStart = session.selectedText
        case .changed:
            guard let start = gestureStart else { return }
            let t = gesture.translation(in: canvasView)
            session.changeSelectedText(commit: false) {
                $0.centerX = min(1.2, max(-0.2, start.centerX + Double(t.x / max(size.width, 1))))
                $0.centerY = min(1.2, max(-0.2, start.centerY + Double(t.y / max(size.height, 1))))
            }
        default:
            gestureStart = nil
            session.commit()
            activePanel?.refresh()
        }
    }
    
    @objc private func textPinched(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            gestureStart = gestureStart ?? session.selectedText
        case .changed:
            guard let start = gestureStart else { return }
            session.changeSelectedText(commit: false) {
                $0.fontScale = min(700, max(30, start.fontScale * Double(gesture.scale)))
            }
        default:
            finishTransformGesture()
        }
    }
    
    @objc private func textRotated(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            gestureStart = gestureStart ?? session.selectedText
        case .changed:
            guard let start = gestureStart else { return }
            session.changeSelectedText(commit: false) {
                var degrees = start.rotation + Double(gesture.rotation) * 180 / .pi
                if degrees > 180 { degrees -= 360 }
                if degrees < -180 { degrees += 360 }
                // Snap to straight when close.
                if abs(degrees) < 3 { degrees = 0 }
                $0.rotation = degrees
            }
        default:
            finishTransformGesture()
        }
    }
    
    private func finishTransformGesture() {
        // Pinch and rotate can run together; commit once both ended.
        let active = canvasView.gestureRecognizers?.contains {
            ($0 is UIPinchGestureRecognizer || $0 is UIRotationGestureRecognizer)
            && ($0.state == .began || $0.state == .changed)
        } ?? false
        guard !active else { return }
        gestureStart = nil
        session.commit()
        activePanel?.refresh()
    }
    
    // MARK: - Tools
    
    private func openTool(_ tool: Tool) {
        guard sourcesReady else { return }
        if activeTool == tool, activePanel != nil { return }
        if activePanel != nil {
            // Switching tools keeps the current edit and replaces the panel.
            session.commit()
            closePanel(revert: false, keepPresenter: true)
        }
        // Snapshot first: ✕ also undoes anything opening the tool created (e.g. a new text).
        panelSnapshot = (session.document, session.undoStack.count)
        let panel: TBPanelView
        switch tool {
        case .background:
            panel = BackgroundPickerView(host: self)
        case .text:
            if session.document.texts.isEmpty { session.addText() }
            if session.selectedText == nil { session.selectedTextID = session.document.texts.last?.id }
            panel = TextStyleEditorView(host: self)
        case .refine:
            panel = MaskRefinementView(host: self)
        case .shadow:
            panel = ShadowEditorView(host: self, subjectAvailable: previewCutout != nil)
        case .resize:
            panel = CanvasResizeView(host: self, photoSize: fullPhotoSize)
        }
        panel.onApply = { [weak self] in
            self?.session.commit()
            self?.closePanel(revert: false)
        }
        panel.onCancel = { [weak self] in self?.closePanel(revert: true) }
        present(panel: panel)
        activeTool = tool
        clvTools.reloadData()
    }
    
    private func present(panel: TBPanelView) {
        // Hides the tool bar and slides the panel up from the bottom (or replaces the open one).
        panelPresenter.show(panel, preferredHeight: panel.preferredHeight)
        activePanel = panel
    }
    
    /// - Parameter keepPresenter: switching tools – the next panel replaces this one, so the
    ///   tool bar stays hidden and nothing slides.
    private func closePanel(revert: Bool, keepPresenter: Bool = false, animated: Bool = true) {
        guard activePanel != nil else { return }
        view.endEditing(true)
        if revert, let snapshot = panelSnapshot {
            session.revert(to: snapshot.document, undoCount: snapshot.undoCount)
        }
        panelSnapshot = nil
        activePanel = nil
        activeTool = nil
        if isMaskPreview {
            isMaskPreview = false
            requestRender(final: true)
        }
        if !keepPresenter {
            // Restores the tool bar and the normal canvas layout.
            panelPresenter.dismiss(animated: animated)
        }
        clvTools.reloadData()
        updateOverlay()
        updateUndoButtons()
    }
    
    // MARK: - TBPanelHost
    
    func presentColorPicker(initial: UIColor, completion: @escaping (UIColor) -> Void) {
        let picker = TBColorPickerController()
        picker.selectedColor = initial
        picker.supportsAlpha = false
        picker.onPick = completion
        present(picker, animated: true)
    }
    
    func presentBackgroundPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func openMaskBrush() {
        let hud = ProgressHUD.show(in: view, message: "Preparing mask…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let id: UUID = itemID
        let settings = session.document.mask
        Task { [weak self] in
            let original = await viewModel.fullOriginal(for: id)
            let mask = await viewModel.subjectMask(for: id, settings: settings)
            hud.dismiss()
            guard let self else { return }
            guard let original, let mask else {
                self.showMessage("Mask unavailable", "The subject mask couldn't be opened. Please try again.")
                return
            }
            let vc = RefineEdgesVC.fatchEditorInstance()
            vc.original = original
            vc.initialMask = mask
            vc.modeTitles = (erase: "Erase", restore: "Refine")
            vc.modeHints = (erase: "Erase: the text shows here", restore: "Refine: the subject covers the text")
            vc.onApply = { [weak self] refined in self?.saveRefinedMask(refined) }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func saveRefinedMask(_ mask: CGImage) {
        let hud = ProgressHUD.show(in: view, message: "Saving mask…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let id: UUID = itemID
        Task { [weak self] in
            do {
                let name = try await viewModel.saveRefinedMask(mask, for: id)
                hud.dismiss()
                self?.session.change { $0.mask.refinedMaskFileName = name }
                self?.activePanel?.refresh()
            } catch {
                hud.dismiss()
                self?.showMessage("Couldn't save the mask", error.localizedDescription)
            }
        }
    }
    
    func setMaskPreview(_ enabled: Bool) {
        isMaskPreview = enabled
        updateOverlay()
        requestRender(final: true)
    }
    
    func showMessage(_ title: String, _ message: String) {
        presentErrorAlert(title: title, message: message)
    }
    
    func confirm(_ title: String, _ message: String, action: String, completion: @escaping () -> Void) {
        
        showAlert(title: title, msg: message, okayTitle: action, cancelTitle: "Cancel", doneAction: {
            completion()
        })
    }
    
    func promptText(_ title: String, initial: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = initial; $0.clearButtonMode = .whileEditing }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            completion(alert.textFields?.first?.text ?? initial)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Actions
    
    @IBAction func btnBack(_ sender: UIButton) {
        session.commit()
        if activePanel != nil { closePanel(revert: false) }
        viewModel.setTextBehind(session.document, for: itemID)
        viewModel.cancelProcessing()
        thumbnailTask?.cancel()
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        let render = thumbnailRender()
        Task {
            // Final thumbnail of the composition, then remove files nothing references any more.
            if let image = await render?() { await viewModel.saveThumbnail(image) }
            viewModel.purgeUnusedFiles()
        }
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Recents thumbnail
    
    /// A closure rendering the current composition small (same renderer as preview/export).
    private func thumbnailRender() -> (() async -> UIImage?)? {
        guard sourcesReady, let original = previewOriginal else { return nil }
        let document = session.document
        let cutout = previewCutout
        var background: UIImage?
        if case .image(let selection, _) = document.background {
            background = backgroundImages[backgroundKey(selection)]
        }
        let backgroundImage = background
        return {
            await Task.detached(priority: .utility) {
                let size = TextBehindGeometry.outputSize(photo: original.size, canvas: document.canvas, maxDimension: 600)
                let sources = TBRenderSources(original: original, cutout: cutout, backgroundImage: backgroundImage, mask: nil)
                return TextBehindSubjectRenderer.render(document, sources: sources, size: size)
            }.value
        }
    }
    func bannerAd(){
        if UserDefaults.isPremiumUser {
            bannerView.isHidden = true
            lodingAds.isHidden = true
            self.adsBase.isHidden = true
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: 0).isActive = true
            
            self.view.setTemplateWithSubviews(false)
            return
        }
        let adsType = appData.textBehindSubjectVC.adType ?? ""
        let adsSize = appData.textBehindSubjectVC.adSize ?? 50
        
        let adSize = getAdSize(type: adsType, size: adsSize)
        if adsType == "NETIVE" || adsType == "BIG_NETIVE"{
            self.veBanner.isHidden = true
            self.adsBase.isHidden = false
            self.lodingAds.isHidden = true
            self.adsBase.setupAdsView(data: adsType == "NETIVE" ? .smallNative : .bigNative)
        }else if adsType == "BANNER" || adsType == "LARGE_BANNER" || adsType == "MEDIUM_RECTANGLE"{
            self.veBanner.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
        }else{
            self.bannerView.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        }
        if adsType != "NETIVE" || adsType != "BIG_NETIVE"{
            self.view.layoutIfNeeded()
            self.bannerView.setTemplateWithSubviews(true, viewBackgroundColor: .white)
            self.lodingAds.isHidden = false
            bannerView.adUnitID = appData.bannerAdsId
            bannerView.rootViewController = self
            bannerView.delegate = self
            bannerView.adSize = adSize
            
            let request = Request()
            bannerView.load(request)
        }
    }
    
    func getAdSize(type: String, size: Int) -> AdSize {
        switch type {
        case "BANNER":
            return AdSizeBanner
        case "LARGE_BANNER":
            return AdSizeLargeBanner
        case "MEDIUM_RECTANGLE":
            return AdSizeMediumRectangle
        default:
            let screenWidth = UIScreen.main.bounds.width
            return adSizeFor(cgSize: CGSize(width: screenWidth, height: CGFloat(size)))
        }
    }
    /// Updates the Recents thumbnail after saved changes (debounced, not on every UI event).
    private func scheduleThumbnail(delay: Double = 1.2) {
        thumbnailTask?.cancel()
        thumbnailTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled, let self else { return }
            _ = await self.ensureBackgroundImage(for: self.session.document.background, quiet: true)
            guard !Task.isCancelled, let render = self.thumbnailRender() else { return }
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            guard let image = await render(), !Task.isCancelled else { return }
            await viewModel.saveThumbnail(image)
        }
    }
    
    @IBAction func btnUndo(_ sender: UIButton) {
        adsManager.showInterstitial {
            self.session.undo()
            self.activePanel?.refresh()
        }
    }
    
    @IBAction func btnRedo(_ sender: UIButton) {
        adsManager.showInterstitial {
            self.session.redo()
            self.activePanel?.refresh()
        }
    }
    
    @IBAction func btnPreview(_ sender: UIButton) {
        adsManager.showInterstitial {
            self.isPreviewing.toggle()
            self.btnPreview.setSymbol(self.isPreviewing ? "eye.fill" : "eye", size: 18)
            self.btnPreview.tintColor = self.isPreviewing ? UIColor(named: "AccentColor") : UIColor(named: "PrimaryText")
            if self.isPreviewing, self.activePanel != nil {
                self.session.commit()
                // Immediately, so the tool bar's hidden state below isn't overridden by an animation.
                self.closePanel(revert: false, animated: false)
            }
            UIView.animate(withDuration: 0.2) {
                self.vwToolbar.alpha = self.isPreviewing ? 0 : 1
                self.scrollView.setZoomScale(1, animated: false)
            }
            self.vwToolbar.isUserInteractionEnabled = !self.isPreviewing
            self.updateOverlay()
        }
    }
    
    @IBAction func btnExport(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard self.sourcesReady else { return }
            self.session.commit()
            if self.activePanel != nil { self.closePanel(revert: false) }
            self.viewModel.setTextBehind(self.session.document, for: self.itemID)
            // The shared Export screen (same as every other feature).
            ExportVC.push(
                from: self.navigationController, viewModel: self.viewModel, itemID: self.itemID,
                textBehind: ExportVC.TextBehindExport(
                    document: self.session.document, previewImage: self.imageView.image, photoSize: self.fullPhotoSize,
                    onFormatChange: { [weak self] format, quality in
                        self?.session.change {
                            $0.exportFormat = format
                            $0.jpegQuality = quality
                        }
                    }))
        }
    }
    
    @IBAction func btnRetry(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard let item = self.viewModel.item(self.itemID) else { return }
            self.sourcesReady = false
            self.previewMaskKey = nil
            self.cutoutKey = nil
            if item.isCompleted {
                self.loadSources()
            } else {
                self.showStatus("Finding the subject…", busy: true, retry: false)
                self.viewModel.retry(item.id)
            }
        }
    }
}

// MARK: - Gestures

extension TextBehindSubjectVC: UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard sourcesReady, !isPreviewing, !isMaskPreview else { return false }
        if gestureRecognizer is UIPanGestureRecognizer {
            // One-finger drag starts on a text layer (and selects it).
            guard let layer = textLayer(at: gestureRecognizer.location(in: canvasView)), !layer.isLocked else { return false }
            if session.selectedTextID != layer.id {
                session.selectedTextID = layer.id
                activePanel?.refresh()
            }
            return true
        }
        // Pinch / rotate change the selected text.
        guard let selected = session.selectedText else { return false }
        return !selected.isLocked && !selected.isHidden
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPinchGestureRecognizer && other is UIRotationGestureRecognizer)
        || (gestureRecognizer is UIRotationGestureRecognizer && other is UIPinchGestureRecognizer)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvasView }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCanvas()
    }
}

// MARK: - Tool bar

extension TextBehindSubjectVC: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Tool.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorToolClvCell", for: indexPath) as! EditorToolClvCell
        let tool = Tool.allCases[indexPath.item]
        cell.setData(title: tool.title, symbol: tool.symbol, enabled: sourcesReady, selected: tool == activeTool)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: floor(collectionView.bounds.width / CGFloat(Tool.allCases.count)), height: collectionView.bounds.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { 0 }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tool = Tool.allCases[indexPath.item]
        if tool == activeTool {
            session.commit()
            closePanel(revert: false)
        } else {
            openTool(tool)
        }
    }
}

// MARK: - Background photo

extension TextBehindSubjectVC: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        let hud = ProgressHUD.show(in: view, message: "Adding background…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak self] in
            let picked = await PhotoPickerLoader.load(results)
            guard let photo = picked.first else {
                hud.dismiss()
                self?.showMessage("Couldn't add image", "The selected photo couldn't be read.")
                return
            }
            let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                defer { photo.discardTemporaryFile() }
                return photo.loadImage(maxPixel: BackgroundRemovalService.maxProcessingDimension)
            }.value
            do {
                guard let image else { throw BackgroundRemovalError.invalidImage }
                // Stored as a decorative background – background removal is not run on it.
                let selection = try await viewModel.addCustomBackground(image)
                hud.dismiss()
                guard let self, let fileName = selection.customFileName else { return }
                (self.activePanel as? BackgroundPickerView)?.addCustomImage(fileName)
            } catch {
                hud.dismiss()
                self?.showMessage("Couldn't add image", error.localizedDescription)
            }
        }
    }
}

/// UIColorPickerViewController reporting the final colour through a closure.
final class TBColorPickerController: UIColorPickerViewController, UIColorPickerViewControllerDelegate {
    var onPick: ((UIColor) -> Void)?
    private var lastHex: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        // Closing the picker without choosing keeps the current colour.
        lastHex = selectedColor.hexRGB
    }
    
    private func deliver(_ color: UIColor) {
        // didSelect and didFinish can report the same colour; apply it once.
        guard color.hexRGB != lastHex else { return }
        lastHex = color.hexRGB
        onPick?(color)
    }
    
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        deliver(viewController.selectedColor)
    }
    
    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard !continuously else { return }
        deliver(color)
    }
}
extension TextBehindSubjectVC: BannerViewDelegate {
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Ad loaded successfully")
        self.lodingAds.isHidden = true
        self.view.setTemplateWithSubviews(false)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Ad failed to load: \(error.localizedDescription)")
        // Stop the shimmer even on failure so the user doesn't see a loading state forever
    }
}

