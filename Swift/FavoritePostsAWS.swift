import SwiftUI
import UIKit

struct FavoritePostsAWS: View {
    @EnvironmentObject var userData: UserData
    @State private var postImages: [PostImage] = []
    @State private var isLoading: Bool = true
    @State private var selectedFilter: String = "All"
    
    private var filterOptions: [String] {
        var allOptions = userData.favorites.values
            .flatMap { $0.split(separator: ",").map(String.init) } // Split comma-separated values and flatten
            .map { $0 + "s" } // Add "s" to each option
            .unique() // Extension method to get unique elements, defined below
            .sorted() // Sort alphabetically
        
        // Ensure "Post" follows "All" directly if present
        if allOptions.contains("Posts") {
            allOptions.removeAll { $0 == "Posts" } // Remove "Posts" from wherever it currently is
            allOptions = ["All", "Posts"] + allOptions // Add "Posts" right after "All"
        } else {
            allOptions = ["All"] + allOptions // Just ensure "All" is the first item
        }
        
        return allOptions
    }

    var body: some View {
        NavigationView {
            if isLoading {
                // Display a loading indicator or message
                Text("Loading...")
            } else {
                if postImages.isEmpty {
                    // Display the message in red if there are no favorite posts
                    Text("You have not favorited any posts yet")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Favorite Posts")
                } else {
                    List(postImages, id: \.post_id) { postImage in
                        VStack {
                            NavigationLink(destination: PostDetailsAWS(postImage: postImage)) {
                                ZStack(alignment: .topTrailing) {
                                    if let image = base64ToImage(base64String: postImage.image_base64) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .cornerRadius(10)
                                            .shadow(radius: 5)
                                            .padding(.vertical, 8)
                                    } else {
                                        // Provide a placeholder image or view if the image data isn't valid
                                        Image(systemName: "photo")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity)
                                            .foregroundColor(.gray)
                                            .padding(.vertical, 8)
                                    }
                                    // Adjust the padding here to move the label slightly further down
                                    Text(postImage.category)
                                        .padding(6)
                                        .background(Color.black.opacity(0.7))
                                        .foregroundColor(Color.white)
                                        .cornerRadius(5)
                                        // Increase the top padding value here to move the label down a bit
                                        .padding([.top, .trailing], 20)
                                }
                            }
                            .buttonStyle(PlainButtonStyle()) // To keep the list style
                        }
                        .listRowInsets(EdgeInsets())
                    }

                }
            }
        }
        .padding()
        .navigationTitle("Favorite Posts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(filterOptions, id: \.self) { option in
                        Button(option) {
                            self.selectedFilter = option
                            self.sendMatchingFavoritesToLambda(for: option)
                        }
                    }
                } label: {
                    HStack {
                        Text("Filter by: \(selectedFilter)")
                    }
                }
            }
        }
        .onAppear {
            self.sendMatchingFavoritesToLambda(for: "All")
        }
    }
    
    func decodeResponse(_ data: Data) {
        do {
            let decodedResponse = try JSONDecoder().decode([PostImage].self, from: data)
            DispatchQueue.main.async {
                self.postImages = decodedResponse
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false  // Also set isLoading to false in case of an error
                print("JSON Decoding Error: \(error.localizedDescription)")
            }
        }
    }
    
    func base64ToImage(base64String: String) -> UIImage? {
        guard let imageData = Data(base64Encoded: base64String) else {
            return nil // Return nil if the base64 string can't be converted to Data
        }
        return UIImage(data: imageData) // This might still be nil if the data isn't a valid image
    }
    
    func sendMatchingFavoritesToLambda(for filter: String) {
        let filterKey = filter == "All" ? "" : filter.dropLast() // Adjust for the "s" at the end, except for "All"
        let matchingKeys: [Int]
        if filter == "All" {
            matchingKeys = Array(userData.favorites.keys)
        } else {
            matchingKeys = userData.favorites.filter { key, value in
                value.contains(String(filterKey))
            }.map { $0.key }
        }

        // Update the URL for the AWS Lambda function
        let lambdaURL = URL(string: "https://xm3t4p5ygfz6dmypnnu5mhlj340vvofw.lambda-url.us-east-2.on.aws/")!

        // Prepare the URLRequest
        var request = URLRequest(url: lambdaURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode the matching keys as JSON
        let jsonBody: [String: Any] = ["matchingKeys": matchingKeys]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                print("Failed to encode JSON body: \(error)")
            }
            return
        }

        // Create and start the network task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = true
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Error sending data to Lambda: \(error)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Lambda responded with an unexpected status code.")
                }
                return
            }

            if let data = data {
                self.decodeResponse(data)
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false // Set isLoading to false if there's no data
                }
            }
        }
        task.resume()
    }

}

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

struct FavoritePostsAWS_Previews: PreviewProvider {
    static var previews: some View {
        FavoritePostsAWS().environmentObject(UserData())
    }
}
