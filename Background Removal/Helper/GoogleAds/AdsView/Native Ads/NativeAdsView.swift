//
//  NativeAdsView.swift
//  vpnproxy
//
//  Created by Vasu Savaliya on 25/05/24.
//

import UIKit
import GoogleMobileAds
//import Lottie
import UIView_Shimmer

class NativeAdsView: BaseCustomView, ShimmeringViewProtocol {
    
    @IBOutlet weak var adLablview: UIView!
    @IBOutlet weak var adview: UIView!
    @IBOutlet weak var nativeAdView: NativeAdView!
    
    weak var delegate: bannerAdsDelegate?
    var isVisible = true
    
    var adLoader: AdLoader!
    var adsData: NativeAd?
    var shimmeringAnimatedItems: [UIView] {
        return [
            nativeAdView.iconView,
            nativeAdView.headlineView,
            nativeAdView.callToActionView,
            nativeAdView.bodyView,
            nativeAdView.mediaView,
            adLablview
        ].compactMap { $0 }
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func destroyBannerAd() {
        isVisible = false
        adLoader = nil
        
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
        //        self.nativeAdView.isHidden = true
        adLoader = AdLoader(
            adUnitID: nativeAdsId, rootViewController: topMostViewController(),
            adTypes: [.native], options: nil)
        adLoader.delegate = self
        adLoader.load(Request())
    }
    
    func imageOfStars(from starRating: NSDecimalNumber?) -> UIImage? {
        guard let rating = starRating?.doubleValue else { return nil }
        switch rating {
        case 5.0:
            return UIImage(named: "stars_5")
        case 4.5..<5.0:
            return UIImage(named: "stars_4_5")
        case 4.0..<4.5:
            return UIImage(named: "stars_4")
        case 3.5..<4.0:
            return UIImage(named: "stars_3_5")
        default:
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
        (nativeAdView.headlineView as? UILabel)?.numberOfLines = 1
        nativeAdView.mediaView?.mediaContent = nativeAd.mediaContent
        
        (nativeAdView.bodyView as? UILabel)?.text = nativeAd.body
                (nativeAdView.bodyView as? UILabel)?.font = .figtree(.medium, size: 16)
        (nativeAdView.bodyView as? UILabel)?.numberOfLines = 2
        nativeAdView.bodyView?.isHidden = nativeAd.body == nil
        
        nativeAdView.callToActionView?.backgroundColor =  UIColor.hexColor(hex: appData.adsButtonColor)
        adview.backgroundColor =  UIColor.hexColor(hex: appData.adsBackgroundColor)
        adLablview.backgroundColor =  UIColor.hexColor(hex: appData.adsButtonColor)
        adLablview.layer.cornerRadius = 10
        adLablview.layer.maskedCorners =  .layerMaxXMaxYCorner
       
        let buttonTitle = "  " + (nativeAd.callToAction ?? "") + "  "
        (nativeAdView.callToActionView as? UIButton)?.setTitle(buttonTitle, for: .normal)
                (nativeAdView.callToActionView as? UIButton)?.titleLabel?.font = .figtree(.medium, size: 16)
        nativeAdView.callToActionView?.isHidden = nativeAd.callToAction == nil
        
        (nativeAdView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        nativeAdView.iconView?.isHidden = nativeAd.icon == nil
        
        nativeAdView.callToActionView?.isUserInteractionEnabled = false
        nativeAdView.nativeAd = nativeAd
        
        nativeAd.paidEventHandler = { adValue in
            let value = adValue.value
            let currencyCode = adValue.currencyCode
            GAEventsTracker.logADEvents(value, currencyCode, "native")
        }
        
        //        self.adsImageView.image = adsData.icon?.image
        //        self.adsTitleLabel.text = adsData.headline
        //        self.adsDescriptionLabel.text = adsData.body
        //
        //        self.btnCallToAction.setTitle(adsData.callToAction ?? "", for: .normal)
        //        self.btnCallToAction.isHidden = adsData.callToAction == nil
        self.delegate?.didSuccessAds()
    }
    
}

extension NativeAdsView: NativeAdLoaderDelegate {
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
extension NativeAdsView: NativeAdDelegate {
    
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
