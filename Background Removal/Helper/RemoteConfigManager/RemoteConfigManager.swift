//
//  RemoteConfigManager.swift
//  Emi Loan Calculator
//
//  Created by Gopal Ghori on 15/12/25.
//

import Foundation
import Foundation
import FirebaseRemoteConfig
import SwiftyJSON
import FBSDKCoreKit
//let shareURL = URL(string: "https://apps.apple.com/app/id\(appID)")!
var appData: AppModel!

class RemoteConfigManager {
    static let shared = RemoteConfigManager()
    private let remoteConfig = RemoteConfig.remoteConfig()
    
    private init() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0 // Fetch interval in seconds
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    }
    func getBoolValue(forKey key: String) -> Bool {
        return RemoteConfig.remoteConfig()[key].boolValue
    }
    func fetchRemoteConfig(completion: @escaping (Bool) -> Void) {
        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                print("Error fetching remote config: \(error)")
                completion(false)
                return
            }
            completion(status == .successFetchedFromRemote)
        }
    }
    
    func getStringValue(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue
    }
    func getAdsColor() -> AppModel? {
        let jsonString = remoteConfig.configValue(forKey: "appData").stringValue
        print("🔥 Raw adsColor from Firebase =", jsonString)
        
        if jsonString.isEmpty {
            print("⚠️ adsColor key missing or empty in Remote Config")
            return nil
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            print("⚠️ adsColor JSON is not valid UTF-8")
            return nil
        }
        
        do {
            let json = try JSON(data: data)
            let colorObj = AppModel(fromJson: json)
            print("🎨 adsColor decoded:", colorObj.toDictionary())
            return colorObj
        } catch {
            print("❌ Failed to parse adsColor JSON:", error)
            return nil
        }
    }
    
    func getRemoteConfig(completion: @escaping (Bool) -> Void) {
        RemoteConfigManager.shared.fetchRemoteConfig { success in
            if success {
                appData = RemoteConfigManager.shared.getAdsColor()
                print("colorsJSON = \(String(describing: appData))")
                
                Settings.shared.appID = appData.fbAppId
                Settings.shared.clientToken =  appData.fbClientToken
                ApplicationDelegate.shared.initializeSDK()
                
                completion(true)
            } else {
                print("Failed to fetch remote config")
                appData.bannerAdsId = "ca-app-pub-3940256099942544/2435281174"
                appData.interstitialAdsId = "ca-app-pub-3940256099942544/4411468910"
                appData.nativeAdsId = "ca-app-pub-3940256099942544/4411468910"
                appData.appOpenAdsId = "ca-app-pub-3940256099942544/5575463023"
                completion(false)
            }
        }
    }
    
}
//
//    appModel.swift
//    Model file generated using JSONExport: https://github.com/Ahmed-Ali/JSONExport

class AppModel : NSObject, NSCoding{
    
