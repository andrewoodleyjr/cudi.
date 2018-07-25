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

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate  {
    @IBOutlet weak var uploadBtn: UIButton!
    @IBOutlet weak var messageTxt: UITextView!
    @IBOutlet weak var timeLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var purchaseBtn: UIButton!
    
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
    
    @IBAction func uploadVideo(_ sender: Any) {
        showImagePicker()
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
    
    let imagePickerController = UIImagePickerController()
    var videoProcessor = VideoProcessor.init()
    var time = 15.0
    var removeWatermark = false
    
    struct UserDefaultsKeys {
        static let DURATION = "DURATION"
    }
    
    // handle notification
    @objc func statusUpdate(_ notification: NSNotification) {
        let message = notification.userInfo?["message"] as? String
        print(message as Any)
        messageTxt.text = message
        if (message == "done"){
            finishedProcessVideo()
        }
    }
    
    func createActionSheetOption(time: Int, title: String) -> UIAlertAction {
        return UIAlertAction(title: title, style: .default, handler: {
            (alert: UIAlertAction!) -> Void in
            UserDefaults.standard.set(time, forKey: UserDefaultsKeys.DURATION)
            self.updateLabel()
        })
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        imagePickerController.dismiss(animated: true, completion: nil)
        videoProcessor.processVideo(sourceURL: (info[UIImagePickerControllerMediaURL] as! URL), duration: Float(time), withWaterMark: true)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        resetMessageLbl()
        imagePickerController.dismiss(animated: true, completion: nil)
    }
    
    func finishedProcessVideo() {
        showAlert(title: "Your video was successfully saved")
        resetMessageLbl()
        StoreReviewHelper.checkAndAskForReview()
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
    
    func updateLabel(){
        if(!isKeyPresentInUserDefaults(key: "DURATION")){
            UserDefaults.standard.set(15, forKey: UserDefaultsKeys.DURATION)
            return timeLbl.text = "15 sec"
        }
        time =  UserDefaults.standard.double(forKey: "DURATION")
        timeLbl.text = "\(String(Int(time))) sec"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setBarStyle()
        initializeImageController()
        checkWatermarkStatus()
        updateLabel()
        initAppPurchaseSetUp()
        videoProcessor = VideoProcessor()
        checkPermission()
        NotificationCenter.default.addObserver(self, selector: #selector(self.statusUpdate(_:)), name: NSNotification.Name(rawValue: "VideoStatusUpdate"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.successfulPurchase(_:)), name: NSNotification.Name(rawValue: "SuccessfulPurchase"), object: nil)
    }
    
    func checkWatermarkStatus(){
        removeWatermark = UserDefaults.standard.bool(forKey: "REMOVED_WATERMARK")
        if(removeWatermark){
            return purchaseBtn.isHidden = true
        }
        purchaseBtn.isHidden = false
    }
    
    @objc func successfulPurchase(_ notification: NSNotification) {
        UserDefaults.standard.set(true, forKey: "REMOVED_WATERMARK")
        checkWatermarkStatus()
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
        IAPHandler.shared.restorePurchase()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        StoreReviewHelper.incrementAppOpenedCount()
    }
}

