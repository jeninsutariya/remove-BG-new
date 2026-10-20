//
//  SmallNativeAdsView.swift
//  vpnproxy
//
//  Created by Vasu Savaliya on 20/06/24.
//

import UIKit
import GoogleMobileAds
//import Lottie
import UIView_Shimmer


class SmallNativeAdsView: BaseCustomView,ShimmeringViewProtocol {
    
    @IBOutlet weak var lblBody: UILabel!
    @IBOutlet weak var adsLableView: UIView!
    @IBOutlet weak var adview: UIView!
    
    @IBOutlet weak var nativeAdView: NativeAdView!
    var shimmeringAnimatedItems: [UIView] {
        return [
            nativeAdView.iconView,
            nativeAdView.headlineView,
            nativeAdView.callToActionView,
            lblBody,
            adsLableView
        ].compactMap { $0 }
    }

    weak var delegate: bannerAdsDelegate?
    var isVisible = true
    
    var adLoader: AdLoader!
    var adsData: NativeAd?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func destroyBannerAd() {
        isVisible = false
        adLoader = nil
        startSmartShining()
        self.nativeAdView.isHidden = true
        self.nativeAdView.nativeAd = nil
        self.delegate?.didFailedAds()
        
    }
    func startSmartShining() {
        adview.layer.masksToBounds = true
    }
    func setupNativeAds() {
        self.setTemplateWithSubviews(true, viewBackgroundColor: .white)
        self.checkConfiguration()
    }
    
    func checkConfiguration() {
        
        if appData.isAdsShow == 0 {
            self.destroyBannerAd()
            return
        }
        self.loadBannerView()
    }
    
    func loadBannerView() {
//                self.nativeAdView.isHidden = true
        adLoader = AdLoader(
            adUnitID: nativeAdsId, rootViewController: topMostViewController(),
            adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(Request())
    }
    
    /// if the star rating is less than 3.5 stars.
    func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
        guard let rating = starRating?.doubleValue else {
            return nil
        }
        if rating >= 5 {
            return UIImage(named: "stars_5")
        } else if rating >= 4.5 {
            return UIImage(named: "stars_4_5")
        } else if rating >= 4 {
            return UIImage(named: "stars_4")
        } else if rating >= 3.5 {
            return UIImage(named: "stars_3_5")
        } else {
            return nil
        }
    }
    
    func setupDate() {
        guard let nativeAd = adsData else { return }
        
        self.isVisible = true
        
        nativeAd.delegate = self
        self.nativeAdView.isHidden = false
        
        nativeAdView.isUserInteractionEnabled = true
        
        (nativeAdView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeAdView.headlineView as? UILabel)?.font = .figtree(.medium, size: 16)
        (nativeAdView.headlineView as? UILabel)?.numberOfLines = 2
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        (nativeAdView.headlineView as? UILabel)?.textAlignment = .left
        let buttonTitle = "  " + (nativeAd.callToAction ?? "") + "  "
        (nativeAdView.callToActionView as? UIButton)?.setTitle(buttonTitle, for: .normal)
        (nativeAdView.callToActionView as? UIButton)?.titleLabel?.font = .figtree(.medium, size: 16)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil
        
        nativeAdView.callToActionView?.backgroundColor = UIColor.hexColor(hex: appData.adsButtonColor)
        adsLableView.backgroundColor = UIColor.hexColor(hex: appData.adsButtonColor)
        adview.backgroundColor = UIColor.hexColor(hex: appData.adsBackgroundColor)
        
        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
        nativeAdView.nativeAd = nativeAd
        if let body = nativeAd.body {
               lblBody.text = body
               nativeAdView.bodyView = lblBody
               lblBody.isHidden = false
           } else {
               lblBody.isHidden = true
           }
        nativeAd.paidEventHandler = { adValue in
            let value = adValue.value
            let currencyCode = adValue.currencyCode
            GAEventsTracker.logADEvents(value, currencyCode, "native")
        }
        
        self.delegate?.didSuccessAds()
    }
}

extension SmallNativeAdsView: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("didFailToReceiveAdWithError", error)
        self.isVisible = false
        self.delegate?.didFailedAds()
    }
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        // A native ad has loaded, and can be displayed.
        print("nativeAd.mediaContent", nativeAd.mediaContent)
        self.adsData = nativeAd
        self.setupDate()
        self.setTemplateWithSubviews(false)
    }
    
    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        // The adLoader has finished loading ads, and a new request can be sent.
        print("adLoader.adUnitID", adLoader.adUnitID)
    }
}

// MARK: - GADNativeAdDelegate implementation
extension SmallNativeAdsView: NativeAdDelegate {
    
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
    
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
    
    func nativeAdWillPresentScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
    
    func nativeAdWillDismissScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
    
    func nativeAdDidDismissScreen(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
    
    func nativeAdWillLeaveApplication(_ nativeAd: NativeAd) {
        print("\(#function) called")
    }
}
