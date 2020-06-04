//
//  ViewController.swift
//  GeofencingLabTest2
//
//  Created by Louise Chan on 2020-05-28.
//  Copyright © 2020 Louise Chan. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate {
    
    // MARK: Outlets
    @IBOutlet weak var geofenceingSwitch: UISwitch!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var txtLongInput: UITextField!
    @IBOutlet weak var txtLatInput: UITextField!
    
    // MARK: Variables
    var mapAnnotations: [MKAnnotation] = []
    
    var drivingDirections: [String] = []
    
    var boolLastToFirst = false
    var lastIndexBeforeUpdate  = 0
    var locationManager: CLLocationManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup initial map position
        setupInitialMapPosition()
        
        self.mapView.delegate = self
        self.txtLongInput.delegate = self
        self.txtLatInput.delegate = self
    }

    // MARK: Text field delegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Table view delegates
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return drivingDirections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "drivingDirCell")
        
        // if there are no table cells to dequeue, just create a new cell
        if (cell == nil) {
            cell = UITableViewCell(style: .default, reuseIdentifier: "drivingDirCell")
        }
        
        cell?.textLabel?.text = drivingDirections[indexPath.row]
        return cell!
    }
    
    // MARK: Core Location delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        //guard let location = locations.last else { return }
        
        if let location = manager.location {
            if checkGeofence(location: location) {
                if self.view.backgroundColor == .white {
                    self.view.backgroundColor = .green
                    centerViewOnUserLocation()
                }
            } else {
                if self.view.backgroundColor == .green {
                    self.view.backgroundColor = .white
                }
            }
        }
    }
    
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
    // MARK: Map view delegates
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay)
        renderer.strokeColor = UIColor.blue
        
        renderer.lineWidth = 4
        
        return renderer
    }
    
    // MARKER: MapKit helper functions
    func setupInitialMapPosition() {
        // Setup initial position in the map
        
        // GBC 2d coordinates, this will be the initial position of the map
        let gbcCoords = CLLocationCoordinate2D(latitude: 43.6761, longitude: -79.4105)
        
        // Setup zoom level
        let zoomLevel = MKCoordinateSpan(latitudeDelta: 0.75, longitudeDelta: 0.75)
        
        // Create a region object (control visible portion of the map)
        let region = MKCoordinateRegion(center: gbcCoords, span: zoomLevel)
        
        // Set the map's region to the region object that was made
        mapView.setRegion(region, animated: true)
        
    }
    
    func showMapPinError(msg: String) {
        // Create alert controller object and setup title and message to show
        let alertBox = UIAlertController(title:"Error!",
                                         message: msg,
                                         preferredStyle: .alert);
        
        // Add OK button for user action but don't specify any handler for the action
        alertBox.addAction(
            UIAlertAction(title: "OK", style: .default, handler: nil)
        )
        
        // Show the alert box on top of the view controller
        self.present(alertBox, animated: true)
    }
    
    func addAnnotationToMap(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        let annotationTitles = ["A", "B", "C", "D", "E"]
        
        let index = mapAnnotations.count
        let coordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        let annotation = MKPointAnnotation()
        
        annotation.coordinate = coordinates
        annotation.title = annotationTitles[index]
        mapAnnotations.append(annotation)
        mapView.addAnnotation(mapAnnotations[index])
    }
    
    func drawPolylinesBetweenPins() {
        // 1. Define your points that you want to connect
        // Making a starting and ending point (coordinates)
        
        var coordinates: [CLLocationCoordinate2D] = []
        for i in 0..<mapAnnotations.count {
            coordinates.append(mapAnnotations[i].coordinate)
        }
        
        // Link the last coordinate to the first one if more than 2 pins
        if mapAnnotations.count > 2 {
            coordinates.append(mapAnnotations[0].coordinate)
        }
        
        // 2. Create a Polyline --> MKPolyline
        let polylines = MKPolyline(coordinates: coordinates, count: coordinates.count)

        
        // Refresh polylines on the map
        mapView.removeOverlays(mapView.overlays)
        mapView.addOverlay(polylines)
    }
    
    // MARKER: Tableview helper functions
    func addDataToTableviewDataSource(_ data: String) {
        drivingDirections.append(data)
    }
    
    func convertTimeIntervalToDayHMS(timeData: TimeInterval) -> (day: Int, hour: Int, min: Int) {
        var timeLeft = Int(timeData.rounded())
        let day = timeLeft/86400
        timeLeft -= day * 86400
        let hour = timeLeft/3600
        timeLeft -= hour * 3600
        let minute = timeLeft/60
        return (day, hour, minute)
    }
    
    func addDrivingDirectionsToDataSource(start: MKAnnotation, end: MKAnnotation) {
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.coordinate))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true // get back more than 1 route
        
        let directions = MKDirections(request: request)
        
        // Send the request to Apple, and wait for a response
        directions.calculate { (response, error) in
            // If you are in here, it means apple sent you results
            // do something with the results from Apple
            //self.addDataToTableviewDataSource("--------------------------------")
            self.addDataToTableviewDataSource("** Driving Directions from \(start.title!!) to \(end.title!!) **")
            
            guard let response = response else {
                // We'll get here if no directions can be found for the given coordinates
                let errorMsg = "No directions found"
                self.addDataToTableviewDataSource(errorMsg)
                print("\(errorMsg) for pins \(start.title!!) to \(end.title!!)")
                return
            }
            
            // Directions have been found, add the shortest route directions in the table view datasource
            print("Directions found")
            
            // response.routes = an array of all the possible routes between start->end
            let sortedRoutes = response.routes.sorted(by: { routeA, routeB in
                return routeA.distance < routeB.distance
            })
            
            // Update data source with closest route
            let bestRoute = sortedRoutes[0]
            // Get the estimated travel time
            let estTime = self.convertTimeIntervalToDayHMS(timeData: bestRoute.expectedTravelTime)
            
            
            self.addDataToTableviewDataSource("Estimated time: \(estTime.day)d, \(estTime.hour)h, \(estTime.min)m\n")
            
            for step in bestRoute.steps {
                if step.instructions != "" {
                    print("\(step.instructions)")
                    self.addDataToTableviewDataSource("\(step.instructions)")
                }
            }
            self.addDataToTableviewDataSource("")
            //self.addDataToTableviewDataSource("---------------------------")
        
            self.tableView.reloadData()
            
            if self.mapAnnotations.count > 2 && self.boolLastToFirst == false {
                self.boolLastToFirst = true
                self.lastIndexBeforeUpdate = self.drivingDirections.count
                self.addDrivingDirectionsToDataSource(start: self.mapAnnotations[self.mapAnnotations.count-1], end: self.mapAnnotations[0])
            } else {
                self.boolLastToFirst = false
            }
            
        }
        
    }
    
    // MARK: Core Location helper functions
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            //locationManager?.requestWhenInUseAuthorization()
            checkLocationAuthorization()
        } else {
            // TODO Show alert letting the user know they have to turn this on.
            
            locationManager?.stopUpdatingLocation()
            mapView.showsUserLocation = false
        }
    }
    
    func disableUserLocationTracking() {
        locationManager?.stopUpdatingLocation()
        self.view.backgroundColor = .white
        mapView.showsUserLocation = false
        
    }
    
    func enableUserLocationServices() {
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func checkLocationAuthorization() {
        let authStatus = CLLocationManager.authorizationStatus()
        switch authStatus {
        case .authorizedWhenInUse:
            mapView.showsUserLocation = true
            centerViewOnUserLocation()
            locationManager?.startUpdatingLocation()
            break
        case .denied:
            disableUserLocationTracking()
            // TODO: Add alert box telling user that user did not allow geofencing
            break
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
            break
        case .restricted:
            // Show an alert letting them know what's up
            break
        case .authorizedAlways:
            break
        default:
            break;
        }
    }
    
    func centerViewOnUserLocation() {
        if let location = locationManager?.location?.coordinate {
            let region = MKCoordinateRegion.init(center: location, latitudinalMeters: 3000, longitudinalMeters: 3000)
            
            mapView.setRegion(region, animated: true)
            
            if let location = locationManager?.location {
                if checkGeofence(location: location) {
                    if self.view.backgroundColor == .white {
                        self.view.backgroundColor = .green
                    }
                } else {
                    if self.view.backgroundColor == .green {
                        self.view.backgroundColor = .white
                    }
                }
            }
            
            
        }
    }
    
    func checkGeofence(location: CLLocation) -> Bool {
        
        for annotation in mapAnnotations {
            let distance = location.distance(from: CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude))
            
            if distance <= 1000 {
                return true
            }
        }
        
        return false
        
    }
    
    // MARK: Actions
    
    @IBAction func btnClearMapPressed(_ sender: UIButton) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        mapAnnotations.removeAll()
        drivingDirections.removeAll()
        lastIndexBeforeUpdate = 0
        boolLastToFirst = false
        
        tableView.reloadData()
        
        disableUserLocationTracking()
        
    }
    
    
    @IBAction func btnAddPinPressed(_ sender: UIButton) {
        txtLatInput.resignFirstResponder()
        txtLongInput.resignFirstResponder()
        
        if mapAnnotations.count >= 5 {
            showMapPinError(msg: "Number of map pins have exceeded the limit.")
            // Clear text fields after error display
            txtLatInput.text = ""
            txtLongInput.text = ""
        } else {
            // Check if latitude is valid
            let latString = txtLatInput.text ?? ""
            guard let lat = Double(latString) else {
                return
            }
            
            // Check if longitude input is valid
            let lngString = txtLongInput.text ?? ""
            guard let lng = Double(lngString) else {
                return
            }
        
            addAnnotationToMap(latitude: lat, longitude: lng)
            
            // Check if we need to enable user location tracking
            if geofenceingSwitch.isOn {
                enableUserLocationServices()
            }
            
            // Check if polylines can now be drawn to the pins
            let annotationCount = mapAnnotations.count
            if annotationCount > 1 {
                // Draw polylines between each pins on the map
                drawPolylinesBetweenPins()
                
                if lastIndexBeforeUpdate != 0 && annotationCount > 3 /*&& prevlastIndex != 0*/ {
                    // delete rows of last point and point 0
                    for _ in lastIndexBeforeUpdate..<drivingDirections.count {
                        drivingDirections.remove(at: lastIndexBeforeUpdate)
                    }
                }
                
                addDrivingDirectionsToDataSource(start: mapAnnotations[annotationCount-2], end: mapAnnotations[annotationCount-1])
            }
            
            // Clear text fields after adding coordinates
            txtLatInput.text = ""
            txtLongInput.text = ""
            
            self.tableView.reloadData()
            
            
            
        }
        
    }
    
    @IBAction func geoSwitchToggled(_ sender: Any) {
        if geofenceingSwitch.isOn {
            if mapAnnotations.count != 0 {
                enableUserLocationServices()
            }
        }
        else {
            disableUserLocationTracking()
        }
    }
    
}

