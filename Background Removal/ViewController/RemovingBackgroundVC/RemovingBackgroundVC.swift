//
//  RemovingBackgroundVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 16/10/26.
//
//  Processing screen: shows each photo while Apple Vision removes its background,
//  reveals the real transparent result, then opens the editor.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

class RemovingBackgroundVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var veBackground: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var lblPercent: UILabel!

    // MARK: - Input

    /// Single photo (kept for existing callers).
    var image: UIImage?
    /// Photos from ImageSourcePickerVC (one or many).
    var pickedImages: [PickedImage] = []
    /// Existing project to (re)process instead of creating a new one.
    var viewModel: BackgroundRemovalViewModel?

    enum Destination {
        case editor
        case changeBackground
        case textBehind
    }
    /// What opens after processing.
    var destination: Destination = .editor

    // MARK: - Views

    private let mainView = UIView()
    private let baseImageView = UIImageView()      // checkerboard (UI only)
    private let removebgImageView = UIImageView()  // transparent result
    private let imageView = UIImageView()          // original photo

    private let scanColor = UIColor(red: 0.16, green: 0.42, blue: 1.0, alpha: 1.0)
    private let scanView = UIView()
    private let scanGlowLayer = CAGradientLayer()
    private let scanLineLayer = CALayer()
    private let scanHeight: CGFloat = 90

    private var mainWidthConstraint: NSLayoutConstraint?
    private var mainHeightConstraint: NSLayoutConstraint?

    // MARK: - State

    private var displayedImageSize: CGSize?
    private var displayIndex = 0
    private var displayedItemID: UUID?
    private var isRevealing = false
    private var didFinish = false
    private var observers: [NSObjectProtocol] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        bannerAd()
        setupScanViews()
        progressView.progress = 0
        lblStatus.text = "Preparing photos…"
        lblPercent.text = ""
        mainView.alpha = 0
        prepareProject()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImageSize()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scanView.bounds = CGRect(x: 0, y: 0, width: mainView.bounds.width, height: scanHeight)
        if scanView.layer.animation(forKey: "scan") == nil {
            scanView.center = CGPoint(x: mainView.bounds.midX, y: 0)
        }
        scanGlowLayer.frame = scanView.bounds
        scanLineLayer.frame = CGRect(x: 0, y: scanHeight / 2 - 1.5, width: mainView.bounds.width, height: 3)
        CATransaction.commit()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || didFinish { stopScanning(animated: false) }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Setup Image View
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
        let adsType = appData.removingBackgroundVC.adType ?? ""
        let adsSize = appData.removingBackgroundVC.adSize ?? 50
        
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
    private func setupImageView() {
        veBackground.clipsToBounds = true

        mainView.translatesAutoresizingMaskIntoConstraints = false
        mainView.backgroundColor = .clear
        mainView.layer.cornerRadius = 20
        mainView.layer.masksToBounds = true
        veBackground.addSubview(mainView)

        mainWidthConstraint = mainView.widthAnchor.constraint(equalToConstant: 0)
        mainHeightConstraint = mainView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            mainView.centerXAnchor.constraint(equalTo: veBackground.centerXAnchor),
            mainView.centerYAnchor.constraint(equalTo: veBackground.centerYAnchor),
            mainWidthConstraint!,
            mainHeightConstraint!
        ])

        // 1. Checkerboard (bottom) – visual indicator only.
        baseImageView.contentMode = .scaleAspectFill
        baseImageView.image = UIImage(named: "Remove BG Image")

        // 2. Transparent result.
        removebgImageView.contentMode = .scaleAspectFit
        removebgImageView.alpha = 0

        // 3. Original photo (top) – fades away when the result is ready.
        imageView.contentMode = .scaleAspectFit

        [baseImageView, removebgImageView, imageView].forEach { iv in
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.clipsToBounds = true
            iv.backgroundColor = .clear
            mainView.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: mainView.topAnchor),
                iv.bottomAnchor.constraint(equalTo: mainView.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: mainView.trailingAnchor)
            ])
        }
    }

    private func setupScanViews() {
        // Soft glow around a bright line; moved with Core Animation (no per-frame work).
        scanGlowLayer.colors = [
            scanColor.withAlphaComponent(0).cgColor,
            scanColor.withAlphaComponent(0.28).cgColor,
            scanColor.withAlphaComponent(0).cgColor
        ]
        scanGlowLayer.locations = [0, 0.5, 1]
        scanView.layer.addSublayer(scanGlowLayer)

        scanLineLayer.backgroundColor = scanColor.cgColor
        scanLineLayer.shadowColor = scanColor.cgColor
        scanLineLayer.shadowOpacity = 1
        scanLineLayer.shadowRadius = 8
        scanLineLayer.shadowOffset = .zero
        scanView.layer.addSublayer(scanLineLayer)

        scanView.isUserInteractionEnabled = false
        scanView.alpha = 0
        mainView.addSubview(scanView)
    }

    // MARK: - Project

    private func prepareProject() {
        observeViewModel()
        guard viewModel == nil else {
            beginDisplay()
            return
        }
        var photos = pickedImages
        if photos.isEmpty, let image {
            photos = [PickedImage(source: .image(image), suggestedName: nil)]
        }
        guard !photos.isEmpty else {
            navigationController?.popViewController(animated: true)
            return
        }
        Task { [weak self] in
            do {
                let mode: EditorMode
                switch self?.destination {
                case .changeBackground?: mode = .changeBackground
                case .textBehind?: mode = .textBehind
                default: mode = .removeBackground
                }
                let model = try await BackgroundRemovalViewModel.create(from: photos, mode: mode)
                guard let self else { return }
                self.viewModel = model
                self.observeViewModel()
                self.beginDisplay()
            } catch {
                guard let self else { return }
                self.lblStatus.text = "Couldn't read the photos"
                self.presentErrorAlert(title: "Couldn't open the photos", message: error.localizedDescription)
            }
        }
    }

    private func observeViewModel() {
        guard let viewModel, observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: BackgroundRemovalViewModel.itemDidChangeNotification,
                                            object: viewModel, queue: .main) { [weak self] note in
            guard let id = note.userInfo?[BackgroundRemovalViewModel.itemIDKey] as? UUID else { return }
            MainActor.assumeIsolated { self?.itemDidChange(id) }
        })
        observers.append(center.addObserver(forName: BackgroundRemovalViewModel.queueDidFinishNotification,
                                            object: viewModel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateProgress() }
        })
    }

    private func beginDisplay() {
        guard let viewModel else { return }
        // Start at the first item that still needs work (or the first item).
        displayIndex = viewModel.items.firstIndex { !$0.isCompleted } ?? 0
        showItem(at: displayIndex)
        viewModel.startProcessing()
        updateProgress()
    }

    // MARK: - Display

    private func showItem(at index: Int) {
        guard let viewModel, viewModel.items.indices.contains(index) else {
            finish()
            return
        }
        let item = viewModel.items[index]
        displayedItemID = item.id
        isRevealing = false
        updateLabels(for: item, index: index)

        Task { [weak self] in
            guard let self else { return }
            let preview = await viewModel.originalPreview(for: item.id, maxPixel: 1600)
            guard self.displayedItemID == item.id else { return }
            self.imageView.image = preview
            self.imageView.alpha = 1
            self.removebgImageView.image = nil
            self.removebgImageView.alpha = 0
            self.displayedImageSize = preview?.size
            self.updateImageSize()
            self.view.layoutIfNeeded()

            // Fade in + gentle scale into position.
            self.mainView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            UIView.animate(withDuration: 0.45, delay: 0, options: [.curveEaseOut]) {
                self.mainView.alpha = 1
                self.mainView.transform = .identity
            }

            if let current = viewModel.item(item.id), !self.isRevealing {
                switch current.status {
                case .completed: self.reveal(current)
                case .failed: self.showFailure(current)
                case .waiting, .processing: self.startScanning()
                }
            }
        }
    }

    private func itemDidChange(_ id: UUID) {
        updateProgress()
        guard id == displayedItemID, !isRevealing, let item = viewModel?.item(id) else { return }
        updateLabels(for: item, index: displayIndex)
        switch item.status {
        case .completed: reveal(item)
        case .failed: showFailure(item)
        case .processing, .waiting: startScanning()
        }
    }

    private func updateLabels(for item: BackgroundRemovalItem, index: Int) {
        let total = viewModel?.items.count ?? 1
        lblTitle.text = "Removing background"
        lblSubtitle.text = total > 1 ? "Image \(index + 1) of \(total)" : "Finding the subject and cleaning edges"
        switch item.status {
        case .waiting: lblStatus.text = "Waiting…"
        case .processing: lblStatus.text = "Detecting the subject with Apple Vision"
        case .completed: lblStatus.text = "Background removed"
        case .failed: lblStatus.text = "Couldn't process this photo"
        }
    }

    /// Progress = finished photos / total (real work, no simulated percentage).
    private func updateProgress() {
        guard let viewModel else { return }
        let total = viewModel.items.count
        let finished = viewModel.items.filter { $0.status == .completed || $0.status == .failed }.count
        progressView.setProgress(Float(finished) / Float(max(total, 1)), animated: true)
        lblPercent.text = total > 1 ? "\(finished)/\(total)" : (finished == 1 ? "Done" : "")
    }

    // MARK: - Scan animation

    private func startScanning() {
        guard scanView.layer.animation(forKey: "scan") == nil, mainView.bounds.height > 0 else { return }
        scanView.center = CGPoint(x: mainView.bounds.midX, y: 0)
        let move = CABasicAnimation(keyPath: "position.y")
        move.fromValue = 0
        move.toValue = mainView.bounds.height
        move.duration = 1.6
        move.autoreverses = true
        move.repeatCount = .infinity
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scanView.layer.add(move, forKey: "scan")
        UIView.animate(withDuration: 0.25) { self.scanView.alpha = 1 }
    }

    private func stopScanning(animated: Bool) {
        let removeAnimation = { self.scanView.layer.removeAnimation(forKey: "scan") }
        guard animated else {
            scanView.alpha = 0
            removeAnimation()
            return
        }
        UIView.animate(withDuration: 0.2, animations: { self.scanView.alpha = 0 }) { _ in removeAnimation() }
    }

    /// Fades the original background away to reveal the real transparent result.
    private func reveal(_ item: BackgroundRemovalItem) {
        guard let viewModel, !isRevealing else { return }
        isRevealing = true
        stopScanning(animated: true)
        Task { [weak self] in
            guard let self else { return }
            let foreground = await viewModel.foregroundPreview(for: item.id, maxPixel: 1600)
            guard self.displayedItemID == item.id else { return }
            self.removebgImageView.image = foreground
            UIView.animate(withDuration: 0.55, delay: 0, options: [.curveEaseInOut]) {
                self.imageView.alpha = 0
                self.removebgImageView.alpha = 1
            } completion: { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.advance()
                }
            }
        }
    }

    private func showFailure(_ item: BackgroundRemovalItem) {
        guard !isRevealing else { return }   // already handled for this photo
        isRevealing = true
        stopScanning(animated: true)
        guard let viewModel else { return }
        if viewModel.items.count == 1 {
            presentErrorAlert(title: "Couldn't remove the background",
                              message: item.errorMessage ?? "Please try again.",
                              retryTitle: "Try Again") { [weak self] in
                guard let self else { return }
                self.isRevealing = false
                self.startScanning()
                viewModel.retry(item.id)
            }
            return
        }
        // Batch: keep going; the editor lets the user retry this photo later.
        isRevealing = true
        UIView.animate(withDuration: 0.3) { self.imageView.alpha = 0.45 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.advance() }
    }

    private func advance() {
        guard let viewModel else { return }
        displayIndex += 1
        if displayIndex < viewModel.items.count {
            UIView.animate(withDuration: 0.25, animations: {
                self.mainView.alpha = 0
            }, completion: { _ in
                self.showItem(at: self.displayIndex)
            })
        } else {
            finish()
        }
    }

    private func finish() {
        guard !didFinish, let viewModel else { return }
        guard !viewModel.project.completedItems.isEmpty else {
            presentErrorAlert(title: "No backgrounds removed",
                              message: viewModel.items.first?.errorMessage ?? "None of the photos could be processed.",
                              retryTitle: "Try Again") { [weak self] in
                guard let self else { return }
                viewModel.startProcessing(viewModel.items.map(\.id))
                self.displayIndex = 0
                self.showItem(at: 0)
            }
            return
        }
        didFinish = true
        lblStatus.text = "Background removed"
        openEditor()
    }

    // MARK: - Update Image Size

    private func updateImageSize() {
        guard let imageSize = displayedImageSize ?? image?.size else { return }
        let containerSize = veBackground.bounds.size
        guard containerSize.width > 0, containerSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let fittedWidth = imageSize.width * scale
        let fittedHeight = imageSize.height * scale

        // Only touch constraints when the size actually changes (avoids layout loops)
        if mainWidthConstraint?.constant != fittedWidth ||
            mainHeightConstraint?.constant != fittedHeight {
            mainWidthConstraint?.constant = fittedWidth
            mainHeightConstraint?.constant = fittedHeight
            veBackground.layoutIfNeeded()
        }
    }

    // MARK: - Navigation

    private func openEditor() {
        guard let viewModel, let nav = navigationController else { return }
        let editor = UIViewController.editorScreen(for: viewModel)
        var stack = nav.viewControllers
        let index = stack.firstIndex(of: self) ?? stack.count
        stack.removeSubrange(index...)
        stack.append(editor)
        // Change Background projects open the editor with the Background sheet already showing;
        // Text Behind projects open TextBehindSubjectVC.
        nav.setViewControllers(stack, animated: true)
    }

    // MARK: - Cancel

    @IBAction func btnCancel(_ sender: UIButton) {
        viewModel?.cancelProcessing()
        stopScanning(animated: false)
        navigationController?.popViewController(animated: true)
    }
}
extension RemovingBackgroundVC: BannerViewDelegate {
    
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
