//
//  Artwork.swift
//  FreeStuff
//

import Foundation
import MapKit
import Contacts

let maxHoursColorGradient: Double = 120 // pins are coloured with max 5 days

class Artwork: NSObject, MKAnnotation {
    let title: String?
    let postDescription: String
    let link: String?
    var status: String
    let coordinate: CLLocationCoordinate2D
    let id: String
    let time_posted: String
    let time_expiration: String
    let text: String
    let shortDescription: String
    let category: String
    let subcategory: String
    let photoPaths : [String]
    let userID: String
    
    init(title: String, postDescription: String, link: String, status: String, coordinate: CLLocationCoordinate2D, id: Int, time_posted: String, time_expiration: String, category: String, subcategory: String, photoPaths: [String], userID: String) {
        self.title = title
        self.postDescription = postDescription
        self.coordinate = coordinate
        self.link = link
        self.status = status
        self.id = String(id)
        self.time_posted = time_posted
        self.time_expiration = time_expiration
        self.text = self.title! + self.postDescription
        self.shortDescription = self.postDescription.count > 20 ? String(self.postDescription.prefix(20)) + "..." : self.postDescription
        self.category = category
        self.subcategory = subcategory
        self.photoPaths = photoPaths
        self.userID = userID
        
        super.init()
    }
    
    // Read in data from dictionary
    @available(iOS 13.0, *)
    init?(feature: MKGeoJSONFeature) {
      // Extract location and properties from GeoJSON object
      guard
        let point = feature.geometry.first as? MKPointAnnotation,
        let propertiesData = feature.properties,
        let json = try? JSONSerialization.jsonObject(with: propertiesData),
        let properties = json as? [String: Any]
        else {
          return nil
        }
        // Extract class variables
        title = properties["name"] as? String
        postDescription = (properties["description"] as? String)!
        link = (properties["external_url"] as? String)
        status = (properties["status"] as? String)!
        time_posted = (properties["time_posted"] as? String)!
        time_expiration = (properties["expiration_date"] as? String)!
        id = String((properties["id"] as? Int)!)
        coordinate = point.coordinate
        text = title! + postDescription
        shortDescription = postDescription.count > 20 ? String(postDescription.prefix(20)) + "..." : postDescription
        category = (properties["category"] as? String)!
        subcategory = (properties["subcategory"] as? String)!
        photoPaths = ((properties["photo_id"] as! String).components(separatedBy: ","))
        userID = (properties["user_id"] as? String)!
        
        super.init()
    }
    
    var subtitle: String? {
        return shortDescription
    }
    
    // To get directions in map
    // Annotation right callout accessory opens this mapItem in Maps app
    func mapItem() -> MKMapItem {
        let addressDict = [CNPostalAddressStreetKey: subtitle!]
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDict)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        return mapItem
    }
    
    //    func getLink() -> String {
    //        return self.link
    //    }
    
    func parseDate(_ string: String) -> Date? {
        let formats = [
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd HH:mm:ss"
            ]

            for format in formats {
                let formatter = DateFormatter()
                formatter.timeZone = .current
                formatter.dateFormat = format

                if let date = formatter.date(from: string.components(separatedBy: ".").first ?? "") {
                    return date
                }
            }

        return nil
    }

    func colorFromGreenToRed(hoursSince: Double) -> UIColor {
        
        guard maxHoursColorGradient > 0, hoursSince.isFinite else {
            return MarkerColors.palette.first ?? .systemGreen
        }

        let ratio = min(max(hoursSince / maxHoursColorGradient, 0), 1)

        let index = Int(
            floor(ratio * Double(MarkerColors.palette.count))
        )

        // Clamp index safely
        let clampedIndex = min(
            max(index, 0),
            MarkerColors.palette.count - 1
        )

        return MarkerColors.palette[clampedIndex]
    }
    
    var markerTintColor: UIColor  {
        // Handle coloring
        if status == "permanent" {
            return .blue
        } else {
            if let postDate = parseDate(time_posted) {
                // in days:
//                let daysAgo = Calendar.current.dateComponents([.day], from: postDate, to: Date()).day ?? 0
//                let col = colorForDaysAgo(daysAgo)
                let hoursAgo = Date().timeIntervalSince(postDate) / 3600
                let col = colorFromGreenToRed(hoursSince: hoursAgo)
                return col
            } else {
                return .gray // fallback
            }
        }
    }
}

extension Artwork {
  static func artworks() -> [Artwork] {
    guard
      let url = Bundle.main.url(forResource: "candies", withExtension: "json"),
      let data = try? Data(contentsOf: url)
      else {
        return []
    }
    
    do {
      return []
    } catch {
      return []
    }
  }
}

