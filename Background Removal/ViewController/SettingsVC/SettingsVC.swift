//
//  SettingsVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 09/10/26.
//

import UIKit
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
    
    private let arrSupport: [SettingsItem] = [
        SettingsItem(id: .restorePurchases, title: "Restore purchases", icon: "ic_restore", type: .arrow),
        SettingsItem(id: .rateApp, title: "Rate Cutout", icon: "ic_rate", type: .arrow),
        SettingsItem(id: .shareApp, title: "Share app", icon: "ic_share", type: .arrow),
        SettingsItem(id: .privacyPolicy, title: "Privacy Policy", icon: "ic_privacy", type: .arrow),
        SettingsItem(id: .terms, title: "Terms and Conditions", icon: "ic_terms", type: .arrow)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setUI()
        self.setTableView()
    }
    func setUI(){
        setBootonView(self.vwAppaerance)
        setBootonView(self.vwExport)
        setBootonView(self.vwSupport)
        self.lblAppInfo.text = "Cutout · Version 1.0"
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
            cell.setSwitch()
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
//            if UserDefaults.isPremiumUser {
//                showToast(message: "Full-quality export is active")
//            } else {
//                let vc = ProUpgradeVC.fatchInstance()
//                self.present(vc, animated: true, completion: nil)
//            }
            break
        case .restorePurchases:
            break
        case .rateApp:
            print("Rate App")
        case .shareApp:
            print("Share App")
        case .privacyPolicy:
            print("Privacy Policy")
        case .terms:
            print("Terms")
        case nil:
            break
        }
    }
}
