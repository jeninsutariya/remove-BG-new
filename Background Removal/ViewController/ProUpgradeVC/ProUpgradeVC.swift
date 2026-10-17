//
//  ProUpgradeVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 11/10/26.
//

import UIKit

class ProUpgradeVC: UIViewController {

    @IBOutlet weak var tblProdactHeight: NSLayoutConstraint!
    @IBOutlet weak var tblProdact: UITableView!
    @IBOutlet weak var vwRimage: UIView!
    @IBOutlet weak var vwLimage: UIView!
    var selectedIndex: Int = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setTableView()
        self.setTransform(vwLimage, -6)
        self.setTransform(vwRimage, 6)
    }
    func setTransform(_ view: UIView, _ angle: CGFloat){
        let removeBGImageRadians = angle * (.pi / 180.0)
        view.transform = CGAffineTransform(rotationAngle: removeBGImageRadians)
        view.layer.masksToBounds = false
        view.layer.masksToBounds = true
    }
    
    func setTableView(){
        self.tblProdactHeight.constant = 2 * 80
        self.tblProdact.dataSource = self
        self.tblProdact.delegate = self
        self.tblProdact.register(UINib(nibName: "ProUpgradeTVC", bundle: nil), forCellReuseIdentifier: "ProUpgradeTVC")
        
    }
    
    @IBAction func btnClose(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
    

}
extension ProUpgradeVC: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(withIdentifier: "ProUpgradeTVC", for: indexPath) as! ProUpgradeTVC
        cell.setSata(isSelected: self.selectedIndex == indexPath.row)
        cell.veBestValue.isHidden = indexPath.row == 1
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedIndex = indexPath.row
        self.tblProdact.reloadData()
    }
}
