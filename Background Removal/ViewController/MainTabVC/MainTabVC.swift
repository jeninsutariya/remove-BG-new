//
//  MainTabVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 06/10/26.
//

import UIKit

class MainTabVC: UITabBarController,UITabBarControllerDelegate {

    override func viewDidLoad() {
          super.viewDidLoad()
          // 1. Assign the delegate to intercept tab clicks
          self.delegate = self
        if let items = tabBar.items, items.count > 2 {

            let proImage = UIImage(named: "ProTab")?
                .withRenderingMode(.alwaysOriginal)

            items[2].image = proImage
            items[2].selectedImage = proImage
        }
        // Premium users don't need the Pro tab, so remove it from the tab bar
        if UserDefaults.isPremiumUser, var controllers = viewControllers, controllers.count > 2 {
            controllers.remove(at: 2)
            setViewControllers(controllers, animated: false)
        }

      }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            if let items = tabBar.items, items.count > 2 {

                let proImage = UIImage(named: "ProTab")?
                    .withRenderingMode(.alwaysOriginal)

                items[2].image = proImage
                items[2].selectedImage = proImage
            }
            // Premium users don't need the Pro tab, so remove it from the tab bar
        }
    }
      // 2. This method dictates whether the tab bar should switch to the selected tab
      func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
          
          // Find the index of the tab that the user clicked
          guard let index = viewControllers?.firstIndex(of: viewController) else {
              return true
          }

          // 3. Let's say the 3rd tab (index 2) should present a modal screen instead of switching
          if index == 2 {
              presentModalScreen()
              
              // Return false so the tab bar highlights do not switch away from the current tab
              return false
          }

          // Return true for all other tabs so they function normally
          return true
      }

      private func presentModalScreen() {
          // Instantiate the view controller you want to present
          // (Either from a Storyboard or programmatically)
//          let modalVC = ProUpgradeVC()
//          
//          let navigationController = UINavigationController(rootViewController: modalVC)
//          
//          modalVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
//            barButtonSystemItem: .close,
//              target: self,
//              action: #selector(dismissModal)
//          )
          let vc = ProUpgradeVC.fatchInstance()
          self.present(vc, animated: true, completion: nil)
      }

      @objc private func dismissModal() {
          self.dismiss(animated: true, completion: nil)
      }

}
