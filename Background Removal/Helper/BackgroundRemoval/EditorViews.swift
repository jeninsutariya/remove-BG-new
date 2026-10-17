//
//  EditorViews.swift
//  Background Removal
//
//  Views used by the editor screens (set as Custom Class in Editor.storyboard).
//

import UIKit

// MARK: - Storyboard

extension UIStoryboard {
    static var editorStoryboard = UIStoryboard(name: "Editor", bundle: nil)
}

extension UIViewController {
    /// Same pattern as `fatchInstance()`, for the screens in Editor.storyboard.
    class func fatchEditorInstance() -> Self {
        let controller = UIStoryboard.editorStoryboard.instantiateViewController(withIdentifier: "\(Self.self)") as! Self
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }
}

// MARK: - Checkerboard

/// Grey/white (light) or navy (dark) checkerboard behind transparent pixels.
class CheckerboardView: UIView {
    @IBInspectable var cellSize: CGFloat = 11 { didSet { updatePattern() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        updatePattern()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        updatePattern()
    }

    static func pattern(cell: CGFloat, traits: UITraitCollection) -> UIImage {
        let dark = traits.userInterfaceStyle == .dark
        let base = dark ? EditorSwatches.hex(0x161D2B) : EditorSwatches.hex(0xFAFAFA)
        let alt = dark ? EditorSwatches.hex(0x222C3F) : EditorSwatches.hex(0xECECEC)
        let size = CGSize(width: cell * 2, height: cell * 2)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            base.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            alt.setFill()
            ctx.fill(CGRect(x: cell, y: 0, width: cell, height: cell))
            ctx.fill(CGRect(x: 0, y: cell, width: cell, height: cell))
        }
    }

    private func updatePattern() {
        backgroundColor = UIColor(patternImage: Self.pattern(cell: cellSize, traits: traitCollection))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { updatePattern() }
    }
}

// MARK: - Live canvas

/// Live preview of an `EditSession`: background, text behind, subject with shadow.
/// Uses the same `CanvasLayout` as `EditRenderer`, so exports match the preview.
class EditorCanvasView: UIView, UIGestureRecognizerDelegate {

    private(set) var spec = EditSpec()
    private weak var session: EditSession?

    private let checker = CheckerboardView(frame: .zero)
    private let colorView = UIView()
    private let photoView = UIImageView()
    private let textLabel = UILabel()
    private let textFrame = CAShapeLayer()
    private let subjectView = UIImageView()
    private let originalView = UIImageView()
    private lazy var textPan = UIPanGestureRecognizer(target: self, action: #selector(panText(_:)))
    private var panStart = CGPoint.zero

    /// Dashed frame + dragging while the Text tool is open.
    var isEditingText = false {
        didSet {
            textPan.isEnabled = isEditingText
            setNeedsLayout()
        }
    }
    var onTextMoved: ((CGPoint) -> Void)?
    var onTextMoveEnded: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        checker.cellSize = 20
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        subjectView.contentMode = .scaleToFill
        originalView.contentMode = .scaleToFill
        originalView.isHidden = true
        textFrame.fillColor = UIColor.clear.cgColor
        textFrame.strokeColor = UIColor.white.withAlphaComponent(0.75).cgColor
        textFrame.lineWidth = 1
        textFrame.lineDashPattern = [4, 3]
        textFrame.isHidden = true
        [checker, colorView, photoView, textLabel, subjectView, originalView].forEach { addSubview($0) }
        layer.addSublayer(textFrame)
        textPan.isEnabled = false
        textPan.delegate = self
        addGestureRecognizer(textPan)
        isAccessibilityElement = true
        accessibilityLabel = "Edited photo"
    }

    /// Aspect ratio (width / height) of the canvas for the given edit.
    func aspectRatio(for spec: EditSpec) -> CGFloat {
        guard let session else { return 1 }
        let size = CanvasLayout.canvasPixelSize(imageSize: session.pixelSize, aspect: spec.aspect)
        return size.width / max(size.height, 1)
    }

    func show(session: EditSession, spec override: EditSpec? = nil) {
        self.session = session
        spec = override ?? session.spec
        subjectView.image = session.cutout
        originalView.image = session.original
        setNeedsLayout()
    }

