//
//  FilterViewController.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 30.04.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Contacts

var showGoods: Bool = true
var showFood: Bool = true

@available(iOS 14.0, *)
class FilterViewController: UITableViewController {
    
    
    @IBOutlet weak var freeGoodsSwitch: UISwitch!
    @IBOutlet weak var freeFoodSwitch: UISwitch!
            
    @IBOutlet weak var goodsCategoryLabel: UILabel!
    @IBOutlet weak var goodsCategorySelection: UIButton!
    

    @IBOutlet weak var maxDaysLabel: UILabel!

    @IBOutlet weak var timePostedSlider: UISlider!
    @IBOutlet weak var permanentPostsSwitch: UISwitch!
    @IBOutlet weak var foodCategorySelection: UIButton!
    @IBOutlet weak var foodCategoryLabel: UILabel!
    
    static var hasChanged = false
    
    var isOptionEnabled = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Machine status switches
        // 1) goods switch
        let user_settings = UserDefaults.standard
        freeGoodsSwitch.isOn = user_settings.value(forKey: "showGoodsSwitch") as? Bool ?? default_switches["showGoodsSwitch"]!
        freeGoodsSwitch.addTarget(self, action: #selector(showGoods), for: .valueChanged)
        // 2) visied switch
        freeFoodSwitch.isOn = user_settings.value(forKey: "showFoodSwitch") as? Bool ?? default_switches["showFoodSwitch"]!
        freeFoodSwitch.addTarget(self, action: #selector(showFood), for: .valueChanged)
        
        maxDaysLabel.text = "\(maxDaysToExpiration) days old"
        
        // Set subcategory labels
        goodsCategoryLabel.text = user_settings.value(forKey: "selectedGoodsCategory") as? String ?? "All"
        foodCategoryLabel.text = user_settings.value(forKey: "selectedFoodCategory") as? String ?? "All"
        
        let goodsCategories = ["All"] + goodsSubcategories
        let goodsActions = goodsCategories.map { category in
                UIAction(title: category, handler: { [weak self] _ in
                    self!.userdefaultsStringHelper(defaultsKey: "selectedGoodsCategory", selected: category)
                    self!.goodsCategoryLabel.text = category
                })
            }
        // goods category menu
        configureButton(button: goodsCategorySelection)
        let menu = UIMenu(title: "Select Subcategory", options: .displayInline, children: goodsActions)
        goodsCategorySelection.menu = menu
        goodsCategorySelection.showsMenuAsPrimaryAction = true  // tap directly opens menu
        
        // food category menu
        let foodCategories = ["All"] + foodSubcategories
        let foodActions = foodCategories.map { category in
                UIAction(title: category, handler: { [weak self] _ in
                    self!.userdefaultsStringHelper(defaultsKey: "selectedFoodCategory", selected: category)
                    self!.foodCategoryLabel.text = category
                })
            }
        configureButton(button: foodCategorySelection)
        let foodMenu = UIMenu(title: "Select Subcategory", options: .displayInline, children: foodActions)
        foodCategorySelection.menu = foodMenu
        foodCategorySelection.showsMenuAsPrimaryAction = true
        
        // show permanent posts switch
        permanentPostsSwitch.isOn = user_settings.value(forKey: "showPermanentSwitch") as? Bool ?? default_switches["showPermanentSwitch"]!
        permanentPostsSwitch.addTarget(self, action: #selector(showPermanent), for: .valueChanged)
        
        // configure time posted slider
        let savedValue = user_settings.value(forKey: "timePostedMax") as? Float
        let maxTimePosted = savedValue ?? Float(maxDaysToExpiration)

        timePostedSlider.minimumValue = 1
        timePostedSlider.maximumValue = Float(maxDaysToExpiration)
        timePostedSlider.value = maxTimePosted
        timePostedSlider.addTarget(self, action: #selector(sliderValueDidChange(_:)), for: .valueChanged)
        timePostedSlider.isContinuous = false
        
        
        // Debug: print all user defaults
//        print(user_settings.value(forKey: "timePostedMax"),
//              user_settings.value(forKey: "showPermanentSwitch"),
//              user_settings.value(forKey: "showGoodsSwitch"), user_settings.value(forKey: "showFoodSwitch"),
//              user_settings.value(forKey: "selectedGoodsCategory"),
//              user_settings.value(forKey: "selectedFoodCategory"))

    }

    // Function for radius slider for push notifications
    @objc func sliderValueDidChange(_ sender:UISlider!)
    {
        UserDefaults.standard.set(sender.value, forKey: "timePostedMax")
        UserDefaults.standard.synchronize()
        FilterViewController.hasChanged = true
        self.tableView.reloadData()
    }
    
    func configureButton(button: UIButton) {
        // category selection
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let image = UIImage(systemName: "line.3.horizontal.decrease")
        button.setImage(image, for: .normal)
    }
    
    // Functions for Switches
    @objc func showPermanent(sender:UISwitch!) {
        userdefaulsBoolHelper(defaultsKey: "showPermanentSwitch", isOn: sender.isOn)
    }

    // Functions for Switches
    @objc func showGoods(sender:UISwitch!) {
        userdefaulsBoolHelper(defaultsKey: "showGoodsSwitch", isOn: sender.isOn)
    }
    @objc func showFood(sender:UISwitch!) {
        userdefaulsBoolHelper(defaultsKey: "showFoodSwitch", isOn: sender.isOn)
    }
    
    func userdefaulsBoolHelper(defaultsKey: String, isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        FilterViewController.hasChanged = true
    }
    
    func userdefaultsStringHelper(defaultsKey: String, selected: String) {
        UserDefaults.standard.set(selected, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        FilterViewController.hasChanged = true
    }
}
