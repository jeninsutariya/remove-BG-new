//
//  ExportVC.swift
//  Background Removal
//
//  11 Export (Editor.storyboard): format, size, background, Save to Photos, Share.
//

import UIKit
import Photos

class ExportVC: UIViewController {

    // MARK: - Outlets

    @IBOutlet weak var btnBack: UIButton!
    @IBOutlet weak var vwPreviewChecker: CheckerboardView!
    @IBOutlet weak var imgPreview: UIImageView!
    @IBOutlet weak var lblFileName: UILabel!
    @IBOutlet weak var lblDimensions: UILabel!
    @IBOutlet weak var vwOptions: UIView!
    @IBOutlet weak var segFormat: UISegmentedControl!
    @IBOutlet weak var btnSize: UIButton!
    @IBOutlet weak var btnBackground: UIButton!
    @IBOutlet weak var lblNote: UILabel!
    @IBOutlet weak var vwHD: UIView!
    @IBOutlet weak var lblHDSubtitle: UILabel!
    @IBOutlet weak var vwProBadge: UIView!
    @IBOutlet weak var imgHDChevron: UIImageView!
    @IBOutlet weak var btnSave: UIButton!
    @IBOutlet weak var btnShare: UIButton!

    // MARK: - State

    var session: EditSession!

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

