//
//  HomeController.swift
//  GoRussky
//
//  Created by Kartinin Studio on 07.06.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit
import Firebase
import MapKit
import Foundation

private let reuseIdentifier = "LocationCell"
private let annotationIdentifier = "DriverAnnotation"
private enum ActionButtonConfiguration {
    case showMenu
    case dismissActionView
    
    init() {
        self = .showMenu
    }
}
private enum AnnotationType: String {
    case pickup
    case destination
}

protocol HomeControllerDelegate: class {
    func handleMenuToggle()
}

class HomeController: UIViewController {
    //MARK: - Properties
    
    private let mapView = MKMapView()
    private let locationManager = LocationHandler.shared.locationManager

    
    private let inputActivationView = LocationInputActivationView()
    private let locationInputView = LocationInputView()
    private let tableView = UITableView()
    private let rideActionView = RideActionView()
    private var searchResults = [MKPlacemark]()
    private var savedLocations = [MKPlacemark]()
    private final let locationInputViewHeight: CGFloat = 200
    private final let rideActionViewHeight: CGFloat = 300
    private var actionButtonConfig = ActionButtonConfiguration()
    private var route: MKRoute?
    
    weak var delegate: HomeControllerDelegate?
    
    var user: User? {
        didSet{
            locationInputView.user = user
            print("DEBUG: ..")
            if user?.accountType == .passenger {
                print("DEBUG: user is passenger")
                fetchDrivers()
                configureLocationInputActivationView()
                observeCurrentTrip()
                configureSavedUserLocations()
            } else {
                //Service.shared.observeTrips()
                print("DEBUG: user is .. not passenger")
                observeTrips()
                //fetchDrivers()
            }
        }
    }
    
    private var trip: Trip? {
        didSet {
            guard let user = user else { return }
            
            if user.accountType == .driver {
                print("DEBUG: Show pickup passenger controller...")
                guard let trip = trip else { return }
                let controller = PickUpController(trip: trip)
                controller.modalPresentationStyle = .custom
                controller.delegate = self
                self.present(controller, animated: true, completion: nil)
            } else {
                print("DEBUG: Show ride action view for accepted trip ..")
            }
 
        }
    }
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "Hamburger_icon").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(actionButtonPressed), for: .touchUpInside)
        return button
    }()
    
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        enableLocationServices()
        configureUI()
        
