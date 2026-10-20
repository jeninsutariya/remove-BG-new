//
//  Copyright (C) 2023 Google LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import GoogleMobileAds
import UserMessagingPlatform
import FirebaseAnalytics
import UIView_Shimmer
/// The Google Mobile Ads SDK provides the User Messaging Platform (Google's
/// IAB Certified consent management platform) as one solution to capture
/// consent for users in GDPR impacted countries. This is an example and
/// you can choose another consent management platform to capture consent.

@MainActor
class GoogleMobileAdsConsentManager: NSObject {
  static let shared = GoogleMobileAdsConsentManager()

  var canRequestAds: Bool {
      return ConsentInformation.shared.canRequestAds
  }

  var isPrivacyOptionsRequired: Bool {
      return ConsentInformation.shared.privacyOptionsRequirementStatus == .required
  }

  /// Helper method to call the UMP SDK methods to request consent information and load/present a
  /// consent form if necessary.
  func gatherConsent(
    from viewController: UIViewController? = nil,
    consentGatheringComplete: @escaping (Error?) -> Void
  ) {
      let parameters = RequestParameters()

    // For testing purposes, you can use UMPDebugGeography to simulate a location.
      let debugSettings = DebugSettings()
    // debugSettings.geography = UMPDebugGeography.EEA
    parameters.debugSettings = debugSettings

    // Requesting an update to consent information should be called on every app launch.
      ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) {
      requestConsentError in
      guard requestConsentError == nil else {
        return consentGatheringComplete(requestConsentError)
      }

      Task { @MainActor in
        do {
            try await ConsentForm.loadAndPresentIfRequired(from: viewController)
          // Consent has been gathered.
          consentGatheringComplete(nil)
        } catch {
          consentGatheringComplete(error)
        }
      }
    }
  }

  /// Helper method to call the UMP SDK method to present the privacy options form.
  @MainActor func presentPrivacyOptionsForm(from viewController: UIViewController? = nil)
    async throws
  {
      try await ConsentForm.presentPrivacyOptionsForm(from: viewController)
  }
}

class GAEventsTracker {

    private static let maxEventNameLength = 40
    private static let maxParameterNameLength = 40

    static func logEvents(_ eventName: String, _ param: [String: Any] = [:]) {
        let sanitizedEventName = sanitizeEventName(eventName)
        let sanitizedParameters = sanitizeParameters(param)

        print(">>>> Events Log: \(sanitizedEventName)")
        print(">>>> Events Log Param: \(sanitizedParameters)")
        Analytics.logEvent(sanitizedEventName, parameters: sanitizedParameters)
    }

    static func logScreenView(_ screenName: String, screenClass: String? = nil) {
        let sanitizedScreenName = sanitizeEventName(screenName)
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: sanitizedScreenName
        ]

        if let screenClass, !screenClass.isEmpty {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }

        print(">>>> Screen View: \(sanitizedScreenName)")
        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }

    static func logADEvents(_ value: NSDecimalNumber, _ currencyCode: String, _ format:String) {

        print(">>>> Events Log value: \(value)")
        print(">>>> Events Log currencyCode: \(currencyCode)")
        print(">>>> Events Log format: \(format)")

        Analytics.logEvent(
            AnalyticsEventAdImpression,
            parameters: [
                AnalyticsParameterAdPlatform: "AdMob",
                AnalyticsParameterCurrency: currencyCode,
                AnalyticsParameterValue: value,
                AnalyticsParameterAdFormat: format
            ])

    }

    private static func sanitizeEventName(_ eventName: String) -> String {
        let lowered = eventName.lowercased()
        let replaced = lowered.replacingOccurrences(
            of: "[^a-z0-9_]",
            with: "_",
            options: .regularExpression
        )
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let prefixed = trimmed.first?.isNumber == true ? "event_\(trimmed)" : trimmed
        let safeName = prefixed.isEmpty ? "app_event" : prefixed
        return String(safeName.prefix(maxEventNameLength))
    }

    private static func sanitizeParameters(_ parameters: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]

        for (key, value) in parameters {
            let sanitizedKey = sanitizeParameterName(key)
            if let sanitizedValue = sanitizeParameterValue(value) {
                sanitized[sanitizedKey] = sanitizedValue
            }
        }

        return sanitized
    }

    private static func sanitizeParameterName(_ parameterName: String) -> String {
        let lowered = parameterName.lowercased()
        let replaced = lowered.replacingOccurrences(
            of: "[^a-z0-9_]",
            with: "_",
            options: .regularExpression
        )
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let prefixed = trimmed.first?.isNumber == true ? "param_\(trimmed)" : trimmed
        let safeName = prefixed.isEmpty ? "value" : prefixed
        return String(safeName.prefix(maxParameterNameLength))
    }

    private static func sanitizeParameterValue(_ value: Any) -> Any? {
        switch value {
        case let value as String:
            return value
        case let value as NSString:
            return value
        case let value as Int:
            return value
        case let value as Int64:
            return value
        case let value as Double:
            return value
        case let value as Float:
            return value
        case let value as Bool:
            return value ? 1 : 0
        case let value as NSNumber:
            return value
        default:
            return String(describing: value)
        }
    }
}
extension BannerView: @retroactive ShimmeringViewProtocol { }
