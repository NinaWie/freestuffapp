//
//  ViewController.swift
//  FreeStuff
//

import UIKit
import MapKit
import CoreLocation
import Contacts
import SwiftUI

let locationManager = CLLocationManager()
let LAT_DEGREE_TO_KM = 110.948
let closeNotifyDist = 0.3 // in km, send "you are very close" at this distance
var radius = 20.0
let MAX_AREA_DEGREES: Double = 1.0


@available(iOS 13.0, *)
class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var PennyMap: MKMapView!
    @IBOutlet weak var ownLocation: UIButton!
    @IBOutlet var toggleMapButton: UIButton!
    
    @IBOutlet weak var newStuffButton: UIButton!
    @IBOutlet weak var navigationbar: UINavigationItem!
    
    //    For search results
    @IBOutlet var searchFooter: SearchFooter!
    @IBOutlet var searchFooterBottomConstraint: NSLayoutConstraint!
    @IBOutlet var tableView: UITableView!
    
    @IBOutlet weak var settingsbutton: UIButton!
    
    let regionInMeters: Double = 10000
    // Array for annotation database
    var artworks: [Artwork] = []
    var pinIdDict : [String:Int] = [:]
    var selectedPin: Artwork?
    
    // Searchbar variables
    let searchController = UISearchController(searchResultsController: nil)
    var filteredArtworks: [Artwork] = []
    var pastNearby : Array<Int> = []
    // this variable is to notify once when we are very close to a machine (-1 as placeholder)
    var lastClosestID: Int = -1
    
    // To display the search results
    lazy var locationResult : UITableView = UITableView(frame: PennyMap.frame)
    var tableShown: Bool = false
    
    //  Map type + button
    var currMap = 1
    let satelliteButton = UIButton(frame: CGRect(x: 10, y: 510, width: 50, height: 50))
    @IBOutlet weak var mapType : UISegmentedControl!
    
    // cache data
    var lastFetchedBounds: (neLat: Double, neLng: Double, swLat: Double, swLng: Double)?
    var timeLastFetched: Date? = nil


    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        self.navigationbar.standardAppearance = UINavigationBarAppearance()
        self.navigationbar.standardAppearance?.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]


        // Do any additional setup after loading the view, typically from a nib.
        artworks = Artwork.artworks()

        
        // Set up search bar
        searchController.searchResultsUpdater = self
        // Results should be displayed in same searchbar as used for searching
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search posting"
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.searchBar.overrideUserInterfaceStyle = .light
        // iOS 11 compatability issue
        navigationItem.searchController = searchController
        // Disable search bar if view is changed
        definesPresentationContext = true
        
        // config button
        let configButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(configButtonTapped)
        )
        configButton.tintColor = .black
        navigationItem.rightBarButtonItem = configButton
        
        // about button
        let aboutButton = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(aboutButtonTapped)
        )
        aboutButton.tintColor = .black
        navigationItem.leftBarButtonItem = aboutButton
        
        // Check and enable localization (blue dot)
        checkLocationServices()
        
        // Map initialization goes here:
        setDelegates()
        
        // Register the functions to create annotated pins
        PennyMap.register(
            ArtworkMarkerView.self,
            forAnnotationViewWithReuseIdentifier:MKMapViewDefaultAnnotationViewReuseIdentifier
        )

        let button = UIButton()
        button.frame = CGRect(x: 150, y: 150, width: 100, height: 50)
        self.view.addSubview(button)
        
        addMapTrackingButton()
        addSettingsButton()
        toggleMapTypeButton()
        addNewButton()
    
        // Check whether version is new
        VersionManager.shared.showVersionInfoAlertIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // check if a machine was deleted
        if PinViewController.wasDeleted {
            loadPins(checkRegionChange: false)
            PinViewController.wasDeleted = false
        }

        // each time the view appears, check colours of the pins -> maybe add again to mark pins as favourite
