//
//  RemovingBackgroundEditorVC.swift
//  Background Removal
//
//  07 Result & Editor: canvas preview (checkerboard behind transparent areas – UI only),
//  undo / redo, hold-to-compare, thumbnail strip for batch projects and the tool bar:
//  • Remove Background / Batch Remove → Refine, Shadow, Resize
//  • Change Background               → Background, Refine, Shadow, Resize
//  The preview is rendered by ImageCompositingService – the same code as the export.
//

import UIKit
import PhotosUI
import UIView_Shimmer
import GoogleMobileAds

class RemovingBackgroundEditorVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var btnUndo: UIButton!
    @IBOutlet weak var btnRedo: UIButton!
    @IBOutlet weak var btnExport: UIButton!
    @IBOutlet weak var vwStatusChip: UIView!
    @IBOutlet weak var imgStatusIcon: UIImageView!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var btnStatus: UIButton!
    @IBOutlet weak var vwCanvasContainer: UIView!
    @IBOutlet weak var vwCanvasCard: UIView!
    @IBOutlet weak var canvasWidth: NSLayoutConstraint!
    @IBOutlet weak var canvasHeight: NSLayoutConstraint!
    @IBOutlet weak var vwChecker: CheckerboardView!
    @IBOutlet weak var imgPreview: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var btnCompare: UIButton!
    @IBOutlet weak var clvThumbnails: UICollectionView!
    @IBOutlet weak var thumbnailsHeight: NSLayoutConstraint!
    @IBOutlet weak var vwToolbar: UIView!
    @IBOutlet weak var clvTools: UICollectionView!
    /// Strong: it is deactivated while a tool sheet is open.
    @IBOutlet var containerBottom: NSLayoutConstraint!

    /// Set by the presenter before the screen appears.
    var viewModel: BackgroundRemovalViewModel!

    private var currentItemID: UUID?
    private var tools: [EditorTool] { viewModel.project.mode.tools }

    // Preview
    private var previewTask: Task<Void, Never>?
    private var previewSize: CGSize?
    private var lastPreview: UIImage?
    private var isComparing = false

    // Tool sheet in progress (preview only until ✓)
    private var activePanel: EditorToolPanel?
    /// Shared tool-panel presentation (hides the tool bar while a panel is open).
    private lazy var panelPresenter = EditorPanelPresenter(rootView: view, toolbar: vwToolbar, canvas: vwCanvasContainer,
                                                           normalCanvasBottom: containerBottom,
                                                           alsoHidden: [clvThumbnails], followsKeyboard: false)
    private var activeTool: EditorTool?
    /// Applies the open panel's draft (used by ✓ and when switching tools).
    private var activeApply: (() -> Void)?
    private var draftBackground: BackgroundSelection?
    private var draftEdits: ItemEdits?
    private var didAutoOpenBackground = false

    // Undo / redo per image
    private var undoStacks: [UUID: [ItemSnapshot]] = [:]
    private var redoStacks: [UUID: [ItemSnapshot]] = [:]

    private var observers: [NSObjectProtocol] = []
    /// Debounced Recents thumbnail update after edits.
    private var thumbnailTask: Task<Void, Never>?
    private var didRefreshThumbnailOnOpen = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        currentItemID = viewModel.project.completedItems.first?.id ?? viewModel.items.first?.id
        setupViews()
        observe()
        reloadThumbnails()
        showCurrentItem(animated: false)
        // Resume items that were not finished (e.g. after relaunch). Failed items wait for Retry.
        if viewModel.hasPendingItems { viewModel.startProcessing() }
        bannerAd()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clvThumbnails.reloadData()
        showCurrentItem(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autoOpenBackgroundIfNeeded()
        if !didRefreshThumbnailOnOpen {
            // Also repairs projects saved before thumbnails showed the edited result.
            didRefreshThumbnailOnOpen = true
            scheduleThumbnail(delay: 0)
        }
    }

    /// Keeps the Recents thumbnail in sync with the edited result (not after every UI event:
    /// after saved changes, debounced).
    private func scheduleThumbnail(delay: Double = 1.2) {
        thumbnailTask?.cancel()
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        thumbnailTask = Task {
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            await viewModel.refreshThumbnail()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The card size is computed from the container's current size (never from the card's
        // previous size). Apply a changed size right away so it follows panel open/close
        // animations instead of jumping a frame later.
        if fitCanvas() { view.layoutIfNeeded() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        previewTask?.cancel()
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
        let adsType = appData.removingBackgroundEditorVC.adType ?? ""
        let adsSize = appData.removingBackgroundEditorVC.adSize ?? 50
        
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

    // MARK: - Setup

    private func setupViews() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnBack.layer.cornerRadius = 22
        btnBack.layer.borderWidth = 1
        btnBack.layer.borderColor = UIColor(named: "Border Color")?.cgColor
        btnBack.accessibilityLabel = "Back"
        btnUndo.setSymbol("arrow.uturn.backward", size: 19)
        btnRedo.setSymbol("arrow.uturn.forward", size: 19)
        btnUndo.accessibilityLabel = "Undo"
        btnRedo.accessibilityLabel = "Redo"
        btnExport.layer.cornerRadius = 22

        vwStatusChip.layer.cornerRadius = 20
        vwStatusChip.layer.shadowColor = UIColor.black.cgColor
        vwStatusChip.layer.shadowOpacity = 0.06
        vwStatusChip.layer.shadowRadius = 10
        vwStatusChip.layer.shadowOffset = CGSize(width: 0, height: 4)

        vwCanvasCard.layer.cornerRadius = 24
        vwCanvasCard.layer.cornerCurve = .continuous
        vwCanvasCard.clipsToBounds = true
        vwChecker.cellSize = 14
        imgPreview.contentMode = .scaleAspectFit
        imgPreview.isAccessibilityElement = true

        btnCompare.setSymbol("rectangle.lefthalf.inset.filled", size: 17)
        btnCompare.tintColor = UIColor(named: "PrimaryText")
        btnCompare.layer.cornerRadius = 24
        btnCompare.accessibilityLabel = "Hold to compare with the original"

        vwToolbar.layer.cornerRadius = 28
        vwToolbar.layer.shadowColor = UIColor.black.cgColor
        vwToolbar.layer.shadowOpacity = 0.06
        vwToolbar.layer.shadowRadius = 14
        vwToolbar.layer.shadowOffset = CGSize(width: 0, height: 4)

        clvTools.register(UINib(nibName: "EditorToolClvCell", bundle: nil), forCellWithReuseIdentifier: "EditorToolClvCell")
        clvTools.dataSource = self
        clvTools.delegate = self
        clvTools.isScrollEnabled = false

        clvThumbnails.register(UINib(nibName: "ProcessedImageCell", bundle: nil), forCellWithReuseIdentifier: "ProcessedImageCell")
        clvThumbnails.dataSource = self
        clvThumbnails.delegate = self
        clvThumbnails.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        if let layout = clvThumbnails.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 56, height: 56)
            layout.minimumLineSpacing = 10
        }
    }

    private func observe() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: BackgroundRemovalViewModel.itemDidChangeNotification,
                                            object: viewModel, queue: .main) { [weak self] note in
            let id = note.userInfo?[BackgroundRemovalViewModel.itemIDKey] as? UUID
            MainActor.assumeIsolated {
                self?.scheduleThumbnail()
                self?.itemDidChange(id)
            }
        })
    }

    // MARK: - State

    private var currentItem: BackgroundRemovalItem? {
        currentItemID.flatMap { viewModel.item($0) }
    }

    private var isPanelOpen: Bool { activePanel != nil }

    private func reloadThumbnails() {
        let multiple = viewModel.items.count > 1
        thumbnailsHeight.constant = multiple ? 64 : 0
        clvThumbnails.isHidden = !multiple
        clvThumbnails.reloadData()
    }

    private func itemDidChange(_ id: UUID?) {
        guard let id, let index = viewModel.items.firstIndex(where: { $0.id == id }) else { return }
        if clvThumbnails.numberOfItems(inSection: 0) == viewModel.items.count {
            clvThumbnails.reloadItems(at: [IndexPath(item: index, section: 0)])
        } else {
            clvThumbnails.reloadData()
        }
        guard id == currentItemID, !isPanelOpen else { return }
        showCurrentItem(animated: true)
        autoOpenBackgroundIfNeeded()
    }

    private func updateChrome() {
        let item = currentItem
        let done = item?.isCompleted == true
        clvTools.reloadData()
        btnExport.isEnabled = !viewModel.project.completedItems.isEmpty && !isPanelOpen
        btnExport.alpha = btnExport.isEnabled ? 1 : 0.5
        btnCompare.isHidden = !done
        updateUndoButtons()

        let accent = UIColor(named: "AccentColor") ?? .systemBlue
        btnStatus.isEnabled = item?.status == .failed
        switch item?.status {
        case .completed where done:
            setChip(symbol: "checkmark.circle.fill", tint: accent, text: "Background removed")
            spinner.stopAnimating()
        case .failed:
            setChip(symbol: "exclamationmark.circle.fill", tint: .systemRed, text: "Couldn't remove · Tap to retry")
            spinner.stopAnimating()
        case .processing:
            setChip(symbol: "wand.and.stars", tint: accent, text: "Removing background…")
            spinner.startAnimating()
        default:
            setChip(symbol: "clock.fill", tint: UIColor(named: "SecondaryText") ?? .gray, text: "Waiting…")
            spinner.startAnimating()
        }
    }

    private func setChip(symbol: String, tint: UIColor, text: String) {
        imgStatusIcon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        imgStatusIcon.tintColor = tint
        lblStatus.text = text
        vwStatusChip.accessibilityLabel = text
    }

    private func autoOpenBackgroundIfNeeded() {
        guard viewModel.project.mode == .changeBackground, !didAutoOpenBackground, !isPanelOpen,
              currentItem?.isCompleted == true, viewIfLoaded?.window != nil,
              currentItem?.background == BackgroundSelection.none else { return }
        didAutoOpenBackground = true
        openTool(.background)
    }

    // MARK: - Preview

    /// Values shown on the canvas: the open sheet's draft, otherwise the saved item.
    private var shownBackground: BackgroundSelection { draftBackground ?? currentItem?.background ?? BackgroundSelection.none }
    private var shownEdits: ItemEdits { draftEdits ?? currentItem?.edits ?? ItemEdits.unedited }

    private func showCurrentItem(animated: Bool) {
        updateChrome()
        guard let item = currentItem else {
            imgPreview.image = nil
            return
        }
        imgPreview.accessibilityLabel = "\(item.sourceName ?? "Image"), \(item.status.displayName)"
        if item.isCompleted {
            renderPreview(animated: animated)
        } else {
            previewTask?.cancel()
            vwChecker.isHidden = true
            let id = item.id
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            previewTask = Task { [weak self] in
                let image = await viewModel.originalPreview(for: id, maxPixel: 1400)
                guard let self, !Task.isCancelled, self.currentItemID == id else { return }
                self.setPreview(image, animated: animated)
            }
        }
    }

    /// Renders background + edits with the export compositor. `fast` uses a smaller size while
    /// a slider is moving.
    private func renderPreview(animated: Bool = false, fast: Bool = false) {
        guard let item = currentItem, item.isCompleted else { return }
        previewTask?.cancel()
        let id = item.id
        let background = shownBackground
        let edits = shownEdits
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        vwChecker.isHidden = !background.isTransparent
        previewTask = Task { [weak self] in
            if fast { try? await Task.sleep(nanoseconds: 30_000_000) }   // coalesce slider events
            guard !Task.isCancelled else { return }
            do {
                let image = try await viewModel.compositePreview(for: id, background: background, edits: edits,
                                                                 maxPixel: fast ? 900 : 1400)
                guard let self, !Task.isCancelled, self.currentItemID == id else { return }
                self.lastPreview = image
                if !self.isComparing { self.setPreview(image, animated: animated) }
            } catch {
                guard let self, !Task.isCancelled else { return }
                showToast(message: "This background couldn't be loaded. Check your connection.")
                if self.draftBackground != nil, case .remoteImage = background {
                    // Fall back to the saved background; ✓ then changes nothing.
                    self.draftBackground = nil
                    let saved = self.currentItem?.background ?? BackgroundSelection.none
                    (self.activePanel as? BackgroundToolView)?.configure(viewModel: viewModel, selection: saved)
                    self.renderPreview()
                }
            }
        }
    }

    private func setPreview(_ image: UIImage?, animated: Bool) {
        previewSize = image?.size
        fitCanvas()
        if animated {
            UIView.transition(with: imgPreview, duration: 0.25, options: .transitionCrossDissolve) {
                self.imgPreview.image = image
            }
        } else {
            imgPreview.image = image
        }
    }

    /// Sizes the canvas card to the rendered image's aspect ratio inside the available area.
    /// Returns true when the card size changed.
    @discardableResult
    private func fitCanvas() -> Bool {
        let bounds = vwCanvasContainer.bounds.insetBy(dx: 24, dy: 8)
        guard bounds.width > 0, bounds.height > 0 else { return false }
        let size = previewSize ?? CGSize(width: 3, height: 4)
        let scale = min(bounds.width / max(size.width, 1), bounds.height / max(size.height, 1))
        let width = floor(size.width * scale)
        let height = floor(size.height * scale)
        guard canvasWidth.constant != width || canvasHeight.constant != height else { return false }
        canvasWidth.constant = width
        canvasHeight.constant = height
        return true
    }

    // MARK: - Undo / redo

    private func pushUndo(_ snapshot: ItemSnapshot) {
        var stack = undoStacks[snapshot.itemID] ?? []
        stack.append(snapshot)
        if stack.count > 30 { stack.removeFirst() }
        undoStacks[snapshot.itemID] = stack
        redoStacks[snapshot.itemID] = []
        updateUndoButtons()
    }

    /// Saves a change of the current item and records it for undo.
    private func commit(background: BackgroundSelection? = nil, edits: ItemEdits? = nil) {
        guard let id = currentItemID, let before = viewModel.snapshot(of: id) else { return }
        let newBackground = background ?? before.background
        let newEdits = edits ?? before.edits
        guard newBackground != before.background || newEdits != before.edits else { return }
        pushUndo(before)
        viewModel.setBackground(newBackground, for: id)
        viewModel.setEdits(newEdits, for: id)
    }

    private func updateUndoButtons() {
        let id = currentItemID
        let canUndo = !(id.flatMap { undoStacks[$0] } ?? []).isEmpty && !isPanelOpen
        let canRedo = !(id.flatMap { redoStacks[$0] } ?? []).isEmpty && !isPanelOpen
        let disabled = UIColor(red: 0.72, green: 0.79, blue: 0.87, alpha: 1)
        btnUndo.isEnabled = canUndo
        btnRedo.isEnabled = canRedo
        btnUndo.tintColor = canUndo ? UIColor(named: "PrimaryText") : disabled
        btnRedo.tintColor = canRedo ? UIColor(named: "PrimaryText") : disabled
    }

    @IBAction func btnUndo(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard let id = self.currentItemID, let previous = self.undoStacks[id]?.popLast(),
                  let current = self.viewModel.snapshot(of: id) else { return }
            self.redoStacks[id, default: []].append(current)
            self.viewModel.restore(previous)
            self.updateUndoButtons()
        }
    }

    @IBAction func btnRedo(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard let id = self.currentItemID, let next = self.redoStacks[id]?.popLast(),
                  let current = self.viewModel.snapshot(of: id) else { return }
            self.undoStacks[id, default: []].append(current)
            self.viewModel.restore(next)
            self.updateUndoButtons()
        }
    }

    // MARK: - Tools

    private func openTool(_ tool: EditorTool) {
        guard let item = currentItem, item.isCompleted else {
            showToast(message: "Wait until the background is removed")
            return
        }
        if isPanelOpen {
            guard tool != activeTool else { return }
            // Switching tools keeps the current edit; the new panel replaces this one and the
            // tool bar stays hidden.
            activeApply?()
            if tool == .refine {
                closePanel(animated: false)
            } else {
                activePanel = nil
                draftBackground = nil
                draftEdits = nil
            }
        }
        switch tool {
        case .refine:
            openRefine()
        case .background:
            let panel = EditorToolPanel.loadFromNib(BackgroundToolView.self)
            panel.configure(viewModel: viewModel, selection: item.background)
            panel.onChange = { [weak self] selection in
                self?.draftBackground = selection
                self?.renderPreview()
            }
            panel.onAddPhoto = { [weak self] in self?.pickBackgroundPhoto() }
            panel.onPickColor = { [weak self] color in self?.pickCustomColor(color) }
            present(panel: panel, apply: { [weak self] in
                guard let self, let selection = self.draftBackground else { return }
                self.commit(background: selection)
            }, tool: .background)
        case .shadow:
            let panel = EditorToolPanel.loadFromNib(ShadowToolView.self)
            panel.configure(item.edits.shadow)
            panel.onChange = { [weak self] shadow in
                guard let self else { return }
                var edits = self.shownEdits
                edits.shadow = shadow
                self.draftEdits = edits
                self.renderPreview(fast: true)
            }
            present(panel: panel, apply: { [weak self] in
                guard let self, let edits = self.draftEdits else { return }
                self.commit(edits: edits)
            }, tool: .shadow)
        case .resize:
            let panel = EditorToolPanel.loadFromNib(ResizeToolView.self)
            panel.configure(aspect: item.edits.aspect, subjectScale: item.edits.subjectScale)
            panel.onChange = { [weak self] aspect, scale in
                guard let self else { return }
                var edits = self.shownEdits
                edits.aspect = aspect
                edits.subjectScale = scale
                self.draftEdits = edits
                self.renderPreview(fast: true)
            }
            present(panel: panel, apply: { [weak self] in
                guard let self, let edits = self.draftEdits else { return }
                self.commit(edits: edits)
            }, tool: .resize)
        }
    }

    /// Shows a tool panel in the editor area above the tool bar (the tool bar stays visible).
    /// The panel never reaches the home-indicator area, so its height doesn't depend on
    /// safe-area insets and stays the same while it is open.
    private func present(panel: EditorToolPanel, apply: @escaping () -> Void, tool: EditorTool) {
        draftBackground = nil
        draftEdits = nil
        activePanel = panel
        activeTool = tool
        activeApply = apply
        panel.onCancel = { [weak self] in self?.closePanel(animated: true) }
        panel.onApply = { [weak self] in
            apply()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self?.closePanel(animated: true)
        }
        // Hides the tool bar and slides the panel up from the bottom (or replaces the open one).
        panelPresenter.show(panel, preferredHeight: nil)
        updateChrome()
    }

    private func closePanel(animated: Bool = true) {
        guard activePanel != nil else { return }
        activePanel = nil
        activeTool = nil
        activeApply = nil
        draftBackground = nil
        draftEdits = nil
        // Restores the tool bar and the normal canvas layout.
        panelPresenter.dismiss(animated: animated)
        showCurrentItem(animated: true)
    }

    private func openRefine() {
        guard let id = currentItemID else { return }
        let hud = ProgressHUD.show(in: view, message: "Preparing…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak self] in
            let inputs = await viewModel.refineInputs(for: id)
            hud.dismiss()
            guard let self else { return }
            guard let inputs else {
                self.presentErrorAlert(title: "Refine unavailable", message: "This image couldn't be opened for refining.")
                return
            }
            let vc = RefineEdgesVC.fatchEditorInstance()
            vc.original = inputs.original
            vc.initialMask = inputs.mask
            vc.onApply = { [weak self] mask in self?.applyRefinedMask(mask, original: inputs.original, itemID: id) }
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func applyRefinedMask(_ mask: CGImage, original: UIImage, itemID: UUID) {
        guard let before = viewModel.snapshot(of: itemID) else { return }
        let hud = ProgressHUD.show(in: view, message: "Applying…")
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak self] in
            do {
                try await viewModel.applyRefinedMask(mask, original: original, for: itemID)
                hud.dismiss()
                self?.pushUndo(before)
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't apply", message: error.localizedDescription)
            }
        }
    }

    private func pickBackgroundPhoto() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func pickCustomColor(_ color: UIColor?) {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.selectedColor = color ?? .white
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) {
        adsManager.showInterstitial {
            if self.isPanelOpen {
                self.closePanel()
                return
            }
            // Processing stops when the user leaves; unfinished items stay "Waiting" in the saved project.
            self.viewModel.cancelProcessing()
            self.thumbnailTask?.cancel()
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            Task {
                // Final thumbnail first, then remove files nothing references any more.
                await viewModel.refreshThumbnail()
                viewModel.purgeUnusedFiles()
            }
            self.navigationController?.popViewController(animated: true)
        }
    }

    @IBAction func btnExport(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard !self.isPanelOpen else { return }
            ExportVC.push(from: self.navigationController, viewModel: self.viewModel,
                          itemID: self.currentItem?.isCompleted == true ? self.currentItemID : self.viewModel.project.completedItems.first?.id)
        }
    }

    @IBAction func btnStatus(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard let item = self.currentItem, item.status == .failed else { return }
            if let message = item.errorMessage {
                self.presentErrorAlert(title: "Background removal failed", message: message,
                                  retry: { [weak self] in self?.viewModel.retry(item.id) })
            } else {
                self.viewModel.retry(item.id)
            }
        }
    }

    @IBAction func btnCompareDown(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard let id = self.currentItemID, self.currentItem?.isCompleted == true else { return }
            self.isComparing = true
            let viewModel: BackgroundRemovalViewModel = self.viewModel
            Task { [weak self] in
                let original = await viewModel.originalPreview(for: id, maxPixel: 1400)
                guard let self, self.isComparing, self.currentItemID == id else { return }
                self.vwChecker.isHidden = true
                self.imgPreview.image = original
            }
        }
    }

    @IBAction func btnCompareUp(_ sender: UIButton) {
        adsManager.showInterstitial {
            guard self.isComparing else { return }
            self.isComparing = false
            self.vwChecker.isHidden = !self.shownBackground.isTransparent
            self.imgPreview.image = self.lastPreview
        }
    }
}

