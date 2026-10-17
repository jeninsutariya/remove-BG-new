//
//  LoaderView.swift
//  AI Story
//
//  Created by Codeash Mac on 13/08/25.
//

import Foundation
import UIKit
import Lottie

class LoaderView {
    static let shared = LoaderView()
    private static var loadingViewTag = 9999999
    
    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    func show(isAdsloader: Bool = false) {
        guard let window = keyWindow else { return }
        
        // Prevent duplicate loaders
        if window.viewWithTag(Self.loadingViewTag) != nil { return }
        
        // 1. Full screen background overlay
        let loadingView = UIView(frame: window.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        loadingView.tag = Self.loadingViewTag
        
        // 2. Add blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = loadingView.bounds
        blurView.alpha = 0.5
        loadingView.addSubview(blurView)
        
        // 3. Create a Square Container for the content
        let containerView = UIView()
        containerView.backgroundColor = isAdsloader ? UIColor.black.withAlphaComponent(0.8) : .clear
        containerView.layer.cornerRadius = 15
        containerView.translatesAutoresizingMaskIntoConstraints = false
        loadingView.addSubview(containerView)
        
        // 4. Create Lottie animation view
        let animationView = LottieAnimationView(name: "Cosmos")
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play()
        containerView.addSubview(animationView)
        
        // 5. Constraints Setup
        NSLayoutConstraint.activate([
            // Center container in the middle of the screen
            containerView.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 160),
            
            // Lottie Constraints (Top of container)
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            animationView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            animationView.widthAnchor.constraint(equalToConstant: 80),
            animationView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // 6. Conditional Label for Ads
        if isAdsloader {
            let loadingLabel = UILabel()
            loadingLabel.text = "Ads Loading...\nPlease Wait"
            loadingLabel.textColor = .white
            loadingLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
            loadingLabel.textAlignment = .center
            loadingLabel.numberOfLines = 0
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(loadingLabel)
            
            NSLayoutConstraint.activate([
                loadingLabel.topAnchor.constraint(equalTo: animationView.bottomAnchor, constant: 5),
                loadingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                loadingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
                loadingLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
            ])
        } else {
            // If no label, attach the bottom of animation to bottom of container
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10).isActive = true
        }
        
        window.addSubview(loadingView)
    }
    
    func hide() {
        // Reduced delay to 0.5 for a "snappier" feel, or keep at 1.0 as per your preference
        delay(0.5) {
            guard let window = self.keyWindow else { return }
            if let loadingView = window.viewWithTag(Self.loadingViewTag) {
                loadingView.removeFromSuperview()
            }
        }
    }
    
    private func delay(_ delay: Double = 0.0, _ completion: @escaping () -> ()) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: completion)
    }
}
