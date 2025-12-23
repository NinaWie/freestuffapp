//
//  Geoutils.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 24.04.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import Foundation
import CoreLocation

class GeoUtils {
    static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double, radius: Double = 6367444.7) -> Double {
        let haversin = { (angle: Double) -> Double in
            return (1 - cos(angle)) / 2
        }

        let ahaversin = { (angle: Double) -> Double in
            return 2 * asin(sqrt(angle))
        }

        let dToR = { (angle: Double) -> Double in
            return (angle / 360) * 2 * Double.pi
        }

        let lat1Rad = dToR(lat1)
        let lon1Rad = dToR(lon1)
        let lat2Rad = dToR(lat2)
        let lon2Rad = dToR(lon2)

        return radius * ahaversin(haversin(lat2Rad - lat1Rad) + cos(lat1Rad) * cos(lat2Rad) * haversin(lon2Rad - lon1Rad))
    }
}