//signOut()

        //view.backgroundColor = .red
    }
    
    override func viewWillAppear(_ animated: Bool) {
        guard let trip = trip else { return }
    }
    
    //MARK: - Selectors
    @objc func actionButtonPressed() {
        switch actionButtonConfig {
        case .showMenu:
            delegate?.handleMenuToggle()
            
        case .dismissActionView:
            removeAnnotationsAndOverlays()
            mapView.showAnnotations(mapView.annotations, animated: true)
            
            UIView.animate(withDuration: 0.3){
                self.inputActivationView.alpha = 1
                self.configureActionButton(config: .showMenu)
                self.animateRideActionView(shouldShow: false)
            }
            

        }
    }
    
    func startTrip(){
        guard let trip = self.trip else { return }
        DriverService.shared.updateTripState(trip: trip, state: .inProgress) { (err, ref) in
            self.rideActionView.config = .tripInProgress
            self.removeAnnotationsAndOverlays()
            self.mapView.addAnnotationAndSelect(forCoordinate: trip.destinationCoordinates)
            
            let placemark = MKPlacemark(coordinate: trip.destinationCoordinates)
            let mapItem = MKMapItem(placemark: placemark)
            
            self.setCustomRegion(withType: .destination, withCoordinates: trip.destinationCoordinates)
            self.generatePolyLine(toDestination: mapItem)
            
            self.mapView.zoomToFit(annotations: self.mapView.annotations)
        }
    }
    
    //MARK: - API
    
    func fetchDrivers() {
        guard let location = locationManager?.location else { return }
        PassengerService.shared.fetchDrivers(location: location) { (driver) in
            //print("DEBUG: Driver is \(user.location) ")
            guard let coordinate = driver.location?.coordinate else { return }
            let annotation = DriverAnnotation(uid: driver.uid, coordinate: coordinate)
            print("DEBUG: Driver coordinate is \(coordinate)")
            var drivarIsVisible: Bool {
                return self.mapView.annotations.contains(where: { annotation -> Bool in
                    guard let driverAnno = annotation as? DriverAnnotation else { return false}
                    if driverAnno.uid == driver.uid {
                        //print("DEBUG: HAndle update driver position")
                        driverAnno.updateAnnotationPosition(withCoordinate: coordinate)
                        self.zoomForActiveTrip(withDriverUid: driver.uid)
                        return true
                    }
                    return false
                })
            }
            if !drivarIsVisible {
                self.mapView.addAnnotation(annotation)
            }
            
           
        }
    }
    
    //MARK: - Passenger API
    
    func observeCurrentTrip() {
        PassengerService.shared.observeCurrentTrip { trip in
            self.trip = trip
            guard let state = trip.state else { return }
            guard let driverUid = trip.driverUid else { return }
            
            switch state {
            case .requested:
                break
            case .denied: 
                self.shouldPresentLoadingView(false)
                self.presentAlertController(withTitle: "Oops", message: "Это выглядет так, что водитель не найден, попробуйте еще раз!")
                PassengerService.shared.deleteTrip { (err, ref) in
                    self.centerMapOnUserLocation()
                    self.configureActionButton(config: .showMenu)
                    self.inputActivationView.alpha = 1
                    self.removeAnnotationsAndOverlays()
                }
            case .accepted:
                self.shouldPresentLoadingView(false)
                self.removeAnnotationsAndOverlays()
                
                self.zoomForActiveTrip(withDriverUid: driverUid)
                
                Service.shared.fetchUserData(uid: driverUid, completion: { driver in
                    self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: driver)
                })
            case .driverArrived:
                self.rideActionView.config = .driverArrived
            case .inProgress:
                self.rideActionView.config = .tripInProgress
            case .arrivedAtDestination:
                self.rideActionView.config = .endTrip
            case .completed:
                PassengerService.shared.deleteTrip { (err, ref) in
                    self.animateRideActionView(shouldShow: false)
                    self.centerMapOnUserLocation()
                    self.configureActionButton(config: .showMenu)
                    self.inputActivationView.alpha = 1
                    self.presentAlertController(withTitle: "Trip Completed", message: "Мы надеямся что вы были довольны поездкой")
                }
            }
        }
    }
    
    //MARK: - Drivers API
    
    func observeTrips() {
        DriverService.shared.observeTrips { trip in
            self.trip = trip
        }
    }
    
    func observeCancelledTrip(trip: Trip){
        DriverService.shared.observeTripCancelled(trip: trip) {
            self.removeAnnotationsAndOverlays()
            self.animateRideActionView(shouldShow: false)
            self.mapView.zoomToFit(annotations: self.mapView.annotations)
            self.centerMapOnUserLocation()
            self.presentAlertController(withTitle: "Упс..!", message: "Пассажир отменил поездку")
        }
    }
    
    
    
    
    //MARK: - helper function
    
    fileprivate func configureActionButton(config: ActionButtonConfiguration) {
        switch config {
        case .showMenu:
            self.actionButton.setImage(#imageLiteral(resourceName: "Hamburger_icon").withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu
        case .dismissActionView:
            actionButton.setImage(#imageLiteral(resourceName: "backButton").withRenderingMode(.alwaysOriginal), for: .normal)
            actionButtonConfig = .dismissActionView
        }
       
    }
    
    func configureSavedUserLocations() {
        guard let user = user else { return }
        savedLocations.removeAll()
        
        if let homeLocation = user.homeLocation {
            geocodeAddressString(address: homeLocation)
        }
        
        if let workLocation = user.workLocation {
            geocodeAddressString(address: workLocation)
        }
    }
    
    func geocodeAddressString(address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            guard let clplacemark = placemarks?.first else { return }
            let placemark = MKPlacemark(placemark: clplacemark)
            self.savedLocations.append(placemark)
            self.tableView.reloadData()
        }
    }
    
    func configureUI(){
        configureMapView()
        configureRideActionView()
        
        view.addSubview(actionButton)
        actionButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor, paddingTop: 16,paddingLeft: 20, width: 30, height: 30)
       
        configureTableView()
    }
    
    func configureLocationInputActivationView(){
        view.addSubview(inputActivationView)
        inputActivationView.centerX(inView: view)
        inputActivationView.setDimension(height: 50, width: view.frame.width - 64)
        inputActivationView.anchor(top: actionButton.bottomAnchor, paddingTop: 32)
        inputActivationView.alpha = 0
        inputActivationView.delegate = self
        UIView.animate(withDuration: 2){
                   self.inputActivationView.alpha = 1
               }
    }
    
    func configureMapView() {
        
        
        view.addSubview(mapView)
        mapView.frame = view.frame
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.delegate = self
    }
    func configureLocationInputView(){
        locationInputView.delegate = self
        view.addSubview(locationInputView)
        locationInputView.anchor(top: view.topAnchor, left: view.leftAnchor, right: view.rightAnchor, height: locationInputViewHeight)
        locationInputView.alpha = 0
        
        UIView.animate(withDuration: 0.5, animations: {
            self.locationInputView.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, animations: {
                self.tableView.frame.origin.y = self.locationInputViewHeight
            })
        }
    }
    
    func configureRideActionView() {
        view.addSubview(rideActionView)
        rideActionView.delegate = self
        rideActionView.frame = CGRect(x: 0, y: view.frame.height,
                                      width: view.frame.width, height: rideActionViewHeight)
    }
    
    func configureTableView(){
        tableView.delegate =  self
        tableView.dataSource = self
        
        tableView.register(LocationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.rowHeight = 60
        tableView.tableFooterView = UIView()
        
        let height = view.frame.height - locationInputViewHeight
        tableView.frame = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: height)
        
        tableView.backgroundColor = .red
        view.addSubview(tableView)
    }
    func dissmisLocationView(completion: ((Bool) -> Void)? = nil){
        UIView.animate(withDuration: 0.3, animations: {
            self.locationInputView.alpha = 0
            self.tableView.frame.origin.y = self.view.frame.height
            self.locationInputView.removeFromSuperview()
        }, completion:  completion)
    }
    
    func animateRideActionView(shouldShow: Bool, destination: MKPlacemark? = nil, config: RideActionViewConfiguration? = nil, user: User? = nil) {
        let yOrigin  = shouldShow ? self.view.frame.height - self.rideActionViewHeight : self.view.frame.height
        
        UIView.animate(withDuration: 0.3) {
                       self.rideActionView.frame.origin.y = yOrigin
                   }
        if shouldShow {
            guard let config = config else { return }
            
            if let destination = destination {
                rideActionView.destination = destination
            }
            if let user = user {
                rideActionView.user = user
            }
            
            rideActionView.config = config
        }
    }
}

