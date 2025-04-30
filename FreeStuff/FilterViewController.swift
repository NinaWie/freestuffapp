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
var selectedFoodCategory: String = "All"
var selectedGoodsCategory: String = "All"

@available(iOS 14.0, *)
class FilterViewController: UITableViewController {
    
    
    @IBOutlet weak var freeGoodsSwitch: UISwitch!
    @IBOutlet weak var freeFoodSwitch: UISwitch!
            
    @IBOutlet weak var goodsCategoryLabel: UILabel!
    @IBOutlet weak var goodsCategorySelection: UIButton!
    
    @IBOutlet weak var foodCategorySelection: UIButton!
    @IBOutlet weak var foodCategoryLabel: UILabel!
    
    static var hasChanged = false
    
    var isOptionEnabled = false

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Machine status switches
        // 1) goods switch
        let user_settings = UserDefaults.standard
        freeGoodsSwitch.isOn = user_settings.value(forKey: "showGoodsSwitch") as? Bool ?? default_switches["showGoodsSwitch"] as! Bool
        freeGoodsSwitch.addTarget(self, action: #selector(showGoods), for: .valueChanged)
        // 2) visied switch
        freeFoodSwitch.isOn = user_settings.value(forKey: "showFoodSwitch") as? Bool ?? default_switches["showFoodSwitch"] as! Bool
        freeFoodSwitch.addTarget(self, action: #selector(showFood), for: .valueChanged)


        let goodsCategories = ["All"] + goodsSubcategories
        let goodsActions = goodsCategories.map { category in
                UIAction(title: category, handler: { [weak self] _ in
                    selectedGoodsCategory = category
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
                    selectedFoodCategory = category
                    self!.foodCategoryLabel.text = category
                })
            }
        configureButton(button: foodCategorySelection)
        let foodMenu = UIMenu(title: "Select Subcategory", options: .displayInline, children: foodActions)
        foodCategorySelection.menu = foodMenu
        foodCategorySelection.showsMenuAsPrimaryAction = true
        
    }

    
    func configureButton(button: UIButton) {
        // category selection
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let image = UIImage(systemName: "chevron.down")
        button.setImage(image, for: .normal)
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
    }
    

    // Functions for Switches
    @objc func showGoods(sender:UISwitch!) {
        userdefauls_helper(defaultsKey: "showGoodsSwitch", isOn: sender.isOn)
    }
    @objc func showFood(sender:UISwitch!) {
        userdefauls_helper(defaultsKey: "showFoodSwitch", isOn: sender.isOn)
    }
    
    func userdefauls_helper(defaultsKey: String, isOn: Bool) {
        UserDefaults.standard.set(isOn, forKey: defaultsKey)
        UserDefaults.standard.synchronize()
        FilterViewController.hasChanged = true
    }
}
