//
//  EditorToolPanel.swift
//  Background Removal
//
//  Base class for the editor tool sheets loaded from XIB (header: ✕  Title  ✓),
//  plus small styling helpers shared by the editor screens.
//

import UIKit

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
        btnCancelPanel?.accessibilityLabel = "Cancel"
        btnApplyPanel?.setSymbol("checkmark", size: 16, weight: .bold)
        btnApplyPanel?.tintColor = .white
        btnApplyPanel?.layer.cornerRadius = 22
        btnApplyPanel?.accessibilityLabel = "Apply"
        vwGrabber?.layer.cornerRadius = 2.5
    }

    @IBAction func btnPanelCancel(_ sender: UIButton) { onCancel?() }
    @IBAction func btnPanelApply(_ sender: UIButton) { onApply?() }
}

extension UIButton {
    /// SF Symbol icon (kept in code so the storyboard doesn't depend on symbol sizes).
    func setSymbol(_ name: String, size: CGFloat = 17, weight: UIImage.SymbolWeight = .semibold) {
        setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight)),
                 for: .normal)
    }
}

extension UISegmentedControl {
    /// Pill switcher from the Figma file (white selected segment on light blue).
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
