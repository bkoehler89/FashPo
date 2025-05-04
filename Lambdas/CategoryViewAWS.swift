import SwiftUI
import UIKit

struct ImageLambdaResponse: Decodable {
    let imagesData: [PostImage]
    let isSubscribed: Bool

    enum CodingKeys: String, CodingKey {
        case imagesData = "images_data"
        case isSubscribed = "is_subscribed"
    }
}

struct CategoryViewAWS: View {
    @EnvironmentObject var userData: UserData
    @State private var postImages: [PostImage] = []
    @State private var subscribed: Bool = false
    @State private var subscriptionStatusLoaded: Bool = false
    @State private var pageSize: Int = 5
    @State private var isLoadingNextPage = false
    @State private var allPostsLoaded = false
    @State private var isLoading = true
    @State private var lastPostId: String = ""


    
    var categoryId: String
    var categoryTitle: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    Text("Loading...")
                } else {
                    LazyVStack {
                        if subscriptionStatusLoaded {
                            // Subscribe Button
                            Button(action: {
                                // Toggles the subscription status when button is tapped
                                self.toggleSubscription()
                            }) {
                                Text(subscribed ? "Unsubscribe" : "Subscribe")  // Change the text based on the subscription status
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(subscribed ? Color.red : Color.green)  // Change the background color based on the subscription status
                                    .cornerRadius(10)
                            }
                            .padding(.bottom, 8) // Padding below the button
                            .padding(.leading, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(postImages, id: \.post_id) { postImage in
                            NavigationLink(destination: PostDetailsAWS(postImage: postImage)) {
                                if let image = base64ToImage(base64String: postImage.image_base64) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(10)
                                        .shadow(radius: 5)
                                        .padding(.vertical, 8)
                                } else {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 8)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Show the button only if the initial load is complete and not all posts have been loaded
                        if subscriptionStatusLoaded && !allPostsLoaded {
                            Button(action: {
                                self.postImages.removeAll() // Clear the current images
                                loadNextPage() // Load the next batch
                            }) {
                                Text("Load Next Images")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.vertical)
                        } else if allPostsLoaded {
                            Text("All posts loaded")
                                .padding()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle(categoryTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    resetAndLoadImages()
                }) {
                    Image(systemName: "arrow.clockwise") // Using a system image for the refresh icon
                }
            }
        }
        .onAppear {
            loadPostImages()
        }
    }

    
    func loadPostImages() {
        // Check if all posts are already loaded or if a load operation is in progress
        guard !isLoadingNextPage, !allPostsLoaded else {
            return
        }

        // Indicate that we are starting a load operation
        isLoadingNextPage = true
        isLoading = true

        // Set up the request to the Lambda function
        guard let url = URL(string: "https://4gnac3um7dvbe7a3yex7lcg3re0iyrcr.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "categoryId": categoryId,
            "userId": userData.id,
            "lastPostId": lastPostId,
            "pageSize": pageSize,
            "gender": userData.gender
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Perform the network request
        URLSession.shared.dataTask(with: request) { data, response, error in

            // Back on the main thread, we check the result and update the state
            DispatchQueue.main.async {
                // Reset the loading state
                self.isLoadingNextPage = false
                self.isLoading = false
            }

            // Handle any errors from the request
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            // Check the response code
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Error: Invalid HTTP response")
                return
            }

            // Unwrap the received data
            guard let data = data else {
                print("Error: No data received")
                return
            }

            do {
                // Decode the JSON into our data model
                let decodedResponse = try JSONDecoder().decode(ImageLambdaResponse.self, from: data)
                DispatchQueue.main.async {
                    // Append the new posts to the existing list
                    self.postImages += decodedResponse.imagesData
                    // Set the lastPostId for the next batch load
                    self.lastPostId = self.postImages.last?.post_id ?? ""

                    // Update the subscription status
                    self.subscribed = decodedResponse.isSubscribed

                    // Check if all posts have been loaded
                    if decodedResponse.imagesData.count < self.pageSize {
                        self.allPostsLoaded = true
                    }

                    // Mark that we've finished loading
                    self.subscriptionStatusLoaded = true
                    for postImage in decodedResponse.imagesData {
                        print("Post ID: \(postImage.post_id), Owner ID: \(postImage.owner_id), Description: \(postImage.description), Category: \(postImage.category)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("JSON Decoding Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    func toggleSubscription() {
        let categoryIdInt = Int(categoryId) ?? 0 // Convert categoryId to Int, assuming categoryId is a String
        if subscribed {
            // If currently subscribed, unsubscribe and remove the category from userData.categories
            if userData.categories[categoryIdInt] != nil {
                userData.categories.removeValue(forKey: categoryIdInt)
            }
        } else {
            // If currently not subscribed, subscribe and add the category to userData.categories
            userData.categories[categoryIdInt] = categoryTitle
        }
        
        // After updating userData.categories, toggle the subscribed status
        subscribeToCategory(subscribe: !subscribed)  // This line remains unchanged, continuing to handle the actual subscription logic via Lambda
    }
    
    func base64ToImage(base64String: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64String) else {
            return nil // Return nil if the base64 string can't be converted to Data
        }
        return UIImage(data: imageData) // This might still be nil if the data isn't a valid image
    }
    
    func subscribeToCategory(subscribe: Bool) {
        // The URL of your Lambda function for subscription
        guard let url = URL(string: "https://3hcdq5matn2vdajomhxwq273xi0njlqs.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        // Prepare the URL request to send to the AWS Lambda function
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Use userData.id directly since it's non-optional
        let userId = userData.id
        
        // Construct the body with categoryId, userId, and the subscribe action
        let body: [String: Any] = ["categoryId": categoryId, "userId": userId, "subscribe": subscribe]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to encode categoryId or userId")
            return
        }

        // Create the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Server responded with status code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    DispatchQueue.main.async {
                        // Toggle the subscribed status after a successful response
                        self.subscribed.toggle()
                    }
                } else {
                    // Handle different response status codes as needed
                }
            }
        }

        // Start the data task
        task.resume()
    }
    
    func loadNextPage() {
        guard !isLoadingNextPage, !allPostsLoaded else { return }
        isLoadingNextPage = false
        loadPostImages()
    }
    
    func resetAndLoadImages() {
        postImages.removeAll()
        subscribed = false
        subscriptionStatusLoaded = false
        pageSize = 5
        isLoadingNextPage = false
        allPostsLoaded = false
        isLoading = true
        loadPostImages()
        lastPostId = ""
    }
}

struct CategoryViewAWS_Previews: PreviewProvider {
    static var previews: some View {
        // Provide sample values for the preview
        CategoryViewAWS(categoryId: "1", categoryTitle: "Formal").environmentObject(UserData())
    }
}

