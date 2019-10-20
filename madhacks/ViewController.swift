//
//  ViewController.swift
//  madhacks
//
//  Created by Alex Ionkov on 10/19/19.
//  Copyright © 2019 Alex Ionkov. All rights reserved.
//

import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import AVFoundation

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    let storage = Storage.storage();
    let db =  Firestore.firestore();
    var imageNames: [String] = [];
    var dictionary:  [String: Array] = [:] as! [String : Array<Any>];
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video)
            else {
                print("Unable to access back camera!")
                return
        }
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            
            try! backCamera.lockForConfiguration()
            backCamera.focusMode = .continuousAutoFocus
            backCamera.unlockForConfiguration()
            
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Setup your camera here...
    }
    
    func setupLivePreview() {
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        cameraView.layer.addSublayer(videoPreviewLayer!)
        
        DispatchQueue.global(qos: .userInitiated).async { //[weak self] in
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.cameraView.bounds
            }
        }
    }
    
    @IBAction func takePhoto(_ sender: Any) {
        let photoSettings : AVCapturePhotoSettings!
        photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.flashMode = .off
        //capture photo
        stillImageOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let image = UIImage(data: imageData)
        print(imageData)
        
    }
    
    func downloadMarkers(fileName:String){
    
    // initialize
        let group = DispatchGroup()
        print("starting download........")
        db.collection("Markers").getDocuments() { (querySnapshot, err) in
            if let err = err {
                        print("Error getting documents: \(err)")
                    } else {
                        print("starting refrence image download........")
                        for document in querySnapshot!.documents {
                            group.enter()
                            
                            let maingroup = DispatchGroup()
                            maingroup.enter()
                            
                            let docID = document.documentID
                            let storageRef =  self.storage.reference();
                            let docData = document.data()
                            
                            let imgLoc = docData["Location"] as! GeoPoint
                            let imgVer = docData["Verified"] as! Bool
                            
                            self.dictionary[docID] = [imgLoc,imgVer];
                            
                            if(imgVer){
                                //need to use the geo location and put it on the map
                                
                                
                                // this is downloading the image
                                let model = storageRef.child(docID + "/" +  fileName);
                                
                                //this set downloads the image and stores it localy
                                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
                                let tempDirectory = URL.init(fileURLWithPath: paths, isDirectory: true)
                                let targetUrl = tempDirectory.appendingPathComponent(docID)
                                model.write(toFile: targetUrl) { (url, error) in
                                    if error != nil {
                                        print("ERROR: \(error!)")
                                    }else{
                                        print(url!)
                                        self.imageNames.insert(docID.trimmingCharacters(in: .whitespacesAndNewlines), at: 0);
                                        print(self.imageNames)
                                        
                                        
                                        let imageData = try! Data(contentsOf: url!)
                                        
                                        let image = UIImage(data: imageData)
                                        
                                        //do whatever is needed with the image to place on the app
                                        
                                        
                                        print("image " + docID + " downloaded")
                                        print(self.dictionary);
                                        maingroup.leave()
                                        
                                    }
                                }
                            }
                }
                                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                }
            }
        }
    }
    
    func uploadMarkers(verified: Bool, location: GeoPoint, fileName: String){
        
        var ref: DocumentReference? = nil
        // Add a new document with a generated ID
        ref = db.collection("Markers").addDocument( data: ["Location":location,"Verified":verified]) { err in
            if let err = err {
                print("Error adding document: \(err)")
            } else {
                print("Document added")
                let storageRef = self.storage.reference();
                
                // Create a reference to the file you want to upload
                let riversRef = storageRef.child(ref!.documentID + "/" + fileName)
                
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
                let tempDirectory = URL.init(fileURLWithPath: paths, isDirectory: true)
                let targetUrl = tempDirectory.appendingPathComponent(fileName)
                
                // Upload the file to the path "id/filename.jpg"
                       _ = riversRef.putFile(from: targetUrl,  metadata: nil) { metadata, error in
                           guard metadata != nil else {
                               // Uh-oh, an error occurred!
                               print("did not upload file")
                               return
                           }
                               print("upload Success!!")
                       }
            }
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.captureSession.stopRunning()
    }
}

