//
//  PinViewController.swift
//  FreeStuff
//

import UIKit
import MapKit

var FOUNDIMAGE : Bool = false

let flaskURL = "http://37.120.179.15:5000/"
let imageURL = "http://37.120.179.15:8000/"

class PinViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var statusPicker: UISegmentedControl!
    @IBOutlet weak var websiteCell: UITableViewCell!
    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var commentTextField: UITextField!
    
    var pinData : Artwork!
    let statusChoices = ["unvisited", "visited", "marked", "retired"]
    let statusColors: [UIColor] = [.red, .green, .yellow, .gray]
    
    enum StatusChoice : String {
        case unvisited
        case visited
        case marked
        case retired
    }
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var imagePicker = UIImagePickerController()
    
    var artwork: Artwork? {
      didSet {
        configureView()
      }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .light
        }
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        updatedLabel.numberOfLines = 0
        updatedLabel.contentMode = .scaleToFill

        loadComments(completionBlock:
        {
            (output) in
            DispatchQueue.main.async {
                self.updatedLabel.text = output
                self.tableView.reloadData()
            }
        })
        // textfield
        commentTextField.attributedPlaceholder = NSAttributedString(
            string: "Type your comment here")
            
        // submit button
        submitButton.addTarget(self, action: #selector(addComment), for: .touchUpInside
                               )
        // main command to ensure that the subviews are sorted
        statusPicker.layoutSubviews()
        
        // Add title, address and updated
        titleLabel.numberOfLines = 3
        titleLabel.textAlignment = NSTextAlignment.center
        titleLabel.text = self.pinData.title!
        addressLabel.numberOfLines = 3
        addressLabel.text = self.pinData.locationName
        
        // default status
        statusPicker.selectedSegmentIndex = statusChoices.firstIndex(of: pinData.status) ?? 0
        
        statusPicker.addTarget(self, action: #selector(PinViewController.statusChanged(_:)), for: .valueChanged)
        
        // get color of currently selected index
        let colForSegment: UIColor = statusColors[statusPicker.selectedSegmentIndex]
        // color selected segmented
        if #available(iOS 13.0, *) {
            statusPicker.selectedSegmentTintColor = colForSegment
        }
        else{
            statusPicker.tintColor = colForSegment
        }
        // color all the other segments with alpha=0.2
        for (num, col) in zip([0, 1, 2, 3], statusColors){
            let subView = statusPicker.subviews[num] as UIView
            subView.layer.backgroundColor = col.cgColor
            subView.layer.zPosition = -1
            subView.alpha = 0.2
        }

        // load image asynchronously
        self.imageview.getImage(id: self.pinData.id)
        // initialize tap gesture to enlarge image
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)));
        self.imageview.isUserInteractionEnabled = true
        self.imageview.addGestureRecognizer(tapGestureRecognizer)
        
    }

    func loadComments(completionBlock: @escaping (String) -> Void) -> Void {
        let urlEncodedStringRequest = imageURL + "comments/\(self.pinData.id).json"
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
            if let url = URL(string: urlEncodedStringRequest){
                let session = URLSession(configuration: config)
                let task = session.dataTask(with: url) {[weak self](data, response, error) in
                    guard let data = data else { return }
                    let results = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    if let results_ = results as? Dictionary<String, String> {
                        let sortedDates = results_.keys.sorted {$0 > $1}
                        var displayString : String = ""
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        var isFirst = true
                        for date in sortedDates {
                            if let value = results_[date]{
                                let dateStringArr = date.split(separator: " ")
                                let dateString = dateStringArr.first ?? ""
                                if isFirst==false {
                                    displayString += "\n"
                                }
                                else{
                                    isFirst = false
                                }
                                displayString += "\(dateString): \(value)"
                            }
                        }
                        completionBlock(displayString ?? "No comments yet")
                    }
                }
                task.resume()
            }
        }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        if FOUNDIMAGE{
            self.performSegue(withIdentifier: "bigImage", sender: self)
        }
        else{
            chooseImage()
        }
    }
    
    func configureView() {
      if let artwork = artwork,
        let textLabel = textLabel,
        let imageView = imageView {
        textLabel.text = artwork.title
        imageView.image = UIImage(named: "maps")
        title = artwork.title
      }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
        {
        // Website is section 4 of the table view currently
        if indexPath.section == 4
            {
                //Open the website when you click on the link.
                UIApplication.shared.open(URL(string: pinData.link)!)
            }
            else if indexPath.section == 2 {
                let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
                self.pinData.mapItem().openInMaps(launchOptions: launchOptions)
            }
        if indexPath.section == 5{
            let mailtostring = String(
                "mailto:wnina@ethz.ch?subject=[FreeStuff] - Change of machine \(pinData.id)&body=Dear FreeStuff developers,\n\n I have noted a change of machine \(pinData.title!) (ID=\(pinData.id)).\n<b>Details:</b>:\n**PLEASE PROVIDE ANY IMPORTANT DETAILS HERE, e.g. STATUS CHANGE, CORRECT ADDRESS, GEOGRAPHIC COORDINATES, etc.\n\n With best regards,"
            ).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "error"
            UIApplication.shared.open(URL(string:mailtostring )!)
            }
        }

    @objc func statusChanged(_ sender: UISegmentedControl) {
        let status = statusChoices[sender.selectedSegmentIndex]
        
        saveStatusChange(machineid: self.pinData.id, new_status: status)
        
        // change color for selected segment
        let colForSegment = statusColors[sender.selectedSegmentIndex]
        if #available(iOS 13.0, *) {
            statusPicker.selectedSegmentTintColor = colForSegment
        }
        else{
            statusPicker.tintColor = colForSegment
        }
    }
    
    @objc func addComment(){
        
        // Create the alert controller
        let alertController = UIAlertController(title: "Attention!", message: "Please be mindful. Your comment will be shown to all users of the app. Write as clear & concise as possible.", preferredStyle: .alert)

        // Create the OK action
        let okAction = UIAlertAction(title: "OK, add comment!", style: .default) { (_) in
            
            var comment = self.commentTextField.text
            if comment?.count ?? 0 > 0 {
                self.commentTextField.text = ""
                self.commentTextField.attributedPlaceholder = NSAttributedString(
                    string: "Your comment will be shown soon!")
                if let request = "/add_comment?comment=\(comment!)&id=\(self.pinData.id)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed){
    //                let urlEncodedStringRequest = BaseURL + request
                    let urlEncodedStringRequest = flaskURL + request
                    
                    if let url = URL(string: urlEncodedStringRequest){
                        let task = URLSession.shared.dataTask(with: url) {[weak self](data, response, error) in
                            if let error = error {
                                print("Error: \(error)")
                                return
                            }
                            DispatchQueue.main.async {
                                    let alertController = UIAlertController(title: "Comment added!", message: "Please reopen the machine view to see your comment.", preferredStyle: .alert)
                                    let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                                    alertController.addAction(okAction)
                                    self!.present(alertController, animated: true, completion: nil)
                                }
                        }
                        task.resume()
                    }
                }
            }
        }

        // Create the cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
        }

        // Add the actions to the alert controller
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)

        // Present the alert controller
        self.present(alertController, animated: true, completion: nil)
        

    }
    
    func chooseImage() {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            // Create the alert controller
            let alertController = UIAlertController(title: "Attention!", message: "Your image will be shown to all users of the app! Please be considerate. Upload only images that are strictly related to penny machines. With the upload, you grant the FreeStuff team the unrestricted right to process, alter, share, distribute and publicly expose this image.", preferredStyle: .alert)

            // Create the OK action
            let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
                // Show the image picker
                let imagePicker = UIImagePickerController()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                imagePicker.allowsEditing = false
                self.present(imagePicker, animated: true, completion: nil)
            }

            // Create the cancel action
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            }

            // Add the actions to the alert controller
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)

            // Present the alert controller
            self.present(alertController, animated: true, completion: nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage

//         Convert the image to a data object
            guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                print("Failed to convert image to data")
                return
            }

            // call flask method to upload the image
            guard let url = URL(string: flaskURL+"/upload_image?id=\(self.pinData.id)") else {
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            // Add the image data to the request body
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let body = NSMutableData()
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            request.httpBody = body as Data

            // Create a URLSessionDataTask to send the request
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error: \(error)")
                    return
                }
                DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "Upload Successful", message: "Please reopen the machine view to see your image.", preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true, completion: nil)
                    }
            }
            task.resume()

        dismiss(animated:true, completion: nil)
    }


    
    func saveStatusChange(machineid: String, new_status: String){
        // find directory in documents folder corresponding to app data
        let documentsDirectoryPathString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let documentsDirectoryPath = NSURL(string: documentsDirectoryPathString)!

        // set output file path
        let jsonFilePath = documentsDirectoryPath.appendingPathComponent("pin_status.json")
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        // creating a .json file in the Documents folder
        // first check whether file exists
        var currentStatusDict = [[String: String]()]
        // Load the json data
        if fileManager.fileExists(atPath: jsonFilePath!.absoluteString, isDirectory: &isDirectory) {
            do{
                let data = try Data(contentsOf: URL(fileURLWithPath: jsonFilePath!.absoluteString), options:.mappedIfSafe)
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                currentStatusDict = jsonResult as! [[String:String]]
//                print("Read json successfully for changing status", jsonResult)
                // remove file
                try fileManager.removeItem(atPath: jsonFilePath!.absoluteString)
            }
            catch{
                print("file already exists but could not be read", error)
            }
        }

        // update value
        currentStatusDict[0][machineid] = new_status
//        print("after update value", currentStatusDict)
        
        // creating JSON out of the above array
        var jsonData: NSData!
        do {
            // setup json encoder
            jsonData = try JSONSerialization.data(withJSONObject: currentStatusDict, options: JSONSerialization.WritingOptions()) as NSData
            let jsonString = String(data: jsonData as Data, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("Array to JSON conversion failed: \(error.localizedDescription)")
        }

        // Write that JSON
        do {
            // Bug fix: create new file each time to prevent that file is only partly overwritten
            let created = fileManager.createFile(atPath: jsonFilePath!.absoluteString, contents: nil, attributes: nil)
            if !created {
                print("Couldn't create file for some reason")
            }
            let file = try FileHandle(forWritingTo: jsonFilePath!)
            file.write(jsonData as Data)
//            print("JSON data was written to teh file successfully!")
        } catch let error as NSError {
            print("Couldn't write to file: \(error.localizedDescription)")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "bigImage") {
            let destinationViewController = segue.destination as! ZoomViewController
            destinationViewController.image = self.imageview.image
        }
        
    }
    
}

extension UIImageView {
    func loadURL(url: URL) {
        FOUNDIMAGE = false
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.image = image
                    }
                    FOUNDIMAGE = true
                }
            }
        }
        // If link cannot be found, show default image
        if !FOUNDIMAGE {
            self.image = UIImage(named: "default_image")
        }
    }
    
    func getImage(id: String){
        let link_to_image = "http://37.120.179.15:8000/\(id).jpg"
        guard let imageUrl = URL(string: link_to_image) else { return }
        self.loadURL(url: imageUrl)
    }
}

