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

        self.label.text = "Let's stop trashing perfectly good stuff! This app helps you to find free things around you, like furniture, clothes, or food.\n\nThis app is completely free and requires no sign-up. It’s designed for sharing items that are **left outside** (on the street or in a publicly accessible location). If the item isn’t directly visible, further pickup instructions may be in the post description. \n\nTo **offer something**, tap the + button, fill in the details, and choose the location.\nTo **pick something up**, go to the posted location and tap the green “Pick up” button.\n\nColor code of pins:\nBlue: Permanent posts (e.g. freedges)\nGreen: Recently posted\nRed: A few days old\n\n\nThis is Free Stuff v\(currentVersion ?? "").\n©Nina Wiedemann (2025)"
    }
}