    /// Free exports are capped; Pro (UserDefaults.isPremiumUser) exports full resolution.
    private let freeMaxDimension: CGFloat = 1080
    private var isPro: Bool { UserDefaults.isPremiumUser }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()   // the user may have upgraded on the Pro screen
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) { applyBorders() }
    }

    private func setupUI() {
        btnBack.setSymbol("chevron.left", size: 17, weight: .bold)
        btnBack.tintColor = UIColor(named: "PrimaryText")
        btnBack.layer.cornerRadius = 22
        vwPreviewChecker.layer.cornerRadius = 26
        vwPreviewChecker.clipsToBounds = true
        vwPreviewChecker.cellSize = 12.5
        imgPreview.layer.cornerRadius = 26
        imgPreview.clipsToBounds = true
        vwOptions.layer.cornerRadius = 24
        vwHD.layer.cornerRadius = 24
        vwProBadge.layer.cornerRadius = 12
        btnSave.layer.cornerRadius = 29
        btnShare.layer.cornerRadius = 27
        segFormat.applyEditorStyle()
        btnSave.setSymbol("arrow.down.to.line", size: 17, weight: .bold)
        btnSave.tintColor = .white
        btnShare.setSymbol("square.and.arrow.up", size: 16, weight: .bold)
        btnShare.tintColor = UIColor(named: "AccentColor")
        imgHDChevron.image = UIImage(systemName: "chevron.right",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        imgHDChevron.tintColor = UIColor(named: "PrimaryText")
        for button in [btnSave!, btnShare!] {
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        }
        applyBorders()
    }

    private func applyBorders() {
        let border = (UIColor(named: "Border Color") ?? .lightGray).cgColor
        for view in [btnBack!, vwOptions!, vwHD!] {
            view.layer.borderWidth = 1
            view.layer.borderColor = border
        }
        btnShare.layer.borderWidth = 1
        btnShare.layer.borderColor = (UIColor(named: "BrandPrimary") ?? .lightGray).cgColor
    }

    // MARK: - Options

    private var backgroundOverride: BackgroundSpec? {
        switch background {
        case .edited: return format == .jpg && session.spec.background.isTransparent ? .color(.white) : nil
        case .transparent: return format == .jpg ? .color(.white) : .transparent
        case .white: return .color(.white)
        }
    }

    private var maxDimension: CGFloat? {
        guard !isPro else { return size.maxDimension }
        return min(size.maxDimension ?? .greatestFiniteMagnitude, freeMaxDimension)
    }

    private var options: EditRenderer.Options {
        EditRenderer.Options(maxDimension: maxDimension, backgroundOverride: backgroundOverride)
    }

    private var fileName: String {
        "\(session.name.replacingOccurrences(of: "/", with: "-")).\(format.fileExtension)"
    }

    private func backgroundTitle(_ option: BackgroundOption) -> String {
        switch option {
        case .edited: return session.spec.background.displayName
        case .transparent: return "Transparent"
        case .white: return "White"
        }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        segFormat.selectedSegmentIndex = format.rawValue
        lblFileName.text = fileName
        let px = EditRenderer.outputPixelSize(imageSize: session.pixelSize, spec: session.spec, maxDimension: maxDimension)
        lblDimensions.text = "\(Int(px.width)) × \(Int(px.height)) px"
        btnSize.setTitle("\(size.title)  ›", for: .normal)
        btnBackground.setTitle("\(backgroundTitle(background))  ›", for: .normal)

        let effective = backgroundOverride ?? session.spec.background
        if format == .jpg {
            lblNote.text = "JPG files are smaller. Transparent areas become white."
        } else {
            lblNote.text = effective.isTransparent ? "PNG keeps the transparent background." : "PNG keeps full quality."
        }
        vwProBadge.isHidden = isPro
        lblHDSubtitle.text = isPro ? "Full resolution, no watermark" : "Free exports up to \(Int(freeMaxDimension)) px"

        let preview = EditRenderer.Options(maxDimension: 540, backgroundOverride: backgroundOverride)
        imgPreview.image = session.render(options: preview)
        vwPreviewChecker.isHidden = !effective.isTransparent
    }

    private func encodedData() -> Data? {
        let image = session.render(options: options)
        switch format {
        case .png:
            return image.pngData()
        case .jpg:
            return image.jpegData(compressionQuality: 0.92)
        }
    }

    // MARK: - Actions

    @IBAction func btnBack(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func segFormatChanged(_ sender: UISegmentedControl) {
        format = ExportFormat(rawValue: sender.selectedSegmentIndex) ?? .png
        refresh()
    }

    @IBAction func btnSize(_ sender: UIButton) {
        let full = CanvasLayoutSize.full(session)
        let sheet = UIAlertController(title: "Export size",
                                      message: isPro ? nil : "Free exports are limited to \(Int(freeMaxDimension)) px. Upgrade to Pro for full resolution.",
                                      preferredStyle: .actionSheet)
        for option in SizeOption.allCases {
            let longest = Int(min(option.maxDimension ?? .greatestFiniteMagnitude, full))
            let title = "\(option.title) · \(longest) px" + (option == size ? "  ✓" : "")
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.size = option
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds
        present(sheet, animated: true)
    }

    @IBAction func btnBackground(_ sender: UIButton) {
        let sheet = UIAlertController(title: "Background", message: nil, preferredStyle: .actionSheet)
        for option in BackgroundOption.allCases {
            let base = option == .edited ? "As edited (\(session.spec.background.displayName))" : backgroundTitle(option)
            sheet.addAction(UIAlertAction(title: base + (option == background ? "  ✓" : ""), style: .default) { [weak self] _ in
                self?.background = option
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sender
        sheet.popoverPresentationController?.sourceRect = sender.bounds
        present(sheet, animated: true)
    }

    @IBAction func btnHD(_ sender: UIButton) {
        guard !isPro else { return }
        let vc = ProUpgradeVC.fatchInstance()
        present(vc, animated: true)
    }

    @IBAction func btnSave(_ sender: UIButton) {
        LoaderView.shared.show()
        guard let data = encodedData() else {
            LoaderView.shared.hide()
            showMessage(title: "Couldn't export", message: "The image couldn't be created.")
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    LoaderView.shared.hide()
                    self.showSettingsAlert()
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, error in
                DispatchQueue.main.async {
                    LoaderView.shared.hide()
                    if success {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        showToast(message: "Saved to Photos")
                    } else {
                        self.showMessage(title: "Couldn't save", message: error?.localizedDescription ?? "Please try again.")
                    }
                }
            })
        }
    }

    @IBAction func btnShare(_ sender: UIButton) {
        guard let data = encodedData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            showMessage(title: "Couldn't share", message: error.localizedDescription)
            return
        }
        let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = sender
        activity.popoverPresentationController?.sourceRect = sender.bounds
        present(activity, animated: true)
    }

    // MARK: - Alerts

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showSettingsAlert() {
        let alert = UIAlertController(title: "Photos access needed",
                                      message: "Allow \"Add Photos Only\" access in Settings to save your cutouts.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        present(alert, animated: true)
    }
}

/// Longest side (px) of the canvas for the current edit, before any size limit.
private enum CanvasLayoutSize {
    static func full(_ session: EditSession) -> CGFloat {
        let size = CanvasLayout.canvasPixelSize(imageSize: session.pixelSize, aspect: session.spec.aspect)
        return max(size.width, size.height)
    }
}
