import SwiftUI
import UIKit

struct CreatePostAWS: View {
    @EnvironmentObject var userData: UserData
    @EnvironmentObject var sharedFormData: SharedFormData
    @State private var selectedCategory = "---"
    @State private var isPickerPresented = false
    @State private var selectedImage: UIImage?
    @State private var description = ""
    @State private var selectedItem = "Hat"
    @State private var addedItems: [String] = []
    @State private var navigateToReviewPost = false
    let allItems = ["Hat", "Jacket", "Shirt", "Pants", "Belt", "Shoes", "Socks", "Watch"]
    @State private var availableItems = ["Hat", "Jacket", "Shirt", "Pants", "Belt", "Shoes", "Socks", "Watch"]
    @State private var showCategorySelectionError = false
    @State private var showImageUploadError = false
    @State private var selectedGender = "All"

    

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select a Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("---").tag("---")
                        ForEach(userData.categories.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    if userData.categories.isEmpty {
                        Text("Subscribe to a category to create a post.")
                            .foregroundColor(.red)
                    } else if showCategorySelectionError {
                        Text("Select a category to post to")
                            .foregroundColor(.red)
                    }
                }


                Section(header: Text("Select a Picture")) {
                    Button("Choose Picture") {
                        isPickerPresented = true
                    }
                    .sheet(isPresented: $isPickerPresented) {
                        ImagePicker(selectedImage: $selectedImage)
                    }

                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                    } else if showImageUploadError {
                        Text("Please upload an image.")
                            .foregroundColor(.red)
                    }
                }


                Section(header: Text("Add Items")) {
                    ForEach(addedItems, id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Button("Remove") {
                                removeSelectedItem(item)
                            }
                            .foregroundColor(.red)
                        }
                    }

                    HStack {
                        
                        // Picker in the middle of the row
                        Picker("Select Item", selection: $selectedItem) {
                            ForEach(availableItems, id: \.self) { item in
                                Text(item).tag(item)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 200) // Adjust width as needed for alignment
                        .accentColor(.orange)
                        
                        Spacer() // Adjust the space as needed to align the picker and button
                        
                        // "Add" button at the end of the row
                        Button("Add") {
                            addSelectedItem()
                        }
                        .frame(width: 40) // Adjust width as needed for alignment
                    }
                }

                Section(header: Text("Description")) {
                    TextField("Enter description", text: $description)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Restrict Visibility")) {
                    Picker("Gender", selection: $selectedGender) {
                        Text("All").tag("All")
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Button("Review Post") {
                        // Reset validation states
                        showCategorySelectionError = false
                        showImageUploadError = false
                        
                        // Perform checks
                        let isCategoryListEmpty = userData.categories.isEmpty
                        let isCategorySelected = selectedCategory != "---" && !isCategoryListEmpty
                        let isImageUploaded = selectedImage != nil
                        
                        // Validate conditions
                        if isCategoryListEmpty {
                            // If categories list is empty, specific error message will already be displayed
                        } else if !isCategorySelected {
                            showCategorySelectionError = true
                        }
                        
                        if !isImageUploaded {
                            showImageUploadError = true
                        }
                        
                        if isCategorySelected && isImageUploaded && !isCategoryListEmpty {
                            // Proceed with navigation
                            navigateToReviewPost = true
                        }
                    }

                    .background(
                        NavigationLink(destination: ReviewPostAWS(reviewData: makePostReviewData()), isActive: $navigateToReviewPost) {
                            EmptyView()
                        }
                        .hidden()
                    )
                }
            }
            .navigationTitle("Create Post")
            .onReceive(sharedFormData.$resetForm) { reset in
                if reset {
                    self.resetForm()
                    sharedFormData.resetForm = false // Reset the flag
                }
            }
        }
    }
    
    private func addSelectedItem() {
        if availableItems.contains(selectedItem) {
            addedItems.append(selectedItem)
            availableItems.removeAll { $0 == selectedItem }
            if !availableItems.isEmpty {
                selectedItem = availableItems.first!
            }
        }
    }

    private func removeSelectedItem(_ item: String) {
        if addedItems.contains(item) {
            addedItems.removeAll { $0 == item }

            // Find the original index of the item in the allItems array
            if let originalIndex = allItems.firstIndex(of: item) {
                // Insert the item back into the availableItems array at the original index
                availableItems.insert(item, at: originalIndex)
            }

            // Update selectedItem if availableItems is not empty
            if !availableItems.isEmpty {
                selectedItem = availableItems.first!
            }
        }
    }
    
    private func resetForm() {
        selectedCategory = "---" // reset to initial value
        isPickerPresented = false
        selectedImage = nil
        description = ""
        selectedItem = allItems.first ?? "Hat" // reset to first item or "Hat" if array is empty
        addedItems = []
        availableItems = allItems
        selectedGender = "All"
    }
    
    func makePostReviewData() -> PostReviewData {
        return PostReviewData(
            selectedCategory: selectedCategory,
            selectedImage: selectedImage,
            addedItems: addedItems,
            description: description,
            selectedGender: selectedGender // Add this line
        )
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.selectedImage = selectedImage
            }

            picker.dismiss(animated: true)
        }
    }
}

struct PostReviewData {
    var selectedCategory: String
    var selectedImage: UIImage?
    var addedItems: [String]
    var description: String
    var selectedGender: String
}

class SharedFormData: ObservableObject {
    @Published var resetForm: Bool = false
}

struct CreatePostAWS_Previews: PreviewProvider {
    static var previews: some View {
        CreatePostAWS()
            .environmentObject(UserData()) // You already have this
            .environmentObject(SharedFormData()) // Add this for shared form data
    }
}
