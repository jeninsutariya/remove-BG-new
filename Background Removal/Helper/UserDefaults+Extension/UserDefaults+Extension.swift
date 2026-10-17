//
//  UserDefaults+Extension.swift
//  AI Story
//
//  Created by Codeash Mac on 11/08/25.
//

import Foundation
import SwiftUI
extension UserDefaults{
    
    static func clearAllUserDefaults() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
            UserDefaults.standard.synchronize()
        }
    }
    static var isUserFistTime: Int{
        get {
            return UserDefaults.standard.integer(forKey: "isUserFistTime")
        }set {
            UserDefaults.standard.set(newValue, forKey: "isUserFistTime")
        }
    }
    public static var MainClickCount: Int {
        get {
            return UserDefaults.standard.value(forKey: "fontOrderOpenCount") as? Int ?? 1
        } set {
            UserDefaults.standard.set(newValue, forKey: "fontOrderOpenCount")
        }
    }


    static var selectedLanguageName: String{
        get {
            return UserDefaults.standard.string(forKey: "selectedLanguageName") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "selectedLanguageName")
        }
    }
    static var fcmtokan: String{
        get {
            return UserDefaults.standard.string(forKey: "fcmtokan") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "fcmtokan")
        }
    }
    static var isAcceptAgreement: Bool{
        get {
            return UserDefaults.standard.bool(forKey: "isAcceptAgreement")
        }set {
            UserDefaults.standard.set(newValue, forKey: "isAcceptAgreement")
        }
    }
    static var didFinishFullTutorial: Bool{
        get {
            return UserDefaults.standard.bool(forKey: "didFinishFullTutorial")
        }set {
            UserDefaults.standard.set(newValue, forKey: "didFinishFullTutorial")
        }
    }
    static var isPremiumUser: Bool{
        get {
            return UserDefaults.standard.bool(forKey: "isPremiumUser")
        }set {
            UserDefaults.standard.set(newValue, forKey: "isPremiumUser")
        }
    }
    static var userID: Int{
        get {
            return UserDefaults.standard.integer(forKey: "userID")
        }set {
            UserDefaults.standard.set(newValue, forKey: "userID")
        }
    }
    static var userEmail: String{
        get {
            return UserDefaults.standard.string(forKey: "userEmail") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "userEmail")
        }
    }
    static var userRole: String{
        get {
            return UserDefaults.standard.string(forKey: "userRole") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "userRole")
        }
    }
    static var profilePicture: String{
        get {
            return UserDefaults.standard.string(forKey: "profilePicture") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "profilePicture")
        }
    }
    static var userLanguage: String{
        get {
            return UserDefaults.standard.string(forKey: "userLanguage") ?? "english"
        }set {
            UserDefaults.standard.set(newValue, forKey: "userLanguage")
        }
    }
    static var userName: String{
        get {
            return UserDefaults.standard.string(forKey: "userName") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "userName")
        }
    }
    static var token: String{
        get {
            return UserDefaults.standard.string(forKey: "token") ?? ""
        }set {
            UserDefaults.standard.set(newValue, forKey: "token")
        }
    }
    
}