    var adsBackgroundColor : String!
    var adsButtonColor : String!
    var appId : String!
    var appOpenAdsId : String!
    var bannerAdsId : String!
    var exportVC : AdsType!
    var fbAppId : String!
    var fbClientToken : String!
    var homeVC : AdsType!
    var interstitialAdsId : String!
    var interstitialCount : Int!
    var isAdsShow : Int!
    var isShowAppOpenAds : Int!
    var nativeAdsId : String!
    var onboardingFastVC : AdsType!
    var onboardingForthVC : AdsType!
    var onboardingSecondVC : AdsType!
    var onboardingThardVC : AdsType!
    var openPremiumCount : Int!
    var privacyPolicy : String!
    var projectsVC : AdsType!
    var refineEdgesVC : AdsType!
    var removingBackgroundEditorVC : AdsType!
    var removingBackgroundVC : AdsType!
    var searchVC : AdsType!
    var settingsVC : AdsType!
    var terms : String!
    var textBehindSubjectVC : AdsType!
    
    
    /**
     * Instantiate the instance using the passed json values to set the properties values
     */
    init(fromJson json: JSON!){
        if json.isEmpty{
            return
        }
        adsBackgroundColor = json["adsBackgroundColor"].stringValue
        adsButtonColor = json["adsButtonColor"].stringValue
        appId = json["appId"].stringValue
        appOpenAdsId = json["appOpenAdsId"].stringValue
        bannerAdsId = json["bannerAdsId"].stringValue
        let exportVCJson = json["exportVC"]
        if !exportVCJson.isEmpty{
            exportVC = AdsType(fromJson: exportVCJson)
        }
        fbAppId = json["fbAppId"].stringValue
        fbClientToken = json["fbClientToken"].stringValue
        let homeVCJson = json["homeVC"]
        if !homeVCJson.isEmpty{
            homeVC = AdsType(fromJson: homeVCJson)
        }
        interstitialAdsId = json["interstitialAdsId"].stringValue
        interstitialCount = json["interstitialCount"].intValue
        isAdsShow = json["isAdsShow"].intValue
        isShowAppOpenAds = json["isShowAppOpenAds"].intValue
        nativeAdsId = json["nativeAdsId"].stringValue
        let onboardingFastVCJson = json["onboardingFastVC"]
        if !onboardingFastVCJson.isEmpty{
            onboardingFastVC = AdsType(fromJson: onboardingFastVCJson)
        }
        let onboardingForthVCJson = json["onboardingForthVC"]
        if !onboardingForthVCJson.isEmpty{
            onboardingForthVC = AdsType(fromJson: onboardingForthVCJson)
        }
        let onboardingSecondVCJson = json["onboardingSecondVC"]
        if !onboardingSecondVCJson.isEmpty{
            onboardingSecondVC = AdsType(fromJson: onboardingSecondVCJson)
        }
        let onboardingThardVCJson = json["onboardingThardVC"]
        if !onboardingThardVCJson.isEmpty{
            onboardingThardVC = AdsType(fromJson: onboardingThardVCJson)
        }
        openPremiumCount = json["openPremiumCount"].intValue
        privacyPolicy = json["privacyPolicy"].stringValue
        let projectsVCJson = json["projectsVC"]
        if !projectsVCJson.isEmpty{
            projectsVC = AdsType(fromJson: projectsVCJson)
        }
        let refineEdgesVCJson = json["refineEdgesVC"]
        if !refineEdgesVCJson.isEmpty{
            refineEdgesVC = AdsType(fromJson: refineEdgesVCJson)
        }
        let removingBackgroundEditorVCJson = json["removingBackgroundEditorVC"]
        if !removingBackgroundEditorVCJson.isEmpty{
            removingBackgroundEditorVC = AdsType(fromJson: removingBackgroundEditorVCJson)
        }
        let removingBackgroundVCJson = json["removingBackgroundVC"]
        if !removingBackgroundVCJson.isEmpty{
            removingBackgroundVC = AdsType(fromJson: removingBackgroundVCJson)
        }
        let searchVCJson = json["searchVC"]
        if !searchVCJson.isEmpty{
            searchVC = AdsType(fromJson: searchVCJson)
        }
        let settingsVCJson = json["settingsVC"]
        if !settingsVCJson.isEmpty{
            settingsVC = AdsType(fromJson: settingsVCJson)
        }
        terms = json["terms"].stringValue
        let textBehindSubjectVCJson = json["textBehindSubjectVC"]
        if !textBehindSubjectVCJson.isEmpty{
            textBehindSubjectVC = AdsType(fromJson: textBehindSubjectVCJson)
        }
    }
    
    /**
     * Returns all the available property values in the form of [String:Any] object where the key is the approperiate json key and the value is the value of the corresponding property
     */
    func toDictionary() -> [String:Any]
    {
        var dictionary = [String:Any]()
        if adsBackgroundColor != nil{
            dictionary["adsBackgroundColor"] = adsBackgroundColor
        }
        if adsButtonColor != nil{
            dictionary["adsButtonColor"] = adsButtonColor
        }
        if appId != nil{
            dictionary["appId"] = appId
        }
        if appOpenAdsId != nil{
            dictionary["appOpenAdsId"] = appOpenAdsId
        }
        if bannerAdsId != nil{
            dictionary["bannerAdsId"] = bannerAdsId
        }
        if exportVC != nil{
            dictionary["exportVC"] = exportVC.toDictionary()
        }
        if fbAppId != nil{
            dictionary["fbAppId"] = fbAppId
        }
        if fbClientToken != nil{
            dictionary["fbClientToken"] = fbClientToken
        }
        if homeVC != nil{
            dictionary["homeVC"] = homeVC.toDictionary()
        }
        if interstitialAdsId != nil{
            dictionary["interstitialAdsId"] = interstitialAdsId
        }
        if interstitialCount != nil{
            dictionary["interstitialCount"] = interstitialCount
        }
        if isAdsShow != nil{
            dictionary["isAdsShow"] = isAdsShow
        }
        if isShowAppOpenAds != nil{
            dictionary["isShowAppOpenAds"] = isShowAppOpenAds
        }
        if nativeAdsId != nil{
            dictionary["nativeAdsId"] = nativeAdsId
        }
        if onboardingFastVC != nil{
            dictionary["onboardingFastVC"] = onboardingFastVC.toDictionary()
        }
        if onboardingForthVC != nil{
            dictionary["onboardingForthVC"] = onboardingForthVC.toDictionary()
        }
        if onboardingSecondVC != nil{
            dictionary["onboardingSecondVC"] = onboardingSecondVC.toDictionary()
        }
        if onboardingThardVC != nil{
            dictionary["onboardingThardVC"] = onboardingThardVC.toDictionary()
        }
        if openPremiumCount != nil{
            dictionary["openPremiumCount"] = openPremiumCount
        }
        if privacyPolicy != nil{
            dictionary["privacyPolicy"] = privacyPolicy
        }
        if projectsVC != nil{
            dictionary["projectsVC"] = projectsVC.toDictionary()
        }
        if refineEdgesVC != nil{
            dictionary["refineEdgesVC"] = refineEdgesVC.toDictionary()
        }
        if removingBackgroundEditorVC != nil{
            dictionary["removingBackgroundEditorVC"] = removingBackgroundEditorVC.toDictionary()
        }
        if removingBackgroundVC != nil{
            dictionary["removingBackgroundVC"] = removingBackgroundVC.toDictionary()
        }
        if searchVC != nil{
            dictionary["searchVC"] = searchVC.toDictionary()
        }
        if settingsVC != nil{
            dictionary["settingsVC"] = settingsVC.toDictionary()
        }
        if terms != nil{
            dictionary["terms"] = terms
        }
        if textBehindSubjectVC != nil{
            dictionary["textBehindSubjectVC"] = textBehindSubjectVC.toDictionary()
        }
        return dictionary
    }
    
