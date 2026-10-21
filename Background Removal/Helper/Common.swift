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

func calculateAlertContentHeight(for viewController: AlertVC) -> CGFloat {
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
class BaseCustomView: UIView {

    // ----------------------------------------------------
    // MARK:
    // MARK: - Variables
    // ----------------------------------------------------
    public var nibName: String {
        return String(describing: Self.self) // defaults to the name of the class implementing this protocol.
    }
    var contentView: UIView?

    // ----------------------------------------------------
    // MARK:
    // MARK: - Override Functions
    // ----------------------------------------------------
    override init(frame fem: CGRect) {
        super.init(frame: fem)
        
        self.loadNIB()
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.loadNIB()
    }

    func loadNIB(){
        guard let view = loadViewFromNib() else { return }
        view.frame = self.bounds
        self.addSubview(view)
        contentView = view
    }
    
    // ----------------------------------------------------
    // MARK:
    // MARK: - Custome Functions
    // ----------------------------------------------------
    func loadViewFromNib() -> UIView? {
        let bundle = Bundle(for: type(of: self))
        let nib = UINib(nibName: nibName, bundle: bundle)
        return nib.instantiate(withOwner: self, options: nil).first as? UIView
    }
}
func topMostViewController() -> UIViewController {
    return (UIApplication.shared.delegate as! AppDelegate).visibleViewController ?? UIViewController()
}

func showAlert(title: String = "Alert", msg: String = "", okayTitle: String = "Okay", cancelTitle: String = "", doneAction: (() -> ())? = nil, cancleAction: (() -> ())? = nil) {
//    let alertView = ShowAlertView()
//    alertView.frame = UIScreen.main.bounds
//    alertView.setView(title: title,message: msg, cancelTitle: cancelTitle, submitTitle: okayTitle)
//    alertView.onCancel = {
//        cancleAction?()
//    }
//    alertView.onSubmit = {
//        doneAction?()
//    }
//    topMostViewController().view.addSubview(alertView)
    let sheetVC = AlertVC.fatchInstance()
    let contentHeight = calculateAlertContentHeight(for: sheetVC)
    sheetVC.lblTitle.text = title
    sheetVC.lblSubtitle.text = msg
    sheetVC.btnOkey.setTitle(okayTitle, for: .normal)
    sheetVC.btnCancel.setTitle(cancelTitle, for: .normal)
    sheetVC.onCancel = {
        cancleAction?()
    }
    sheetVC.onSubmit = {
        doneAction?()
    }
    sheetVC.btnCancel.isHidden = cancelTitle == ""
    sheetVC.btnOkey.isHidden = okayTitle == ""
    DispatchQueue.main.async {
        showImageSourcePicker(from: topMostViewController(),vc: sheetVC,contentHeight: contentHeight)
    }
    
    
}

func showAlertWithOneOption(msg: String = "", doneAction: (() -> ())? = nil) {
    showAlert(title: "Alert", msg: msg, okayTitle: "Okay", doneAction:  {
        doneAction?()
    })
}
