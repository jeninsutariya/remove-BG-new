//
//  AlertVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 21/10/26.
//

import UIKit

class AlertVC: UIViewController {
    @IBOutlet weak var lblSubtitle: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnOkey: UIButton!
    @IBOutlet weak var contentView: UIView!
    var onCancel: (() -> Void)?
    var onSubmit: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setBorder()
    }
    
    private func setUI() {
        btnCancel.layer.cornerRadius = btnCancel.bounds.height / 2
        btnOkey.layer.cornerRadius = btnOkey.bounds.height / 2
        
        btnCancel.clipsToBounds = true
        btnOkey.clipsToBounds = true
    }
    
    private func setBorder() {
        btnCancel.layer.borderWidth = 1
        btnCancel.layer.borderColor = AppColor.borderColor.cgColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setBorder()
        }
    }
    @IBAction func btnOkey(_ sender: UIButton) {
        onSubmit?()
        dismiss(animated: true)
    }
    @IBAction func btnCancel(_ sender: UIButton) {
        onCancel?()
        dismiss(animated: true)
    }
    
}
