//
//  MapController.swift
//  madhacks
//
//  Created by Alex Ionkov on 10/19/19.
//  Copyright © 2019 Alex Ionkov. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import FirebaseFirestore
import FirebaseStorage

class MapController : UIViewController {
    let locationManager = CLLocationManager()
    @IBOutlet weak var mapView: MKMapView!
    
    let storage = Storage.storage();
    let db =  Firestore.firestore();
    var imageNames: [String] = [];
    var dictionary:  [String: Array] = [:] as! [String : Array<Any>];
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
        
    }
    
    func downloadMarkers(){
        
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
                
                    let docID = document.documentID
                    let storageRef =  self.storage.reference();
                    let docData = document.data()
                    
                    let imgLoc = docData["Location"] as! GeoPoint
                    let imgVer = docData["Verified"] as! Bool
                    
                    if(imgVer){
                        //need to use the geo location and put it on the map
                        //This is where we can call the pin controller and create a new one
                        
                        // this is downloading the image
                        let model = storageRef.child(docID + "/image.jpg");
                        
                        //this set downloads the image and stores it localy
                        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
                        let tempDirectory = URL.init(fileURLWithPath: paths, isDirectory: true)
                        let targetUrl = tempDirectory.appendingPathComponent(docID)
                        model.write(toFile: targetUrl) { (url, error) in
                            if error != nil {
                                print("ERROR: \(error!)")
                            }else{
                                print(url!)

                                let imageData = try! Data(contentsOf: url!)
                                
                                let image = UIImage(data: imageData)
                                
                                //do whatever is needed with the image to place on the app
                                self.dictionary[docID] = [imgLoc,imgVer,image ?? UIImage.self];
                                
                                print("image " + docID + " downloaded")
                                print(self.dictionary);
                                group.leave()
                                
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                    //use this for any aysynchronis tasks that may occur
                    
                }
            }
        }
    }
}
extension MapController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        
        mapView.mapType = MKMapType.standard
        
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: locValue, span: span)
        mapView.setRegion(region, animated: true)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = locValue
        mapView.addAnnotation(annotation)
    }
    
}
