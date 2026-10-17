//
//  UIViewController+Extension.swift
//  TextTone
//
//  Created by Codeash Mac on 21/04/25.
//

import Foundation
import UIKit
extension UIStoryboard{
    static var mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
}

extension UIViewController{
    public class func fatchInstance() -> Self {
        let controller = UIStoryboard.mainStoryboard.instantiateViewController(withIdentifier: "\(Self.self)") as! Self
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }
}
func showToast(message : String) {
    guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
          let window = windowScene.windows.first else { return }
    
    let toastLabel = UILabel()
    toastLabel.text = message
    toastLabel.textAlignment = .center
    toastLabel.textColor = UIColor.black
    toastLabel.font = UIFont(name: "HelveticaNeue-Medium", size: 16)
    toastLabel.numberOfLines = 0
    toastLabel.alpha = 0.8
    toastLabel.layer.cornerRadius = 10
    toastLabel.clipsToBounds = true
    toastLabel.translatesAutoresizingMaskIntoConstraints = false
    let padding: CGFloat = 12
    let toastContainer = UIView()
    toastContainer.backgroundColor = UIColor.white.withAlphaComponent(0.7)
    toastContainer.layer.cornerRadius = 10
    toastContainer.translatesAutoresizingMaskIntoConstraints = false
    toastContainer.clipsToBounds = true
    
    toastContainer.addSubview(toastLabel)
    window.addSubview(toastContainer)
    NSLayoutConstraint.activate([
        toastLabel.topAnchor.constraint(equalTo: toastContainer.topAnchor, constant: padding),
        toastLabel.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -padding),
        toastLabel.leadingAnchor.constraint(equalTo: toastContainer.leadingAnchor, constant: padding),
        toastLabel.trailingAnchor.constraint(equalTo: toastContainer.trailingAnchor, constant: -padding),
    ])
    NSLayoutConstraint.activate([
        toastContainer.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 20),
        toastContainer.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -20),
        toastContainer.centerXAnchor.constraint(equalTo: window.centerXAnchor)
    ])
    
    toastContainer.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
    
    UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseOut, animations: {
        toastContainer.alpha = 1.0
    }) { _ in
        UIView.animate(withDuration: 0.5, delay: 2.0, options: .curveEaseIn, animations: {
            toastContainer.alpha = 0.0
        }) { _ in
            toastContainer.removeFromSuperview()
        }
    }
    
}
