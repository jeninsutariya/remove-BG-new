//
//  OnboardingThardVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 05/10/26.
//

import UIKit

class OnboardingThardVC: UIViewController {

    @IBOutlet weak var vwImageShow: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    @IBAction func btnContinue(_ sender: UIButton) {
        let vc = OnboardingForthVC.fatchInstance()
        self.navigationController?.pushViewController(vc, animated: true)
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
