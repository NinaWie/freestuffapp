//
//  AboutViewController.swift
//  FreeStuff
//

import UIKit

class AboutViewController: UIViewController {

    
    @IBOutlet weak var label: UILabel!
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        
        self.label.contentMode = .scaleToFill
        self.label.numberOfLines = 30

        self.label.text = "Let's stop trashing perfectly good stuff! This app helps you to find free things around you, like furniture, clothes, or food.\n\nThis is Free Stuff v\(currentVersion ?? "")."
    }
}

