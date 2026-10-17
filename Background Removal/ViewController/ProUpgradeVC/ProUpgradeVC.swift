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
    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var btnRestore: UIButton!
    var selectedIndex: Int = 0
    private var premiumObserver: NSObjectProtocol?
    private var isWorking = false
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setTableView()
        self.setTransform(vwLimage, -6)
        self.setTransform(vwRimage, 6)
        
        premiumObserver = NotificationCenter.default.addObserver(forName: PremiumManager.didChangeNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePremiumState() }
        }
        updatePremiumState()
        Task { await PremiumManager.shared.loadProducts() }
        #if DEBUG
        addDebugPremiumSwitch()
        #endif
    }
    
    func updatePremiumState() {
        let active = PremiumManager.shared.hasActiveEntitlement
        btnContinue.setTitle(active ? "Premium active" : "Continue", for: .normal)
        btnContinue.isEnabled = !active && !isWorking
        btnRestore.isEnabled = !isWorking
        tblProdact.reloadData()
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
    
    /// Starts a real StoreKit purchase. Premium unlocks only after the App Store verifies it.
    @IBAction func btnContinue(_ sender: UIButton) {
        guard !isWorking else { return }
        let productID = PremiumManager.productIDs[min(selectedIndex, PremiumManager.productIDs.count - 1)]
        setWorking(true)
        Task { [weak self] in
            do {
                let purchased = try await PremiumManager.shared.purchase(productID: productID)
                self?.setWorking(false)
                if purchased {
                    showToast(message: "Premium unlocked")
                    self?.dismiss(animated: true)
                }
            } catch {
                self?.setWorking(false)
                self?.presentErrorAlert(title: "Purchase not completed", message: error.localizedDescription)
            }
        }
    }
    
    @IBAction func btnRestore(_ sender: UIButton) {
        guard !isWorking else { return }
        setWorking(true)
        Task { [weak self] in
            do {
                try await PremiumManager.shared.restorePurchases()
                self?.setWorking(false)
                if PremiumManager.shared.hasActiveEntitlement {
                    showToast(message: "Purchases restored")
                } else {
                    self?.presentErrorAlert(title: "Nothing to restore",
                                            message: "No active subscription was found for your Apple ID.")
                }
            } catch {
                self?.setWorking(false)
                self?.presentErrorAlert(title: "Restore failed", message: error.localizedDescription)
            }
        }
    }
    
    private func setWorking(_ working: Bool) {
        isWorking = working
        working ? LoaderView.shared.show() : LoaderView.shared.hide()
        updatePremiumState()
    }
    
    #if DEBUG
    /// Developer-only premium override (compiled out of Release builds).
    private func addDebugPremiumSwitch() {
        let toggle = UISwitch()
        toggle.isOn = PremiumManager.shared.debugOverrideEnabled
        toggle.addAction(UIAction { action in
            PremiumManager.shared.debugOverrideEnabled = (action.sender as? UISwitch)?.isOn ?? false
        }, for: .valueChanged)
        let label = UILabel()
        label.text = "DEBUG premium override"
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .systemRed
        let stack = UIStackView(arrangedSubviews: [label, toggle])
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4)
        ])
    }
    #endif
    

}
extension ProUpgradeVC: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(withIdentifier: "ProUpgradeTVC", for: indexPath) as! ProUpgradeTVC
        cell.setSata(isSelected: self.selectedIndex == indexPath.row)
        cell.veBestValue.isHidden = indexPath.row == 1
        let yearly = indexPath.row == 0
        cell.lblTitle.text = yearly ? "Yearly" : "Monthly"
        if let price = PremiumManager.shared.displayPrice(for: PremiumManager.productIDs[min(indexPath.row, 1)]) {
            cell.lblSubtitle.text = yearly ? "\(price) per year" : "\(price) per month"
        } else {
            cell.lblSubtitle.text = "Price loading…"
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedIndex = indexPath.row
        self.tblProdact.reloadData()
    }
}