// MARK: - Collections (tools + thumbnails)

extension RemovingBackgroundEditorVC: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == clvTools ? tools.count : viewModel.items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == clvTools {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorToolClvCell", for: indexPath) as! EditorToolClvCell
            let tool = tools[indexPath.item]
            cell.setData(title: tool.title, symbol: tool.symbol, enabled: currentItem?.isCompleted == true,
                         selected: tool == activeTool)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProcessedImageCell", for: indexPath) as! ProcessedImageCell
        let item = viewModel.items[indexPath.item]
        cell.configure(item: item, isCurrent: item.id == currentItemID, selectionMode: false, isChecked: false)
        let id = item.id
        let viewModel: BackgroundRemovalViewModel = self.viewModel
        Task { [weak cell] in
            let image = await viewModel.thumbnail(for: id)
            cell?.setThumbnail(image, for: id)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == clvTools {
            let count = CGFloat(max(tools.count, 1))
            return CGSize(width: floor(collectionView.bounds.width / count), height: collectionView.bounds.height)
        }
        return CGSize(width: 56, height: 56)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        collectionView == clvTools ? 0 : 10
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == clvTools {
            openTool(tools[indexPath.item])
            return
        }
        guard !isPanelOpen else { return }
        let item = viewModel.items[indexPath.item]
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

// MARK: - Background photo

extension RemovingBackgroundEditorVC: PHPickerViewControllerDelegate {
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
                (self.activePanel as? BackgroundToolView)?.addCustomFile(fileName)
            } catch {
                hud.dismiss()
                self?.presentErrorAlert(title: "Couldn't add image", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Custom colour

extension RemovingBackgroundEditorVC: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        (activePanel as? BackgroundToolView)?.applyCustomColor(viewController.selectedColor)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        guard !continuously else { return }
        (activePanel as? BackgroundToolView)?.applyCustomColor(color)
    }
}
extension RemovingBackgroundEditorVC: BannerViewDelegate {
    
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
