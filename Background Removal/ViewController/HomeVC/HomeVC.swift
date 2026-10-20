//
//  HomeVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 06/10/26.
//

import UIKit
import UIView_Shimmer
import GoogleMobileAds

struct HomeCardModel: Codable {
    let title: String
    let subtitle: String
    let topImage: String
    let bottomImage: String
    let id: Int
    
    enum CodingKeys: String, CodingKey {
        case title = "title"
        case subtitle = "subtitle"
        case topImage = "topImage"
        case bottomImage = "bottomImage"
        case id = "id"
    }
}

class HomeVC: UIViewController {
    @IBOutlet weak var veBanner: UIView!
    @IBOutlet weak var adsBase: AdsBaseView!
    @IBOutlet weak var bannerView: BannerView!
    @IBOutlet weak var lodingAds: UILabel!
    @IBOutlet weak var btnRecents: UIButton!
    @IBOutlet weak var lblRecents: UILabel!
    @IBOutlet weak var vwRemoveBGImage: UIView!
    @IBOutlet weak var vwRemoveBackground: UIView!
    @IBOutlet weak var vwChangeBGImage: UIView!
    @IBOutlet weak var vwChangeBG: UIView!
    @IBOutlet weak var vwTextBehindImage: UIView!
    @IBOutlet weak var vwTextBehind: UIView!
    @IBOutlet weak var vwBatchRemoveImage: UIView!
    @IBOutlet weak var vwBatchRemove: UIView!
    
