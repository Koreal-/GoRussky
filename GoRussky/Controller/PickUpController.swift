//
//  PickUpController.swift
//  GoRussky
//
//  Created by Kartinin Studio on 07.07.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import UIKit
import MapKit

protocol PickupControllerDelegate: class {
    func didAcceptTrip(_ trip: Trip)
}

class PickUpController: UIViewController {
    
    weak var delegate: PickupControllerDelegate?
    
    //MARK:- PROPERTIES
    private let mapView = MKMapView()
    let trip: Trip
    
    private lazy var circlularProgressView: CircularProgressView = {
        let frame = CGRect(x: 0, y: 0, width: 360, height: 360)
        let cp = CircularProgressView(frame: frame)
        
        cp.addSubview(mapView)
        mapView.setDimension(height: 268, width: 268)
        mapView.layer.cornerRadius = 268 / 2
        mapView.centerX(inView: cp)
        mapView.centerY(inView: cp, constant: 32)
        
        return cp
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "close-icon").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleDismissal), for: .touchUpInside)
        return button
    }()
    
    private let pickupLabel: UILabel = {
        let label = UILabel()
        label.text = "Хотите ли вы принять этот заказ?"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    private let acceptTripButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Принять заказ", for: .normal)
        button.addTarget(self, action: #selector(handleAcceptTrip), for: .touchUpInside)
        return button
    }()
    
    //MARK:- LIFECYCLE
    
    init(trip:Trip) {
        self.trip = trip
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        configureMapView()
        self.perform(#selector(animateProgress), with: nil, afterDelay: 0.5)

        // Do any additional setup after loading the view.
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //MARK: - Selectors
    
    @objc func handleDismissal() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func animateProgress() {
        circlularProgressView.animatePulsatingLayer()
        circlularProgressView.setProgressWidthAnimation(duration: 11, value: 0) {
            
            DriverService.shared.updateTripState(trip: self.trip, state: .denied) { (err, ref) in
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    @objc func handleAcceptTrip() {
        DriverService.shared.acceptTrip(trip: trip) { (error, ref) in
            self.delegate?.didAcceptTrip(self.trip)
        }
    }
    
    //MARK: - API
    
    //MARK:- HELPER Functions
    func configureMapView() {
        let region = MKCoordinateRegion(center: trip.pickupCoordinates, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: false)
        
        mapView.addAnnotationAndSelect(forCoordinate: trip.pickupCoordinates)
        
       /* let anno = MKPointAnnotation()
        anno.coordinate = trip.pickupCoordinates
        mapView.addAnnotation(anno)
        self.mapView.selectAnnotation(anno, animated: true)*/
    }
    func configureUI(){
        view.backgroundColor = .backgroundColor
        
        view.addSubview(cancelButton)
        cancelButton.anchor(top: view.safeAreaLayoutGuide.topAnchor, left: view.leftAnchor,paddingTop: -70, paddingLeft: -70)
        cancelButton.transform = CGAffineTransform.identity.scaledBy(x: 0.1, y: 0.1)
        
        view.addSubview(circlularProgressView)
        circlularProgressView.setDimension(height: 360, width: 360)
        circlularProgressView.anchor(top: view.safeAreaLayoutGuide.topAnchor, paddingTop: 32)
        circlularProgressView.centerX(inView: view)
        
        view.addSubview(pickupLabel)
        pickupLabel.centerX(inView: view)
        pickupLabel.anchor(top: circlularProgressView.bottomAnchor, paddingTop: 32)
        
        view.addSubview(acceptTripButton)
        acceptTripButton.anchor(top: pickupLabel.bottomAnchor, left: view.leftAnchor, right: view.rightAnchor, paddingTop: 16, paddingLeft: 32, paddingRight: 32,height: 50)
        
    }

    
}