    /**
     * NSCoding required initializer.
     * Fills the data from the passed decoder
     */
    @objc required init(coder aDecoder: NSCoder)
    {
        adsBackgroundColor = aDecoder.decodeObject(forKey: "adsBackgroundColor") as? String
        adsButtonColor = aDecoder.decodeObject(forKey: "adsButtonColor") as? String
        appId = aDecoder.decodeObject(forKey: "appId") as? String
        appOpenAdsId = aDecoder.decodeObject(forKey: "appOpenAdsId") as? String
        bannerAdsId = aDecoder.decodeObject(forKey: "bannerAdsId") as? String
        exportVC = aDecoder.decodeObject(forKey: "exportVC") as? AdsType
        fbAppId = aDecoder.decodeObject(forKey: "fbAppId") as? String
        fbClientToken = aDecoder.decodeObject(forKey: "fbClientToken") as? String
        homeVC = aDecoder.decodeObject(forKey: "homeVC") as? AdsType
        interstitialAdsId = aDecoder.decodeObject(forKey: "interstitialAdsId") as? String
        interstitialCount = aDecoder.decodeObject(forKey: "interstitialCount") as? Int
        isAdsShow = aDecoder.decodeObject(forKey: "isAdsShow") as? Int
        isShowAppOpenAds = aDecoder.decodeObject(forKey: "isShowAppOpenAds") as? Int
        nativeAdsId = aDecoder.decodeObject(forKey: "nativeAdsId") as? String
        onboardingFastVC = aDecoder.decodeObject(forKey: "onboardingFastVC") as? AdsType
        onboardingForthVC = aDecoder.decodeObject(forKey: "onboardingForthVC") as? AdsType
        onboardingSecondVC = aDecoder.decodeObject(forKey: "onboardingSecondVC") as? AdsType
        onboardingThardVC = aDecoder.decodeObject(forKey: "onboardingThardVC") as? AdsType
        openPremiumCount = aDecoder.decodeObject(forKey: "openPremiumCount") as? Int
        privacyPolicy = aDecoder.decodeObject(forKey: "privacyPolicy") as? String
        projectsVC = aDecoder.decodeObject(forKey: "projectsVC") as? AdsType
        refineEdgesVC = aDecoder.decodeObject(forKey: "refineEdgesVC") as? AdsType
        removingBackgroundEditorVC = aDecoder.decodeObject(forKey: "removingBackgroundEditorVC") as? AdsType
        removingBackgroundVC = aDecoder.decodeObject(forKey: "removingBackgroundVC") as? AdsType
        searchVC = aDecoder.decodeObject(forKey: "searchVC") as? AdsType
        settingsVC = aDecoder.decodeObject(forKey: "settingsVC") as? AdsType
        terms = aDecoder.decodeObject(forKey: "terms") as? String
        textBehindSubjectVC = aDecoder.decodeObject(forKey: "textBehindSubjectVC") as? AdsType
        
    }
    
