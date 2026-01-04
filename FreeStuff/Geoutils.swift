//
//  Geoutils.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 24.04.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import Foundation
import CoreLocation
import SwiftUI

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

final class ZoomHintView: UIView {

    private let label: UILabel = {
        let label = UILabel()
        label.text = "Zoom in to see more results"
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = UIColor.black.withAlphaComponent(0.65)
        layer.cornerRadius = 10
        layer.masksToBounds = true

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        alpha = 0
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}
