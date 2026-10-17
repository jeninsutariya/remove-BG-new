//
//  OnboardingSecondVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 05/10/26.
//

import UIKit

class OnboardingSecondVC: UIViewController {

    @IBOutlet weak var vwImageShow: UIView!
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let leftIMG = UIImage(named: "Onboarding2"),
              let rightIMG = UIImage(named: "Onboarding2BG")
                else {
            return
        }
        
        let revealView = RevealImageView()
        revealView.translatesAutoresizingMaskIntoConstraints = false
        revealView.contentMode = .scaleAspectFit
        vwImageShow.addSubview(revealView)
        
        let g = vwImageShow.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            revealView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 0),
            revealView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: 0),
            revealView.centerYAnchor.constraint(equalTo: g.centerYAnchor),
            revealView.heightAnchor.constraint(equalTo: revealView.widthAnchor, multiplier: leftIMG.size.height / leftIMG.size.width),
        ])
        
        revealView.leftImage = leftIMG
        revealView.rightImage = rightIMG
        
    }
    @IBAction func btnContinue(_ sender: UIButton) {
        let vc = OnboardingThardVC.fatchInstance()
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