//        check_json_dict()
        // check whether some setting has changed, if yes, reload all data on the map
        if #available(iOS 14.0, *) {
            if FilterViewController.hasChanged {
                loadPins(checkRegionChange: false)
                FilterViewController.hasChanged = false
            }
        }
        if SettingsViewController.clusterHasChanged {
            PennyMap.removeAnnotations(artworks)
            addAnnotationsIteratively()
            SettingsViewController.clusterHasChanged = false
        }
    }
    
    func addAnnotationsIteratively() {
        PennyMap.addAnnotations(artworks)
        
//     DEPRECATED code for adding artworks one by one and checking for filter, instead of loading just the relevant ones from the database
//        let relevantUserDefauls : [String] = ["showGoodsSwitch", "showFoodSwitch"]
//        var includedStates : [String] = []
//        for userdefault in relevantUserDefauls {
//            let user_settings = UserDefaults.standard
//            let value = (user_settings.value(forKey: userdefault) as? Bool ?? default_switches[userdefault])
//            if value! {
//                let partStr = String( userdefault.prefix(userdefault.count - 6))
//                includedStates.append(partStr)
//            }
//        }
//
//        for artwork in artworks {
//            let categoryToSwitch = "show\(artwork.category)"
//            if (includedStates.contains(categoryToSwitch)) {
//                    PennyMap.addAnnotation(artwork)
//            } else if (!includedStates.contains(categoryToSwitch)) {
//                PennyMap.removeAnnotation(artwork)
//            }
//        }
        
    }
    
    func setDelegates(){
        PennyMap.delegate = self
        PennyMap.showsScale = true
        PennyMap.showsPointsOfInterest = true
        locationResult.delegate = self
        locationResult.dataSource = self
        searchController.searchBar.delegate = self
    }
    
    
    // center to own location
    func addMapTrackingButton(){
        let image = UIImage(systemName: "location", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold, scale: .large))?.withTintColor(.white)
        ownLocation.backgroundColor = .white
        ownLocation.layer.cornerRadius = 0.5 * ownLocation.bounds.size.width
        ownLocation.clipsToBounds = true
        ownLocation.setImage(image, for: .normal)
        ownLocation.imageView?.contentMode = .scaleAspectFit
        ownLocation.addTarget(self, action: #selector(ViewController.centerMapOnUserButtonClicked), for: .touchUpInside)
        
        addShadow(button: ownLocation)
        
        PennyMap.addSubview(ownLocation)
    }
    
    func addSettingsButton(){
        let image = UIImage(systemName: "line.3.horizontal.decrease", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold, scale: .large))?.withTintColor(.gray)
        settingsbutton.backgroundColor = .white
        settingsbutton.layer.cornerRadius = 0.5 * settingsbutton.bounds.size.width
        settingsbutton.clipsToBounds = true
        settingsbutton.setImage(image, for: .normal)
        settingsbutton.imageView?.contentMode = .scaleAspectFit

        // Add shadow
        addShadow(button: settingsbutton)

        PennyMap.addSubview(settingsbutton)
    }
    
    @objc func configButtonTapped() {
        // go to configuration screen
        self.performSegue(withIdentifier: "ShowSettingsViewController", sender: self)
    }
    
    @objc func aboutButtonTapped() {
        // go to about screen
        self.performSegue(withIdentifier: "ShowAboutViewController", sender: self)
    }
    
    func addNewButton(){
        let image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold, scale: .large))?.withTintColor(.gray)
        newStuffButton.setTitle("", for: .normal)
        newStuffButton.backgroundColor = .white
        newStuffButton.layer.cornerRadius = 0.5 * newStuffButton.bounds.size.width
        newStuffButton.clipsToBounds = true
        newStuffButton.setImage(image, for: .normal)
        newStuffButton.imageView?.contentMode = .scaleAspectFit

        newStuffButton.addTarget(self, action: #selector(postNewStuff), for: .touchUpInside)
        
        addShadow(button: newStuffButton)

        PennyMap.addSubview(newStuffButton)
    }
    
    @objc func postNewStuff(){
        if #available(iOS 14.0, *) {
            let coordinate = FreeStuff.locationManager.location!.coordinate
            let view = NewMachineFormView(
                coordinate: coordinate,
                onPostComplete: {
                    self.loadPins(checkRegionChange: false)
                }
            )
            let swiftUIViewController = UIHostingController(rootView: view)
            present(swiftUIViewController, animated: true)
        }
    }
    
    
    func toggleMapTypeButton(){
        
        var toggleMapImage:UIImage = UIImage(named: "map_symbol_without_border")!
        toggleMapImage = toggleMapImage.withRenderingMode(UIImage.RenderingMode.alwaysOriginal)
        toggleMapButton.setImage(toggleMapImage, for: .normal)
        toggleMapButton.imageView?.contentMode = .scaleAspectFit
        toggleMapButton.addTarget(self, action: #selector(changeMapType), for: .touchUpInside)
        addShadow(button: toggleMapButton)
        
        self.view.addSubview(toggleMapButton)
    }
    
    func addShadow(button: UIButton) {
        // Add shadow
        button.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        button.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        button.layer.shadowOpacity = 1.0
        button.layer.shadowRadius = 0.0
        button.layer.masksToBounds = false
//        button.layer.cornerRadius = 4.0
    }

    @objc func centerMapOnUserButtonClicked() {
        self.PennyMap.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
    }
    
    // Check if global location services are enabled
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            // Show alert to tell user to turn on location services
        }
    }

    func setupLocationManager(){
        FreeStuff.locationManager.delegate = self
        FreeStuff.locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // Check whether this app has location permission
    func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus(){
        case .authorizedWhenInUse:
            PennyMap.showsUserLocation = true
            centerViewOnUserLocation()
            //locationManager.startUpdatingLocation()
            break
        case .denied:
            // Show alert instructing how to turn on permissions
            break
        case .notDetermined:
            FreeStuff.locationManager.requestWhenInUseAuthorization()
            break
        case .restricted:
            // Show alert that location can not be accessed
            break
        case .authorizedAlways:
            PennyMap.showsUserLocation = true
            centerViewOnUserLocation()
            break
        }
    }
    
    // Set the initial map location
    func centerViewOnUserLocation() {
        // Default to user location if accessible
        if let location = FreeStuff.locationManager.location?.coordinate{
            let region = MKCoordinateRegion.init(
                center:location,
                latitudinalMeters: regionInMeters,
                longitudinalMeters: regionInMeters
            )
            PennyMap.setRegion(region, animated: true)
        } else { // goes to Uetliberg otherwise
            let location = CLLocationCoordinate2D(
                latitude: 47.349586,
                longitude: 8.491197
            )
            let region = MKCoordinateRegion.init(
                center:location,
                latitudinalMeters: regionInMeters,
                longitudinalMeters: regionInMeters
            )
            PennyMap.setRegion(region, animated: true)
        }
    }
    
    func check_json_dict(){
        // initialize empty status dictionary
        var statusDict = [[String: String]()]
        //variable indicating whether we load something
        var is_empty = true
        // whole stuff required to read file
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let documentsDirectoryPath = NSURL(string: documentsDirectoryPathString)!
        let jsonFilePath = documentsDirectoryPath.appendingPathComponent("pin_status.json")
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: jsonFilePath!.absoluteString, isDirectory: &isDirectory) {
//            print("file path exists, try load data")
            do{
                let data = try Data(contentsOf: URL(fileURLWithPath: jsonFilePath!.absoluteString), options:.mappedIfSafe)
                
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                statusDict = jsonResult as! [[String:String]]
                is_empty = false
            }
            catch{
                print("file already exists but could not be read", error)
            }
        }
        // If we have saved some already:
        if !is_empty{
            let ids_in_dict = Array(statusDict[0].keys)
            // iterate over saved IDs and update status on map
            for id_machine in ids_in_dict{
                let machine = artworks[pinIdDict[id_machine]!]
                PennyMap.removeAnnotation(machine)
                let thisMachineStatus = statusDict[0][machine.id] ?? "unvisited"
                machine.status = thisMachineStatus
                // Only add the machine back to the map if it is supposed to be shown (according to settings)
                let user_settings = UserDefaults.standard
                let userdefault = thisMachineStatus+"Switch"
                // get userdefault (use default if not set yet)
                let shouldDisplayMachine = (user_settings.value(forKey: userdefault) as? Bool ?? default_switches[userdefault])
                // add pin if necessary
                if shouldDisplayMachine! {
                    PennyMap.addAnnotation(machine)
                }
            }
        }
    }
    
    // To load machine locations from JSON
    @available(iOS 13.0, *)
    func loadPins(checkRegionChange: Bool = true) {
        // get region
        let region = PennyMap.region
        let center = region.center
        let span = region.span

        let neLat = center.latitude + span.latitudeDelta / 2
        let neLng = center.longitude + span.longitudeDelta / 2
        let swLat = center.latitude - span.latitudeDelta / 2
        let swLng = center.longitude - span.longitudeDelta / 2
        
        let area = abs(neLat - swLat) * abs(neLng - swLng)
        if area > MAX_AREA_DEGREES {
            showAlert(title: "Region Too Large", message: "Please zoom in to a smaller area.")
        }
        
        // Check if the current view is inside the last fetched bounds
        if checkRegionChange && isNewRegionInsideLastBounds(neLat: neLat, neLng: neLng, swLat: swLat, swLng: swLng) {
            return
        }
        
        // clear existing data
        if artworks.count > 0 {
            PennyMap.removeAnnotations(artworks)
            artworks = []
        }

        // get userSettings
        let userSettings = UserDefaults.standard
        // for first time usage only:
        if userSettings.object(forKey: "showGoodsSwitch") == nil {
            userSettings.set(true, forKey: "showGoodsSwitch")
            userSettings.set(true, forKey: "showFoodSwitch")
            userSettings.set("All", forKey: "selectedGoodsCategory")
            userSettings.set("All", forKey: "selectedFoodCategory")
            userSettings.set(maxDaysToExpiration, forKey: "timePostedMax")
            userSettings.set(true, forKey: "showPermanentSwitch")
        }
        let showGoods = userSettings.bool(forKey: "showGoodsSwitch")
        let showFood = userSettings.bool(forKey: "showFoodSwitch")
        let goodsSubcategory = userSettings.string(forKey: "selectedGoodsCategory") ?? "All"
        let foodSubcategory = userSettings.string(forKey: "selectedFoodCategory") ?? "All"
        let timePostedMax = userSettings.float(forKey: "timePostedMax")
        let showPermanent = userSettings.bool(forKey: "showPermanentSwitch")

        // Construct the URL with query parameters
        var urlComponents = URLComponents(string: "\(flaskURL)/postings.json")!
        urlComponents.queryItems = [
            URLQueryItem(name: "nelat", value: "\(neLat)"),
            URLQueryItem(name: "nelng", value: "\(neLng)"),
            URLQueryItem(name: "swlat", value: "\(swLat)"),
            URLQueryItem(name: "swlng", value: "\(swLng)"),
            URLQueryItem(name: "showGoods", value: showGoods ? "1" : "0"),
            URLQueryItem(name: "showFood", value: showFood ? "1" : "0"),
            URLQueryItem(name: "goodsSubcategory", value: goodsSubcategory),
            URLQueryItem(name: "foodSubcategory", value: foodSubcategory),
            URLQueryItem(name: "timePostedMax", value: "\(timePostedMax)"),
            URLQueryItem(name: "showPermanent", value: showPermanent ? "1": "0")
        ]

        guard let jsonUrl = urlComponents.url else { return }

        let task = URLSession.shared.dataTask(with: jsonUrl) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.showAlert(title: "Network Error", message: error.localizedDescription)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.showAlert(title: "Network Error", message: "No data could be loaded")
                }
                return
            }

            do {
                let serverJsonAsMap = try MKGeoJSONDecoder()
                    .decode(data)
                    .compactMap { $0 as? MKGeoJSONFeature }

                // Store last bounds to prevent redundant calls later
                self.lastFetchedBounds = (neLat: neLat, neLng: neLng, swLat: swLat, swLng: swLng)
                
                let pinsFromServer = serverJsonAsMap.compactMap(Artwork.init)

                // Update on main thread
                DispatchQueue.main.async {
                    self.artworks.append(contentsOf: pinsFromServer)
                    for (ind, pin) in self.artworks.enumerated() {
                        self.pinIdDict[pin.id] = ind
                    }
                    self.addAnnotationsIteratively()
                }

            } catch {
                print("Error decoding JSON:", error)
            }
        }
        task.resume()
    }
    
    // Helper function to show an alert
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func isNewRegionInsideLastBounds(neLat: Double, neLng: Double, swLat: Double, swLng: Double) -> Bool {
        guard let bounds = lastFetchedBounds else {
            return false
        }

        return neLat <= bounds.neLat &&
               neLng <= bounds.neLng &&
               swLat >= bounds.swLat &&
               swLng >= bounds.swLng
    }

    
    // Search bar functionalities
    var isSearchBarEmpty: Bool {
      return searchController.searchBar.text?.isEmpty ?? true
    }
    
    // Implements the search itself
    func filterContentForSearchText(_ searchText: String,
                                    category: Artwork? = nil) {
    filteredArtworks = artworks.filter { (artwork: Artwork) -> Bool in
        return artwork.text.lowercased().contains(searchText.lowercased())
        }
        filteredArtworks = filteredArtworks.sorted(by: {$0.title! < $1.title! })
        
        // This sets the table view frame to cover exactly the entire underlying map
        locationResult.frame = PennyMap.bounds
        
        // Default height of table view cell is 44 - locationResult.rowHeight does not work
        let height = CGFloat(filteredArtworks.count * 44)
        if height < PennyMap.bounds.height{
            var tableFrame = locationResult.frame
            tableFrame.size.height = height
            locationResult.frame = tableFrame
        }
        
        if !tableShown {
            PennyMap.addSubview(locationResult)
            tableShown = true
        }
        locationResult.reloadData()
    }
    
    // Whether we are currently filtering
    var isFiltering: Bool {
      return searchController.isActive && !isSearchBarEmpty
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "ShowPinViewController") {
            let destinationViewController = segue.destination as! PinViewController
            destinationViewController.pinData = self.selectedPin!
        }
        
    }
    
    @objc func changeMapType(sender: UIButton!) {
         switch currMap{
             case 1:
                PennyMap.mapType = .satellite
                 currMap = 2
             case 2:
                PennyMap.mapType = .hybrid
                 currMap = 3
             default:
                PennyMap.mapType = .standard
                 currMap = 1
         }
    }
}


