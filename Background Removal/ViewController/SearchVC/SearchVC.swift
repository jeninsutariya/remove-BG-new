//
//  SearchVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

class SearchVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var vwProhectNotFound: UIView!
    @IBOutlet weak var veResultsMain: UIView!
    @IBOutlet weak var tblProjectsHeight: NSLayoutConstraint!
    @IBOutlet weak var tblProjects: UITableView!
    @IBOutlet weak var veResults: UIView!
    @IBOutlet weak var lblResults: UILabel!
    @IBOutlet weak var clvRecent: UICollectionView!
    @IBOutlet weak var vwRecent: UIView!
    @IBOutlet weak var btnCancelWidth: NSLayoutConstraint!
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var imgSearchIcon: UIImageView!
    @IBOutlet weak var btnClear: UIButton!
    @IBOutlet weak var vwSearch: UIView!
    @IBOutlet weak var vwSearchBG: UIView!
    @IBOutlet weak var txtSearch: UITextField!
     var recentSearches: [String] = []
     var filteredProjects: [BackgroundRemovalProject] = []
    /// Saved projects (same source as ProjectsVC), searched by name.
    var projects: [BackgroundRemovalProject] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setCollectionView()
        setTableView()
        bannerAd()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadProjects()
    }
    /// Loads the saved projects and refreshes any search already typed.
    func reloadProjects() {
        Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadAllProjects()
            }.value
            guard let self else { return }
            self.projects = loaded
            if !self.isSearchTextEmpty { self.performSearch(self.txtSearch.text ?? "") }
        }
    }
    func openProject(_ project: BackgroundRemovalProject) {
        guard let latest = ProjectStorageService.shared.loadProject(id: project.id) else {
            showToast(message: "This project is no longer available")
            reloadProjects()
            return
        }
        let vc = UIViewController.editorScreen(for: BackgroundRemovalViewModel(project: latest))
        self.navigationController?.pushViewController(vc, animated: true)
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
     
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.veResults.layer.borderWidth = 1
            self.veResults.layer.borderColor = AppColor.borderColor.cgColor
            self.vwProhectNotFound.layer.borderWidth = 1
            self.vwProhectNotFound.layer.borderColor = AppColor.borderColor.cgColor
        }
    }
    func bannerAd(){
        if UserDefaults.isPremiumUser {
            bannerView.isHidden = true
            lodingAds.isHidden = true
            self.adsBase.isHidden = true
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: 0).isActive = true
            
            self.view.setTemplateWithSubviews(false)
            return
        }
        let adsType = appData.searchVC.adType ?? ""
        let adsSize = appData.searchVC.adSize ?? 50
        
        let adSize = getAdSize(type: adsType, size: adsSize)
        if adsType == "NETIVE" || adsType == "BIG_NETIVE"{
            self.veBanner.isHidden = true
            self.adsBase.isHidden = false
            self.lodingAds.isHidden = true
            self.adsBase.setupAdsView(data: adsType == "NETIVE" ? .smallNative : .bigNative)
        }else if adsType == "BANNER" || adsType == "LARGE_BANNER" || adsType == "MEDIUM_RECTANGLE"{
            self.veBanner.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
        }else{
            self.bannerView.isHidden = false
            self.adsBase.isHidden = true
            self.lodingAds.isHidden = false
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            bannerView.heightAnchor.constraint(equalToConstant: adSize.size.height).isActive = true
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        }
        if adsType != "NETIVE" || adsType != "BIG_NETIVE"{
            self.view.layoutIfNeeded()
            self.bannerView.setTemplateWithSubviews(true, viewBackgroundColor: .white)
            self.lodingAds.isHidden = false
            bannerView.adUnitID = appData.bannerAdsId
            bannerView.rootViewController = self
            bannerView.delegate = self
            bannerView.adSize = adSize
            
            let request = Request()
            bannerView.load(request)
        }
    }
    
    func getAdSize(type: String, size: Int) -> AdSize {
        switch type {
        case "BANNER":
            return AdSizeBanner
        case "LARGE_BANNER":
            return AdSizeLargeBanner
        case "MEDIUM_RECTANGLE":
            return AdSizeMediumRectangle
        default:
            let screenWidth = UIScreen.main.bounds.width
            return adSizeFor(cgSize: CGSize(width: screenWidth, height: CGFloat(size)))
        }
    }
    func setUI() {
        txtSearch.delegate = self
        txtSearch.returnKeyType = .search
        txtSearch.placeholder = "Search projects"
        
        btnClear.isHidden = true
        btnCancelWidth.constant = 0
        
        vwSearch.layer.borderColor = AppColor.accent.cgColor
        updateSearchAppearance(isHighlighted: false)

        self.veResults.layer.borderWidth = 1
        self.veResults.layer.borderColor = AppColor.borderColor.cgColor

        self.updateResultsVisibility()
        self.veResultsMain.isHidden = true
        self.vwProhectNotFound.isHidden = true
    }

    func setCollectionView(){
        self.clvRecent.delegate = self
        self.clvRecent.dataSource = self
        self.clvRecent.register(UINib(nibName: "RecentsSearchClvCell", bundle: .none), forCellWithReuseIdentifier: "RecentsSearchClvCell")
    }

    func setTableView(){
        self.tblProjects.delegate = self
        self.tblProjects.dataSource = self
        self.tblProjects.register(UINib(nibName: "SearchProjectTblCell", bundle: .main), forCellReuseIdentifier: "SearchProjectTblCell")
        self.tblProjectsHeight.constant = 0
    }
    
    private func updateSearchAppearance(isHighlighted: Bool) {
        if isHighlighted {
            vwSearchBG.backgroundColor = AppColor.badgeColor
            vwSearch.layer.borderWidth = 1
            vwSearch.layer.borderColor = AppColor.accent.cgColor
            imgSearchIcon.tintColor = AppColor.accent
            self.vwProhectNotFound.isHidden = !self.filteredProjects.isEmpty
        } else {
            vwSearchBG.backgroundColor = .clear
            vwSearch.layer.borderWidth = 0
            imgSearchIcon.tintColor = AppColor.secondaryText
            self.vwProhectNotFound.isHidden = true
        }
    }
    
    private var isSearchTextEmpty: Bool {
        return (txtSearch.text ?? "").isEmpty
    }
    
     func search(_ text: String) -> [BackgroundRemovalProject] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return projects.filter {
            $0.name.range(of: query, options: .caseInsensitive) != nil
        }
    }

    private func performSearch(_ text: String) {
        filteredProjects = search(text)
        lblResults.text = resultsTitle(for: filteredProjects.count)
        tblProjectsHeight.constant = CGFloat(filteredProjects.count * 70)
        tblProjects.reloadData()
        updateResultsVisibility()
        self.veResultsMain.isHidden = self.filteredProjects.isEmpty
        self.vwProhectNotFound.isHidden = !self.filteredProjects.isEmpty
    }

    private func updateResultsVisibility() {
        let hasQuery = !isSearchTextEmpty
        veResults.isHidden = !hasQuery
        vwRecent.isHidden = hasQuery || recentSearches.isEmpty
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        clvRecent.reloadData()
        updateResultsVisibility()
    }
     func addRecentSearch(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        
        recentSearches.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        recentSearches.insert(query, at: 0)
        
        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }
    }
    func resultsTitle(for count: Int) -> String {
        return count == 1 ? "1 RESULT" : "\(count) RESULTS"
    }
    @IBAction func btnBack(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func btnClear(_ sender: UIButton) {
        txtSearch.text = ""
        btnClear.isHidden = true
        performSearch("")
    }
    
    @IBAction func btnCancel(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.btnClear.isHidden = true
            self.txtSearch.resignFirstResponder()
            self.btnCancelWidth.constant = 0
            self.updateSearchAppearance(isHighlighted: !self.isSearchTextEmpty)
        }
    }
    @IBAction func btnClearRecent(_ sender: UIButton) {
        adsManager.showInterstitial {
            self.clearRecentSearches()
        }
    }
}

