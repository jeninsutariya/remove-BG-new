//
//  ImageSourcePickerVC.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 15/10/26.
//

import UIKit
import PhotosUI
import AVFoundation

protocol ImageSourcePickerDelegate: AnyObject {
    func imageSourcePicker(_ picker: ImageSourcePickerVC,didSelect images: [UIImage])
}

enum ImageSelectionMode {
    case single
    case multiple
}

class ImageSourcePickerVC: UIViewController {
    
    @IBOutlet weak var btnCancel: UIButton!
    @IBOutlet weak var btnGallery: UIButton!
    @IBOutlet weak var btnCamera: UIButton!
    @IBOutlet weak var contentView: UIView!
    
    weak var delegate: ImageSourcePickerDelegate?
    
    var selectionMode: ImageSelectionMode = .single
    
    var maximumSelectionLimit: Int = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUI()
        setBorder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        setUI()
    }
    
    private func setUI() {
        btnCancel.layer.cornerRadius = btnCancel.bounds.height / 2
        btnGallery.layer.cornerRadius = btnGallery.bounds.height / 2
        btnCamera.layer.cornerRadius = btnCamera.bounds.height / 2
        
        btnCancel.clipsToBounds = true
        btnGallery.clipsToBounds = true
        btnCamera.clipsToBounds = true
    }
    
    private func setBorder() {
        btnCancel.layer.borderWidth = 1
        btnCancel.layer.borderColor = AppColor.borderColor.cgColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setBorder()
        }
    }
    
    @IBAction func btnGallery(_ sender: UIButton) {
        
        var configuration = PHPickerConfiguration()
        
        configuration.filter = .images
        
        switch selectionMode {
        case .single:
            configuration.selectionLimit = 1
            
        case .multiple:
            configuration.selectionLimit = max(1,maximumSelectionLimit)
        }
        
        let picker = PHPickerViewController(configuration: configuration)
        
        picker.delegate = self
        
        present(picker, animated: true)
    }
    
    @IBAction func btnCamera(_ sender: UIButton) {
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showAlert(
                title: "Camera Unavailable",
                message: "The camera is not available on this device."
            )
            return
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
            
        case .authorized:
            openCamera()
            
        case .notDetermined:
            
            AVCaptureDevice.requestAccess(for: .video) {
                [weak self] granted in
                
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if granted {
                        self.openCamera()
                    } else {
                        self.showCameraSettingsAlert()
                    }
                }
            }
            
        case .denied, .restricted:
            showCameraSettingsAlert()
            
        @unknown default:
            showAlert(
                title: "Camera Error",
                message: "Unable to access the camera."
            )
        }
    }
    
    private func openCamera() {
        
        let picker = UIImagePickerController()
        
        picker.sourceType = .camera
        picker.delegate = self
        
        present(picker, animated: true)
    }
    
    private func returnSelectedImages(_ images: [UIImage]) {
        
        delegate?.imageSourcePicker(
            self,
            didSelect: images
        )
        
        dismiss(animated: true)
    }
    
    @IBAction func btnCancel(_ sender: UIButton) {
        dismiss(animated: true)
    }
    
    private func showAlert(title: String,message: String) {
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )
        
        present(alert, animated: true)
    }
    
    private func showCameraSettingsAlert() {
        
        let alert = UIAlertController(
            title: "Camera Permission Required",
            message: "Allow camera access in Settings to take a photo.",
            preferredStyle: .alert
        )
        
        alert.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .cancel
            )
        )
        
        alert.addAction(
            UIAlertAction(
                title: "Settings",
                style: .default
            ) { _ in
                
                guard let url = URL(
                    string: UIApplication.openSettingsURLString
                ) else {
                    return
                }
                
                UIApplication.shared.open(url)
            }
        )
        
        present(alert, animated: true)
    }
}

extension ImageSourcePickerVC: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController,didFinishPicking results: [PHPickerResult]) {
        
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else {
            return
        }
        
        let group = DispatchGroup()
        let lock = NSLock()
        
        var selectedImages: [Int: UIImage] = [:]
        
        for (index, result) in results.enumerated() {
            
            let provider = result.itemProvider
            
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                continue
            }
            
            group.enter()
            
            provider.loadObject(ofClass: UIImage.self) {
                object, error in
                
                defer {
                    group.leave()
                }
                
                guard let image = object as? UIImage else {
                    return
                }
                
                lock.lock()
                selectedImages[index] = image
                lock.unlock()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            
            guard let self = self else {
                return
            }
            
            let images = selectedImages
                .sorted { $0.key < $1.key }
                .map { $0.value }
            
            guard !images.isEmpty else {
                return
            }
            
            self.returnSelectedImages(images)
        }
    }
}

extension ImageSourcePickerVC: UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController,didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        
        let image = (
            info[.editedImage] ?? info[.originalImage]
        ) as? UIImage
        
        picker.dismiss(animated: true) { [weak self] in
            
            guard let self = self,
                  let image = image else {
                return
            }
            
            self.returnSelectedImages([image])
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
