//
//  EditorVC.swift
//  Background Removal
//
//  07 Result & Editor (Editor.storyboard) + tool sheets loaded from XIB:
//  Background (08), Text Behind (09), Refine Edges (10, separate screen), Shadow, Resize.
//

import UIKit
import PhotosUI

class EditorVC: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var btnUndo: UIButton!
    @IBOutlet weak var btnRedo: UIButton!
    @IBOutlet weak var btnExport: UIButton!
    @IBOutlet weak var vwStatusChip: UIView!
    @IBOutlet weak var imgStatusCheck: UIImageView!
    @IBOutlet weak var vwCanvasContainer: UIView!
    @IBOutlet weak var vwCanvasShadow: UIView!
    @IBOutlet weak var canvasView: EditorCanvasView!
    @IBOutlet weak var canvasWidth: NSLayoutConstraint!
    @IBOutlet weak var canvasHeight: NSLayoutConstraint!
    @IBOutlet weak var btnCompare: UIButton!
    @IBOutlet weak var vwToolbar: UIView!
    @IBOutlet weak var clvTools: UICollectionView!
    /// Strong: it is deactivated while a tool sheet is open.
    @IBOutlet var canvasBottomToToolbar: NSLayoutConstraint!

    // MARK: - State

    var session: EditSession!

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
            case .refine: return "eraser"
            case .shadow: return "shadow"
            case .resize: return "crop"
            }
        }
    }

    private var activeTool: Tool?
    private var panel: EditorToolPanel?
    private var canvasBottomToPanel: NSLayoutConstraint?

    /// While a sheet is open, edits are drafts with their own undo/redo; ✓ commits, ✕ reverts.
    private var drafts: [EditSpec] = []
    private var draftIndex = 0
    private var continuousEdit = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        clvTools.register(UINib(nibName: "EditorToolClvCell", bundle: nil), forCellWithReuseIdentifier: "EditorToolClvCell")
        clvTools.dataSource = self
        clvTools.delegate = self

        session.onChange = { [weak self] in self?.sessionChanged() }
        canvasView.onTextMoved = { [weak self] point in self?.textMoved(to: point) }
        canvasView.onTextMoveEnded = { [weak self] in self?.continuousEdit = false }
        sessionChanged()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitCanvas(animated: false)
        vwCanvasShadow.layer.shadowPath = UIBezierPath(roundedRect: vwCanvasShadow.bounds, cornerRadius: 32).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { applyBorders() }
    }

    private func setupUI() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnUndo.setSymbol("arrow.uturn.backward", size: 19)
        btnRedo.setSymbol("arrow.uturn.forward", size: 19)
        btnCompare.setSymbol("square.split.2x1", size: 19)
        btnCompare.tintColor = UIColor(named: "PrimaryText")
        imgStatusCheck.image = UIImage(systemName: "checkmark.circle.fill")
        imgStatusCheck.tintColor = UIColor(named: "AccentColor")

        btnBack.layer.cornerRadius = 22
        btnCompare.layer.cornerRadius = 24
        btnExport.layer.cornerRadius = 22
        vwStatusChip.layer.cornerRadius = 19
        vwToolbar.layer.cornerRadius = 32
        canvasView.layer.cornerRadius = 32
        canvasView.layer.cornerCurve = .continuous

        vwCanvasShadow.layer.cornerRadius = 32
        vwCanvasShadow.layer.shadowColor = UIColor.black.cgColor
        vwCanvasShadow.layer.shadowOpacity = 0.1
        vwCanvasShadow.layer.shadowOffset = CGSize(width: 0, height: 14)
        vwCanvasShadow.layer.shadowRadius = 17
        vwToolbar.layer.shadowColor = UIColor.black.cgColor
        vwToolbar.layer.shadowOpacity = 0.08
        vwToolbar.layer.shadowOffset = CGSize(width: 0, height: 12)
        vwToolbar.layer.shadowRadius = 15
        applyBorders()
    }

    private func applyBorders() {
        let border = (UIColor(named: "Border Color") ?? .lightGray).cgColor
        for view in [btnBack!, btnCompare!, vwStatusChip!, vwToolbar!] {
            view.layer.borderWidth = 1
            view.layer.borderColor = border
        }
    }

    // MARK: - Canvas

    private var currentSpec: EditSpec {
        drafts.indices.contains(draftIndex) ? drafts[draftIndex] : session.spec
    }

    private func sessionChanged() {
        canvasView.show(session: session, spec: activeTool == nil ? nil : currentSpec)
        fitCanvas(animated: false)
        updateUndoButtons()
    }

    /// Sizes the canvas to the edit's aspect ratio inside the available area.
    private func fitCanvas(animated: Bool) {
        let area = vwCanvasContainer.bounds.insetBy(dx: 28, dy: 20)
        guard area.width > 0, area.height > 0 else { return }
        let ratio = canvasView.aspectRatio(for: currentSpec)
        var size = CGSize(width: area.width, height: area.width / ratio)
        if size.height > area.height {
            size = CGSize(width: area.height * ratio, height: area.height)
        }
        guard abs(canvasWidth.constant - size.width) > 0.5 || abs(canvasHeight.constant - size.height) > 0.5 else { return }
        canvasWidth.constant = size.width
        canvasHeight.constant = size.height
        if animated {
            UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
        }
    }

    private func render(_ spec: EditSpec) {
        canvasView.show(session: session, spec: spec)
        view.setNeedsLayout()
        fitCanvas(animated: true)
        updateUndoButtons()
    }

    private func updateUndoButtons() {
        let canUndo = activeTool == nil ? session.canUndo : draftIndex > 0
        let canRedo = activeTool == nil ? session.canRedo : draftIndex < drafts.count - 1
        btnUndo.isEnabled = canUndo
        btnRedo.isEnabled = canRedo
        let enabled = UIColor(named: "PrimaryText") ?? .label
        let disabled = EditorSwatches.hex(0xB7C9DE)
        btnUndo.tintColor = canUndo ? enabled : disabled
        btnRedo.tintColor = canRedo ? enabled : disabled
    }

    // MARK: - Drafts

    private func pushDraft(_ spec: EditSpec) {
        guard spec != currentSpec else { return }
        drafts.removeSubrange((draftIndex + 1)...)
        drafts.append(spec)
        draftIndex = drafts.count - 1
        render(spec)
    }

    /// Slider drags / typing / text dragging collapse into one undo step.
    private func updateDraft(_ spec: EditSpec) {
        guard !drafts.isEmpty else { return }
        if !continuousEdit {
            guard spec != currentSpec else { return }
            continuousEdit = true
            pushDraft(spec)
            return
        }
        drafts[draftIndex] = spec
        drafts.removeSubrange((draftIndex + 1)...)
        render(spec)
    }

    private func textMoved(to point: CGPoint) {
        guard let textPanel = panel as? TextToolView else { return }
        textPanel.updateCenter(point)
        var spec = currentSpec
        spec.text = textPanel.spec
        updateDraft(spec)
    }

    // MARK: - Tools

    private func open(_ tool: Tool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if tool == .refine {
            let vc = RefineEdgesVC.fatchEditorInstance()
            vc.session = session
            vc.onApply = { [weak self] mask in self?.session.apply(mask: mask) }
            navigationController?.pushViewController(vc, animated: true)
            return
        }
        guard activeTool == nil else { return }
        activeTool = tool
        continuousEdit = false
        let start = session.spec
        drafts = [start]
        draftIndex = 0

        // Text and Shadow show their effect immediately (as the first undoable step).
        var initial: EditSpec?
        if tool == .text, start.text == nil {
            var spec = start
            spec.text = TextSpec()
            if spec.background.isTransparent { spec.background = .color(EditorSwatches.brandBlue) }
            initial = spec
        } else if tool == .shadow, !start.shadow.isOn {
            var spec = start
            spec.shadow.isOn = true
            initial = spec
        }

        let panel = makePanel(for: tool, spec: initial ?? start)
        showPanel(panel)
        if let initial { pushDraft(initial) }
        canvasView.isEditingText = tool == .text
        updateUndoButtons()
    }

    private func makePanel(for tool: Tool, spec: EditSpec) -> EditorToolPanel {
        let panel: EditorToolPanel
        switch tool {
        case .background:
            let view = EditorToolPanel.loadFromNib(BackgroundToolView.self)
            let photos = session.photoOrder.compactMap { id in session.photos[id].map { (id: id, image: $0) } }
            view.configure(current: spec.background, photos: photos)
            view.onSelect = { [weak self] background in
                guard let self else { return }
                var next = self.currentSpec
                next.background = background
                self.pushDraft(next)
            }
            view.onChoosePhoto = { [weak self] in self?.choosePhoto() }
            view.onCustomColor = { [weak self] in self?.chooseCustomColor() }
            panel = view
        case .text:
            let view = EditorToolPanel.loadFromNib(TextToolView.self)
            view.configure(spec.text ?? TextSpec())
            view.onChange = { [weak self] text in
                guard let self else { return }
                var next = self.currentSpec
                next.text = text
                self.updateDraft(next)
            }
            view.onCommit = { [weak self] in self?.continuousEdit = false }
            panel = view
        case .shadow:
            let view = EditorToolPanel.loadFromNib(ShadowToolView.self)
            view.configure(spec.shadow)
            view.onChange = { [weak self] shadow in
                guard let self else { return }
                var next = self.currentSpec
                next.shadow = shadow
                self.updateDraft(next)
            }
            view.onCommit = { [weak self] in self?.continuousEdit = false }
            panel = view
        case .resize:
            let view = EditorToolPanel.loadFromNib(ResizeToolView.self)
            view.configure(aspect: spec.aspect, subjectScale: spec.subjectScale)
            view.onChange = { [weak self] aspect, scale in
                guard let self else { return }
                var next = self.currentSpec
                next.aspect = aspect
                next.subjectScale = scale
                self.updateDraft(next)
            }
            view.onCommit = { [weak self] in self?.continuousEdit = false }
            panel = view
        case .refine:
            fatalError("Refine opens its own screen")
        }
        panel.onCancel = { [weak self] in self?.closePanel(apply: false) }
        panel.onApply = { [weak self] in self?.closePanel(apply: true) }
        return panel
    }

    private func showPanel(_ newPanel: EditorToolPanel) {
        newPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newPanel)
        NSLayoutConstraint.activate([
            newPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        canvasBottomToToolbar.isActive = false
        canvasBottomToPanel = vwCanvasContainer.bottomAnchor.constraint(equalTo: newPanel.topAnchor)
        canvasBottomToPanel?.isActive = true
        panel = newPanel

        view.layoutIfNeeded()
        newPanel.transform = CGAffineTransform(translationX: 0, y: newPanel.bounds.height)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            newPanel.transform = .identity
            self.vwToolbar.alpha = 0
            self.btnExport.alpha = 0
            self.vwStatusChip.alpha = 0
            self.btnCompare.alpha = 0
            self.fitCanvas(animated: false)
            self.view.layoutIfNeeded()
        }
    }

    private func closePanel(apply: Bool) {
        guard let panel else { return }
        view.endEditing(true)
        if apply {
            var result = currentSpec
            if let text = result.text, text.text.trimmingCharacters(in: .whitespaces).isEmpty { result.text = nil }
            session.apply(spec: result)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        activeTool = nil
        drafts = []
        draftIndex = 0
        continuousEdit = false
        canvasView.isEditingText = false
        canvasView.show(session: session)

        canvasBottomToPanel?.isActive = false
        canvasBottomToToolbar.isActive = true
        self.panel = nil
        UIView.animate(withDuration: 0.3, animations: {
            panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height)
            self.vwToolbar.alpha = 1
            self.btnExport.alpha = 1
            self.vwStatusChip.alpha = 1
            self.btnCompare.alpha = 1
            self.view.layoutIfNeeded()
            self.fitCanvas(animated: false)
            self.view.layoutIfNeeded()
        }, completion: { _ in
            panel.removeFromSuperview()
        })
        updateUndoButtons()
    }

    // MARK: - Photo / colour pickers for the Background sheet

    private func choosePhoto() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func chooseCustomColor() {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) {
        if activeTool != nil {
            closePanel(apply: false)
            return
        }
        let alert = UIAlertController(title: "Discard edits?", message: "Your cutout hasn't been exported yet.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    @IBAction func btnUndo(_ sender: UIButton) {
        continuousEdit = false
        if activeTool == nil {
            session.undo()
        } else if draftIndex > 0 {
            draftIndex -= 1
            render(drafts[draftIndex])
            refreshPanel()
        }
    }

    @IBAction func btnRedo(_ sender: UIButton) {
        continuousEdit = false
        if activeTool == nil {
            session.redo()
        } else if draftIndex < drafts.count - 1 {
            draftIndex += 1
            render(drafts[draftIndex])
            refreshPanel()
        }
    }

    /// Keeps the open sheet's controls in sync after undo / redo.
    private func refreshPanel() {
        let spec = currentSpec
        switch panel {
        case let view as BackgroundToolView:
            let photos = session.photoOrder.compactMap { id in session.photos[id].map { (id: id, image: $0) } }
            view.configure(current: spec.background, photos: photos)
        case let view as TextToolView:
            view.configure(spec.text ?? TextSpec())
        case let view as ShadowToolView:
            view.configure(spec.shadow)
        case let view as ResizeToolView:
            view.configure(aspect: spec.aspect, subjectScale: spec.subjectScale)
        default:
            break
        }
    }

    @IBAction func btnExport(_ sender: UIButton) {
        let vc = ExportVC.fatchEditorInstance()
        vc.session = session
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func btnCompareDown(_ sender: UIButton) {
        canvasView.showOriginal(true)
    }

    @IBAction func btnCompareUp(_ sender: UIButton) {
        canvasView.showOriginal(false)
    }
}

// MARK: - Toolbar

extension EditorVC: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        Tool.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorToolClvCell", for: indexPath) as! EditorToolClvCell
        let tool = Tool.allCases[indexPath.item]
        cell.setData(title: tool.title, symbol: tool.symbol)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        open(Tool.allCases[indexPath.item])
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: floor(collectionView.bounds.width / CGFloat(Tool.allCases.count)), height: collectionView.bounds.height)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 0 }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { 0 }
}

// MARK: - Pickers

extension EditorVC: PHPickerViewControllerDelegate, UIColorPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                guard let self, let panel = self.panel as? BackgroundToolView else { return }
                let id = self.session.addPhoto(image)
                if let stored = self.session.photos[id] { panel.addPhoto(id: id, image: stored) }
            }
        }
    }

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        (panel as? BackgroundToolView)?.setCustomColor(viewController.selectedColor)
    }
}