extension SearchVC: UITextFieldDelegate {
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        btnClear.isHidden = isSearchTextEmpty
        performSearch(textField.text ?? "")
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        print("user is editing")
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.updateSearchAppearance(isHighlighted: true)
            
            if !self.isSearchTextEmpty {
                self.btnClear.isHidden = false
            }
            
            self.btnCancelWidth.constant = 60
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("user is editing ended")
        
        btnClear.isHidden = true
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.updateSearchAppearance(isHighlighted: !self.isSearchTextEmpty)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        addRecentSearch(textField.text ?? "")
        clvRecent.reloadData()

        btnClear.isHidden = true
        textField.resignFirstResponder()
        btnCancelWidth.constant = 0

        return true
    }
}
extension SearchVC:UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.recentSearches.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecentsSearchClvCell", for: indexPath) as! RecentsSearchClvCell
        cell.lblTitle.text = self.recentSearches[indexPath.row]
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        adsManager.showInterstitial {
            let searchText = self.recentSearches[indexPath.row]
            self.txtSearch.text = searchText
            self.btnClear.isHidden = false
            self.updateSearchAppearance(isHighlighted: true)
            self.performSearch(searchText)
        }
    }
    
}
extension SearchVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredProjects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchProjectTblCell", for: indexPath) as! SearchProjectTblCell
        cell.setData(self.filteredProjects[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let project = self.filteredProjects[indexPath.row]
        addRecentSearch(txtSearch.text ?? "")
        clvRecent.reloadData()
        adsManager.showInterstitial {
            self.openProject(project)
        }
    }
}
extension SearchVC: BannerViewDelegate {
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("Ad loaded successfully")
        self.lodingAds.isHidden = true
        self.view.setTemplateWithSubviews(false)
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("Ad failed to load: \(error.localizedDescription)")
        // Stop the shimmer even on failure so the user doesn't see a loading state forever
    }
}