    @IBOutlet weak var clvRecents: UICollectionView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var clvCardView: UICollectionView!
    @IBOutlet weak var vwPageThree: UIView!
    @IBOutlet weak var vwPageTwo: UIView!
    @IBOutlet weak var vwPageOne: UIView!
    var timer: Timer?
    var currentIndex = 0
    /// Saved projects shown in Recents (newest first).
    var recentProjects: [BackgroundRemovalProject] = []
    /// What the next picked photos are for.
    var pendingDestination: RemovingBackgroundVC.Destination = .editor
    var pendingSelectionMode: ImageSelectionMode = .single
    private var storageObserver: NSObjectProtocol?
    static let batchSelectionLimit = 20
    var homeCardData: [HomeCardModel] = [
        HomeCardModel(title: "Bulk Remove", subtitle: "Clear a whole album at once", topImage: "top bg home", bottomImage: "bottom bg home", id: 1),
        HomeCardModel(title: "Change Background", subtitle: "Pick a color or photo backdrop", topImage: "top chang bg", bottomImage: "bottom chang bg", id: 2),
        HomeCardModel(title: "Text Behind", subtitle: "Put text behind your subject", topImage: "top text behind", bottomImage: "bootm text behind", id: 3),
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        startAutoScrollTimer()
        setPageViewAnimate()
        bannerAd()
        setBootonView(self.vwRemoveBackground)
        setBootonView(self.vwChangeBG)
        setBootonView(self.vwTextBehind)
        setBootonView(self.vwBatchRemove)
        
        setTransform(self.vwRemoveBGImage)
        setTransform(self.vwChangeBGImage)
        setTransform(self.vwTextBehindImage)
        setTransform(self.vwBatchRemoveImage)
        
        storageObserver = NotificationCenter.default.addObserver(forName: ProjectStorageService.didChangeNotification,
                                                                 object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadRecents() }
        }
        reloadRecents()
        RatingManager.appDidOpen()
        
        
    }
    func isRecentsShow(_ isShow :Bool){
        btnRecents.isHidden = isShow
        lblRecents.isHidden = isShow
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
        let adsType = appData.homeVC.adType ?? ""
        let adsSize = appData.homeVC.adSize ?? 50
        
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
    func reloadRecents() {
        Task { [weak self] in
            let projects = await Task.detached(priority: .utility) {
                Array(ProjectStorageService.shared.loadAllProjects().prefix(10))
            }.value
            guard let self else { return }
            self.recentProjects = projects
            self.clvRecents.reloadData()
            self.isRecentsShow(self.recentProjects.count == 0)
        }
    }
    func setupCollectionView(){
        self.clvCardView.delegate = self
        self.clvCardView.dataSource = self
        self.clvCardView.register(UINib(nibName: "HomeClvCell", bundle: .none), forCellWithReuseIdentifier: "HomeClvCell")
        
        self.clvRecents.delegate = self
        self.clvRecents.dataSource = self
        self.clvRecents.register(UINib(nibName: "RecentsClvCell", bundle: .none), forCellWithReuseIdentifier: "RecentsClvCell")
    }
    
    func setTransform(_ view: UIView){
        let removeBGImageRadians = 4 * (.pi / 180.0)
        view.transform = CGAffineTransform(rotationAngle: removeBGImageRadians)
        view.layer.masksToBounds = false
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setBootonView(self.vwRemoveBackground)
            setBootonView(self.vwChangeBG)
            setBootonView(self.vwTextBehind)
            setBootonView(self.vwBatchRemove)
        }
    }
    func setBootonView(_ view: UIView){
        view.layer.borderWidth = 1
        view.layer.borderColor = AppColor.borderColor.cgColor
    }
    
    func startAutoScrollTimer() {
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(scrollToNextItem), userInfo: nil, repeats: true)
    }
    
    @objc func scrollToNextItem() {
        if currentIndex < homeCardData.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0
        }
        
        let indexPath = IndexPath(item: currentIndex, section: 0)
        self.clvCardView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        setPageViewAnimate()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if timer == nil {
            startAutoScrollTimer()
        }
    }
    func setPageViewAnimate() {
        print("Index :: \(currentIndex)")
        
        _ = [vwPageOne, vwPageTwo, vwPageThree]
        
        let newOrder: [UIView]
        
        switch currentIndex {
        case 0:
            newOrder = [vwPageOne, vwPageTwo, vwPageThree]
        case 1:
            newOrder = [vwPageTwo, vwPageOne, vwPageThree]
        case 2:
            newOrder = [vwPageTwo, vwPageThree, vwPageOne]
        default:
            newOrder = [vwPageOne, vwPageTwo, vwPageThree]
        }
        
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
            for (index, view) in newOrder.enumerated() {
                self.stackView.removeArrangedSubview(view)
                self.stackView.insertArrangedSubview(view, at: index)
            }
            
            self.stackView.layoutIfNeeded()
        }
    }
    
    func selectRemoveBG() {
        openImagePicker(mode: .single, destination: .editor)
    }
    
    func openImagePicker(mode: ImageSelectionMode, destination: RemovingBackgroundVC.Destination) {
            pendingDestination = destination
            pendingSelectionMode = mode
            let sheetVC = ImageSourcePickerVC.fatchInstance()
            sheetVC.delegate = self
            sheetVC.selectionMode = mode
            sheetVC.maximumSelectionLimit = HomeVC.batchSelectionLimit
            let contentHeight = calculateContentHeight(for: sheetVC)
            showImageSourcePicker(from: self,vc: sheetVC,contentHeight: contentHeight)
    }
    
    @IBAction func btnRecentsSeeAll(_ sender: UIButton) {
        self.tabBarController?.selectedIndex = 1
    }
    @IBAction func btnSettings(_ sender: UIButton) {
        let vc = SettingsVC.fatchInstance()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    @IBAction func btnRemoveBackground(_ sender: UIButton) {
        self.selectRemoveBG()
    }
    @IBAction func btnChangeBackground(_ sender: UIButton) {
        openImagePicker(mode: .single, destination: .changeBackground)
    }
    @IBAction func btnTextBehind(_ sender: UIButton) {
        openImagePicker(mode: .single, destination: .textBehind)
    }
    @IBAction func btnBatchRemove(_ sender: UIButton) {
        openImagePicker(mode: .multiple, destination: .editor)
    }
    
    func openProject(_ project: BackgroundRemovalProject) {
        // Reload from disk so the latest saved state is used.
        guard let latest = ProjectStorageService.shared.loadProject(id: project.id) else {
            showToast(message: "This project is no longer available")
            reloadRecents()
            return
        }
        let vc = UIViewController.editorScreen(for: BackgroundRemovalViewModel(project: latest))
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    
    
}
extension HomeVC: UICollectionViewDelegate,UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.clvRecents{
            return recentProjects.count
        }else{
            return homeCardData.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.clvRecents{
            let  cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecentsClvCell", for: indexPath) as! RecentsClvCell
            cell.setData(project: recentProjects[indexPath.row])
            return cell
        }else{
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HomeClvCell", for: indexPath) as! HomeClvCell
            cell.setData(data: homeCardData[indexPath.row])
            return cell
        }
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == self.clvRecents{
            return  CGSize(width: (collectionView.frame.size.height), height: (collectionView.frame.size.height))
        }else{
            return  CGSize(width: (collectionView.frame.size.width), height: (collectionView.frame.size.height))
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == clvCardView else { return }
        let pageWidth = scrollView.frame.width
        currentIndex = Int(round(scrollView.contentOffset.x / pageWidth))
        setPageViewAnimate()
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == clvRecents {
            openProject(recentProjects[indexPath.row])
            return
        }
        guard collectionView == clvCardView else { return }
        let item = homeCardData[indexPath.row]
        switch item.id {
        case 1:
            openImagePicker(mode: .multiple, destination: .editor)
        case 2:
            openImagePicker(mode: .single, destination: .changeBackground)
        case 3:
            openImagePicker(mode: .single, destination: .textBehind)
        default:
            break
        }
    }
}

extension HomeVC: ImageSourcePickerDelegate{
    func imageSourcePicker(_ picker: ImageSourcePickerVC, didPick images: [PickedImage]) {
        print("Selected images: \(images.count)")
        guard !images.isEmpty else { return }
        
        let vc = RemovingBackgroundVC.fatchInstance()
        vc.pickedImages = images
        vc.destination = pendingDestination
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
extension HomeVC: BannerViewDelegate {
    
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
