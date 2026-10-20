//
//  RatingManager.swift
//  Live Football Score
//
//  Created by Jenin Sutariya on 17/01/26.
//

import Foundation
import UIKit
import StoreKit

class RatingManager {
    private static let clickCountKey = "user_button_clicks"
    
    
    private static let openCountKey = "app_open_count"
    private static let lastVersionPromptedKey = "last_version_prompted"
    
    static func appDidOpen() {
        
        let defaults = UserDefaults.standard
        
        var count = defaults.integer(forKey: openCountKey)
        count += 1
        defaults.set(count, forKey: openCountKey)
        
        print("App opened \(count) times")
        
        // 3 times not show, 1 time show
        if count % 4 == 0 {
            requestReview()
        }
    }
    
    static func requestReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    static func requestReviewManually() {
        // TODO: replace xxxxxxxxxx in the following URL with your Apps Apple ID
        let url = "https://apps.apple.com/app/id\(/*appData.appID ?? ""*/0)?action=write-review"
        guard let writeReviewURL = URL(string: url)
        else { fatalError("Expected a valid URL") }
        UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
    }
}