@available(iOS 13.0, *)
extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.calloutTapped))
        view.addGestureRecognizer(gesture)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        // Call backend on every update of the region
        loadPins()
    }

    @objc func calloutTapped(sender:UITapGestureRecognizer) {
        guard let annotation = (sender.view as? MKAnnotationView)?.annotation as? Artwork else { return }

        let selectedLocation = annotation.title
        // set selected pin to pass it to detail VC
        self.selectedPin = annotation
        self.performSegue(withIdentifier: "ShowPinViewController", sender: self)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        //     callout when maps button is pressed
        let location = view.annotation as! Artwork
        if (control == view.rightCalloutAccessoryView) {
            // This would open the directions
            let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            location.mapItem().openInMaps(launchOptions: launchOptions)
        }
        else {
            self.performSegue(withIdentifier: "ShowPinViewController", sender: nil)
        }
    }
}




// Global handling of GPS  localization issues
@available(iOS 13.0, *)
extension ViewController: CLLocationManagerDelegate {
    // location manager fail
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
       manager.stopMonitoringSignificantLocationChanges()
        print("Stopped monitoring because of error", error)
        return
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations : [CLLocation]) {
        // Update position on map
        guard let location = locations.last else {return}

        // Get closest pins
        let lonCurrent = location.coordinate.longitude // 168.823 // 8.5490 // here are we!
        let latCurrent =  location.coordinate.latitude // -44.9408  // 47.3899
        let (pennyCounter, minDist, closestID, foundIndices) = getCandidates(artworks: artworks, curLat: latCurrent, curLon: lonCurrent, radius:radius)
//        print("Found", pennyCounter, "machines, the closest is", minDist, closestID, artworks[closestID].title)
        // check whether we have found any new machines
        let doPush = determinePush(currentNearby: foundIndices)
        if doPush && (pennyCounter > 0){
            let notificationString = "There are \(pennyCounter) machines nearby. The closest is \(round(minDist * 10)/10)km away \(artworks[closestID].title!)"
            pushNotification(notificationString: notificationString)
        }
        // push with other notification if one is really close
        // Do this only once (variable sendVeryCloseNotification)
        if pennyCounter > 0 && minDist < closeNotifyDist && closestID != lastClosestID{
            let notificationString = "You are very close to a Penny! It is only \(round(minDist * 10)/10)km away \(artworks[closestID].title!)"
            pushNotification(notificationString: notificationString)
            // this is to prevent that the "nearby" notification is sent only once (per location)
            lastClosestID = closestID
        }
    }
    
    // Send user a local notification if they have the app running in the bg
    func pushNotification(notificationString: String) {
        // print("SENT PUSH", notificationString)
        let notification = UILocalNotification()
        notification.alertAction = "Check FreeStuff"
        notification.alertBody = notificationString
        notification.fireDate = Date(timeIntervalSinceNow: 1)
        UIApplication.shared.scheduleLocalNotification(notification)
    }
    
    func determinePush(currentNearby:Array<Int>) -> Bool {
        // Decide whether a push notification is sent to the user.
        // If any of the found nearby machines has not been nearby at previous lookup, send a notification.
        var doPush = false
        for i in currentNearby {
            if !pastNearby.contains(i) {
                doPush = true
                break
            }
        }
        self.pastNearby = currentNearby
        return doPush
    }

    // Function to measure distances to pins
    func getCoordinateRange(lat: Double, long: Double, radius: Double) -> (Double, Double, Double, Double) {
        
        // Determine the range of latitude/longitude values that we have to search
        let latDegreeChange = radius / LAT_DEGREE_TO_KM
        let longDegreeChange = radius / (LAT_DEGREE_TO_KM * cos(lat*(Double.pi/180)))
        let minLat = lat - latDegreeChange
        let maxLat = lat + latDegreeChange
        let minLong = long - longDegreeChange
        let maxLong = long + longDegreeChange
        
        return (minLat, maxLat, minLong, maxLong)
    }
    
    func searchLatIndex(artworks: [Artwork], minLat: Double, curIndex: Int, totalIndex: Int) -> Int{
        let curLength = artworks.count
        if curLength == 1{
            return totalIndex
        }
        if artworks[curIndex].coordinate.latitude > minLat{
            let nextIndex = Int(curIndex/2)
            return searchLatIndex(artworks: Array(artworks[0..<curIndex]), minLat: minLat, curIndex: nextIndex, totalIndex: totalIndex - curIndex + nextIndex)
        }
        else if artworks[curIndex].coordinate.latitude < minLat{
            let nextMiddle = (Double(curLength-curIndex)/2.0)
            let nextIndex = Int(ceil(nextMiddle))
            return searchLatIndex(artworks: Array(artworks[curIndex..<curLength]), minLat: minLat, curIndex: nextIndex, totalIndex: nextIndex + totalIndex)
        }
        else{
            return totalIndex
        }
    }

    func getCandidates(artworks: [Artwork], curLat:Double, curLon: Double, radius: Double) -> (Int, Double, Int, [Int]){
        let (minLat, maxLat, minLon, maxLon) = getCoordinateRange(lat: curLat, long: curLon, radius: radius)
//        print("min and max", (minLat, maxLat, minLon, maxLon))
        
        let guess = Int(artworks.count/2)
        let startIndex = searchLatIndex(artworks: artworks, minLat: minLat, curIndex: guess, totalIndex: guess)

        // helpers
        var lat: Double
        var lon: Double
        var index = startIndex
        // returns
        var minDist = radius
        var pennyCounter = 0
        var closestID = 0
        var foundIndices: [Int] = []
        
        // iterate over artworks
        for artwork in artworks[startIndex..<artworks.count] {
            lat = artwork.coordinate.latitude
            lon = artwork.coordinate.longitude
            if lat > maxLat {
                break
            }

            // Check whether the pin is in the square
            if minLon < lon && lon < maxLon && artwork.status == "unvisited"{
                let distance = GeoUtils.haversineDistance(
                    lat1: curLat,
                    lon1: curLon,
                    lat2: lat,
                    lon2: lon
                )
                let distInKm = distance/1000
                // check whether in circle
                if distInKm < radius{
                    pennyCounter += 1
                    if distInKm < minDist{
                        minDist = distInKm
                        closestID = index
                    }
                    foundIndices.append(index)
                }
            }
            index += 1

        }
        return (pennyCounter, minDist, closestID, foundIndices)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // called if authorization has changed
        checkLocationAuthorization()
    }
}


