//
//  EditorSupport.swift
//  Background Removal
//
//  Small UI helpers shared by the background-removal screens.
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

    /// The editor that matches how the project was created.
    static func editorScreen(for viewModel: BackgroundRemovalViewModel) -> UIViewController {
        if viewModel.project.mode == .textBehind {
            let editor = TextBehindSubjectVC.fatchEditorInstance()
            editor.viewModel = viewModel
            editor.itemID = viewModel.items.first?.id
            return editor
        }
        let editor = RemovingBackgroundEditorVC.fatchEditorInstance()
        editor.viewModel = viewModel
        return editor
    }

    func presentErrorAlert(title: String, message: String, retryTitle: String? = nil, retry: (() -> Void)? = nil) {
        showAlert(title: title,msg: message, okayTitle: retryTitle ?? "Retry", cancelTitle: retry == nil ? "OK" : "Cancel", doneAction: {
            retry?()
        })
    }

    func showPhotosSettingsAlert(message: String) {
        showAlert(title: "Photos access needed",msg: message, okayTitle: "Settings", cancelTitle: "Cancel", doneAction: {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
    }
}

// MARK: - Checkerboard (UI only – never exported)

class CheckerboardView: UIView {
    @IBInspectable var cellSize: CGFloat = 12 { didSet { updatePattern() } }

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

    static func pattern(cell: CGFloat, dark: Bool) -> UIImage {
        let base = dark ? UIColor(red: 0.086, green: 0.114, blue: 0.169, alpha: 1) : UIColor(white: 0.98, alpha: 1)
        let alt = dark ? UIColor(red: 0.133, green: 0.173, blue: 0.247, alpha: 1) : UIColor(white: 0.925, alpha: 1)
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
        backgroundColor = UIColor(patternImage: Self.pattern(cell: cellSize, dark: traitCollection.userInterfaceStyle == .dark))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { updatePattern() }
    }
}

// MARK: - Progress HUD

/// Blocking progress overlay with a message and optional determinate progress.
final class ProgressHUD: UIView {
    private let spinner = UIActivityIndicatorView(style: .large)
    private let label = UILabel()
    private let bar = UIProgressView(progressViewStyle: .default)

    static func show(in view: UIView, message: String) -> ProgressHUD {
        let hud = ProgressHUD(message: message)
        hud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hud)
        NSLayoutConstraint.activate([
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hud.topAnchor.constraint(equalTo: view.topAnchor),
            hud.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hud.alpha = 0
        UIView.animate(withDuration: 0.2) { hud.alpha = 1 }
        return hud
    }

    private init(message: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.35)
        let box = UIView()
        box.backgroundColor = UIColor(white: 0.08, alpha: 0.92)
        box.layer.cornerRadius = 22
        spinner.color = .white
        spinner.startAnimating()
        label.text = message
        label.textColor = .white
        label.font = UIFont(name: "Figtree-SemiBold", size: 15) ?? .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.textAlignment = .center
        bar.progressTintColor = UIColor(named: "AccentColor")
        bar.trackTintColor = UIColor.white.withAlphaComponent(0.2)
        bar.isHidden = true
        let stack = UIStackView(arrangedSubviews: [spinner, label, bar])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(stack)
        addSubview(box)
        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: centerXAnchor),
            box.centerYAnchor.constraint(equalTo: centerYAnchor),
            box.widthAnchor.constraint(equalToConstant: 230),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -20),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(progress: Double, message: String? = nil) {
        bar.isHidden = false
        bar.setProgress(Float(progress), animated: true)
        if let message { label.text = message }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
    }
}

// MARK: - Background colours

/// Colour choices in Change Background › Colors.
enum BackgroundColorOption: CaseIterable {
    case transparent, white, black, lightGray, darkGray, red, blue, green, yellow, pink, purple, orange, custom

    var title: String {
        switch self {
        case .transparent: return "None"
        case .white: return "White"
        case .black: return "Black"
        case .lightGray: return "Light gray"
        case .darkGray: return "Dark gray"
        case .red: return "Red"
        case .blue: return "Blue"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .pink: return "Pink"
        case .purple: return "Purple"
        case .orange: return "Orange"
        case .custom: return "Custom"
        }
    }

    var hex: String? {
        switch self {
        case .transparent, .custom: return nil
        case .white: return "FFFFFF"
        case .black: return "000000"
        case .lightGray: return "D1D5DB"
        case .darkGray: return "4B5563"
        case .red: return "EF4444"
        case .blue: return "1677FF"
        case .green: return "22C55E"
        case .yellow: return "FACC15"
        case .pink: return "EC4899"
        case .purple: return "8B5CF6"
        case .orange: return "F97316"
        }
    }

    static var presetHexes: [String] { allCases.compactMap(\.hex) }
}
