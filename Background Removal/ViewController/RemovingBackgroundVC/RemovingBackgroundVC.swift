//
//  RemovingBackgroundVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 16/10/26.
//

import UIKit

class RemovingBackgroundVC: UIViewController {

    @IBOutlet weak var veBackground: UIView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var lblPercent: UILabel!

    var image: UIImage?

    // MARK: - Views

    private let mainView = UIView()
    private let baseImageView = UIImageView()      // checkerboard
    private let removebgImageView = UIImageView()  // result (cut-out)
    private let imageView = UIImageView()          // original (on top, masked)

    // MARK: - Scan animation

    private let scanColor = UIColor(red: 0.16, green: 0.42, blue: 1.0, alpha: 1.0)
    private let scanLineView = UIView()
    private let scanTrailLayer = CAGradientLayer()
    private let revealMaskLayer = CALayer()

    private let scanLineHeight: CGFloat = 3
    private let scanTrailHeight: CGFloat = 70
    private let sweepDuration: CFTimeInterval = 1.8

    private var displayLink: CADisplayLink?
    private var sweepStart: CFTimeInterval = 0
    private var scanProgress: CGFloat = 0
    private var isRevealing = false
    private var resultImage: UIImage?

    private var mainWidthConstraint: NSLayoutConstraint?
    private var mainHeightConstraint: NSLayoutConstraint?

    // MARK: - Processing state

