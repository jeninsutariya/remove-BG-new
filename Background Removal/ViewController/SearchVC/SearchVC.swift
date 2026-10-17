//
//  SearchVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit
enum ProjectFormat: String {
    case png = "PNG"
    case jpg = "JPG"
}

struct SearchProject {
    let id: Int
    let title: String
    let dateText: String
    let format: ProjectFormat
    let imageName: String
    
    /// Subtitle shown under the title, e.g. "Today · PNG"
    var subtitle: String {
        return "\(dateText) · \(format.rawValue)"
    }
}
class SearchVC: UIViewController {
    
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
     var filteredProjects: [SearchProject] = []
     let projects: [SearchProject] = [
        SearchProject(id: 1,  title: "Portrait cutout",      dateText: "Today",     format: .png, imageName: "dummy_portrait_cutout"),
        SearchProject(id: 2,  title: "Portrait on mint",     dateText: "Mon",       format: .jpg, imageName: "dummy_portrait_mint"),
        SearchProject(id: 3,  title: "Portrait in denim",    dateText: "Mon",       format: .png, imageName: "dummy_portrait_denim"),
        SearchProject(id: 4,  title: "Summer beach",         dateText: "Today",     format: .jpg, imageName: "dummy_summer_beach"),
        SearchProject(id: 5,  title: "Summer sale banner",   dateText: "Yesterday", format: .png, imageName: "dummy_summer_sale"),
        SearchProject(id: 6,  title: "Peach product shot",   dateText: "Sun",       format: .png, imageName: "dummy_peach_product"),
        SearchProject(id: 7,  title: "Peach background",     dateText: "Sat",       format: .jpg, imageName: "dummy_peach_bg"),
        SearchProject(id: 8,  title: "Hello poster",         dateText: "Fri",       format: .png, imageName: "dummy_hello_poster"),
        SearchProject(id: 9,  title: "Sneaker cutout",       dateText: "Thu",       format: .png, imageName: "dummy_sneaker"),
        SearchProject(id: 10, title: "Profile photo",        dateText: "Wed",       format: .jpg, imageName: "dummy_profile"),
        SearchProject(id: 11, title: "Coffee mug mockup",    dateText: "2 Oct",     format: .png, imageName: "dummy_mug"),
        SearchProject(id: 12, title: "Passport photo",       dateText: "28 Sep",    format: .jpg, imageName: "dummy_passport")
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        setUI()
        setCollectionView()
        setTableView()
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
    
     func search(_ text: String) -> [SearchProject] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        return projects.filter {
            $0.title.range(of: query, options: .caseInsensitive) != nil
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
        self.clearRecentSearches()
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
        let searchText = self.recentSearches[indexPath.row]
        self.txtSearch.text = searchText
        self.btnClear.isHidden = false
        self.updateSearchAppearance(isHighlighted: true)
        self.performSearch(searchText)
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
    
    
}
