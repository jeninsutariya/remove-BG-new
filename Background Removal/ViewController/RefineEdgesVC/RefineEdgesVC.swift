//
//  RefineEdgesVC.swift
//  Background Removal
//
//  10 Refine Edges (Editor.storyboard): erase / restore the cutout with a soft brush,
//  pinch to zoom, two-finger pan, magnifier loupe and its own undo/redo.
//
//  Painting happens on a working copy (long side ≤ 2048 px) so it stays smooth on large
//  photos. A second canvas records where the user painted; on ✓ only those pixels are
//  merged back into the full-resolution matte, so untouched edges keep full detail.
//  In Restore mode the removed parts of the photo are shown faintly so you can see what
//  you are bringing back.
//

import UIKit

class RefineEdgesVC: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {

    // MARK: - Outlets

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var btnUndo: UIButton!
    @IBOutlet weak var btnRedo: UIButton!
    @IBOutlet weak var vwCanvasArea: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var vwHint: UIView!
    @IBOutlet weak var lblHint: UILabel!
    @IBOutlet weak var vwPanel: UIView!
    @IBOutlet weak var vwGrabber: UIView!
    @IBOutlet weak var btnPanelCancel: UIButton!
    @IBOutlet weak var btnPanelApply: UIButton!
    @IBOutlet weak var segMode: UISegmentedControl!
    @IBOutlet weak var sliderBrush: UISlider!
    @IBOutlet weak var lblBrushValue: UILabel!
    @IBOutlet weak var sliderSoftness: UISlider!
    @IBOutlet weak var lblSoftnessValue: UILabel!

    // MARK: - Input

    /// Upright original photo (full resolution, same pixel size as `initialMask`).
    var original: UIImage!
    /// Current matte (8-bit gray) of the foreground at full resolution.
    var initialMask: CGImage!
    /// Receives the refined full-resolution matte.
    var onApply: ((CGImage) -> Void)?

    // MARK: - State

    private static let workingMaxDimension: CGFloat = 2048
    private static let historyLimit = 12

    private struct Step {
        let mask: CGImage
        let coverage: CGImage
    }

    private var workPhoto: UIImage?
    private var workSize = CGSize(width: 1, height: 1)
    private var mask: MaskBrushCanvas?
    private var coverage: MaskBrushCanvas?
    private var stamp: CGImage?

    private let canvas = UIView()
    private let checker = CheckerboardView(frame: .zero)
    private let ghostView = UIImageView()
    private let photoView = UIImageView()
    private let maskLayer = CALayer()
    private let brushRing = UIView()
    private let brushFill = UIView()
    private let loupe = RefineLoupeView()
    private let loading = UIActivityIndicatorView(style: .large)

    private var lastPoint: CGPoint?
    private var history: [Step] = []
    private var historyIndex = 0
    private var didEdit = false
    private var isApplying = false
    /// Set when a stroke turned into a pinch; the partial stroke is thrown away.
    private var strokeAborted = false
    private var needsMaskRefresh = false
    private var displayLink: CADisplayLink?
    private var canvasSize: CGSize = .zero