//MARK: - MapView helper function
private extension HomeController {
    
    func searchBy(naturalLanguageQuery: String, completion: @escaping([MKPlacemark]) -> Void){
        var results  = [MKPlacemark]()
        
        let request = MKLocalSearch.Request()
        request.region = mapView.region
        request.naturalLanguageQuery = naturalLanguageQuery
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else { return }
            
            response.mapItems.forEach({item in
                results.append(item.placemark)
            })
            completion(results)
        }
    }
    
    func generatePolyLine(toDestination destination: MKMapItem) {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = .automobile
        
        let directionRequest = MKDirections(request: request)
        directionRequest.calculate { (response, error) in
            guard let response = response else { return }
            self.route = response.routes[0]
            guard let polyline = self.route?.polyline else { return }
            self.mapView.addOverlay(polyline)
        }
    }
    func removeAnnotationsAndOverlays() {
        mapView.annotations.forEach { (annotation) in
            if let anno = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(anno)
            }
        }
        if mapView.overlays.count > 0 {
            mapView.removeOverlay(mapView.overlays[0])
        }
    }
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager?.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
        
        mapView.setRegion(region, animated:true)
    }
    
    func setCustomRegion(withType type: AnnotationType, withCoordinates coordinates: CLLocationCoordinate2D){
        let region = CLCircularRegion(center: coordinates, radius: 25, identifier: type.rawValue)
        locationManager?.startMonitoring(for: region)
    }
    func zoomForActiveTrip(withDriverUid uid: String) {
        var annotations = [MKAnnotation]()
        
        self.mapView.annotations.forEach { (annotation) in
            if let anno = annotation as? DriverAnnotation {
                if anno.uid == uid{
                    annotations.append(anno)
                }
            }
            if let userAnno = annotation as? MKUserLocation {
                annotations.append(userAnno)
            }
        }
        self.mapView.zoomToFit(annotations: annotations)
    }
}


