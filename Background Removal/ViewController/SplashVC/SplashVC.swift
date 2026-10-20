//
//  SplashVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 05/10/26.
//

import UIKit
import FBSDKCoreKit
import GoogleMobileAds

class SplashVC: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        progressView.setProgress(0, animated: false)
        RemoteConfigManager.shared.getRemoteConfig { [weak self] isSuccess in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                
                guard isSuccess else {
                    print("❌ RemoteConfig failed")
                    self.startMainScreen()
                    return
                }
                
                guard let appData = appData else {
                    print("❌ appData nil")
                    self.startMainScreen()
                    return
                }
                
                // Facebook SDK safe init
                Settings.shared.appID = appData.fbAppId
                Settings.shared.clientToken = appData.fbClientToken
                ApplicationDelegate.shared.initializeSDK()
                
                // Correct AppDelegate call
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.requestTrackingPermission()
                }
                UIView.animate(withDuration: 2.0) {
                    self.progressView.setProgress(0.5, animated: true)
                }
               
                    if appData.isShowAppOpenAds == 0 {
                        self.startMainScreen()
                    } else {
                        self.setAds()
                    }
        
            }
        }
    }
    func startMainScreen() {
        progressView.setProgress(0.5, animated: false)
     
        UIView.animate(withDuration: 2.0) {
            self.progressView.setProgress(1, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if UserDefaults.isUserFistTime == 1{
                    let vc = MainTabVC.fatchInstance()
                    self.navigationController?.pushViewController(vc, animated: true)
                }else{
                    let vc = OnboardingFastVC.fatchInstance()
                    self.navigationController?.pushViewController(vc, animated: true)
                }
               
            }
            
        }
    }
    func setAds() {
        AppOpenAdManager.shared.appOpenAdManagerDelegate = self
        MobileAds.shared.start()
        Task {
            await AppOpenAdManager.shared.loadAd()
            AppOpenAdManager.shared.showAdIfAvailable()
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
extension SplashVC:  AppOpenAdManagerDelegate {
    func appOpenAdManagerAdDidComplete(_ appOpenAdManager: AppOpenAdManager) {
        startMainScreen()
    }
}