    private var isReady: Bool { mask != nil }
    private var isErasing: Bool { segMode.selectedSegmentIndex == 0 }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCanvas()
        setControlsEnabled(false)
        prepareWorkingCopies()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // One finger paints here, so the edge-swipe back gesture would fight with strokes.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(flushMask))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        displayLink?.invalidate()   // CADisplayLink retains its target
        displayLink = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCanvasIfNeeded()
    }

    // MARK: - Setup

    private func setupUI() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnBack.layer.cornerRadius = 22
        btnBack.layer.borderWidth = 1
        btnBack.layer.borderColor = (UIColor(named: "Border Color") ?? .lightGray).cgColor
        btnUndo.setSymbol("arrow.uturn.backward", size: 19)
        btnRedo.setSymbol("arrow.uturn.forward", size: 19)
        btnBack.accessibilityLabel = "Back"
        btnUndo.accessibilityLabel = "Undo"
        btnRedo.accessibilityLabel = "Redo"
        btnPanelCancel.setSymbol("xmark", size: 16, weight: .bold)
        btnPanelCancel.tintColor = UIColor(named: "PrimaryText")
        btnPanelCancel.layer.cornerRadius = 22
        btnPanelCancel.accessibilityLabel = "Cancel"
        btnPanelApply.setSymbol("checkmark", size: 16, weight: .bold)
        btnPanelApply.tintColor = .white
        btnPanelApply.layer.cornerRadius = 22
        btnPanelApply.accessibilityLabel = "Apply"
        vwGrabber.layer.cornerRadius = 2.5
        vwHint.layer.cornerRadius = 17
        segMode.applyEditorStyle()
        segMode.selectedSegmentIndex = 0

        vwPanel.layer.cornerRadius = 36
        vwPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        vwPanel.layer.shadowColor = UIColor.black.cgColor
        vwPanel.layer.shadowOpacity = 0.07
        vwPanel.layer.shadowOffset = CGSize(width: 0, height: -10)
        vwPanel.layer.shadowRadius = 15

        sliderBrush.minimumValue = 5
        sliderBrush.maximumValue = 100
        sliderBrush.value = 34
        sliderSoftness.minimumValue = 0
        sliderSoftness.maximumValue = 100
        sliderSoftness.value = 22
        lblBrushValue.text = "34"
        lblSoftnessValue.text = "22"
        lblHint.text = "Drag to erase · Pinch to zoom"
        sliderBrush.addTarget(self, action: #selector(hideBrush), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        stamp = MaskBrushCanvas.makeStamp(softness: CGFloat(sliderSoftness.value) / 100)
    }

    private func setupCanvas() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 8
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delaysContentTouches = false
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2   // one finger paints, two fingers pan

        checker.cellSize = 14
        ghostView.contentMode = .scaleToFill
        ghostView.alpha = 0
        photoView.contentMode = .scaleToFill
        maskLayer.contentsGravity = .resize
        photoView.layer.mask = maskLayer
        canvas.addSubview(checker)
        canvas.addSubview(ghostView)
        canvas.addSubview(photoView)
        scrollView.addSubview(canvas)

        brushRing.layer.borderColor = UIColor.white.cgColor
        brushRing.layer.borderWidth = 2
        brushRing.isUserInteractionEnabled = false
        brushRing.isHidden = true
        let accent = UIColor(named: "AccentColor") ?? .systemBlue
        brushFill.backgroundColor = accent.withAlphaComponent(0.22)
        brushFill.layer.borderColor = accent.cgColor
        brushFill.layer.borderWidth = 2
        brushRing.addSubview(brushFill)
        view.addSubview(brushRing)
        loupe.isHidden = true
        view.addSubview(loupe)

        loading.color = accent
        loading.hidesWhenStopped = true
        loading.translatesAutoresizingMaskIntoConstraints = false
        vwCanvasArea.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: vwCanvasArea.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: vwCanvasArea.centerYAnchor)
        ])

        let draw = UIPanGestureRecognizer(target: self, action: #selector(drawn(_:)))
        draw.maximumNumberOfTouches = 1
        draw.delegate = self
        scrollView.addGestureRecognizer(draw)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        tap.delegate = self
        scrollView.addGestureRecognizer(tap)
    }

    /// Builds the smaller working photo and matte off the main thread.
    private func prepareWorkingCopies() {
        guard let original, let initialMask else {
            showLoadError()
            return
        }
        loading.startAnimating()
        let maxDimension = Self.workingMaxDimension
        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> (photo: UIImage, mask: CGImage)? in
                let pixel = max(original.size.width * original.scale, original.size.height * original.scale)
                let photoCG: CGImage?
                if pixel > maxDimension {
                    photoCG = ImageUtilities.uprightCGImage(from: original, maxDimension: maxDimension)
                } else {
                    photoCG = original.cgImage ?? ImageUtilities.uprightCGImage(from: original)
                }
                guard let photoCG,
                      let workMask = MaskRefineService.resized(initialMask, width: photoCG.width, height: photoCG.height)
                else { return nil }
                return (UIImage(cgImage: photoCG, scale: 1, orientation: .up), workMask)
            }.value
            guard let self else { return }
            self.loading.stopAnimating()
            guard let result,
                  let mask = MaskBrushCanvas(mask: result.mask),
                  let coverage = MaskBrushCanvas(width: mask.width, height: mask.height),
                  let coverageImage = coverage.grayImage() else {
                self.showLoadError()
                return
            }
            self.workPhoto = result.photo
            self.workSize = CGSize(width: mask.width, height: mask.height)
            self.mask = mask
            self.coverage = coverage
            self.history = [Step(mask: result.mask, coverage: coverageImage)]
            self.historyIndex = 0
            self.photoView.image = result.photo
            self.ghostView.image = result.photo
            self.canvasSize = .zero
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            self.refreshMask()
            self.setControlsEnabled(true)
            self.updateUndoButtons()
        }
    }

    private func showLoadError() {
        loading.stopAnimating()
        let alert = UIAlertController(title: "Refine unavailable",
                                      message: "This image couldn't be prepared for refining. Please try again.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func setControlsEnabled(_ enabled: Bool) {
        for control in [btnPanelApply!, segMode!, sliderBrush!, sliderSoftness!] as [UIControl] {
            control.isEnabled = enabled
        }
        vwPanel.alpha = enabled ? 1 : 0.6
        if !enabled {
            btnUndo.isEnabled = false
            btnRedo.isEnabled = false
        }
    }

    private func layoutCanvasIfNeeded() {
        let bounds = scrollView.bounds
        guard bounds.width > 0, bounds.height > 0, scrollView.zoomScale == 1, isReady else { return }
        // Fit the whole photo in the area (the panel overlaps its bottom a little).
        let visibleHeight = max(bounds.height - 36, 100)
        let scale = min(bounds.width / workSize.width, visibleHeight / workSize.height)
        let size = CGSize(width: floor(workSize.width * scale), height: floor(workSize.height * scale))
        guard size != canvasSize else { return }
        canvasSize = size
        canvas.frame = CGRect(origin: .zero, size: size)
        checker.frame = canvas.bounds
        ghostView.frame = canvas.bounds
        photoView.frame = canvas.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = photoView.bounds
        CATransaction.commit()
        scrollView.contentSize = size
        centerCanvas()
    }

    // MARK: - Zoom

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerCanvas() }

    private func centerCanvas() {
        let bounds = scrollView.bounds.size
        let content = scrollView.contentSize
        let x = max(0, (bounds.width - content.width) / 2)
        let y = max(0, (bounds.height - 36 - content.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y + 36, right: x)
    }

    // MARK: - Gestures

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Painting only starts on the photo, once it is ready.
        guard isReady, !isApplying else { return false }
        let point = gestureRecognizer.location(in: canvas)
        return canvas.bounds.insetBy(dx: -30, dy: -30).contains(point)
    }

    // MARK: - Brush

    private var brushRadius: CGFloat { CGFloat(sliderBrush.value) }

    /// Canvas point → working-image pixel (top-left origin).
    private func imagePoint(_ location: CGPoint) -> CGPoint {
        let scale = workSize.width / max(canvas.bounds.width, 1)
        return CGPoint(x: location.x * scale, y: location.y * scale)
    }

    /// Brush size is in screen points, so zooming in gives finer control.
    private var radiusInPixels: CGFloat {
        brushRadius / max(scrollView.zoomScale, 0.01) * workSize.width / max(canvas.bounds.width, 1)
    }

    @objc private func drawn(_ gesture: UIPanGestureRecognizer) {
        let inCanvas = gesture.location(in: canvas)
        let inView = gesture.location(in: view)
        switch gesture.state {
        case .began:
            strokeAborted = false
            lastPoint = imagePoint(inCanvas)
            paint(to: inCanvas)
            showBrush(at: inView)
            vwHint.isHidden = true
        case .changed:
            guard !strokeAborted else { return }
            if gesture.numberOfTouches > 1 {
                // A second finger means zoom/pan, not paint: drop this stroke.
                strokeAborted = true
                lastPoint = nil
                hideBrush()
                restore(history[historyIndex])
                return
            }
            paint(to: inCanvas)
            showBrush(at: inView)
        case .ended, .cancelled, .failed:
            lastPoint = nil
            hideBrush()
            if !strokeAborted { pushHistory() }
            strokeAborted = false
        default:
            break
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: canvas)
        lastPoint = imagePoint(point)
        paint(to: point)
        lastPoint = nil
        pushHistory()
    }

    private func paint(to location: CGPoint) {
        guard let mask, let coverage, let stamp else { return }
        let point = imagePoint(location)
        let from = lastPoint ?? point
        mask.stroke(from: from, to: point, radius: radiusInPixels, stamp: stamp, erase: isErasing)
        coverage.stroke(from: from, to: point, radius: radiusInPixels, stamp: stamp, erase: false)
        lastPoint = point
        needsMaskRefresh = true
    }

    @objc private func flushMask() {
        guard needsMaskRefresh else { return }
        needsMaskRefresh = false
        refreshMask()
        if !loupe.isHidden { loupe.updateMask(maskLayer.contents) }
    }

    private func refreshMask() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.contents = mask?.maskImage()
        CATransaction.commit()
    }

    private func showBrush(at point: CGPoint) {
        let d = brushRadius * 2
        brushRing.isHidden = false
        brushRing.frame = CGRect(x: point.x - d / 2 - 2, y: point.y - d / 2 - 2, width: d + 4, height: d + 4)
        brushRing.layer.cornerRadius = brushRing.bounds.width / 2
        brushFill.frame = brushRing.bounds.insetBy(dx: 2, dy: 2)
        brushFill.layer.cornerRadius = brushFill.bounds.width / 2

        // Magnifier in the top-left corner (top-right when the finger is there).
        guard let workPhoto else { return }
        let size: CGFloat = 108
        let top = vwCanvasArea.frame.minY + 16
        let useLeft = point.x > view.bounds.width / 2 || point.y > top + size + 40
        loupe.frame = CGRect(x: useLeft ? 16 : view.bounds.width - size - 16, y: top, width: size, height: size)
        if loupe.isHidden {
            loupe.configure(photo: workPhoto, mask: maskLayer.contents)
            loupe.isHidden = false
        }
        let p = view.convert(point, to: canvas)
        loupe.focus(on: CGPoint(x: p.x / max(canvas.bounds.width, 1), y: p.y / max(canvas.bounds.height, 1)),
                    canvasSize: canvas.bounds.size, zoom: scrollView.zoomScale)
    }

    @objc private func hideBrush() {
        brushRing.isHidden = true
        loupe.isHidden = true
    }

    // MARK: - History

    private func pushHistory() {
        guard let maskImage = mask?.grayImage(), let coverageImage = coverage?.grayImage() else { return }
        history.removeSubrange(min(historyIndex + 1, history.count)...)
        history.append(Step(mask: maskImage, coverage: coverageImage))
        if history.count > Self.historyLimit { history.removeFirst() }
        historyIndex = history.count - 1
        didEdit = true
        updateUndoButtons()
    }

    private func restore(_ step: Step) {
        mask?.load(step.mask)
        coverage?.load(step.coverage)
        refreshMask()
        updateUndoButtons()
    }

    private func updateUndoButtons() {
        let canUndo = isReady && historyIndex > 0
        let canRedo = isReady && historyIndex < history.count - 1
        let disabled = UIColor(red: 0.72, green: 0.79, blue: 0.87, alpha: 1)
        btnUndo.isEnabled = canUndo
        btnRedo.isEnabled = canRedo
        btnUndo.tintColor = canUndo ? UIColor(named: "PrimaryText") : disabled
        btnRedo.tintColor = canRedo ? UIColor(named: "PrimaryText") : disabled
    }

    // MARK: - Apply

    private func apply() {
        guard !isApplying else { return }
        guard didEdit, let initialMask, let editedImage = mask?.grayImage(),
              let coverageImage = coverage?.grayImage() else {
            navigationController?.popViewController(animated: true)
            return
        }
        isApplying = true
        setControlsEnabled(false)
        loading.startAnimating()
        let sameSize = editedImage.width == initialMask.width && editedImage.height == initialMask.height
        Task { [weak self] in
            let merged = await Task.detached(priority: .userInitiated) { () -> CGImage? in
                if sameSize { return editedImage }
                return MaskRefineService.mergeEdits(full: initialMask, edited: editedImage, coverage: coverageImage)
            }.value
            guard let self else { return }
            self.loading.stopAnimating()
            guard let merged else {
                self.isApplying = false
                self.setControlsEnabled(true)
                self.updateUndoButtons()
                self.presentErrorAlert(title: "Couldn't apply", message: "The refined edges couldn't be saved. Please try again.")
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self.onApply?(merged)
            self.navigationController?.popViewController(animated: true)
        }
    }

    private func close() {
        guard !isApplying else { return }
        guard didEdit else {
            navigationController?.popViewController(animated: true)
            return
        }
        let alert = UIAlertController(title: "Discard changes?", message: "Your refine edits will be lost.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) { close() }
    @IBAction func btnCancel(_ sender: UIButton) { close() }
    @IBAction func btnApply(_ sender: UIButton) { apply() }

    @IBAction func btnUndo(_ sender: UIButton) {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        restore(history[historyIndex])
    }

    @IBAction func btnRedo(_ sender: UIButton) {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        restore(history[historyIndex])
    }

    @IBAction func segModeChanged(_ sender: UISegmentedControl) {
        lblHint.text = isErasing ? "Drag to erase · Pinch to zoom" : "Drag to restore · Pinch to zoom"
        vwHint.isHidden = false
        // Show the removed parts faintly while restoring.
        UIView.animate(withDuration: 0.2) { self.ghostView.alpha = self.isErasing ? 0 : 0.3 }
    }

    @IBAction func sliderBrushChanged(_ sender: UISlider) {
        lblBrushValue.text = "\(Int(sender.value.rounded()))"
        showBrush(at: CGPoint(x: view.bounds.midX, y: vwCanvasArea.frame.midY))
        loupe.isHidden = true
    }

    @IBAction func sliderSoftnessChanged(_ sender: UISlider) {
        lblSoftnessValue.text = "\(Int(sender.value.rounded()))"
        stamp = MaskBrushCanvas.makeStamp(softness: CGFloat(sender.value) / 100)
    }
}

/// Circular magnifier showing the area under the finger.
final class RefineLoupeView: UIView {
    private let checker = CheckerboardView(frame: .zero)
    private let photo = UIImageView()
    private let maskLayer = CALayer()
    private let crossH = UIView()
    private let crossV = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 3
        checker.cellSize = 10
        addSubview(checker)
        addSubview(photo)
        photo.layer.mask = maskLayer
        maskLayer.contentsGravity = .resize
        let accent = UIColor(named: "AccentColor") ?? .systemBlue
        crossH.backgroundColor = accent
        crossV.backgroundColor = accent
        addSubview(crossH)
        addSubview(crossV)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        checker.frame = bounds
        crossH.frame = CGRect(x: bounds.midX - 12, y: bounds.midY - 1, width: 24, height: 2)
        crossV.frame = CGRect(x: bounds.midX - 1, y: bounds.midY - 12, width: 2, height: 24)
    }

    func configure(photo image: UIImage, mask: Any?) {
        photo.image = image
        updateMask(mask)
    }

    func updateMask(_ contents: Any?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.contents = contents
        CATransaction.commit()
    }

    /// `point` is normalised 0…1 within the canvas.
    func focus(on point: CGPoint, canvasSize: CGSize, zoom: CGFloat) {
        let magnification = 2 * zoom
        let size = CGSize(width: canvasSize.width * magnification, height: canvasSize.height * magnification)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        photo.frame = CGRect(x: bounds.midX - point.x * size.width, y: bounds.midY - point.y * size.height,
                             width: size.width, height: size.height)
        maskLayer.frame = photo.bounds
        CATransaction.commit()
    }
}
