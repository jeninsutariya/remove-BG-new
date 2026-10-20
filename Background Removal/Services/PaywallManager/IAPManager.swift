//
//  IAPManager.swift
//  Live Football Score
//
//  Created by Jenin Sutariya on 17/01/26.
//

import Foundation
import Foundation
import StoreKit
import SwiftyStoreKit

class PurchaseKeys {
    static var oneMonth = "com.removebg.erase.pro.weekly"
    static var sixMonth = "com.removebg.erase.pro.monthly"
    static var oneYear = "com.removebg.erase.pro.yearly"
    static var sharedSecret = "3991cde7b71a4c5186a5637b1231af2f"
    #if DEBUG
    static let appleValidator = AppleReceiptValidator(service: .sandbox, sharedSecret: PurchaseKeys.sharedSecret)
    #else
    static let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: PurchaseKeys.sharedSecret)
    #endif
}

extension Notification.Name {
    
    static let refreshPremiumLog = Notification.Name("refreshPremiumLog")
    static let refreshLanguage = Notification.Name("refreshLanguage")
    
}

class PurchaseConnector {
    
    static let shared = PurchaseConnector()
    
    var productIds: Set<String> = [PurchaseKeys.oneMonth,PurchaseKeys.sixMonth, PurchaseKeys.oneYear]
    var retrievedProducts = [SKProduct]()
    
    // MARK: - GET PRODUCT INFO
    func retrievedProductsInfo() {
        SwiftyStoreKit.retrieveProductsInfo(self.productIds) { [weak self] (result) in
            self?.retrievedProducts.removeAll()
            guard let self = self else { return }
            for product in result.retrievedProducts {
                print("Product Name: \(product.localizedTitle)")
                print("Product Price: \(product.localizedPrice ?? "")")
                print("Product ID: \(product.productIdentifier)")
                self.retrievedProducts.append(product)
            }
            print(">>>> PREMIUM PLANS <<<<")
            print(">>>> Error: ", result.error ?? "")
            print(">>>> PREMIUM PLANS COUNT: ", result.retrievedProducts.count)
            print(self.retrievedProducts.map({ $0.productIdentifier }))
            print(">>>> END <<<<")
            PurchaseConnector.shared.checkPremiumStatus()
        }
    }
    
    func purchaseProduct(productId: SKProduct, completion: @escaping (_ result: Bool) -> Void) {
        
        let purchaseId = productId.productIdentifier
        
        SwiftyStoreKit.purchaseProduct(purchaseId, quantity: 1, atomically: true) { result in
            switch result {
            case .success(let purchase):
//                GAEventsTracker.logEvents("purchase", ["success": true,"restore_purchases": purchase])
                print(">>>> Purchase Success: \(purchase.productId)")
                NotificationCenter.default.post(name: .refreshPremiumLog, object: nil)

                UserDefaults.isPremiumUser = true
                print("Purchase successful ??????????????????????????????????")
                completion(true)

            case .error(let error):
                switch error.code {
                case .unknown:
                    print("Purchase failed: Unknown error occurred.")
                case .clientInvalid:
                    print("Purchase failed: Not allowed to make the payment.")
                case .paymentCancelled:
                    print("Purchase cancelled by the user.")
                case .paymentInvalid:
                    print("Purchase failed: The purchase identifier was invalid.")
                case .paymentNotAllowed:
                    print("Purchase failed: Device not allowed to make the payment.")
                case .storeProductNotAvailable:
                    print("Purchase failed: Product is not available in the current storefront.")
                case .cloudServicePermissionDenied:
                    print("Purchase failed: Access to cloud service information is not allowed.")
                case .cloudServiceNetworkConnectionFailed:
                    print("Purchase failed: Could not connect to the network.")
                case .cloudServiceRevoked:
                    print("Purchase failed: User has revoked permission to use this cloud service.")
                default:
                    print("Purchase failed: An unknown or unhandled error occurred.")
                }

                completion(false)
            case .deferred(purchase: let purchase):
                completion(false)
            }
        }
    }
    
    func setInAppCompleteTransactions() {
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                case .failed, .purchasing, .deferred:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    @objc func checkPremiumStatus(complition: (() -> ())? = nil) {
        SwiftyStoreKit.verifyReceipt(using: PurchaseKeys.appleValidator) { result in
            switch result {
            case .success(let receipt):
                let purchaseResult = SwiftyStoreKit.verifySubscriptions(ofType: .autoRenewable, productIds: self.productIds, inReceipt: receipt)
                switch purchaseResult {
                case .purchased(let expiryDate, let receiptItems):
                    print(receiptItems)
                    print(">>>> Product is valid until \(expiryDate)")
                    UserDefaults.isPremiumUser = true
                    complition?()
                case .expired(let expiryDate, _):
                    print(">>>> Product is expired since \(expiryDate)")
                    UserDefaults.isPremiumUser = false
                    complition?()
                case .notPurchased:
                    print(">>>> This product has never been purchased")
                    UserDefaults.isPremiumUser = false
                    complition?()
                }
            case .error(let error):
                print(">>>> Receipt verification failed: \(error)")
                UserDefaults.isPremiumUser = false
                complition?()
                
            }
            NotificationCenter.default.post(name: .refreshPremiumLog, object: nil)
        }
    }
    func restorePurchase(complition: @escaping (Bool) -> Void) {
        LoaderView.shared.show()
        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            if results.restoreFailedPurchases.count > 0 {
                print(">>>> Restore Failed: \(results.restoreFailedPurchases)")
                showToast(message: "Restore failed. Please try again later.")
                complition(false)
            } else if results.restoredPurchases.count > 0 {
                print(">>>> Restore Success: \(results.restoredPurchases)")
//                GAEventsTracker.logEvents("restore_purchases", ["success": true,"restore_purchases": results.restoredPurchases])
                // Verify the restored purchases
                self.verifyReceiptAfterRestore { success in
                    if success {
                        showToast(message: "Purchase restored successfully!")
                        UserDefaults.isPremiumUser = true
                        complition(true)
                    } else {
                        showToast(message: "Restore verification failed")
                        complition(false)
                    }
                }
            } else {
                showToast(message: "No previous purchases found to restore")
                complition(false)
            }
            LoaderView.shared.hide()
        }
    }

    private func verifyReceiptAfterRestore(completion: @escaping (Bool) -> Void) {
        SwiftyStoreKit.verifyReceipt(using: PurchaseKeys.appleValidator) { result in
            switch result {
            case .success(let receipt):
                let purchaseResult = SwiftyStoreKit.verifySubscriptions(
                    ofType: .autoRenewable,
                    productIds: self.productIds,
                    inReceipt: receipt
                )
                
                switch purchaseResult {
                case .purchased:
                    completion(true)
                case .expired, .notPurchased:
                    completion(false)
                }
            case .error:
                completion(false)
            }
        }
    }
    
    func switchRootViewController(to viewController: UIViewController = MainTabVC.fatchInstance(), animated: Bool = true) {
        guard let window = UIApplication.shared.windows.first else {
            return
        }
        
        let onboardingVC = MainTabVC.fatchInstance()
        let nav = UINavigationController(rootViewController: onboardingVC)
        nav.isNavigationBarHidden = true
        UIApplication.shared.currentWindow?.rootViewController = nav
        UIApplication.shared.currentWindow?.makeKeyAndVisible()
        
        if animated {
            UIView.transition(with: window,
                              duration: 1,
                              options: [.transitionFlipFromRight],
                              animations: nil,
                              completion: { _ in
                window.makeKeyAndVisible()
            })
        }
    }


}
extension UIApplication {
    var currentWindow: UIWindow? {
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