    func showOriginal(_ show: Bool) {
        originalView.isHidden = !show
        subjectView.isHidden = show
        textLabel.alpha = show ? 0 : 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let session, bounds.width > 0 else { return }
        let layout = CanvasLayout(imageSize: session.pixelSize, spec: spec, drawWidth: bounds.width)

        [checker, colorView, photoView].forEach { $0.frame = bounds }
        checker.isHidden = !spec.background.isTransparent
        colorView.isHidden = true
        photoView.isHidden = true
        switch spec.background {
        case .transparent:
            break
        case .color(let color):
            colorView.isHidden = false
            colorView.backgroundColor = color
        case .photo(let id):
            photoView.isHidden = false
            photoView.image = session.photos[id]
        }

        subjectView.frame = layout.subjectRect
        originalView.frame = layout.subjectRect
        if spec.shadow.isOn {
            let params = layout.shadow(spec.shadow)
            subjectView.layer.shadowColor = UIColor.black.cgColor
            subjectView.layer.shadowOpacity = Float(spec.shadow.opacity / 100)
            subjectView.layer.shadowOffset = params.offset
            subjectView.layer.shadowRadius = params.blur / 2
        } else {
            subjectView.layer.shadowOpacity = 0
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let text = spec.text, !text.text.isEmpty {
            textLabel.isHidden = false
            let string = EditRenderer.attributedText(text, fontSize: layout.fontSize(for: text))
            textLabel.attributedText = string
            let size = string.boundingRect(with: CGSize(width: bounds.width * 2, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin], context: nil).size
            textLabel.bounds = CGRect(x: 0, y: 0, width: ceil(size.width), height: ceil(size.height))
            textLabel.center = CGPoint(x: bounds.width * text.center.x, y: bounds.height * text.center.y)
            textFrame.path = UIBezierPath(roundedRect: textLabel.frame.insetBy(dx: -12, dy: -6), cornerRadius: 12).cgPath
            textFrame.isHidden = !isEditingText
        } else {
            textLabel.isHidden = true
            textFrame.isHidden = true
        }
        CATransaction.commit()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === textPan { return spec.text != nil }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    @objc private func panText(_ gesture: UIPanGestureRecognizer) {
        guard let text = spec.text else { return }
        switch gesture.state {
        case .began:
            panStart = text.center
        case .changed:
            let t = gesture.translation(in: self)
            onTextMoved?(CGPoint(x: max(0.05, min(0.95, panStart.x + t.x / bounds.width)),
                                 y: max(0.05, min(0.95, panStart.y + t.y / bounds.height))))
        case .ended, .cancelled:
            onTextMoveEnded?()
        default:
            break
        }
    }
}

// MARK: - Tool panel base

/// Base class for the editor tool sheets loaded from XIB (header: ✕  Title  ✓).
class EditorToolPanel: UIView {
    @IBOutlet weak var btnCancelPanel: UIButton!
    @IBOutlet weak var btnApplyPanel: UIButton!
    @IBOutlet weak var vwGrabber: UIView!

    var onCancel: (() -> Void)?
    var onApply: (() -> Void)?

    static func loadFromNib<T: EditorToolPanel>(_ type: T.Type) -> T {
        let nibName = String(describing: type)
        guard let view = Bundle.main.loadNibNamed(nibName, owner: nil)?.first as? T else {
            fatalError("Could not load \(nibName).xib")
        }
        return view
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 36
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: -10)
        layer.shadowRadius = 15
        btnCancelPanel?.setSymbol("xmark", size: 16, weight: .bold)
        btnCancelPanel?.tintColor = UIColor(named: "PrimaryText")
        btnCancelPanel?.layer.cornerRadius = 22
        btnApplyPanel?.setSymbol("checkmark", size: 16, weight: .bold)
        btnApplyPanel?.tintColor = .white
        btnApplyPanel?.layer.cornerRadius = 22
        vwGrabber?.layer.cornerRadius = 2.5
    }

    @IBAction func btnPanelCancel(_ sender: UIButton) { onCancel?() }
    @IBAction func btnPanelApply(_ sender: UIButton) { onApply?() }
}

// MARK: - Small helpers

extension UIButton {
    /// SF Symbol icon (kept in code so the storyboard doesn't depend on symbol sizes).
    func setSymbol(_ name: String, size: CGFloat = 17, weight: UIImage.SymbolWeight = .semibold) {
        setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight)),
                 for: .normal)
    }
}

extension UISegmentedControl {
    /// Matches the pill switchers in the Figma file.
    func applyEditorStyle() {
        let normal: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Figtree-SemiBold", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor(named: "Text Muted") ?? .gray
        ]
        let selected: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Figtree-Bold", size: 14) ?? .systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor(named: "PrimaryText") ?? .black
        ]
        setTitleTextAttributes(normal, for: .normal)
        setTitleTextAttributes(selected, for: .selected)
        backgroundColor = UIColor(named: "Ultra Light Blue")
        selectedSegmentTintColor = UIColor(named: "Surface Raised") ?? .white
    }
}
