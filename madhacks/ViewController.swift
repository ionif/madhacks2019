//
//  ViewController.swift
//  madhacks
//
//  Created by Alex Ionkov on 10/19/19.
//  Copyright © 2019 Alex Ionkov. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import CoreML
import Firebase
import FirebaseFirestore
import FirebaseStorage

class ViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    let storage = Storage.storage();
    let db =  Firestore.firestore();
    
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
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        print("proccessing Image")
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        let image = UIImage(data: imageData)
        print(imageData)
        
        guard let ciImage = CIImage(image: image!) else {
            fatalError("couldn't convert UIImage to CIImage")
        }
        
        detectScene(image: ciImage, images: image!)
    
    }
    
    func detectScene(image: CIImage, images: UIImage){
        // Load the ML model through its generated class
        guard let model = try? VNCoreMLModel(for: my_model().model) else {
            fatalError("can't load Places ML model")
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation],
                let topResult = results.first else {
                    fatalError("unexpected result type from VNCoreMLRequest")
            }
            
            
            print(results.first.debugDescription.split(separator: " ")[5])
            
            let prob = Double(results.first.debugDescription.split(separator: " ")[5])!
            var classification = topResult.identifier
            
            if(prob < 0.5){
                classification = "none"
            }
            
            if(classification == "none"){
                // tell the user that there is an exception that the picture taken is not correct
                let alert = UIAlertController(title: "Error", message: "Furniture cannot be recognized", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                
                self?.present(alert, animated: true)
                
            }else{
                //otherwise let the user know that the pciture taken is acceptable and move on to the next page after the laoding page
                if let data = images.jpegData(compressionQuality: 0.8) {
                    let filename = self!.getDocumentsDirectory().appendingPathComponent("image.jpg")
                    try? data.write(to: filename)
                }
                
                //TO-DO: get the current location of the person and put it as the geo point location here
                self!.uploadMarkers(verified: true, location: GeoPoint(latitude: 0.0,longitude: 0.0), fileName: "image.jpg")
            }
            
        }
        
        let handler = VNImageRequestHandler(ciImage: image)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
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

