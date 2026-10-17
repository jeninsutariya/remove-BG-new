//
//  ProjectsVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit

class ProjectsVC: UIViewController {

    @IBOutlet weak var clvProjects: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupCollectionView()
    }
    func setupCollectionView(){
        self.clvProjects.delegate = self
        self.clvProjects.dataSource = self
        self.clvProjects.register(UINib(nibName: "ProjectClvCell", bundle: nil), forCellWithReuseIdentifier: "ProjectClvCell")
    }
    @IBAction func btnSearch(_ sender: UIButton) {
        let vc = SearchVC.fatchInstance()
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
}
extension ProjectsVC: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout{
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 100
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProjectClvCell", for: indexPath) as! ProjectClvCell
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return  CGSize(width: (collectionView.frame.size.width / 2), height: 200)
    }
}
