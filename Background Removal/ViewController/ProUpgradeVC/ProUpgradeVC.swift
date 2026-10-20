//
//  ProUpgradeVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 11/10/26.
//
//  In-App Purchase screen. Products and localized prices come from the App Store through
//  PurchaseConnector (IAPManager.swift); premium unlocks only after the receipt is verified.
//

import UIKit
import StoreKit
import SwiftyStoreKit

class ProUpgradeVC: UIViewController {

    @IBOutlet weak var tblProdactHeight: NSLayoutConstraint!
    @IBOutlet weak var tblProdact: UITableView!
    @IBOutlet weak var vwRimage: UIView!
    @IBOutlet weak var vwLimage: UIView!
    @IBOutlet weak var btnContinue: UIButton!
    @IBOutlet weak var btnRestore: UIButton!
    var selectedIndex: Int = 0

    /// Called once when the screen closes: true when premium was verified by then.
    var onClose: ((_ unlocked: Bool) -> Void)?

    /// The plans shown on this screen (row order = table order).
    private let plans: [(title: String, period: String, productId: String)] = [
        ("Yearly", "per year", PurchaseKeys.oneYear),
        ("Monthly", "per month", PurchaseKeys.oneMonth),
        ("Weekly", "per week", PurchaseKeys.oneWeekly),
    ]
    private enum ProductsState { case loading, loaded, failed }
    private var productsState: ProductsState = .loading
    private var premiumObserver: NSObjectProtocol?
    private var isWorking = false
    private var didReportClose = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setTableView()
        self.setTransform(vwLimage, -6)
        self.setTransform(vwRimage, 6)

        // E.g. an Ask to Buy purchase approved while this screen is open.
        premiumObserver = NotificationCenter.default.addObserver(forName: .refreshPremiumLog, object: nil,
                                                                 queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isWorking, PaywallManager.shared.isPremium else { return }
                self.dismiss(animated: true)
            }
        }
        loadProducts()
    }

    deinit {
        if let premiumObserver { NotificationCenter.default.removeObserver(premiumObserver) }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil, !didReportClose else { return }
        didReportClose = true
        let onClose = self.onClose
        self.onClose = nil
        onClose?(PaywallManager.shared.isPremium)
    }

    func updatePremiumState() {
        btnRestore.isEnabled = !isWorking
        btnContinue.isEnabled = !isWorking && productsState != .loading
        let title: String
        switch productsState {
        case .loading: title = "Loading…"
        case .loaded: title = selectedProduct == nil ? "Unavailable" : "Continue"
        case .failed: title = "Try Again"
        }
        btnContinue.setTitle(title, for: .normal)
        if productsState == .loaded, selectedProduct == nil { btnContinue.isEnabled = false }
        tblProdact.reloadData()
    }

    private var selectedProduct: SKProduct? {
        guard plans.indices.contains(selectedIndex) else { return nil }
        return PurchaseConnector.shared.product(for: plans[selectedIndex].productId)
    }

    private func loadProducts() {
        let connector = PurchaseConnector.shared
        if plans.contains(where: { connector.product(for: $0.productId) != nil }) {
            productsState = .loaded
            updatePremiumState()
            return
        }
        productsState = .loading
        updatePremiumState()
        connector.retrievedProductsInfo { [weak self] success in
            guard let self else { return }
            let found = self.plans.contains { connector.product(for: $0.productId) != nil }
            self.productsState = success && found ? .loaded : .failed
            self.updatePremiumState()
        }
    }

    func setTransform(_ view: UIView, _ angle: CGFloat){
        let removeBGImageRadians = angle * (.pi / 180.0)
        view.transform = CGAffineTransform(rotationAngle: removeBGImageRadians)
        view.layer.masksToBounds = false
        view.layer.masksToBounds = true
    }

    func setTableView(){
        self.tblProdactHeight.constant = CGFloat(plans.count) * 80
        self.tblProdact.dataSource = self
        self.tblProdact.delegate = self
        self.tblProdact.register(UINib(nibName: "ProUpgradeTVC", bundle: nil), forCellReuseIdentifier: "ProUpgradeTVC")

    }

    @IBAction func btnClose(_ sender: UIButton) {
        guard !isWorking else { return }
        self.dismiss(animated: true)
    }

    /// Starts a real StoreKit purchase. Premium unlocks only after the App Store verifies it.
    @IBAction func btnContinue(_ sender: UIButton) {
        guard !isWorking else { return }
        guard productsState == .loaded else {
            loadProducts()
            return
        }
        guard let product = selectedProduct else { return }
        setWorking(true)
        PurchaseConnector.shared.purchaseProduct(productId: product) { [weak self] outcome in
            guard let self else { return }
            self.setWorking(false)
            switch outcome {
            case .purchased:
                showToast(message: "Welcome to Pro!")
                self.dismiss(animated: true)
            case .cancelled:
                break
            case .pending:
                self.presentErrorAlert(title: "Purchase pending",
                                       message: "Your purchase is waiting for approval. Pro unlocks as soon as it's approved.")
            case .notVerified:
                self.presentErrorAlert(title: "Couldn't verify the purchase",
                                       message: "The App Store didn't confirm an active subscription yet. Please try Restore purchases in a moment.")
            case .failed(let message):
                self.presentErrorAlert(title: "Purchase failed", message: message)
            }
        }
    }

    @IBAction func btnRestore(_ sender: UIButton) {
        guard !isWorking else { return }
        // restorePurchase shows its own loader and result toast.
        isWorking = true
        updatePremiumState()
        PurchaseConnector.shared.restorePurchase { [weak self] restored in
            guard let self else { return }
            self.isWorking = false
            self.updatePremiumState()
            if restored, PaywallManager.shared.isPremium { self.dismiss(animated: true) }
        }
    }

    private func setWorking(_ working: Bool) {
        isWorking = working
        working ? LoaderView.shared.show() : LoaderView.shared.hide()
        updatePremiumState()
    }



}
extension ProUpgradeVC: UITableViewDataSource, UITableViewDelegate{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return plans.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(withIdentifier: "ProUpgradeTVC", for: indexPath) as! ProUpgradeTVC
        cell.setSata(isSelected: self.selectedIndex == indexPath.row)
        cell.veBestValue.isHidden = indexPath.row != 0
        let plan = plans[indexPath.row]
        cell.lblTitle.text = plan.title
        // Only the App Store's localized price is shown (never a hard-coded one).
        if let price = PurchaseConnector.shared.product(for: plan.productId)?.localizedPrice {
            cell.lblSubtitle.text = "\(price) \(plan.period)"
        } else {
            cell.lblSubtitle.text = productsState == .loading ? "Loading price…" : "Price unavailable"
        }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isWorking else { return }
        self.selectedIndex = indexPath.row
        self.updatePremiumState()
    }
}
