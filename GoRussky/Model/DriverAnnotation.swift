//
//  DriverAnnotation.swift
//  GoRussky
//
//  Created by Kartinin Studio on 11.06.2020.
//  Copyright © 2020 Kartinin Studio. All rights reserved.
//

import MapKit

class DriverAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var uid: String
    
    init(uid: String, coordinate: CLLocationCoordinate2D){
        self.uid = uid
        self.coordinate = coordinate
    }
    func updateAnnotationPosition (withCoordinate coordinate: CLLocationCoordinate2D){
        UIView.animate(withDuration: 0.2){
            self.coordinate = coordinate
        }
    }
}