// Searchbar updating
@available(iOS 13.0, *)
extension ViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    let searchBar = searchController.searchBar
    
    // Display the penny pin options and execture the search only if a string is entered
    // Makes sure that list is not displayed if cancel is pressed
    if searchBar.text!.count > 0 {
        filterContentForSearchText(searchBar.text!)
    }
    
  }
}

@available(iOS 13.0, *)
extension ViewController: UISearchBarDelegate {
    
    //  Cancel button execution
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        locationResult.removeFromSuperview()
        tableShown = false
    }

}

// Table with search results
@available(iOS 13.0, *)
extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "location")
        
//        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let artwork: Artwork
        if isFiltering {
          artwork = filteredArtworks[indexPath.row]
        } else {
          artwork = artworks[indexPath.row]
        }
        cell.textLabel?.text = artwork.title
        cell.detailTextLabel?.text = artwork.shortDescription
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering {
          return filteredArtworks.count
        }
        return artworks.count
      if isFiltering {
        searchFooter.setIsFilteringToShow(filteredItemCount:
          filteredArtworks.count, of: artworks.count)
        return filteredArtworks.count
      }

      searchFooter.setNotFiltering()
      return artworks.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        self.selectedPin = filteredArtworks[indexPath.row]
        let center = self.selectedPin!.coordinate
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        self.PennyMap.setRegion(region, animated: true)
        locationResult.removeFromSuperview()
        tableShown = false
        searchController.searchBar.endEditing(true)
        
        self.performSegue(withIdentifier: "ShowPinViewController", sender: self)
    }
}

extension UISearchBar {

    private var textField: UITextField? {
        return subviews.first?.subviews.compactMap { $0 as? UITextField }.first
    }

    private var activityIndicator: UIActivityIndicatorView? {
        return textField?.leftView?.subviews.compactMap{ $0 as? UIActivityIndicatorView }.first
    }

    var isLoading: Bool {
        get {
            return activityIndicator != nil
        } set {
            if newValue {
                if activityIndicator == nil {
                    let newActivityIndicator = UIActivityIndicatorView(style: .gray)
                    newActivityIndicator.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                    newActivityIndicator.startAnimating()
                    newActivityIndicator.backgroundColor = UIColor.white
                    textField?.leftView?.addSubview(newActivityIndicator)
                    let leftViewSize = textField?.leftView?.frame.size ?? CGSize.zero
                    newActivityIndicator.center = CGPoint(x: leftViewSize.width/2, y: leftViewSize.height/2)
                }
            } else {
                activityIndicator?.removeFromSuperview()
            }
        }
    }
}
