//
//  RemovingBackgroundVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 16/10/26.
//

import UIKit
import BackgroundRemoval

class RemovingBackgroundVC: UIViewController {

    @IBOutlet weak var veBackground: UIView!

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupImageView()
        setupScanViews()
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
        navigationController?.popViewController(animated: true)
    }
}