    private var session: EditSession?
    private var processingTask: Task<Void, Never>?
    private var processingStart = CACurrentMediaTime()
    private var progress: Float = 0
    private var didOpenEditor = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupScanViews()
        setupProgress()
        startBackgroundRemoval()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()   // CADisplayLink retains self, so always invalidate
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImageSize()
        layoutScan(progress: scanProgress)
    }

    // MARK: - Background Removal

    /// Runs Vision off the main thread; the scan animation reveals the result when it's ready.
    private func startBackgroundRemoval() {
        guard let image else { return }
        let working = BGRemovalEngine.normalized(image)
        guard let cgImage = working.cgImage else {
            showFailure(BGRemovalError.unavailable("this image format isn't supported"))
            return
        }
        processingStart = CACurrentMediaTime()
        processingTask = Task { [weak self] in
            do {
                let mask = try await Task.detached(priority: .userInitiated) {
                    try BGRemovalEngine.makeMask(for: cgImage)
                }.value
                guard let self, !Task.isCancelled else { return }
                let session = EditSession(original: working, mask: mask)
                self.session = session
                self.resultImage = session.cutout   // picked up by the next sweep in tick(_:)
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.showFailure(error)
            }
        }
    }

    private func setupProgress() {
        progressView.progress = 0
        lblStatus.text = "Preparing photo"
        lblPercent.text = "0%"
    }

    private func updateProgress() {
        if isRevealing {
            progress = max(progress, 0.9 + 0.1 * Float(scanProgress))
        } else if resultImage == nil {
            // Ease towards 90% while Vision is working.
            let elapsed = CACurrentMediaTime() - processingStart
            progress = Float(0.9 * (1 - exp(-elapsed / 1.6)))
        }
        progressView.setProgress(progress, animated: false)
        let percent = Int((progress * 100).rounded())
        lblPercent.text = "\(percent)%"
        switch percent {
        case ..<20: lblStatus.text = "Preparing photo"
        case ..<55: lblStatus.text = "Finding the subject"
        case ..<90: lblStatus.text = "Detecting edges"
        case ..<100: lblStatus.text = "Cleaning up"
        default: lblStatus.text = "Done"
        }
    }

    private func showFailure(_ error: Error) {
        stopScanning()
        let alert = UIAlertController(title: "Couldn't remove the background",
                                      message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    /// Replaces this screen with the editor (07 Result & Editor).
    private func openEditor() {
        guard !didOpenEditor, let session, let nav = navigationController else { return }
        didOpenEditor = true
        let editor = EditorVC.fatchEditorInstance()
        editor.session = session
        var stack = nav.viewControllers
        if let index = stack.firstIndex(of: self) {
            stack[index] = editor
        } else {
            stack.append(editor)
        }
        nav.setViewControllers(stack, animated: true)
    }


    // MARK: - Setup Image View

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

        // 1. Checkerboard (bottom)
        baseImageView.contentMode = .scaleAspectFill
        baseImageView.image = UIImage(named: "Remove BG Image")

        // 2. Result – empty until processing finishes
        removebgImageView.contentMode = .scaleAspectFit
        removebgImageView.image = nil

        // 3. Original (top) – gets masked away from the top during reveal
        imageView.contentMode = .scaleAspectFit
        imageView.image = image

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
        // Mask on the original image: only the area BELOW the line stays visible
        revealMaskLayer.backgroundColor = UIColor.black.cgColor
        imageView.layer.mask = revealMaskLayer

        // Soft blue glow trailing above the line
        scanTrailLayer.colors = [
            scanColor.withAlphaComponent(0.0).cgColor,
            scanColor.withAlphaComponent(0.35).cgColor
        ]
        scanTrailLayer.startPoint = CGPoint(x: 0.5, y: 0)
        scanTrailLayer.endPoint = CGPoint(x: 0.5, y: 1)
        mainView.layer.addSublayer(scanTrailLayer)

        // The bright line itself, with a glow
        scanLineView.backgroundColor = scanColor
        scanLineView.layer.shadowColor = scanColor.cgColor
        scanLineView.layer.shadowOpacity = 1
        scanLineView.layer.shadowRadius = 8
        scanLineView.layer.shadowOffset = .zero
        mainView.addSubview(scanLineView)

        layoutScan(progress: 0)
    }

    // MARK: - Scan Loop

    private func startScanning() {
        stopScanning()
        isRevealing = false
        sweepStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopScanning() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        updateProgress()
        let t = CGFloat((link.timestamp - sweepStart) / sweepDuration)

        if t >= 1 {
            if isRevealing {
                finishReveal()
            } else if let result = resultImage {
                // Result is ready → next sweep reveals it
                removebgImageView.image = result
                isRevealing = true
                sweepStart = link.timestamp
                scanProgress = 0
                layoutScan(progress: 0)
            } else {
                // Still processing → sweep again
                sweepStart = link.timestamp
                scanProgress = 0
                layoutScan(progress: 0)
            }
            return
        }

        scanProgress = easeInOut(t)
        layoutScan(progress: scanProgress)
    }

    private func finishReveal() {
        stopScanning()
        scanProgress = 1
        layoutScan(progress: 1)
        imageView.isHidden = true
        hideScanLine()
        progress = 1
        updateProgress()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.openEditor()
        }
    }

    private func hideScanLine() {
        UIView.animate(withDuration: 0.3) {
            self.scanLineView.alpha = 0
        }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.3
        scanTrailLayer.opacity = 0
        scanTrailLayer.add(fade, forKey: "fade")
    }

    /// Positions the line, glow and mask for a progress value 0...1
    private func layoutScan(progress: CGFloat) {
        let bounds = mainView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let y = bounds.height * progress

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        scanLineView.frame = CGRect(x: 0,
                                    y: y - scanLineHeight / 2,
                                    width: bounds.width,
                                    height: scanLineHeight)

        scanTrailLayer.frame = CGRect(x: 0,
                                      y: y - scanTrailHeight,
                                      width: bounds.width,
                                      height: scanTrailHeight)

        // While processing: show the whole original.
        // While revealing: show the original only below the line.
        revealMaskLayer.frame = isRevealing
            ? CGRect(x: 0, y: y, width: bounds.width, height: max(0, bounds.height - y))
            : bounds

        CATransaction.commit()
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    // MARK: - Update Image Size

    private func updateImageSize() {
        guard let image = image else { return }

        let containerSize = veBackground.bounds.size
        let imageSize = image.size

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

    // MARK: - Cancel

    @IBAction func btnCancel(_ sender: UIButton) {
        processingTask?.cancel()
        stopScanning()
        navigationController?.popViewController(animated: true)
    }
}
