//
//  SettingsViewController.swift
//  FreeStuff
//

import UIKit
import MapKit
import CoreLocation
import Contacts

let default_switches: [String: Bool] = [
    "showGoodsSwitch": true,
    "showFoodSwitch": true,
    "clusterPinSwitch": false
]

class SettingsViewController: UITableViewController {
    
    @IBOutlet weak var navigationbar: UINavigationItem!
    @IBOutlet weak var pushSwitch: UISwitch!
    @IBOutlet weak var reportProblemButton: UIButton!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var showGoodsSwitch: UISwitch!
    @IBOutlet weak var showFoodSwitch: UISwitch!
    @IBOutlet weak var clusterPinsSwitch: UISwitch!
    
    static var hasChanged = false
    static var clusterHasChanged = false

    
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
            self.navigationbar.standardAppearance = UINavigationBarAppearance()
            self.navigationbar.standardAppearance?.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
        }
        reportProblemButton!.titleLabel?.text = "Report a problem"
        reportProblemButton.tintColor = UIColor.black
        reportProblemButton.addTarget(self, action: #selector(reportProblem), for: .touchUpInside)
        
        // push notification button
        pushSwitch.isOn =  UserDefaults.standard.bool(forKey: "switchState")
        pushSwitch.addTarget(self, action: #selector(setPushNotifications), for: .valueChanged)
        
        // slider
        radiusSlider.value =  UserDefaults.standard.float(forKey: "radius")
        radius = Double(radiusSlider.value)
        radiusSlider.addTarget(self, action: #selector(sliderValueDidChange(_:)), for: .valueChanged)
        radiusSlider.isContinuous = false
        
        // cluster switch
        let user_settings = UserDefaults.standard
        clusterPinsSwitch.isOn = user_settings.value(forKey: "clusterPinSwitch") as? Bool ?? default_switches["clusterPinSwitch"] as! Bool
        clusterPinsSwitch.addTarget(self, action: #selector(clusterPins), for: .valueChanged)
        // Machine status switches
        // 1) goods switch
        showGoodsSwitch.isOn = user_settings.value(forKey: "showGoodsSwitch") as? Bool ?? default_switches["showGoodsSwitch"] as! Bool
        showGoodsSwitch.addTarget(self, action: #selector(showGoods), for: .valueChanged)
        // 2) visied switch
        showFoodSwitch.isOn = user_settings.value(forKey: "showFoodSwitch") as? Bool ?? default_switches["showFoodSwitch"] as! Bool
        showFoodSwitch.addTarget(self, action: #selector(showFood), for: .valueChanged)
    }
    
    @objc func reportProblem (sender: UIButton!){
        let mailtostring = String(
            "mailto:wnina@ethz.ch?subject=[FreeStuff] - Problem report&body=Dear FreeStuff team,\n\n I would like to inform you about the following problem in your app:\n\n"
        ).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "error"
        UIApplication.shared.openURL(URL(string:mailtostring )!)
    }
    // Functions for Switches
    @objc func showGoods(sender:UISwitch!) {
        userdefauls_helper(defaultsKey: "showGoodsSwitch", isOn: sender.isOn)
    }
    @objc func showFood(sender:UISwitch!) {
        userdefauls_helper(defaultsKey: "showFoodSwitch", isOn: sender.isOn)
    }
    @objc func clusterPins(sender:UISwitch!) {
        userdefauls_helper(defaultsKey: "clusterPinSwitch", isOn: sender.isOn)
    }
    func userdefauls_helper(defaultsKey: String, isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        if defaultsKey == "clusterPinSwitch" {
            SettingsViewController.clusterHasChanged = true
        }
        else {
            SettingsViewController.hasChanged = true
        }
    }
    
    // Function for radius slider for push notifications
    @objc func sliderValueDidChange(_ sender:UISlider!)
    {
        radius =  Double(sender.value)
        UserDefaults.standard.set(sender.value, forKey: "radius")
        UserDefaults.standard.synchronize()
        self.tableView.reloadData()
    }
    
    @objc func setPushNotifications(sender:UISwitch!) {
        if sender.isOn{
            // Case 1: location access not enabled
            if CLLocationManager.authorizationStatus() != .authorizedAlways{
                showAlert()
                sender.isOn = false
            }
            // Case 2: location access enabled
            else{
                locationManager.startMonitoringSignificantLocationChanges()
                locationManager.allowsBackgroundLocationUpdates = true
            }
        }
        else{
            locationManager.stopMonitoringSignificantLocationChanges()
            locationManager.allowsBackgroundLocationUpdates = false
        }
        UserDefaults.standard.set(sender.isOn, forKey: "switchState")
        UserDefaults.standard.synchronize()
    }
    @IBAction func showAlert() {

            // create the alert
            let alert = UIAlertController(title: "Location services required", message: "For this function, go to your Settings and set allow location access to 'Always' for FreeStuff", preferredStyle: .alert)

            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))

            // show the alert
            self.present(alert, animated: true, completion: nil)
        }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?{

        if section == 1{
            return "Send push notification if a new posting is less than \(Int(self.radiusSlider.value)) km away. Location services must be set to 'Always' in settings. Attention: The app must be opened regularly to keep the location updates running."
        }
        if section == 2{
            return "Tell us if there is a problem with the app"
        }
        return ""
    }
}