//MARK: - MKMapViewDelegate


extension HomeController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let user = self.user else { return }
        guard user.accountType == .driver else { return }
        guard let location = userLocation.location else { return }
        DriverService.shared.updateDriverLocation(location: location)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let view = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationIdentifier)
            view.image = #imageLiteral(resourceName: "arrowCarTaxiSmall2020")
            return view
        }
        return nil
    }
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let route = self.route {
            let polyline = route.polyline
            let lineRenderer = MKPolylineRenderer(overlay: polyline)
            lineRenderer.strokeColor = .mainBlueTint
            lineRenderer.lineWidth = 4
            return lineRenderer
        }
        return MKOverlayRenderer()
    }
}

//MARK: -CLLocationManagerDelegate

extension HomeController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        if region.identifier == AnnotationType.pickup.rawValue {
            print("DEBUG: Did start monitoring pick up region \(region)")
        }
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("DEBUG: Driver did enter passenger region")
        guard let trip = self.trip else { return }
        
        if region.identifier == AnnotationType.pickup.rawValue {
            DriverService.shared.updateTripState(trip: trip, state: .driverArrived) { (err, ref) in
                self.rideActionView.config = .pickupPassenger
            }
        }
        if region.identifier == AnnotationType.destination.rawValue {
            print("DEBUG: Did start monitoring destination region \(region)")
            
            DriverService.shared.updateTripState(trip: trip, state: .arrivedAtDestination) { (err, ref) in
                self.rideActionView.config = .endTrip
            }
        }
        
        
    }
    
    func enableLocationServices(){
        locationManager?.delegate = self
        switch CLLocationManager.authorizationStatus(){
        case .notDetermined:
            print("DEBUG: Not determined..")
            locationManager?.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedAlways:
            print("DEBUG: Auth always...")
            locationManager?.startUpdatingLocation()
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        case .authorizedWhenInUse:
            print("DEBUG: Auth when in use ...")
            locationManager?.requestAlwaysAuthorization()
        @unknown default:
            break
        }
    }
}

//MARK: LocationInputActivationViewDelegate
extension HomeController: LocationInputActivationViewDelegate {
    func presentLocationInputView() {
        inputActivationView.alpha = 0
        configureLocationInputView()
    }
}

//MARK: LocationInputViewDelegate
extension HomeController: LocationInputViewDelegate {
    func executeSearch(query: String) {
        searchBy(naturalLanguageQuery: query) { (results) in
            self.searchResults = results
            self.tableView.reloadData()
        }
    }
    
    
    func dismissLocationInputView() {
        dissmisLocationView { _ in
            UIView.animate(withDuration: 0.5, animations: {
                self.inputActivationView.alpha = 1
            })
        }
    }
}

