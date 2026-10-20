//
//  ProjectsVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

class ProjectsVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var nodata: UIView!
    @IBOutlet weak var clvProjects: UICollectionView!
    /// Saved background-removal projects, newest first.
    var projects: [BackgroundRemovalProject] = []
    private var storageObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupCollectionView()
        storageObserver = NotificationCenter.default.addObserver(forName: ProjectStorageService.didChangeNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadProjects() }
        }
        reloadProjects()
        bannerAd()
    }
    func setupCollectionView(){
        self.clvProjects.delegate = self
        self.clvProjects.dataSource = self
        self.clvProjects.register(UINib(nibName: "ProjectClvCell", bundle: nil), forCellWithReuseIdentifier: "ProjectClvCell")
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
        let adsType = appData.projectsVC.adType ?? ""
        let adsSize = appData.projectsVC.adSize ?? 50
        
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
    func reloadProjects() {
        Task { [weak self] in
            let projects = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadAllProjects()
            }.value
            guard let self else { return }
            self.projects = projects
            self.clvProjects.reloadData()
            self.nodata.isHidden = self.projects.count > 0
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
    func confirmDelete(_ project: BackgroundRemovalProject) {
      
        showAlert(title: "Delete project?", msg: """
\"\(project.name)\" and its images will be removed from this app. Photos you already saved stay in your library.
""", okayTitle: "Delete", cancelTitle: "Cancel", doneAction: {
            ProjectStorageService.shared.deleteProject(id: project.id)
        })
    }
    @IBAction func btnSearch(_ sender: UIButton) {
        let vc = SearchVC.fatchInstance()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
}
extension ProjectsVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return projects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProjectClvCell", for: indexPath) as! ProjectClvCell
        cell.setData(project: projects[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return  CGSize(width: (collectionView.frame.size.width / 2), height: 200)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openProject(projects[indexPath.item])
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let project = projects[indexPath.item]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Open", image: UIImage(systemName: "square.and.pencil")) { _ in self?.openProject(project) },
                UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.confirmDelete(project)
                }
            ])
        }
    }
}
extension ProjectsVC: BannerViewDelegate {
    
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
