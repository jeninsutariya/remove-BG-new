//
//  HomeVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 06/10/26.
//

import UIKit

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
    var homeCardData: [HomeCardModel] = [
        HomeCardModel(title: "Batch Remove", subtitle: "Clear a whole album at once", topImage: "top bg home", bottomImage: "bottom bg home", id: 1),
        HomeCardModel(title: "Change Background", subtitle: "Pick a color or photo backdrop", topImage: "top chang bg", bottomImage: "bottom chang bg", id: 2),
        HomeCardModel(title: "Text Behind", subtitle: "Put text behind your subject", topImage: "top text behind", bottomImage: "bootm text behind", id: 3),
    ]
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        startAutoScrollTimer()
        setPageViewAnimate()
        
        setBootonView(self.vwRemoveBackground)
        setBootonView(self.vwChangeBG)
        setBootonView(self.vwTextBehind)
        setBootonView(self.vwBatchRemove)
        
        setTransform(self.vwRemoveBGImage)
        setTransform(self.vwChangeBGImage)
        setTransform(self.vwTextBehindImage)
        setTransform(self.vwBatchRemoveImage)
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
        let sheetVC = ImageSourcePickerVC.fatchInstance()
        sheetVC.delegate = self
        sheetVC.selectionMode = .single
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
    }
    @IBAction func btnTextBehind(_ sender: UIButton) {
    }
    @IBAction func btnBatchRemove(_ sender: UIButton) {
    }
    
    
    
}
extension HomeVC: UICollectionViewDelegate,UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.clvRecents{
            return 10
        }else{
            return homeCardData.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == self.clvRecents{
            let  cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecentsClvCell", for: indexPath) as! RecentsClvCell
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
        guard collectionView == clvCardView else { return }
        let item = homeCardData[indexPath.row]
        print("click = \(item.title),\(item.subtitle) = id: \(item.id)")
    }
}

extension HomeVC: ImageSourcePickerDelegate{
    func imageSourcePicker(_ picker: ImageSourcePickerVC, didSelect images: [UIImage]) {
        print("Selected images: \(images.count)")
        
        if let firstImage = images.first {
            let vc = RemovingBackgroundVC.fatchInstance()
            vc.image = firstImage
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        // Process all selected images.
//        for image in images {
//            // Add your image-processing logic here.
//        }
    }
    
    
}
