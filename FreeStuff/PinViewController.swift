//
//  PinViewController.swift
//  FreeStuff
//

import UIKit
import MapKit

var FOUNDIMAGE : Bool = false

let flaskURL = "http://freestuffapp.duckdns.org/"
// debug: "http://127.0.0.1:5000"
let imageURL = "http://37.120.179.15:8000/freestuff/images"
let commentURL = "http://37.120.179.15:8000/freestuff/comments"

let maxDistanceFromItem: Double = 100.0 // users within 100m can delete a post

class PinViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    static var wasDeleted = false
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var updatedLabel: UILabel!
    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var commentTextField: UITextField!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    
    @IBOutlet weak var scamPostButton: UIButton!
    @IBOutlet weak var deletePostButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var pinData : Artwork!
    
    // Vars for the image/comment upload
    private var activityIndicator: UIActivityIndicatorView?
    private var loadingView: UIView?
    private var loadingLabel: UILabel?
    
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    var imagePicker = UIImagePickerController()
    
    var artwork: Artwork? {
        didSet {
            configureView()
        }
    }
    var img_idx: Int = 0
    var imageList: [UIImage] = []
    
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
        
        // remove post and scam button
        deletePostButton.addTarget(self, action: #selector(deletePost), for: .touchUpInside)
        scamPostButton.addTarget(self, action: #selector(scamPost), for: .touchUpInside)
        
        // Add title, address and updated
        titleLabel.numberOfLines = 0
        titleLabel.contentMode = .scaleToFill
        titleLabel.textAlignment = NSTextAlignment.center
        titleLabel.text = self.pinData.title!
        addressLabel.numberOfLines = 0
        addressLabel.text = self.pinData.postDescription
        
        // add time
        timeLabel.numberOfLines = 0
        timeLabel.text = "Posted: \(self.pinData.time_posted)"
        if self.pinData.status != "permanent" {
            timeLabel.text = timeLabel.text! + "\nExpires: \(self.pinData.time_expiration)"
        }
        // add category
        if !self.pinData.subcategory.isEmpty {
            categoryLabel.text = "Category: \(self.pinData.category) - \(self.pinData.subcategory)"
        }
        else {
            categoryLabel.text = "Category: \(self.pinData.category)"
        }
        
        
        // load images asynchronously
        for photoId in pinData.photoPaths {
            getImage(id: photoId)
        }
        
        // scroll view
        scrollView.delegate = self
        scrollView.isPagingEnabled = true
        
        scrollView.contentSize = CGSize(width: view.frame.width * CGFloat(pinData.photoPaths.count), height: scrollView.frame.height)

    }
    
    func loadURL(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.imageList.append(image)
                        FOUNDIMAGE = true
                        let imageView = UIImageView(image: image)
                        //        // initialize tap gesture to enlarge image
                        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self?.imageTapped(tapGestureRecognizer:)));
                        imageView.isUserInteractionEnabled = true
                        imageView.addGestureRecognizer(tapGestureRecognizer)
                        imageView.contentMode = .scaleAspectFit
                        
                        self?.scrollView.addSubview(imageView)
                        self?.layoutImageView(imageView, index: self?.img_idx ?? 0)
                    }
                }
            }
        }
        
    }
    
    func layoutImageView(_ imageView: UIImageView, index: Int) {
            let xPosition = view.frame.width * CGFloat(index)
            imageView.frame = CGRect(x: xPosition, y: 0, width: view.frame.width, height: scrollView.frame.height)
            img_idx += 1
        }
    
    func getImage(id: String){
        if id == "" { return }
        var link_to_image = "\(imageURL)/\(id).jpg"
        if id.contains("_") {
            link_to_image = "\(imageURL)/\(pinData.id)\(id).jpg"
        }
        guard let fullImageURL = URL(string: link_to_image) else { return }
        self.loadURL(url: fullImageURL)
    }
    
    func loadComments(completionBlock: @escaping (String) -> Void) -> Void {
        let urlEncodedStringRequest = "\(commentURL)/\(self.pinData.id).json"
        
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
           }

            self.showLoadingView(withMessage: "Processing the comment...")
            self.uploadCommentWithTimeout(comment!)
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
    
    @objc func deletePost(){
        // check distance between user and item location
        let coords = locationManager.location!.coordinate
        let distance = GeoUtils.haversineDistance(
            lat1: coords.latitude,
            lon1: coords.longitude,
            lat2: self.pinData.coordinate.latitude,
            lon2: self.pinData.coordinate.longitude
        )
        // if distance to high, just show alert
        if distance > maxDistanceFromItem {
            let alert = UIAlertController(
                title: "Too Far Away",
                message: "You are too far away from this item to delete the post. Only users within \(Int(maxDistanceFromItem)) meters can delete it.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        // Create the alert controller
       let alertController = UIAlertController(title: "Delete post?", message: "Are you at the location and have picked up all items or can confirm that the post is no longer needed?", preferredStyle: .alert)
       // Create the OK action
       let okAction = UIAlertAction(title: "OK, delete post!", style: .default) { (_) in

           self.showLoadingView(withMessage: "Processing...")
           self.deletePostCall(mode: "pickup")
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

    @objc func scamPost(){
        // Create the alert controller
       let alertController = UIAlertController(title: "Report scam", message: "Are you sure this post is fake / scam? Please only report if you are certain this post is predatory, not if you have picked up the item or other reasons.", preferredStyle: .alert)
       // Create the OK action
       let okAction = UIAlertAction(title: "OK, report!", style: .default) { (_) in

           self.showLoadingView(withMessage: "Processing...")
           self.deletePostCall(mode: "scam")
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
    
    func deletePostCall(mode: String){
        // set as deleted
        PinViewController.wasDeleted = true
        
        let urlString = flaskURL + "/delete_post/\(pinData.id)?mode=\(mode)"
        
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Hide the loading view first
            DispatchQueue.main.async {
                self.hideLoadingView()
            }

            if let error = error {
                print("Error: \(error)")
                DispatchQueue.main.async {
                    self.handleResponse(type: "delete", success: false, error: error)
                }
                return
            }

            // If the request is successful, display the success message
            DispatchQueue.main.async {
                self.handleResponse(type: "delete", success: true, error: nil)
            }
        }
        task.resume()
    }
    
    func showLoadingView(withMessage message: String) {
         // Create the loading view
         loadingView = UIView(frame: CGRect(x: 0, y: 0, width: 250, height: 150))
         loadingView?.center = view.center
         loadingView?.backgroundColor = UIColor(white: 0.2, alpha: 0.8)
         loadingView?.layer.cornerRadius = 10
         // Create the loading label
         loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 40))
         loadingLabel?.center = CGPoint(x: loadingView!.bounds.midX, y: loadingView!.bounds.midY - 30)
         loadingLabel?.text = message
         loadingLabel?.textColor = .white
         loadingLabel?.textAlignment = .center
         loadingLabel?.numberOfLines = 0
         loadingView?.addSubview(loadingLabel!)
         // Create and start animating the activity indicator
         activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
         activityIndicator?.center = CGPoint(x: loadingView!.bounds.midX, y: loadingView!.bounds.midY + 20)
         activityIndicator?.startAnimating()
         loadingView?.addSubview(activityIndicator!)
         view.addSubview(loadingView!)
     }

     func hideLoadingView() {
         // Remove or hide the loading view (as in your original code)
         loadingView?.removeFromSuperview()
     }

    func uploadCommentWithTimeout(_ comment: String) {
        let uploadTimeout: TimeInterval = 10
        var task: URLSessionDataTask?

        // submit request to backend
        let requestString = "/add_comment?comment=\(comment)&id=\(self.pinData.id)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let urlEncodedStringRequest = flaskURL + requestString!
        if let url = URL(string: urlEncodedStringRequest){
            let task = URLSession.shared.dataTask(with: url) {[weak self](data, response, error) in
            // Create a URLSessionDataTask to send the request
                guard let self = self else { return }

                // Hide the loading view first
                DispatchQueue.main.async {
                    self.hideLoadingView()
                }

                // Cancel the task if it's still running
                task?.cancel()

                if let error = error {
                    print("Error: \(error)")
                    DispatchQueue.main.async {
                        self.handleResponse(type: "comment", success: false, error: error)
                    }
                    return
                }

                // If the request is successful, display the success message
                DispatchQueue.main.async {
                    self.handleResponse(type: "comment", success: true, error: nil)
                }
            }
            task.resume()
            // Set up a timer to handle the upload timeout
            var timeoutTimer: DispatchSourceTimer?
            timeoutTimer = DispatchSource.makeTimerSource()
            timeoutTimer?.schedule(deadline: .now() + uploadTimeout)
            timeoutTimer?.setEventHandler { [weak self] in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.hideLoadingView() // Hide the loading view in case of timeout
                    // Display a failure message or take appropriate action
                    print("Upload timed out")
                    // You can also show an alert to the user here
                    
                    // Cancel the task if it's still running
                    task.cancel()
                }
                // Cancel the timer
                timeoutTimer?.cancel()
            }
            timeoutTimer?.resume()
        } else {
        print("Invalid URL")
        hideLoadingView()
        }
    }
    
    func chooseImage() {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum){
            // Create the alert controller
            let alertController = UIAlertController(title: "Attention!", message: "Your image will be shown to all users of the app! Please be considerate. Upload only images that are strictly related to the posting. With the upload, you grant the FreeStuff team the unrestricted right to process, alter, share, distribute and publicly expose this image.", preferredStyle: .alert)

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
        
        showLoadingView(withMessage: "Processing the image...")
        let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        // Dismiss the image picker
        dismiss(animated: true) {
            // Call a function to upload the image with a timeout
            self.uploadImageWithTimeout(image)
        }
    }
    
    func uploadImageWithTimeout(_ image: UIImage) {
        let uploadTimeout: TimeInterval = 5
        var task: URLSessionDataTask?
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            print("Failed to convert image to data")
            hideLoadingView()
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
        task = URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }
            // Hide the loading view first
            DispatchQueue.main.async {
                self.hideLoadingView()
            }
            // Cancel the task if it's still running
            task?.cancel()
            if let error = error {
                            print("Error: \(error)")
                            DispatchQueue.main.async {
                                self.handleResponse(type: "image", success: false, error: error)
                            }
                            return
                        }
            // If the request is successful, display the success message
            DispatchQueue.main.async {
                self.handleResponse(type: "image", success: true, error: nil)
            }
        }
        task?.resume()
        // Set up a timer to handle the upload timeout
        var timeoutTimer: DispatchSourceTimer?
        timeoutTimer = DispatchSource.makeTimerSource()
        timeoutTimer?.schedule(deadline: .now() + uploadTimeout)
        timeoutTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.hideLoadingView() // Hide the loading view in case of timeout
                // Display a failure message or take appropriate action
                print("Upload timed out")
                // Cancel the task if it's still running
                task?.cancel()
            }
            // Cancel the timer
            timeoutTimer?.cancel()
        }
        timeoutTimer?.resume()
    }
    
    private func handleResponse(type: String, success: Bool, error: Error?) {
        activityIndicator?.stopAnimating()
        loadingView?.removeFromSuperview()
        if success {
            if type == "comment" {
                showAlert(title: "Success", message: "Upload successful! Please reopen the post to see your comment.")
            }
            else {
                showAlert(title: "Success", message: "Post deleted successfully")
            }
        } else {
            var errorMessage = "An error occurred"
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    errorMessage = "Request timed out. Please check your internet connection and try again."
                case .notConnectedToInternet:
                    errorMessage = "No internet connection. Please connect to the internet and try again."
                case .cancelled:
                    errorMessage = "Request timed out. Please check your internet connection and try again."
                default:
                    errorMessage = "Network error: \(urlError.localizedDescription)"
                }
            } else {
                errorMessage = "Unknown error: \(error?.localizedDescription ?? "No additional details")"
            }
            showAlert(title: "Error", message: errorMessage)
        }
    }
    
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "bigImage") {
            let destinationViewController = segue.destination as! ZoomViewController
            destinationViewController.images = imageList
            let currentPosition = scrollView.contentOffset.x / scrollView.frame.width
            destinationViewController.scrollPosition = currentPosition
        }
        
    }
    
}
