//
//  Common.swift
//  Live Football Score
//
//  Created by Jenin Sutariya on 03/03/26.
//

import Foundation
import UIKit
import StoreKit
let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String

// Get the bundle identifier (App ID)
let bundleIdentifier = Bundle.main.bundleIdentifier

// Get the app version and build number
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
func prepareCountryName(_ str: String) -> String {
    return str
        .replacingOccurrences(of: " ", with: "-")
        .lowercased()
}
let isIPad = UIDevice.current.userInterfaceIdiom == .pad
extension UIApplication {
    var topViewController: UIViewController? {
        guard let scene = connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
func calculateContentHeight(for viewController: ImageSourcePickerVC) -> CGFloat {
    viewController.view.layoutIfNeeded()
    viewController.contentView.layoutIfNeeded()

    let fittingSize = CGSize(
        width: viewController.contentView.bounds.width,
        height: UIView.layoutFittingCompressedSize.height
    )

    let size = viewController.contentView.systemLayoutSizeFitting(
        fittingSize,
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    )

    return size.height
}
func showImageSourcePicker(from viewController: UIViewController, vc: UIViewController, contentHeight: CGFloat) {
    let sheetVC = vc

    sheetVC.loadViewIfNeeded()

    sheetVC.modalPresentationStyle = .pageSheet

    if let sheet = sheetVC.sheetPresentationController {

        if #available(iOS 16.0, *) {

            sheet.detents = [
                .custom { context in
                    return min(
                        contentHeight,
                        context.maximumDetentValue
                    )
                }
            ]

            sheet.prefersGrabberVisible = true

        } else {
            sheet.detents = [.medium()]
        }
    }

    viewController.present(sheetVC, animated: true)
}
