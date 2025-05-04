//
//  ReviewPostAWS.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 2/13/24.
//
import SwiftUI
import UIKit

struct ReviewPostAWS: View {
    @EnvironmentObject var userData: UserData
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var sharedFormData: SharedFormData
    var reviewData: PostReviewData
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading) {
                        Text("Category: \(reviewData.selectedCategory)")
                            .font(.headline)

                        if let selectedImage = reviewData.selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                        }
                        
                        Text("Items:")
                            .font(.headline)
                        ForEach(reviewData.addedItems, id: \.self) { item in
                            Text(item)
                        }
                        
                        Text("Description:")
                            .font(.headline)
                        Text(reviewData.description)

                        Text("Owner ID: \(userData.id)")
                            .font(.headline)

                        Spacer()

                        Button("Submit") {
                            if let imageToUpload = reviewData.selectedImage {
                                submitPost(image: imageToUpload)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .alert(isPresented: $showAlert) {
                            Alert(
                                title: Text("Submission Status"),
                                message: Text(alertMessage),
                                dismissButton: .default(Text("OK")) {
                                    // Actions to take when OK is tapped
                                    if alertMessage == "Your post was created successfully." {
                                        // Reset the form and navigate back
                                        self.sharedFormData.resetForm = true
                                        self.presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .navigationBarTitle("Review Post", displayMode: .inline)
    }

    private func submitPost(image: UIImage) {
        guard let url = URL(string: "https://st7a2vdvwtq6dyjtl2ybbqu6ki0kgvnr.lambda-url.us-east-2.on.aws/") else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.1) else { return }
        let base64String = imageData.base64EncodedString()

        let json: [String: Any] = [
            "image": base64String,
            "owner_id": userData.id,
            "category": reviewData.selectedCategory,
            "description": reviewData.description,
            "clothing_items": reviewData.addedItems,
            "gender_restriction": reviewData.selectedGender
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            self.alertMessage = "Error creating JSON data"
            self.showAlert = true
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                if let error = error {
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self.alertMessage = "Your post was created successfully."
                        self.showAlert = true
                        // Additional logic for resetting form and dismissing view will go in the alert's dismissButton closure
                    } else {
                        self.alertMessage = "Server error: \(httpResponse.statusCode)"
                        self.showAlert = true
                    }
                } else {
                    self.alertMessage = "Unknown response from the server."
                    self.showAlert = true
                }
            }
        }.resume()
    }
}


// Define a struct specifically for preview data
struct PreviewData {
    static var sampleReviewData: PostReviewData {
        PostReviewData(
            selectedCategory: "Formal",
            selectedImage: UIImage(systemName: "photo"), // Use a system image for preview purposes
            addedItems: ["Hat", "Jacket", "Shoes"],
            description: "A great outfit for formal events.",
            selectedGender: "All"
        )
    }
}

// Update the preview provider to use the new struct
struct ReviewPostAWS_Previews: PreviewProvider {
    static var previews: some View {
        ReviewPostAWS(reviewData: PreviewData.sampleReviewData)
            .environmentObject(UserData())
    }
}
