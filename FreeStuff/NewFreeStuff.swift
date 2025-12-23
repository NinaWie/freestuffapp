//
//  NewMachineRequest.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 25.07.23.
//  Copyright © 2025  Nina Wiedemann. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI
import PhotosUI
import Combine
import CoreLocation

let goodsSubcategories = ["Electronics", "Clothing", "Furniture", "Books", "Tools"]
let foodSubcategories = ["Fresh Produce", "Baked Goods", "Canned Goods", "Beverages", "Snacks", "Community fridge"]


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

final class AppSession {
    static let shared = AppSession()
    private init() {}

    lazy var anonUserId: String = {
        (try? AnonymousUserID.getOrCreate()) ?? UUID().uuidString.lowercased()
    }()
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
        DispatchQueue.main.async {
            displayResponse = message
            showAlert = true
            isLoading = false
        }
    }
    
    // Function to handle the submission of the request
    private func submitRequest() {
        isLoading = true
        if name == "" || (selectedImages.count==0 && description == "") {
            finishLoading(message: "Please enter a title and (at least) either an image or a description.")
            return
        }
        // check whether too many images
        if selectedImages.count>5 {
            finishLoading(message: "Too many images. Please select at most 5 images.")
            return
        }
        // text moderation
        if let reason = TextModeration.blockReason(title: name, description: description) {
            finishLoading(message: reason)
            return
        }
        //  format expiration date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .medium
        formatter.dateFormat = "yyyy-MM-dd"
        var expirationDateString = formatter.string(from: expirationDate)
        if isPermanent {
            expirationDateString = ""
        }
        let user_id = AppSession.shared.anonUserId
        
        // URL without query items
        guard let url = URL(string: flaskURL)?.appendingPathComponent("add_post") else {
            finishLoading(message: "Internal error: invalid backend URL.")
            return
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        func appendFile(fieldName: String, filename: String, mimeType: String, fileData: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Fields
        appendField("name", name)
        appendField("description", description)
        appendField("category", selectedCategory.rawValue)
        appendField("subcategory", selectedSubcategory)
        appendField("expiration_date", expirationDateString)
        appendField("lon_coord", "\(selectedLocation.longitude)")
        appendField("lat_coord", "\(selectedLocation.latitude)")
        appendField("user_id", user_id)
        
        // image files - compress such that all images together are small enough
        let totalBudgetKB = 500
        let perImageKB = max(120, totalBudgetKB / max(selectedImages.count, 1))
        let maxBytesPerImage = perImageKB * 1024

        for (index, image) in selectedImages.enumerated() {
            guard let imageData = ImageCompression.jpegDataFast(
                image,
                maxBytes: maxBytesPerImage,
                maxDimension: 1280
            ) else {
                finishLoading(message: "Failed to compress image. Please try again.")
                return
            }

            appendFile(
                fieldName: "photos",
                filename: "photo_\(index).jpg",
                mimeType: "image/jpeg",
                fileData: imageData
            )
        }
        
        // Close multipart 
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                finishLoading(message: "Something went wrong. Please check your internet connection and try again")
                print("Request error:", error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                finishLoading(message: "Something went wrong. Please check your internet connection and try again")
                return
            }
            
            let statusCode = httpResponse.statusCode
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<no body>"
            print("Status:", statusCode)
            print("Body:", responseText)
            
            if 200..<300 ~= statusCode {
                DispatchQueue.main.async {
                    self.showFinishedAlert = true
                    self.presentationMode.wrappedValue.dismiss()
                    isLoading = false
                    onPostComplete()
                }
                return
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


enum ImageCompression {

    static func jpegDataFast(
        _ image: UIImage,
        maxBytes: Int,
        maxDimension: CGFloat = 1280
    ) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        // 3 quick attempts
        let qualities: [CGFloat] = [0.65, 0.45, 0.30]
        var lastData: Data?

        for q in qualities {
            if let d = resized.jpegData(compressionQuality: q) {
                lastData = d
                if d.count <= maxBytes { return d }
            }
        }

        // Optional: one extra downscale step if still too large (keeps it fast)
        if let d = lastData, d.count > maxBytes {
            let smaller = resize(resized, maxDimension: maxDimension * 0.75)
            let q: CGFloat = 0.1
            return smaller.jpegData(compressionQuality: q) ?? lastData
        }

        return lastData
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxDimension else { return image }

        let scale = maxDimension / longSide
        let newSize = CGSize(width: max(1, size.width * scale),
                             height: max(1, size.height * scale))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        // NEW: force standard dynamic range to avoid HDR conversion logs
        if #available(iOS 12.0, *) {
            format.preferredRange = .standard
        }

        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
