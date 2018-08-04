//
//  ViewController.swift
//  cut
//
//  Created by Andre Woodley Jr on 7/18/18.
//  Copyright © 2018 In  The Room, Inc. All rights reserved.
//

import UIKit
import MobileCoreServices
import AssetsLibrary
import AVFoundation
import Photos
import StoreKit
import SwiftyCam

class ViewController:
    SwiftyCamViewController,
    SwiftyCamViewControllerDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate
{

    @IBOutlet weak var uploadBtn: UIButton!
    @IBOutlet weak var messageTxt: UITextView!
    @IBOutlet weak var timeLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var purchaseBtn: UIButton!
//    @IBOutlet weak var captureButton: SwiftyCamButton!
    @IBOutlet weak var flipCameraButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var startRecordBtn: UIButton!
    @IBOutlet weak var helpBtn: UIButton!
    @IBOutlet weak var timeBtn: UIButton!
    @IBOutlet weak var flashBtn: UIButton!
    @IBOutlet weak var uploadLbl: UILabel!
    @IBOutlet weak var stopRecordBtn: UIButton!
    
    let imagePickerController = UIImagePickerController()
    var videoProcessor = VideoProcessor.init()
    var time = 15.0
    var removeWatermark = false

    struct UserDefaultsKeys {
        static let DURATION = "DURATION"
    }


//    let captureButton = SwiftyCamButton(frame: buttonFrame)
//    captureButton.delegate = self;
//    @IBOutlet weak var captureButton: SwiftyRecordButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraDelegate = self
        maximumVideoDuration = 10.0
        shouldUseDeviceOrientation = true
        allowAutoRotate = true
        audioEnabled = true
        swipeToZoomInverted = true
        setBarStyle()
        initializeImageController()
        checkWatermarkStatus()
        updateLabel()
        initAppPurchaseSetUp()
        videoProcessor = VideoProcessor()
        checkPermission()
        fetchPhotos()
        stopRecordBtn.layer.borderWidth = 5.0
        stopRecordBtn.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        uploadBtn.layer.cornerRadius = 3.0
        uploadBtn.layer.borderColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        uploadBtn.layer.borderWidth = 2.0
        NotificationCenter.default.addObserver(self, selector: #selector(self.statusUpdate(_:)), name: NSNotification.Name(rawValue: "VideoStatusUpdate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.successfulPurchase(_:)), name: NSNotification.Name(rawValue: "SuccessfulPurchase"), object: nil)

    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        StoreReviewHelper.incrementAppOpenedCount()
//        captureButton.delegate = self
    }
    
    @objc func statusUpdate(_ notification: NSNotification) {
        let message = notification.userInfo?["message"] as? String
        print(message as Any)
        messageTxt.text = message
        if (message == "done"){
            finishedProcessVideo()
        }
    }
    
    @objc func successfulPurchase(_ notification: NSNotification) {
        UserDefaults.standard.set(true, forKey: "REMOVED_WATERMARK")
        checkWatermarkStatus()
    }
    
    func checkPermission() {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .authorized:
            print("Access is granted by user")
        //            showImagePicker()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({
                (newStatus) in
                print("status is \(newStatus)")
                if newStatus ==  PHAuthorizationStatus.authorized {
                    /* do stuff here */
                    print("success")
                    //                    showImagePicker()
                }
            })
            print("It is not determined until now")
        case .restricted:
            // same same
            print("User do not have access to photo album.")
        case .denied:
            // same same
            print("User has denied the permission.")
        }
    }
    
    func checkWatermarkStatus(){
        removeWatermark = UserDefaults.standard.bool(forKey: "REMOVED_WATERMARK")
        if(removeWatermark){
            return purchaseBtn.isHidden = true
        }
        purchaseBtn.isHidden = false
    }
    
    func createActionSheetOption(time: Int, title: String) -> UIAlertAction {
        return UIAlertAction(title: title, style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            UserDefaults.standard.set(time, forKey: UserDefaultsKeys.DURATION)
            self.updateLabel()
        })
    }
    
    func fetchPhotos () {
        // Sort the images by descending creation date and fetch the first 3
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key:"creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1
        
        // Fetch the image assets
        let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: fetchOptions)
        
        // If the fetch result isn't empty,
        // proceed with the image request
        if fetchResult.count > 0 {
            let totalImageCountNeeded = 1 // <-- The number of images to fetch
            fetchPhotoAtIndex(0, totalImageCountNeeded, fetchResult)
        }
    }
    
    // Repeatedly call the following method while incrementing
    // the index until all the photos are fetched
    func fetchPhotoAtIndex(_ index:Int, _ totalImageCountNeeded: Int, _ fetchResult: PHFetchResult<PHAsset>) {
        
        // Note that if the request is not set to synchronous
        // the requestImageForAsset will return both the image
        // and thumbnail; by setting synchronous to true it
        // will return just the thumbnail
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        
        // Perform the image request
        PHImageManager.default().requestImage(for: fetchResult.object(at: index) as PHAsset, targetSize: view.frame.size, contentMode: PHImageContentMode.aspectFill, options: requestOptions, resultHandler: { (image, _) in
            if let image = image {
                // Add the returned image to your array
                self.uploadBtn.setImage(image, for: .normal)
            }
        })
    }
    
    func finishedProcessVideo() {
        showAlert(title: "Your video was successfully saved")
        resetMessageLbl()
        StoreReviewHelper.checkAndAskForReview()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        imagePickerController.dismiss(animated: true, completion: nil)
        videoProcessor.processVideo(sourceURL: (info[UIImagePickerControllerMediaURL] as! URL), duration: Float(time), withWaterMark: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        resetMessageLbl()
        imagePickerController.dismiss(animated: true, completion: nil)
    }

    
    func initAppPurchaseSetUp() {
        IAPHandler.shared.fetchAvailableProducts()
        IAPHandler.shared.purchaseStatusBlock = {[weak self] (type) in
            guard let strongSelf = self else{ return }
            if type == .purchased {
                let alertView = UIAlertController(title: "", message: type.message(), preferredStyle: .alert)
                let action = UIAlertAction(title: "OK", style: .default, handler: { (alert) in
                    
                })
                alertView.addAction(action)
                strongSelf.present(alertView, animated: true, completion: nil)
            }
        }
    }
    
    func initializeImageController(){
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
    }
    
    func isKeyPresentInUserDefaults(key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }
    
    func resetMessageLbl() {
        messageTxt.text = "chop up long videos\ninto short story format"
        uploadBtn.setTitle("choose",for: .normal)
        uploadBtn.isEnabled = true
        activityIndicator.stopAnimating()
    }
    
    func setBarStyle(){
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    func showAlert(title: String){
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(defaultAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func showImagePicker() {
        messageTxt.text = "hold up...processing\ndon't close this"
        uploadBtn.setTitle("loading",for: .normal)
        uploadBtn.isEnabled = false
        activityIndicator.startAnimating()
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary){
            resetMessageLbl()
            return print("Photo Library Not Available")
        }
        present(imagePickerController, animated: true, completion: nil)
    }

    
    func updateLabel(){
        if(!isKeyPresentInUserDefaults(key: "DURATION")){
            UserDefaults.standard.set(15, forKey: UserDefaultsKeys.DURATION)
            return timeLbl.text = "15"
        }
        time =  UserDefaults.standard.double(forKey: "DURATION")
        timeLbl.text = "\(String(Int(time)))"
    }
    
//    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didTake photo: UIImage) {
//        let newVC = PhotoViewController(image: photo)
//        self.present(newVC, animated: true, completion: nil)
//    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didBeginRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        print("Did Begin Recording")
//        captureButton.growButton()
        UIView.animate(withDuration: 0.25, animations: {
            self.flashButton.alpha = 0.0
            self.flipCameraButton.alpha = 0.0
            self.uploadBtn.alpha = 0.0
            self.flipCameraButton.alpha = 0.0
            self.timeBtn.alpha = 0.0
            self.startRecordBtn.alpha = 0.0
            self.purchaseBtn.alpha = 0.0
            self.helpBtn.alpha = 0.0
            self.stopRecordBtn.alpha = 1.0
            self.uploadLbl.alpha = 0.0
            self.timeLbl.alpha = 0.0
        })
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishRecordingVideo camera: SwiftyCamViewController.CameraSelection) {
        print("Did finish Recording")
//        captureButton.shrinkButton()
        UIView.animate(withDuration: 0.25, animations: {
            self.flashButton.alpha = 1.0
            self.flipCameraButton.alpha = 1.0
            self.uploadBtn.alpha = 1.0
            self.flipCameraButton.alpha = 1.0
            self.timeBtn.alpha = 1.0
            self.startRecordBtn.alpha = 1.0
            self.purchaseBtn.alpha = 1.0
            self.helpBtn.alpha = 1.0
            self.stopRecordBtn.alpha = 0.0
            self.uploadLbl.alpha = 1.0
            self.timeLbl.alpha = 1.0
        })
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFinishProcessVideoAt url: URL) {
        let newVC = VideoViewController(videoURL: url)
        self.present(newVC, animated: true, completion: nil)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFocusAtPoint point: CGPoint) {
        let focusView = UIImageView(image: #imageLiteral(resourceName: "focus"))
        focusView.center = point
        focusView.alpha = 0.0
        view.addSubview(focusView)
        
        UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut, animations: {
            focusView.alpha = 1.0
            focusView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }, completion: { (success) in
            UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseInOut, animations: {
                focusView.alpha = 0.0
                focusView.transform = CGAffineTransform(translationX: 0.6, y: 0.6)
            }, completion: { (success) in
                focusView.removeFromSuperview()
            })
        })
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didChangeZoomLevel zoom: CGFloat) {
        print(zoom)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didSwitchCameras camera: SwiftyCamViewController.CameraSelection) {
        print(camera)
    }
    
    func swiftyCam(_ swiftyCam: SwiftyCamViewController, didFailToRecordVideo error: Error) {
        print(error)
    }
    
    
    
    @IBAction func cameraSwitchTapped(_ sender: Any) {
        switchCamera()
    }
    
    @IBAction func consumable(_ sender: Any) {
        let optionMenu = UIAlertController(title: nil, message: "select option", preferredStyle: .actionSheet)
        
        let restore = UIAlertAction(title: "restore in-app purchase", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            IAPHandler.shared.restorePurchase()
        })
        
        let purchase = UIAlertAction(title: "remove watermark ($0.99)", style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            IAPHandler.shared.purchaseMyProduct(index: 0)
        })
        
        let cancel = UIAlertAction(title: "cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
        })
        
        optionMenu.addAction(purchase)
        optionMenu.addAction(restore)
        optionMenu.addAction(cancel)
        
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    @IBAction func gotoInstagram(_ sender: Any) {
        let url = URL(string: "instagram://user?username=andrewoodleyjr")
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url!, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url!)
        }
    }
    
    @IBAction func showActionSheet(_ sender: Any) {
        let optionMenu = UIAlertController(title: nil, message: "Set Default Video Duration", preferredStyle: .actionSheet)
        
        optionMenu.addAction(createActionSheetOption(time: 10, title: "10 seconds *snapchat"))
        optionMenu.addAction(createActionSheetOption(time: 15, title: "15 seconds *instagram"))
        optionMenu.addAction(createActionSheetOption(time: 20, title: "20 seconds *facebook"))
        optionMenu.addAction(createActionSheetOption(time: 30, title: "30 seconds *whatsapp"))
        optionMenu.addAction(createActionSheetOption(time: 45, title: "45 seconds"))
        optionMenu.addAction(createActionSheetOption(time: 60, title: "60 seconds"))
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (alert: UIAlertAction!) -> Void in
        })
        optionMenu.addAction(cancelAction)
        
        self.present(optionMenu, animated: true, completion: nil)
    }
    
    @IBAction func toggleFlashTapped(_ sender: Any) {
        flashEnabled = !flashEnabled
        
        if flashEnabled == true {
            flashButton.alpha = 1.0
        } else {
            flashBtn.alpha = 0.5
        }
    }
    
    @IBAction func uploadVideo(_ sender: Any) {
        showImagePicker()
    }
    
    @IBAction func startRecording(_ sender: Any) {
        startVideoRecording()
    }
    
    @IBAction func stopRecording(_ sender: Any) {
        stopVideoRecording()
    }
    
}

