//
//  NewMachineRequest.swift
//  PennyMe
//
//  Created by Nina Wiedemann on 25.07.23.
//  Copyright © 2023 Jannis Born. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI
import PhotosUI
import Combine
import CoreLocation

// how far the user can maximally be from the location
let maxDistance: Double = 1000
// variable defining how large the shown region is when changing coordinates
let regionInMeters: Double = 2 * maxDistance
let maxNrImages: Int = 5
let defaultDaysToExpiration: Int = 3
let maxDaysToExpiration: Int = 20

@available(iOS 13.0, *)
struct AlertPresenter: UIViewControllerRepresentable {
    @Binding var showAlert: Bool
    let title: String
    let message: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<AlertPresenter>) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<AlertPresenter>) {
        if showAlert {
            presentAlert()
        }
    }

    private func presentAlert() {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        // Get the topmost view controller from the UIApplication and present the alert
        if let controller = UIApplication.shared.keyWindow?.rootViewController {
            controller.present(alertController, animated: true, completion: nil)
        }
    }

    class Coordinator: NSObject {
        var parent: AlertPresenter

        init(_ alertPresenter: AlertPresenter) {
            parent = alertPresenter
        }
    }
}

@available(iOS 13.0, *)
struct ConfirmationMessageView: View {
    let message: String
    @Binding var isPresented: Bool
    
    @available(iOS 13.0.0, *)
    var body: some View {
        VStack {
            Text(message)
                .padding()
                .background(Color.gray)
                .cornerRadius(15)
        }
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut(duration: 0.3))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}

@available(iOS 14.0, *)
struct PHPickerViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxNrImages // 0 means no limit on selection, here set to 5
        config.filter = .images // Ensure only images can be selected
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PHPickerViewControllerWrapper
        
        init(parent: PHPickerViewControllerWrapper) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            var images: [UIImage] = []
            
            for result in results {
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    
                    // Only update selected images when all images are loaded
                    if images.count == results.count {
                        DispatchQueue.main.async {
                            self.parent.selectedImages = images
                        }
                    }
                }
            }
        }
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
struct IdentifiableCoordinate: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}


@available(iOS 14.0, *)
struct InteractiveMapView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D

    @State private var region: MKCoordinateRegion

    init(selectedLocation: Binding<CLLocationCoordinate2D>) {
        _selectedLocation = selectedLocation
        _region = State(initialValue: MKCoordinateRegion(
            center: selectedLocation.wrappedValue,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [IdentifiableCoordinate(coordinate: selectedLocation)]) { item in
            MapMarker(coordinate: item.coordinate, tint: .red)
        }
        .onChange(of: region.center) { newCenter in
            selectedLocation = newCenter
        }
        .frame(height: 200)
        .cornerRadius(10)
    }
}


