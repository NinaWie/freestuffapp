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
        if #available(iOS 13.0, *) {
            let key = artwork.subcategory.isEmpty ? artwork.category : artwork.subcategory
            if let symbolName = categorySymbolMap[key] {
                glyphImage = UIImage(systemName: symbolName)
            } else {
                glyphImage = UIImage(systemName: "questionmark.circle") // fallback
            }

        }
        
        // Create view when marker is pressed
        let identifier = "marker"
        var view: MKMarkerAnnotationView
        view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.canShowCallout = true
        view.calloutOffset = CGPoint(x: -5, y: 5)
        
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
