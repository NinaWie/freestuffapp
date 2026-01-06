//
//  ArtworkViews.swift
//  FreeStuff
//

import Foundation
import MapKit

let categorySymbolMap: [String: String] = [
    // Main categories
    "Food": "leaf.fill",
    "Goods": "archivebox.fill",

    // Food subcategories
    "Fresh Produce": "carrot.fill",
    "Baked Goods": "birthday.cake",
    "Canned Goods": "cube.box",
    "Beverages": "cup.and.saucer",
    "Snacks": "popcorn",
    "Community fridge": "refrigerator.fill",

    // Goods subcategories
    "Electronics": "desktopcomputer",
    "Clothing": "tshirt",
    "Furniture": "sofa",
    "Books": "books.vertical",
    "Tools": "hammer"
]

class ArtworkMarkerView: MKMarkerAnnotationView {

  var clusterPins: Bool = true
  override var annotation: MKAnnotation? {

    willSet {
      // 1
      guard let artwork = newValue as? Artwork else {
        return
      }
        clusterPins = UserDefaults.standard.bool(forKey: "clusterPinSwitch")
        if !clusterPins {
            displayPriority = MKFeatureDisplayPriority.required
        }

        // Set marker color
        markerTintColor = artwork.markerTintColor

        // Set image
        let key = artwork.subcategory.isEmpty ? artwork.category : artwork.subcategory
        if let symbolName = categorySymbolMap[key] {
            glyphImage = UIImage(systemName: categorySymbolMap[key] ?? "questionmark.circle")
        }
        // Create right button
        rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        let mapsButton = UIButton(
            frame: CGRect(origin: CGPoint.zero,
            size: CGSize(width: 30, height: 30))
        )
        mapsButton.setBackgroundImage(UIImage(named: "maps"), for: UIControl.State())
        rightCalloutAccessoryView = mapsButton
        
        // Multiline subtitles
        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.font = detailLabel.font.withSize(12)
        detailLabel.text = artwork.subtitle
        detailCalloutAccessoryView = detailLabel

    }
  }
}

enum MarkerColors {

    // 10 discrete colors from green (fresh) to red (old)
    static let palette: [UIColor] = {
        let steps = 10
        return (0..<steps).map { i in
            let ratio = Double(i) / Double(steps - 1)   // 0 → 1
            let hue = (1.0 - ratio) * 0.33              // 0.33 → 0.0
            return UIColor(
                hue: hue,
                saturation: 1.0,
                brightness: 0.9,
                alpha: 1.0
            )
        }
    }()
}