@available(iOS 14.0, *)
struct NewMachineFormView: View {
    let coords: CLLocationCoordinate2D
    // Properties to hold user input
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var isPermanent: Bool = false
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .day, value: defaultDaysToExpiration, to: Date())!
    @State private var showFinishedAlert = false
    @State private var isMapPresented = false
    @State private var selectedLocation: CLLocationCoordinate2D
    @State private var displayResponse: String = ""
    @Environment(\.presentationMode) private var presentationMode // Access the presentationMode environment variable
    @State private var selectedImages: [UIImage] = []
    @State private var isImagePickerPresented: Bool = false
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var keyboardHeight: CGFloat = 0
    
    enum MainCategory: String, CaseIterable, Identifiable {
        case goods = "Goods"
        case food = "Food"

        var id: String { self.rawValue }
    }

    @State private var selectedCategory: MainCategory = .goods
    @State private var selectedSubcategory: String = ""

    let goodsSubcategories = ["Electronics", "Clothing", "Furniture", "Books", "Tools"]
    let foodSubcategories = ["Fresh Produce", "Baked Goods", "Canned Goods", "Beverages", "Snacks"]

    
    private var keyboardObserver: AnyCancellable?
    var onPostComplete: () -> Void

    init(coordinate: CLLocationCoordinate2D, onPostComplete: @escaping () -> Void) {
        coords = coordinate
        self.onPostComplete = onPostComplete
        
        _selectedLocation = State(initialValue: coords)
        // Observe keyboard frame changes
        keyboardObserver = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { $0.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect }
            .map { $0.height }
            .subscribe(on: DispatchQueue.main)
            .assign(to: \.keyboardHeight, on: self)
    }

    var body: some View {
        Form {
            Section(header: Text("Post Info")) {
                TextField("Title", text: $name)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Description")
                            .foregroundColor(Color.gray.opacity(0.6))
                            .padding(.top, 12)
                            .padding(.horizontal, 8)
                    }

                    TextEditor(text: $description)
                        .frame(height: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.vertical, 4)
                
                Picker("Main Category", selection: $selectedCategory) {
                    ForEach(MainCategory.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                if selectedCategory == .goods || selectedCategory == .food {
                    Picker("Subcategory (Optional)", selection: $selectedSubcategory) {
                        Text("None").tag("") // Optional
                        ForEach(selectedCategory == .goods ? goodsSubcategories : foodSubcategories, id: \.self) { subcategory in
                            Text(subcategory).tag(subcategory)
                        }
                    }
                }

                
                // is permanent or expires
                Toggle("Permanent", isOn: $isPermanent)

                if !isPermanent {
                    DatePicker(
                        "Expires On",
                        selection: $expirationDate,
                        in: Date()...Calendar.current.date(byAdding: .day, value: maxDaysToExpiration, to: Date())!,
                        displayedComponents: [.date]
                    )
                }
            }

            Section(header: Text("Location")) {
                InteractiveMapView(selectedLocation: $selectedLocation)

                Text("Lat: \(String(format: "%.4f", selectedLocation.latitude)), Lon: \(String(format: "%.4f", selectedLocation.longitude))")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            Section(header: Text("Images")) {
                if !selectedImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(selectedImages, id: \.self) { image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }.padding(.vertical, 4)
                    }
                }

                Button("Select Images") {
                    isImagePickerPresented = true
                }
                .foregroundColor(.blue)
            }

            Section {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Uploading...")
                        Spacer()
                    }
                } else {
                    Button(action: {
                        submitRequest()
                    }) {
                        Text("Finish")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            }
        }
        .navigationTitle("Add New Post")
        .sheet(isPresented: $isImagePickerPresented) {
            PHPickerViewControllerWrapper(selectedImages: $selectedImages)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(displayResponse), dismissButton: .default(Text("Dismiss")))
        }

    }
    
    private func finishLoading(message: String) {
        displayResponse = message
        showAlert = true
        isLoading = false
    }
    
    // Function to handle the submission of the request
    private func submitRequest() {
        isLoading = true
        if name == "" || (selectedImages.count==0 && description == "") {
            finishLoading(message: "Please enter a title and (at least) either an image or a description.")
            return
        }
        
        var urlComponents = URLComponents(string: flaskURL)!
        urlComponents.path = "/add_post"
        urlComponents.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "description", value: description),
            URLQueryItem(name: "lon_coord", value: "\(selectedLocation.longitude)"),
            URLQueryItem(name: "lat_coord", value: "\(selectedLocation.latitude)"),
        ]
        urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
                
        // upload image and make request
        let images = selectedImages
        // Generate a boundary for multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = NSMutableData()

        // Loop through the selected images and append each to the body
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                print("Failed to convert image to data")
                finishLoading(message: "Something went wrong with your image")
                return
            }

            // Append the image to the request body
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\(index)\"; filename=\"image\(index).jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Close the multipart body by adding the boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body as Data
        
        // Create a URLSessionDataTask to send the request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                finishLoading(message: "Something went wrong. Please check your internet connection and try again")
                return
            }
            // Check if a valid HTTP response was received
            guard let httpResponse = response as? HTTPURLResponse else {
                finishLoading(message: "Something went wrong. Please check your internet connection and try again")
                return
            }
            // Extract the status code from the HTTP response
            let statusCode = httpResponse.statusCode
            
            // Check if the status code indicates success (e.g., 200 OK)
            if 200 ..< 300 ~= statusCode {
                // everything worked, finish
                DispatchQueue.main.async {
                    self.showFinishedAlert = true
                    self.presentationMode.wrappedValue.dismiss()
                    isLoading = false
                    onPostComplete()
                }
            }
            else {
                if let responseData = data {
                    do {
                        // Parse the JSON response
                        if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                            // Handle the JSON data here
                            if let answerString = json["error"] as? String {
                                finishLoading(message: answerString)
                                return
                            }
                        }
                    } catch {
                        print("JSON parsing error: \(error)")
                        finishLoading(message: "Something went wrong. Please check your internet connection and try again")
                    }
                }
            }
        }
        task.resume()
    }
}
