//
//  OnboardingForthVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 05/10/26.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

class OnboardingForthVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        bannerAd()
        // Do any additional setup after loading the view.
    }
    @IBAction func btnContinue(_ sender: UIButton) {
        adsManager.showInterstitial {
            UserDefaults.isUserFistTime = 1
            let vc = MainTabVC.fatchInstance()
            let nav = UINavigationController(rootViewController: vc)
            nav.isNavigationBarHidden = true
            
            if let window = UIApplication.shared.currentWindow {
                let transition = CATransition()
                transition.duration = 0.35
                transition.type = .push
                transition.subtype = .fromRight
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
                window.layer.add(transition, forKey: kCATransition)
                window.rootViewController = nav
                window.makeKeyAndVisible()
            }
        }
    }
    func bannerAd(){
        if UserDefaults.isPremiumUser {
            bannerView.isHidden = true
            lodingAds.isHidden = true
            self.adsBase.isHidden = true
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: 0).isActive = true
            
            self.view.setTemplateWithSubviews(false)
            return
        }
        let adsType = appData.onboardingForthVC.adType ?? ""
        let adsSize = appData.onboardingForthVC.adSize ?? 50
        
        let adSize = getAdSize(type: adsType, size: adsSize)
        if adsType == "NETIVE" || adsType == "BIG_NETIVE"{
            self.veBanner.isHidden = true
            self.adsBase.isHidden = false
            self.lodingAds.isHidden = true
            self.adsBase.setupAdsView(data: adsType == "NETIVE" ? .smallNative : .bigNative)
        }else if adsType == "BANNER" || adsType == "LARGE_BANNER" || adsType == "MEDIUM_RECTANGLE"{
            self.veBanner.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
        }else{
            self.bannerView.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        }
        if adsType != "NETIVE" || adsType != "BIG_NETIVE"{
            self.view.layoutIfNeeded()
            self.bannerView.setTemplateWithSubviews(true, viewBackgroundColor: .white)
            self.lodingAds.isHidden = false
            bannerView.adUnitID = appData.bannerAdsId
            bannerView.rootViewController = self
            bannerView.delegate = self
            bannerView.adSize = adSize
            
            let request = Request()
            bannerView.load(request)
        }
    }
    
    func getAdSize(type: String, size: Int) -> AdSize {
        switch type {
        case "BANNER":
            return AdSizeBanner
        case "LARGE_BANNER":
            return AdSizeLargeBanner
        case "MEDIUM_RECTANGLE":
            return AdSizeMediumRectangle
        default:
            let screenWidth = UIScreen.main.bounds.width
            return adSizeFor(cgSize: CGSize(width: screenWidth, height: CGFloat(size)))
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
extension OnboardingForthVC: BannerViewDelegate {
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Ad loaded successfully")
        self.lodingAds.isHidden = true
        self.view.setTemplateWithSubviews(false)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Ad failed to load: \(error.localizedDescription)")
        // Stop the shimmer even on failure so the user doesn't see a loading state forever
    }
}
