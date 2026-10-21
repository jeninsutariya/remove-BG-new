//
//  GoogleAds.swift
//  AppKeyboard
//
//  Created by VASU SAVALIYA on 12/04/23.
//

import Foundation
import UIKit
import GoogleMobileAds
//import MBProgressHUD

protocol GoogleAddsDelegate {
    func dismiss()
}

let interstitialAddsId = appData.interstitialAdsId ?? ""
let appOpenAdsId = appData.appOpenAdsId ?? ""
let nativeAdsId = appData.nativeAdsId ?? ""

let adInterval = 4
let adsManager = GoogleAdds.sharedInstance
class GoogleAdds: NSObject, FullScreenContentDelegate {
    
    static let sharedInstance = GoogleAdds()
    var didCloseAds: (() -> Void)?
    
    var interstitial: InterstitialAd?
    var delegate: GoogleAddsDelegate?
    var clickCount = appData.interstitialCount ?? 4
    func showInterstitialAdds() {
        
        if UserDefaults.MainClickCount % clickCount == 0 {
            self.showFullScreenAds()
        } else {
            UserDefaults.MainClickCount += 1
            self.didCloseAds?()
        }
        
    }

    func showInterstitial(complition: @escaping (() -> Void)){
        if UserDefaults.isPremiumUser {
            complition()
            return
        }
        if UserDefaults.MainClickCount % clickCount == 0 {
            self.showInterstitialAdds()
            self.didCloseAds = { [weak self] in
                guard self != nil else { return }
                complition()
            }
        } else {
            UserDefaults.MainClickCount += 1
            complition()
        }
    }

    func showFullScreenAds(isLoaderShown: Bool = true) {
    
        
        if isLoaderShown {
            LoaderView.shared.show(isTextloader: true, text: "Ads Loading...\nPlease Wait")
        }
        
        let request = Request()
        InterstitialAd.load(with: interstitialAddsId,
                               request: request,
                               completionHandler: { [self] ad, error in
//            ProgressHUD.shared.hideOverlayView() by Jenin Sutariya
//            progressInstance.progressStop()
            LoaderView.shared.hide()

            if let error = error {
                print("Failed to load interstitial ad with error: \(error.localizedDescription)")
                self.didCloseAds?()
                return
            }
            self.interstitial = ad
            
            self.interstitial?.paidEventHandler = { adValue in
                let value = adValue.value
                let currencyCode = adValue.currencyCode
                GAEventsTracker.logADEvents(value, currencyCode, "interstitial")
            }
            
            self.interstitial?.fullScreenContentDelegate = self
            
            if self.interstitial != nil {
                UserDefaults.MainClickCount += 1
                self.interstitial?.present(from: topMostViewController())
            } else {
                print("Ad wasn't ready")
                self.didCloseAds?()
            }
        })
    }


    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("Ad will present full screen content.")
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("Ad did record impression.")
    }
    
    func adWillDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        print("Ad Will dismiss full screen content.")
        self.delegate?.dismiss()
        self.didCloseAds?()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Ad failed to present with error: \(error.localizedDescription)")
        self.delegate?.dismiss()
        self.didCloseAds?()
    }
    
    
}

enum AppConfiguration {
    case Debug
    case TestFlight
    case AppStore
}

struct Config {
    // I This is private because the use of 'appConfiguration' is preferred.
    private static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
 
    static var isDebug : Bool {
        #if DEBUG
        return true
        #else
        return true
        #endif
    }
    
    static var appConfiguration: AppConfiguration {
        if isDebug {
            print("DEBUG")
            return .Debug
        } else if isTestFlight {
            print("TESTFLIGHT")
            return .TestFlight
        } else {
            print("PRODUCTION")
            return .AppStore
        }
    }
    
}
