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
let maxDistance: Double = 30
// variable defining how large the shown region is when changing coordinates
let regionInMeters: Double = 2 * maxDistance

@available(iOS 13.0, *)
struct MapViewRepresentable: UIViewRepresentable {
    @Binding var mapType: MKMapType
    @Binding var centerCoordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        view.mapType = mapType
        let region = MKCoordinateRegion(center: centerCoordinate, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
        view.setRegion(region, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.centerCoordinate = mapView.centerCoordinate
        }
    }
}


@available(iOS 14.0, *)
struct MapView: View {
    @State private var region: MKCoordinateRegion
    @State private var showDoneAlert = false
    @State private var showTooFarAlert = false
    @Binding private var centerCoordinate: CLLocationCoordinate2D
    @Environment(\.presentationMode) private var presentationMode
    let initalCenterCoords: CLLocationCoordinate2D
    @State private var mapType: MKMapType = .standard

    
    init(centerCoordinate: Binding<CLLocationCoordinate2D>, initialCenter: CLLocationCoordinate2D) {
            _centerCoordinate = centerCoordinate
            let regionTemp = MKCoordinateRegion(
                center: initialCenter,
                latitudinalMeters: regionInMeters,
                longitudinalMeters: regionInMeters
            )
            _region = State(initialValue: regionTemp)
            initalCenterCoords = initialCenter
    }
    
    var body: some View {
        ZStack {
            // Custom MapViewRepresentable for map type switching
            MapViewRepresentable(mapType: $mapType, centerCoordinate: $centerCoordinate)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay the marker at the center coordinate
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
                .font(.title)
                .offset(y: -20) // Offset to position the marker correctly
            
            VStack{
                Spacer()
                Button("Finished") {
                    let initLoc = CLLocation(latitude: initalCenterCoords.latitude, longitude: initalCenterCoords.longitude)
                    let centerLoc = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                    print("Distance", initLoc.distance(from: centerLoc) )
                    if initLoc.distance(from: centerLoc) > maxDistance {
                        showTooFarAlert.toggle()
                    }
                    else{
                        showDoneAlert.toggle()
                    }
                }
                .padding(20)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 20) // Padding at the bottom
                .alert(isPresented: $showTooFarAlert) {
                    Alert(
                        title: Text("You must be within a \(Int(maxDistance))m radius from the location."),
                        primaryButton: .default(Text("Cancel editing")){
                            centerCoordinate = initalCenterCoords
                            showTooFarAlert = false
                            self.presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel(Text("Continue")) {
                            centerCoordinate = initalCenterCoords
                            showTooFarAlert = false
                        }
                    )
                }
                .alert(isPresented: $showDoneAlert) {
                    Alert(
                        title: Text("Moved pin location successfully from (\(initalCenterCoords.latitude), \(initalCenterCoords.longitude)) to (\(centerCoordinate.latitude), \(centerCoordinate.longitude))."),
                        primaryButton: .default(Text("Save")) {
                            showDoneAlert = false
                            self.presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel(Text("Continue editing")) {
                            showDoneAlert = false
                        }
                    )
                }
            }
            VStack{
                Spacer()
                HStack{
                    Button(
                        action: {
                            switch mapType {
                            case .standard:
                                mapType = .satellite
                            case .satellite:
                                mapType = .hybrid
                            default:
                                mapType = .standard
                            }
                        }){
                            Image("map_symbol_without_border")
                                .renderingMode(.original)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .padding()
                                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 2)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 2)
                    Spacer()
                }
            }
        }.ignoresSafeArea(.all) // Ignore safe area for the entire ZStack
    }
}


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
        config.selectionLimit = 0 // 0 means no limit on selection
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


@available(iOS 14.0, *)
struct NewMachineFormView: View {
    let coords: CLLocationCoordinate2D
    // Properties to hold user input
    @State private var name: String = ""
    @State private var address: String = ""
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
    private var keyboardObserver: AnyCancellable?

    init(coordinate: CLLocationCoordinate2D) {
        coords = coordinate
        _selectedLocation = State(initialValue: coords)
        // Observe keyboard frame changes
        keyboardObserver = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .compactMap { $0.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect }
            .map { $0.height }
            .subscribe(on: DispatchQueue.main)
            .assign(to: \.keyboardHeight, on: self)
    }

    var body: some View {
        ScrollView{
        VStack {
            // Button to open the ImagePicker when tapped
            Button(action: {
                isImagePickerPresented = true
            }) {
                Text("Select Images")
                    .padding()
                    .foregroundColor(Color.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding()
            
            // Display the selected images
            if !selectedImages.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(selectedImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .padding(5)
                        }
                    }
                }
                .padding()
            }
            // Display coordinates and make button to select them on map
            let rounded_lat = String(format: "%.4f", coords.latitude)
            let rounded_lon = String(format: "%.4f", coords.longitude)
            //(selectedLocation.longitude * 1000).rounded() / 1000)
            VStack(alignment: .leading, spacing: 5) {
                Text("Lat/lon: \(rounded_lat), \(rounded_lon)").padding(3)
                Button(action: {
                    isMapPresented = true
                }) {
                    Text("Change location on map")
                        .padding()
                        .foregroundColor(Color.black)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .cornerRadius(10)
                }
                .sheet(isPresented: $isMapPresented) {
                    MapView(centerCoordinate: $selectedLocation, initialCenter: coords)
                }.padding(3)
            }.padding(3)
            
            // Name input field
            TextField("Description", text: $name)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Email input field
            TextField("Address", text: $address)
                .padding()
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            
            // Submit button
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else {
                Button(action: {
                    submitRequest()
                }) {
                    Text("Finish")
                        .padding()
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }.padding().disabled(isLoading)
            }
            
            AlertPresenter(showAlert: $showFinishedAlert, title: "Finished", message: "Thanks for suggesting this machine. We will review this request shortly. Note that it may take a few days until the machine becomes visible.")
                .padding()
        }
        .alert(isPresented: $showAlert) {
                    Alert(title: Text("Error!"), message: Text(displayResponse), dismissButton: .default(Text("Dismiss")))
                }
        .padding()
        .navigationBarTitle("Add new machine")
        .sheet(isPresented: $isImagePickerPresented) {
            PHPickerViewControllerWrapper(selectedImages: $selectedImages)
        }
        }
        .padding(.bottom, keyboardHeight)
    }
    
    private func finishLoading(message: String) {
        displayResponse = message
        showAlert = true
        isLoading = false
    }
    
    // Function to handle the submission of the request
    private func submitRequest() {
        isLoading = true
        if name == "" || address == "" || selectedImages.count==0 {
            finishLoading(message: "Please enter all information & upload image")
            return
        }
            // upload image and make request
        let image = selectedImages[0]
        
                guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                    print("Failed to convert image to data")
                    finishLoading(message: "Something went wrong with your image")
                    return
                }
                //  Convert the image to a data object
                var urlComponents = URLComponents(string: flaskURL)!
                urlComponents.path = "/add_post"
                urlComponents.queryItems = [
                    URLQueryItem(name: "name", value: name),
                    URLQueryItem(name: "address", value: address),
                    URLQueryItem(name: "lon_coord", value: "\(coords.longitude)"),
                    URLQueryItem(name: "lat_coord", value: "\(coords.latitude)"),
                ]
                urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
                var request = URLRequest(url: urlComponents.url!)
                request.httpMethod = "POST"
                
                // TODO: modify to deal with multiple images
        
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
