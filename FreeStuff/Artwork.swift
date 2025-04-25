//
//  Artwork.swift
//  FreeStuff
//

import Foundation
import MapKit
import Contacts


class Artwork: NSObject, MKAnnotation {
    let title: String?
    let postDescription: String
    let link: String?
    var status: String
    let coordinate: CLLocationCoordinate2D
    let id: String
    let time_posted: String
    let text: String
    let shortDescription: String
    let category: String
    let photoPaths : [String]
    
    init(title: String, postDescription: String, link: String, status: String, coordinate: CLLocationCoordinate2D, id: Int, time_posted: String, category: String, photoPaths: [String]) {
        self.title = title
        self.postDescription = postDescription
        self.coordinate = coordinate
        self.link = link
        self.status = status
        self.id = String(id)
        self.time_posted = time_posted
        self.text = self.title! + self.postDescription
        self.shortDescription = self.postDescription.count > 20 ? String(self.postDescription.prefix(20)) + "..." : self.postDescription
        self.category = category
        self.photoPaths = photoPaths
        
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
        id = String((properties["id"] as? Int)!)
        coordinate = point.coordinate
        text = title! + postDescription
        shortDescription = postDescription.count > 20 ? String(postDescription.prefix(20)) + "..." : postDescription
        category = (properties["category"] as? String)!
        photoPaths = ((properties["photo_id"] as! String).components(separatedBy: ","))
        
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
    
    var markerTintColor: UIColor  {
      switch category {
      case "Food":
        return .green
      case "Goods":
        return .blue
      default:
        return .black
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

