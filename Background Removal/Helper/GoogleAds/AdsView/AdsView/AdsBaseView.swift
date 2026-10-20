//
//  AdsView.swift
//  vpnproxy
//
//  Created by Vasu Savaliya on 20/06/24.
//

import UIKit
import GoogleMobileAds
 enum AdsViewModel {
    case smallNative
    case bigNative
}
class AdsBaseView: BaseCustomView {

    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var smallNativeAdsView: SmallNativeAdsView!
    @IBOutlet weak var nativeAdsView: NativeAdsView?
    
    var bannerAdsLoaded: (() -> Void)?
    var bannerAdsFaildLoaded: (() -> Void)?
    var bannerHeight: CGFloat = 0
    
    var adsViewModel: AdsViewModel?
    
    func setupAdsView(data: AdsViewModel?) {
        self.adsViewModel = data
        if appData.isAdsShow == 0 {
            self.destroyBannerAd()
            return
        }
        if UserDefaults.isPremiumUser{
            self.destroyBannerAd()
            return
        }
        switch data{
        case .bigNative:
            self.smallNativeAdsView?.removeFromSuperview()
            self.nativeAdsView?.startSmartShining()
            self.bannerHeight = max(264.0, 0)
            self.setupNativeAdsView()
            self.bannerAdsLoaded?()
        case .smallNative:
            self.nativeAdsView?.removeFromSuperview()
            self.nativeAdsView?.startSmartShining()
            self.bannerHeight = max(80.0, 0)
            self.setupSmallNativeAdsView()
        case .none:
            self.destroyBannerAd()
        }
        
    }
    
    func destroyBannerAd() {
        self.nativeAdsView?.removeFromSuperview()
        self.smallNativeAdsView?.removeFromSuperview()
    }
    
    func setupNativeAdsView() {
        self.nativeAdsView?.isHidden = false
        self.nativeAdsView?.delegate = self
        self.nativeAdsView?.setupNativeAds()
    }
    
    func setupSmallNativeAdsView() {
        self.smallNativeAdsView?.isHidden = false
        self.smallNativeAdsView?.delegate = self
        self.smallNativeAdsView?.setupNativeAds()
        
    }
}

extension AdsBaseView: bannerAdsDelegate {
    
    func didSuccessAds() {
        self.nativeAdsView?.isHidden = false
        self.smallNativeAdsView?.isHidden = false
        switch adsViewModel{
        case .bigNative:
            self.bannerHeight = max(264.0, 0)
        case .smallNative:
            self.bannerHeight = max(80.0, 0)
        case .none:
            self.bannerHeight = max(0, 0)
        }
  
        print("self.bannerHeight", self.bannerHeight)
        self.bannerAdsLoaded?()
        
    }
    
    func didFailedAds() {

        self.bannerHeight = 0
        self.bannerAdsFaildLoaded?()
    }
}
protocol bannerAdsDelegate: NSObject {
    
    func didFailedAds()
    func didSuccessAds()
}
