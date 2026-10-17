//
//  ProjectsVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 08/10/26.
//

import UIKit

class ProjectsVC: UIViewController {

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
    }
    func setupCollectionView(){
        self.clvProjects.delegate = self
        self.clvProjects.dataSource = self
        self.clvProjects.register(UINib(nibName: "ProjectClvCell", bundle: nil), forCellWithReuseIdentifier: "ProjectClvCell")
    }
    func reloadProjects() {
        Task { [weak self] in
            let projects = await Task.detached(priority: .utility) {
                ProjectStorageService.shared.loadAllProjects()
            }.value
            guard let self else { return }
            self.projects = projects
            self.clvProjects.reloadData()
        }
    }
    func openProject(_ project: BackgroundRemovalProject) {
        guard let latest = ProjectStorageService.shared.loadProject(id: project.id) else {
            showToast(message: "This project is no longer available")
            reloadProjects()
            return
        }
        let vc = RemovingBackgroundEditorVC.fatchEditorInstance()
        vc.viewModel = BackgroundRemovalViewModel(project: latest)
        self.navigationController?.pushViewController(vc, animated: true)
    }
    func confirmDelete(_ project: BackgroundRemovalProject) {
        let alert = UIAlertController(title: "Delete project?",
                                      message: "\"\(project.name)\" and its images will be removed from this app. Photos you already saved stay in your library.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            ProjectStorageService.shared.deleteProject(id: project.id)
        })
        present(alert, animated: true)
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