//MARK: UITableViewDelegate/UITableViewDataSource
extension HomeController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Мои места" : "Поиск места"
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
       /* if section == 0 {
            return savedLocations.count
        } else {
            searchResults.count
        }*/
        return section == 0 ? savedLocations.count : searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as!
        LocationCell
        
        if indexPath.section == 0 {
            cell.placemark = savedLocations[indexPath.row]
        }
        
        if indexPath.section == 1{
            cell.placemark = searchResults[indexPath.row]
        }
        
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedPlaceMark = indexPath.section == 0 ? savedLocations[indexPath.row] : searchResults[indexPath.row]
        
        configureActionButton(config: .dismissActionView)
        
        let destination = MKMapItem(placemark: selectedPlaceMark)
        generatePolyLine(toDestination: destination)
        //print("DEBUG: selected row is \(indexPath.row)")
        
        dissmisLocationView { _ in
            self.mapView.addAnnotationAndSelect(forCoordinate: selectedPlaceMark.coordinate)
            
            let annotations = self.mapView.annotations.filter ({ !$0.isKind(of: DriverAnnotation.self)})
            //self.mapView.showAnnotations(annotations, animated: true)
            self.mapView.zoomToFit(annotations: annotations)
            
            self.animateRideActionView(shouldShow: true, destination: selectedPlaceMark, config: .requestRide)
            //self.rideActionView.destination = selectedPlaceMark
        }
    }
}

// MARK: - RideActionViewDelegate

extension HomeController: RideActionViewDelegate {
    
    func cancelTrip() {
        PassengerService.shared.deleteTrip { (error, ref) in
            if let error = error {
                print("DEBUG: Error deleting trip...\(error.localizedDescription)")
                return
            }
            
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
            self.removeAnnotationsAndOverlays()
            
            self.actionButton.setImage(#imageLiteral(resourceName: "Hamburger_icon").withRenderingMode(.alwaysOriginal), for: .normal)
            self.actionButtonConfig = .showMenu
            
            self.inputActivationView.alpha = 0
        }
    }
    func pickupPassenger() {
           startTrip()
       }
    func dropOffPassenger() {
        guard let trip = self.trip else { return }
        DriverService.shared.updateTripState(trip: trip, state: .completed) { (err, ref) in
            self.removeAnnotationsAndOverlays()
            self.centerMapOnUserLocation()
            self.animateRideActionView(shouldShow: false)
        }
    }
    
    func uploadTrip(_ view: RideActionView) {
        guard let pickupCoordinates = locationManager?.location?.coordinate else { return }
        guard let destinationCoordinates = view.destination?.coordinate else { return }
        
        shouldPresentLoadingView(true, message: "Finding you a ride ..")
        
        PassengerService.shared.uploadTrip(pickupCoordinates, destinationCoordinates){ (err, ref) in
            if let error = err { 
                print("DEBUG: Failed to upload trip with error \(error)")
                return
            }
            
            UIView.animate(withDuration: 0.3, animations: {
                self.rideActionView.frame.origin.y = self.view.frame.height
            })
            
        }
    }

}

// MARK: - PickupControllerDelegate

extension HomeController: PickupControllerDelegate {
    func didAcceptTrip(_ trip: Trip) {
        self.trip = trip
        
        self.mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)
        
        setCustomRegion(withType: .pickup, withCoordinates: trip.pickupCoordinates)
        
        let placemark = MKPlacemark(coordinate: trip.pickupCoordinates)
        let mapItem = MKMapItem(placemark: placemark)
        generatePolyLine(toDestination: mapItem)
        
        mapView.zoomToFit(annotations: mapView.annotations)
        
        observeCancelledTrip(trip: trip)

        self.dismiss(animated: true) {
            Service.shared.fetchUserData(uid: trip.passengerUid, completion: { passenger in
                self.animateRideActionView(shouldShow: true, config: .tripAccepted, user: passenger)
            })
        }
    }
    
}
