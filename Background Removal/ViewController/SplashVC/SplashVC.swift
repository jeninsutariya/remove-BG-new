//
//  SplashVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 05/10/26.
//

import UIKit

class SplashVC: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        progressView.setProgress(0, animated: false)
     
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