    /**
     * NSCoding required method.
     * Encodes mode properties into the decoder
     */
    func encode(with aCoder: NSCoder)
    {
        if adsBackgroundColor != nil{
            aCoder.encode(adsBackgroundColor, forKey: "adsBackgroundColor")
        }
        if adsButtonColor != nil{
            aCoder.encode(adsButtonColor, forKey: "adsButtonColor")
        }
        if appId != nil{
            aCoder.encode(appId, forKey: "appId")
        }
        if appOpenAdsId != nil{
            aCoder.encode(appOpenAdsId, forKey: "appOpenAdsId")
        }
        if bannerAdsId != nil{
            aCoder.encode(bannerAdsId, forKey: "bannerAdsId")
        }
        if exportVC != nil{
            aCoder.encode(exportVC, forKey: "exportVC")
        }
        if fbAppId != nil{
            aCoder.encode(fbAppId, forKey: "fbAppId")
        }
        if fbClientToken != nil{
            aCoder.encode(fbClientToken, forKey: "fbClientToken")
        }
        if homeVC != nil{
            aCoder.encode(homeVC, forKey: "homeVC")
        }
        if interstitialAdsId != nil{
            aCoder.encode(interstitialAdsId, forKey: "interstitialAdsId")
        }
        if interstitialCount != nil{
            aCoder.encode(interstitialCount, forKey: "interstitialCount")
        }
        if isAdsShow != nil{
            aCoder.encode(isAdsShow, forKey: "isAdsShow")
        }
        if isShowAppOpenAds != nil{
            aCoder.encode(isShowAppOpenAds, forKey: "isShowAppOpenAds")
        }
        if nativeAdsId != nil{
            aCoder.encode(nativeAdsId, forKey: "nativeAdsId")
        }
        if onboardingFastVC != nil{
            aCoder.encode(onboardingFastVC, forKey: "onboardingFastVC")
        }
        if onboardingForthVC != nil{
            aCoder.encode(onboardingForthVC, forKey: "onboardingForthVC")
        }
        if onboardingSecondVC != nil{
            aCoder.encode(onboardingSecondVC, forKey: "onboardingSecondVC")
        }
        if onboardingThardVC != nil{
            aCoder.encode(onboardingThardVC, forKey: "onboardingThardVC")
        }
        if openPremiumCount != nil{
            aCoder.encode(openPremiumCount, forKey: "openPremiumCount")
        }
        if privacyPolicy != nil{
            aCoder.encode(privacyPolicy, forKey: "privacyPolicy")
        }
        if projectsVC != nil{
            aCoder.encode(projectsVC, forKey: "projectsVC")
        }
        if refineEdgesVC != nil{
            aCoder.encode(refineEdgesVC, forKey: "refineEdgesVC")
        }
        if removingBackgroundEditorVC != nil{
            aCoder.encode(removingBackgroundEditorVC, forKey: "removingBackgroundEditorVC")
        }
        if removingBackgroundVC != nil{
            aCoder.encode(removingBackgroundVC, forKey: "removingBackgroundVC")
        }
        if searchVC != nil{
            aCoder.encode(searchVC, forKey: "searchVC")
        }
        if settingsVC != nil{
            aCoder.encode(settingsVC, forKey: "settingsVC")
        }
        if terms != nil{
            aCoder.encode(terms, forKey: "terms")
        }
        if textBehindSubjectVC != nil{
            aCoder.encode(textBehindSubjectVC, forKey: "textBehindSubjectVC")
        }
        
    }
    
}

class AdsType : NSObject, NSCoding{
    
    var adSize : Int!
    var adType : String!
    var isCollapsible : Int!
    
    
    /**
     * Instantiate the instance using the passed json values to set the properties values
     */
    init(fromJson json: JSON!){
        if json.isEmpty{
            return
        }
        adSize = json["adSize"].intValue
        adType = json["adType"].stringValue
        isCollapsible = json["isCollapsible"].intValue
    }
    
    /**
     * Returns all the available property values in the form of [String:Any] object where the key is the approperiate json key and the value is the value of the corresponding property
     */
    func toDictionary() -> [String:Any]
    {
        var dictionary = [String:Any]()
        if adSize != nil{
            dictionary["adSize"] = adSize
        }
        if adType != nil{
            dictionary["adType"] = adType
        }
        if isCollapsible != nil{
            dictionary["isCollapsible"] = isCollapsible
        }
        return dictionary
    }
    
    /**
     * NSCoding required initializer.
     * Fills the data from the passed decoder
     */
    @objc required init(coder aDecoder: NSCoder)
    {
        adSize = aDecoder.decodeObject(forKey: "adSize") as? Int
        adType = aDecoder.decodeObject(forKey: "adType") as? String
        isCollapsible = aDecoder.decodeObject(forKey: "isCollapsible") as? Int
        
    }
    
    /**
     * NSCoding required method.
     * Encodes mode properties into the decoder
     */
    func encode(with aCoder: NSCoder)
    {
        if adSize != nil{
            aCoder.encode(adSize, forKey: "adSize")
        }
        if adType != nil{
            aCoder.encode(adType, forKey: "adType")
        }
        if isCollapsible != nil{
            aCoder.encode(isCollapsible, forKey: "isCollapsible")
        }
        
    }
    
}
