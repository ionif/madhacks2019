//
//  PinController.swift
//  madhacks
//
//  Created by Alex Ionkov on 10/19/19.
//  Copyright © 2019 Alex Ionkov. All rights reserved.
//

import Foundation

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class PinController: UIViewController {
    @IBOutlet weak var dateTextField: UITextField!
    let locationManager = CLLocationManager()
        @IBOutlet weak var mapView: MKMapView!
        
        override func viewDidLoad() {
            super.viewDidLoad()
            self.locationManager.requestAlwaysAuthorization()
            
            // For use in foreground
            self.locationManager.requestWhenInUseAuthorization()
            
            if CLLocationManager.locationServicesEnabled() {
                locationManager.delegate = self as! CLLocationManagerDelegate
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.startUpdatingLocation()
            }
            
            self.dateTextField.setInputViewDatePicker(target: self, selector: #selector(tapDone))

            
        }
        
        func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }
            
            let identifier = "MyCustomAnnotation"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView!.annotation = annotation
            }
            
            configureDetailView(annotationView: annotationView!)
            
            return annotationView
        }
        
        func configureDetailView(annotationView: MKAnnotationView) {
            let width = 300
            let height = 200
            
            let snapshotView = UIView()
            let views = ["snapshotView": snapshotView]
            snapshotView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[snapshotView(300)]", options: [], metrics: nil, views: views))
            snapshotView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[snapshotView(200)]", options: [], metrics: nil, views: views))
            
            let options = MKMapSnapshotter.Options()
            options.size = CGSize(width: width, height: height)
            options.mapType = .satelliteFlyover
            options.camera = MKMapCamera(lookingAtCenter: annotationView.annotation!.coordinate, fromDistance: 250, pitch: 65, heading: 0)
            
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start { snapshot, error in
                if snapshot != nil {
                    let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: height))
                    imageView.image = snapshot!.image
                    snapshotView.addSubview(imageView)
                }
            }
            
            annotationView.detailCalloutAccessoryView = snapshotView
        }
    
    @objc func tapDone() {
        if let datePicker = self.dateTextField.inputView as? UIDatePicker {
            let dateformatter = DateFormatter()
            dateformatter.dateStyle = .medium
            self.dateTextField.text = dateformatter.string(from: datePicker.date)
            
        }
    }
    
}

extension PinController : CLLocationManagerDelegate {
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            let locValue:CLLocationCoordinate2D = manager.location!.coordinate
            
            mapView.mapType = MKMapType.standard
            
            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            let region = MKCoordinateRegion(center: locValue, span: span)
            mapView.setRegion(region, animated: true)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = locValue
            mapView.addAnnotation(annotation)
        }
        
}

