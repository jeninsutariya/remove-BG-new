//
//  AppDelegate.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 04/10/26.
//

import UIKit
import CoreData
import FirebaseCore
import GoogleMobileAds
import SwiftyStoreKit
import AppTrackingTransparency
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var visibleViewController: UIViewController? {
        var currentVc = UIApplication.shared.windows.first?.rootViewController
        while let presentedVc = currentVc?.presentedViewController {
            if let navVc = (presentedVc as? UINavigationController)?.viewControllers.last {
                currentVc = navVc
            } else if let tabVc = (presentedVc as? UITabBarController)?.selectedViewController {
                currentVc = tabVc
            } else {
                currentVc = presentedVc
            }
        }
        return currentVc
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Listen for StoreKit transactions and load the verified premium state.
        SwiftyStoreKit.completeTransactions(atomically: true) { _ in }
        MobileAds.shared.start(completionHandler: nil)
        FirebaseApp.configure()
        
        PurchaseConnector.shared.retrievedProductsInfo()
        PurchaseConnector.shared.setInAppCompleteTransactions()
        PurchaseConnector.shared.checkPremiumStatus()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    func requestTrackingPermission() {
       if #available(iOS 14, *) {
           ATTrackingManager.requestTrackingAuthorization { status in
               switch status {
               case .authorized:
                   print("✅ Tracking authorized")
               case .denied:
                   print("❌ Tracking denied")
               case .restricted:
                   print("🚫 Tracking restricted")
               case .notDetermined:
                   print("⚠️ Tracking not determined")
               @unknown default:
                   break
               }
           }
       }
   }

}

