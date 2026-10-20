//
//  SettingsVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 09/10/26.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

enum AppAppearance: Int, CaseIterable {
    case system, light, dark
    
    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    
    var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    
    private static let storageKey = "selectedAppAppearance"
    
    /// Saved theme choice; defaults to following the system.
    static var current: AppAppearance {
        get { AppAppearance(rawValue: UserDefaults.standard.integer(forKey: storageKey)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: storageKey) }
    }
    
    /// Applies the saved theme to every window of every connected scene.
    static func applySaved(animated: Bool = false) {
        let style = current.style
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in windows {
            if animated {
                UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                    window.overrideUserInterfaceStyle = style
                }
            } else {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

enum SettingsItemID {
    case theme
    case defaultFormat
    case saveToPhotos
    case hdExport
    case restorePurchases
    case rateApp
    case shareApp
    case privacyPolicy
    case terms
}

enum SettingsRowType {
    case theme
    case value
    case toggle
    case pro
    case arrow
}

struct SettingsItem {
    let id: SettingsItemID
    let title: String
    let icon: String
    let type: SettingsRowType
}


class SettingsVC: UIViewController {
    @IBOutlet weak var btnPro: UIButton!
    @IBOutlet weak var vwProHeight: NSLayoutConstraint!
    @IBOutlet weak var vwPro: UIView!
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var lblAppInfo: UILabel!
    @IBOutlet weak var tblAppaeranceHeight: NSLayoutConstraint!
    @IBOutlet weak var tblAppaerance: UITableView!
    @IBOutlet weak var vwAppaerance: UIView!
    
    @IBOutlet weak var tblExportHeight: NSLayoutConstraint!
    @IBOutlet weak var tblExport: UITableView!
    @IBOutlet weak var vwExport: UIView!
    
    @IBOutlet weak var tblSupportHeight: NSLayoutConstraint!
    @IBOutlet weak var tblSupport: UITableView!
    @IBOutlet weak var vwSupport: UIView!
    
    private let arrAppearance: [SettingsItem] = [
        SettingsItem(id: .theme, title: "Theme", icon: "ic_theme", type: .theme)
    ]
 
    private let arrExport: [SettingsItem] = [
        SettingsItem(id: .defaultFormat, title: "Default format", icon: "ic_format", type: .value),
        SettingsItem(id: .saveToPhotos, title: "Save to Photos", icon: "ic_save", type: .toggle),
        SettingsItem(id: .hdExport, title: "HD export", icon: "ic_export", type: .pro)
    ]
    
    private var arrSupport: [SettingsItem] = [
        SettingsItem(id: .restorePurchases, title: "Restore purchases", icon: "ic_restore", type: .arrow),
        SettingsItem(id: .rateApp, title: "Rate Cutout", icon: "ic_rate", type: .arrow),
        SettingsItem(id: .shareApp, title: "Share app", icon: "ic_share", type: .arrow),
        SettingsItem(id: .privacyPolicy, title: "Privacy Policy", icon: "ic_privacy", type: .arrow),
        SettingsItem(id: .terms, title: "Terms and Conditions", icon: "ic_terms", type: .arrow)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUI()
        bannerAd()
        self.setTableView()
    }
    func setUI(){
        setBootonView(self.vwAppaerance)
        setBootonView(self.vwExport)
        setBootonView(self.vwSupport)
        self.lblAppInfo.text = "\(appName ?? "") · Version \(appVersion ?? "1.0")"
        if UserDefaults.isPremiumUser{
            self.vwProHeight.constant = 0
            self.vwPro.isHidden = true
            self.btnPro.isEnabled = false
            self.arrSupport.remove(at: 0)
        }
    }
    func setTableView(){
        self.tblAppaerance.dataSource = self
        self.tblAppaerance.delegate = self
        self.tblAppaerance.register(UINib(nibName: "SettingsTVCCell", bundle: nil), forCellReuseIdentifier: "SettingsTVCCell")
        self.tblAppaeranceHeight.constant = CGFloat(self.arrAppearance.count * 61)
        self.tblAppaerance.reloadData()
        
        self.tblExport.dataSource = self
        self.tblExport.delegate = self
        self.tblExport.register(UINib(nibName: "SettingsTVCCell", bundle: nil), forCellReuseIdentifier: "SettingsTVCCell")
        self.tblExportHeight.constant = CGFloat(self.arrExport.count * 61)
        self.tblExport.reloadData()
        
        self.tblSupport.delegate = self
        self.tblSupport.dataSource = self
        self.tblSupport.register(UINib(nibName: "SettingsTVCCell", bundle: nil), forCellReuseIdentifier: "SettingsTVCCell")
        self.tblSupportHeight.constant = CGFloat(self.arrSupport.count * 61)
        self.tblSupport.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setBootonView(self.vwAppaerance)
            setBootonView(self.vwExport)
            setBootonView(self.vwSupport)
        }
    }
    func setBootonView(_ view: UIView){
        view.layer.borderWidth = 1
        view.layer.borderColor = AppColor.borderColor.cgColor
        view.layer.masksToBounds = true
    }
    @IBAction func btnProUpgrade(_ sender: UIButton) {
        let vc = ProUpgradeVC.fatchInstance()
        self.present(vc, animated: true, completion: nil)
    }
    @IBAction func btnBack(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
}
extension SettingsVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == self.tblAppaerance{
            return self.arrAppearance.count
        }else if tableView == self.tblExport{
            return self.arrExport.count
        }else{
            return self.arrSupport.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTVCCell", for: indexPath) as! SettingsTVCCell
        var data: SettingsItem?
        if tableView == self.tblAppaerance{
            data = self.arrAppearance[indexPath.row]
        }else if tableView == self.tblExport{
            data = self.arrExport[indexPath.row]
        }else{
            data = self.arrSupport[indexPath.row]
        }
        switch data?.type {
        case .arrow?:
            cell.setArrow()
        case .pro?:
            cell.setPro()
        case .toggle?:
            cell.setSwitch(isOn: ImageExportService.saveToPhotosEnabled) { isOn in
                ImageExportService.saveToPhotosEnabled = isOn
            }
        case .value?:
            cell.setText("PNG")
        case .theme?:
            cell.setSegmentedControl()
        default:
            cell.setArrow()
        }
        cell.lblTitle.text = data?.title
        cell.imgIcone.image = UIImage(named: data?.icon ?? "")
        cell.imgIcone.tintColor = AppColor.accent
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var data: SettingsItem?
        if tableView == self.tblAppaerance{
            data = self.arrAppearance[indexPath.row]
        }else if tableView == self.tblExport{
            data = self.arrExport[indexPath.row]
        }else{
            data = self.arrSupport[indexPath.row]
        }
        switch data?.id {
        case .theme:
            break
        case .defaultFormat:
            break
        case .saveToPhotos:
            break
        case .hdExport:
            if PaywallManager.shared.isPremium {
                showToast(message: "Full-quality export is active")
            } else {
                let vc = ProUpgradeVC.fatchInstance()
                self.present(vc, animated: true, completion: nil)
            }
        case .restorePurchases:
            // Shows a loader and the result; premium follows the verified receipt.
            PurchaseConnector.shared.restorePurchase { _ in }
        case .rateApp:
            RatingManager.requestReviewManually()
            print("Rate App")
        case .shareApp:
            shareApplication()
            print("Share App")
        case .privacyPolicy:
            openConfiguredURL(appData.privacyPolicy, missingMessage: "Add your privacy policy URL in SettingViewController.")
            print("Privacy Policy")
        case .terms:
            openConfiguredURL(appData.terms, missingMessage: "Add your terms URL in SettingViewController.")
            print("Terms")
        case nil:
            break
        }
    }
    private func openConfiguredURL(_ urlString: String, missingMessage: String) {
        guard !urlString.isEmpty,
              let url = URL(string: urlString) else {
            showAlertWithOneOption(msg: missingMessage)
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        } else {
            showAlertWithOneOption(msg: "Unable to open the link.")
        }
    }
    private func shareApplication() {
        let shareMessage: String

        if let appStoreURL = URL(string: "https://apps.apple.com/app/id\(appData.appId ?? "000")") {
            shareMessage = """
            ✨ Remove BG – Background Remover

            Remove image backgrounds in seconds! 🖼️✂️ Create clean, professional photos with just one tap.

            🔗 Try it now:  \(appStoreURL.absoluteString)

            Download now and make your photos stand out! 🚀
            """
        } else {
            shareMessage = """
            ✨ Remove BG – Background Remover

            Remove image backgrounds in seconds! 🖼️✂️ Create clean, professional photos with just one tap.

            🔗 Try it now: https://apps.apple.com/app/id\(appData.appId ?? "000")

            Download now and make your photos stand out! 🚀
            """
        }

        let activityVC = UIActivityViewController(
            activityItems: [shareMessage],
            applicationActivities: nil
        )

        // iPad Support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        present(activityVC, animated: true)
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
        let adsType = appData.settingsVC.adType ?? ""
        let adsSize = appData.settingsVC.adSize ?? 50
        
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
}
extension SettingsVC: BannerViewDelegate {
    
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
