//
//  RefineEdgesVC.swift
//  Background Removal
//
//  10 Refine Edges (Editor.storyboard): erase / restore the cutout with a soft brush,
//  pinch to zoom, magnifier loupe, own undo/redo. Works on the original photo + matte;
//  ✓ hands the edited matte back to the editor, which rebuilds and saves the foreground.
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

    // MARK: - State

    /// Upright original photo (same pixel size as `initialMask`).
    var original: UIImage!
    /// Current matte (8-bit gray) of the foreground.
    var initialMask: CGImage!
    var onApply: ((CGImage) -> Void)?

    private var pixelSize: CGSize {
        CGSize(width: original.size.width * original.scale, height: original.size.height * original.scale)
    }

    private var mask: MaskBrushCanvas?
    private var stamp: CGImage?
    private let canvas = UIView()
    private let checker = CheckerboardView(frame: .zero)
    private let photoView = UIImageView()
    private let maskLayer = CALayer()
    private let brushRing = UIView()
    private let brushFill = UIView()
    private let loupe = RefineLoupeView()

    private var lastPoint: CGPoint?
    private var history: [CGImage] = []
    private var historyIndex = 0
    /// True once a stroke was made (history may have dropped the initial matte).
    private var didEdit = false
    private var needsMaskRefresh = false
    private var displayLink: CADisplayLink?
    private var canvasSize: CGSize = .zero

    private var isErasing: Bool { segMode.selectedSegmentIndex == 0 }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCanvas()

        mask = MaskBrushCanvas(mask: initialMask)
        history = [initialMask]
        stamp = MaskBrushCanvas.makeStamp(softness: CGFloat(sliderSoftness.value) / 100)
        refreshMask()
        updateUndoButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        btnPanelApply.setSymbol("checkmark", size: 16, weight: .bold)
        btnPanelApply.tintColor = .white
        btnPanelApply.layer.cornerRadius = 22
        vwGrabber.layer.cornerRadius = 2.5
        vwHint.layer.cornerRadius = 17
        segMode.applyEditorStyle()

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
        sliderBrush.addTarget(self, action: #selector(hideBrush), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private func setupCanvas() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 8
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2   // one finger draws, two fingers pan

        checker.cellSize = 14
        photoView.image = original
        photoView.contentMode = .scaleToFill
        maskLayer.contentsGravity = .resize
        photoView.layer.mask = maskLayer
        canvas.addSubview(checker)
        canvas.addSubview(photoView)
        scrollView.addSubview(canvas)

        brushRing.layer.borderColor = UIColor.white.cgColor
        brushRing.layer.borderWidth = 2
        brushRing.isUserInteractionEnabled = false
        brushRing.isHidden = true
        brushFill.backgroundColor = (UIColor(named: "AccentColor") ?? .systemBlue).withAlphaComponent(0.22)
        brushFill.layer.borderColor = (UIColor(named: "AccentColor") ?? .systemBlue).cgColor
        brushFill.layer.borderWidth = 2
        brushRing.addSubview(brushFill)
        view.addSubview(brushRing)
        loupe.isHidden = true
        view.addSubview(loupe)

        let draw = UIPanGestureRecognizer(target: self, action: #selector(drawn(_:)))
        draw.maximumNumberOfTouches = 1
        draw.delegate = self
        scrollView.addGestureRecognizer(draw)
        scrollView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    private func layoutCanvasIfNeeded() {
        let bounds = scrollView.bounds
        guard bounds.width > 0, scrollView.zoomScale == 1 else { return }
        let image = pixelSize
        // Fill the width like the design; very tall photos are fitted.
        var size = CGSize(width: bounds.width, height: bounds.width * image.height / image.width)
        if size.height > bounds.height * 1.6 {
            size = CGSize(width: bounds.height * 1.6 * image.width / image.height, height: bounds.height * 1.6)
        }
        guard size != canvasSize else { return }
        canvasSize = size
        canvas.frame = CGRect(origin: .zero, size: size)
        checker.frame = canvas.bounds
        photoView.frame = canvas.bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = photoView.bounds
        CATransaction.commit()
        scrollView.contentSize = size
        centerCanvas()
        scrollView.contentOffset = CGPoint(x: -scrollView.contentInset.left,
                                           y: -scrollView.contentInset.top + max(0, min(size.height - bounds.height, size.height * 0.08)))
    }

    // MARK: - Zoom

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerCanvas() }

    private func centerCanvas() {
        let bounds = scrollView.bounds.size
        let content = scrollView.contentSize
        let x = max(0, (bounds.width - content.width) / 2)
        let y = max(0, (bounds.height - content.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y + 40, right: x)
    }

    // MARK: - Brush

    private var brushRadius: CGFloat { CGFloat(sliderBrush.value) }

    private func imagePoint(_ location: CGPoint) -> CGPoint {
        let scale = pixelSize.width / max(canvas.bounds.width, 1)
        return CGPoint(x: location.x * scale, y: location.y * scale)
    }

    /// Brush size is on screen, so zooming in gives finer control.
    private var radiusInPixels: CGFloat {
        brushRadius / scrollView.zoomScale * pixelSize.width / max(canvas.bounds.width, 1)
    }

    @objc private func drawn(_ gesture: UIPanGestureRecognizer) {
        let inCanvas = gesture.location(in: canvas)
        let inView = gesture.location(in: view)
        switch gesture.state {
        case .began:
            lastPoint = imagePoint(inCanvas)
            paint(to: inCanvas)
            showBrush(at: inView)
            vwHint.isHidden = true
        case .changed:
            paint(to: inCanvas)
            showBrush(at: inView)
        case .ended, .cancelled, .failed:
            lastPoint = nil
            hideBrush()
            pushHistory()
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
        guard let mask, let stamp else { return }
        let point = imagePoint(location)
        mask.stroke(from: lastPoint ?? point, to: point, radius: radiusInPixels, stamp: stamp, erase: isErasing)
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
        let size: CGFloat = 108
        let top = vwCanvasArea.frame.minY + 16
        let useLeft = point.x > view.bounds.width / 2 || point.y > top + size + 40
        loupe.frame = CGRect(x: useLeft ? 16 : view.bounds.width - size - 16, y: top, width: size, height: size)
        if loupe.isHidden {
            loupe.configure(photo: original, mask: maskLayer.contents)
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
        guard let snapshot = mask?.grayImage() else { return }
        history.removeSubrange(min(historyIndex + 1, history.count)...)
        history.append(snapshot)
        if history.count > 8 { history.removeFirst() }   // full-size mattes are large
        historyIndex = history.count - 1
        didEdit = true
        updateUndoButtons()
    }

    private func updateUndoButtons() {
        let canUndo = historyIndex > 0
        let canRedo = historyIndex < history.count - 1
        btnUndo.isEnabled = canUndo
        btnRedo.isEnabled = canRedo
        let disabled = UIColor(red: 0.72, green: 0.79, blue: 0.87, alpha: 1)
        btnUndo.tintColor = canUndo ? UIColor(named: "PrimaryText") : disabled
        btnRedo.tintColor = canRedo ? UIColor(named: "PrimaryText") : disabled
    }

    private func close(apply: Bool) {
        if apply, didEdit {
            onApply?(history[historyIndex])
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) { close(apply: false) }
    @IBAction func btnCancel(_ sender: UIButton) { close(apply: false) }
    @IBAction func btnApply(_ sender: UIButton) { close(apply: true) }

    @IBAction func btnUndo(_ sender: UIButton) {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        mask?.load(history[historyIndex])
        refreshMask()
        updateUndoButtons()
    }

    @IBAction func btnRedo(_ sender: UIButton) {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        mask?.load(history[historyIndex])
        refreshMask()
        updateUndoButtons()
    }

    @IBAction func segModeChanged(_ sender: UISegmentedControl) {
        lblHint.text = isErasing ? "Drag to erase · Pinch to zoom" : "Drag to restore · Pinch to zoom"
        vwHint.isHidden = false
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
