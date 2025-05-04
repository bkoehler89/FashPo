import SwiftUI
import UIKit

struct UserPostsAWS: View {
    @EnvironmentObject var userData: UserData
    @State private var postImages: [PostImage] = []
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationView {
            if isLoading {
                // Display a loading indicator or message
                Text("Loading...")
            } else {
                if postImages.isEmpty {
                    // Display the message when there are no posts
                    Text("You have not created any posts yet")
                        .foregroundColor(.red)
                        .font(.headline)
                        .padding()
                } else {
                    List(postImages, id: \.post_id) { postImage in
                        VStack (spacing: 0) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationBarTitle("My Posts")
        .onAppear(perform: loadPostImages)
    }
    
    func loadPostImages() {
        // The URL of your Lambda function remains the same
        let url = URL(string: "https://zzniwniwfh2jh7xk2dabw5bo2e0tzhgy.lambda-url.us-east-2.on.aws/")!

        // Prepare the URL request to send to the AWS Lambda function
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include the post_type parameter to specify favorite posts
        let body: [String: Any] = ["user_id": userData.id, "post_type": "user_posts"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Create the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                // Handle the error appropriately in your actual code
                print("Error: \(error.localizedDescription)")
                return
            }

            // Check the status code and print the raw response
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    // If the status code is 200, we have a successful response
                    if let data = data {
                        // Decode the JSON response
                        decodeResponse(data)
                    }
                } else {
                    // Handle unexpected status code appropriately in your actual code
                    print("Server responded with status code: \(httpResponse.statusCode)")
                }
            }
        }

        // Start the data task
        task.resume()
    }

    
    func decodeResponse(_ data: Data) {
        do {
            let decodedResponse = try JSONDecoder().decode([PostImage].self, from: data)
            DispatchQueue.main.async {
                self.postImages = decodedResponse
                self.isLoading = false  // Set isLoading to false when the decoding is complete
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
}

struct UserPostsAWS_Previews: PreviewProvider {
    static var previews: some View {
        UserPostsAWS().environmentObject(UserData())
    }
}
