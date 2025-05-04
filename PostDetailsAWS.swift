import SwiftUI
import Foundation


// Model for clothing articles
struct ClothingArticle: Codable, Identifiable {
    let id: Int
    let type: String
    let user_upvoted: Bool
    let user_favorited: Bool
    let user_downvoted: Bool
    let upvote_percentage: Int?
    let total_votes: Int?
}

struct ClothingArticleState {
    var isLiked: Bool = false
    var isDisliked: Bool = false
    var isFavorited: Bool = false
}

struct PostData: Codable {
    var owner_id: Int?
    var category: String?
    var description: String?
    var image_base64: String
    var clothing_articles: [ClothingArticle]?  // Add this line for clothing articles data
}

struct PostDetailsAWS: View {
    @EnvironmentObject var userData: UserData
    @Environment(\.presentationMode) var presentationMode
    @State private var isPostFavorited: Bool = false
    @State private var owner_id: Int? = nil
    @State private var category: String = ""
    @State private var description: String = ""
    @State private var image: UIImage? = nil
    @State private var clothingArticles: [ClothingArticle] = []
    @State private var articleStates: [ClothingArticleState] = []
    @State private var commentText: String = ""
    @State private var comments: [Comment] = []
    @State private var isImageZoomed: Bool = false
    @State private var showingDeleteConfirmation = false

    let postImage: PostImage

    init(postImage: PostImage) {
        self.postImage = postImage
    }

    
    var body: some View {
        VStack {
            ScrollView {
                VStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
                    Text("Owner ID: \(postImage.owner_id)")
                    Text("Category: \(postImage.category)")
                    if !category.isEmpty {
                        Text("Category: \(category)")
                    }
                    if !postImage.description.isEmpty {
                        Text("Description: \(postImage.description)")
                    }
                    if !postImage.category.isEmpty {
                        ForEach(clothingArticles.indices, id: \.self) { index in
                            HStack {
                                Text(clothingArticles[index].type)
                                    .bold()
                                
                                // Like Button
                                Button("Like") {
                                    let currentState = self.articleStates[index].isLiked
                                    articleStates[index].isLiked.toggle()
                                    // If currently disliking, disable the dislike
                                    if articleStates[index].isDisliked {
                                        articleStates[index].isDisliked = false
                                    }
                                    sendActionToLambda(clothingId: clothingArticles[index].id, action: "like", currentState: currentState)
                                }
                                .buttonStyle(ArticleButtonStyle(backgroundColor: Color.blue, foregroundColor: Color.blue, isClicked: self.articleStates[index].isLiked, isEnabled: !self.articleStates[index].isDisliked))
                                .disabled(self.articleStates[index].isDisliked) // Disable if disliked

                                // Dislike Button
                                Button("Dislike") {
                                    let currentState = self.articleStates[index].isDisliked
                                    articleStates[index].isDisliked.toggle()
                                    // If currently liking, disable the like
                                    if articleStates[index].isLiked {
                                        articleStates[index].isLiked = false
                                    }
                                    sendActionToLambda(clothingId: clothingArticles[index].id, action: "dislike", currentState: currentState)
                                }
                                .buttonStyle(ArticleButtonStyle(backgroundColor: Color.red, foregroundColor: Color.red, isClicked: self.articleStates[index].isDisliked, isEnabled: !self.articleStates[index].isLiked))
                                .disabled(self.articleStates[index].isLiked) // Disable if liked
                                
                                // Favorite Button
                                Button("Favorite") {
                                    let currentState = self.articleStates[index].isFavorited
                                    articleStates[index].isFavorited.toggle()
                                    sendActionToLambda(clothingId: clothingArticles[index].id, action: "favorite", currentState: currentState)
                                    self.addToFavorites(itemType: "clothing", itemId: clothingArticles[index].id)
                                    self.updateUserDataFavorites(favoriteType: clothingArticles[index].type)
                                }
                                .buttonStyle(ArticleButtonStyle(backgroundColor: Color.pink, foregroundColor: Color.pink, isClicked: self.articleStates[index].isFavorited))
                                
                                if let totalVotes = clothingArticles[index].total_votes {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Check if total votes is greater than 0 to display percentage
                                        if totalVotes > 0, let likePercentage = clothingArticles[index].upvote_percentage {
                                            Text("\(likePercentage)%")
                                                .foregroundColor(.black)
                                        }
                                        
                                        // Display total votes
                                        Text("\(totalVotes) Votes")
                                            .foregroundColor(.black)
                                    }
                                    .padding(.leading, 10)
                                }
                            }
                        }
                        Button(isPostFavorited ? "Remove from Favorites" : "Add to Favorites") {
                            self.addToFavorites(itemType: "post", itemId: Int(postImage.post_id)!)
                            self.updateUserDataFavorites(favoriteType: "Post")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isPostFavorited ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        HStack {
                            TextField("Comment", text: $commentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()

                            Button("Submit") {
                                submitComment()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        ForEach(comments) { comment in
                            HStack {
                                Text("\"\(comment.text)\" ") // Comment text
                                    .foregroundColor(.black) +
                                Text("by \(comment.owner_id)") // "by XXX" in green
                                    .foregroundColor(.green)

                                // Show delete button only if the current user is the owner of the post or the owner of the comment
                                if userData.id == comment.owner_id || userData.id == postImage.owner_id {
                                    Button(action: {
                                        deleteComment(commentId: comment.id)
                                    }) {
                                        Text("Delete")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                    .buttonStyle(PlainButtonStyle()) // Use a plain button style
                                }
                            }
                            .padding([.top, .bottom], 2) // Apply padding to the top and bottom of each comment
                        }
                        
                        if userData.id == postImage.owner_id {
                            Button("Delete Post") {
                                self.showingDeleteConfirmation = true
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red) // Set the background color to red
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationBarItems(trailing: Button(action: {
            refreshData()
        }) {
            Image(systemName: "arrow.clockwise").foregroundColor(.blue)
        })
        .navigationTitle("Post \(postImage.post_id)")
        .onAppear {
            // Attempt to use the image from postImage.image_base64
            if let imageData = Data(base64Encoded: self.postImage.image_base64) {
                self.image = UIImage(data: imageData)
            } else {
                // If the conversion fails, use a default image from your assets
                self.image = UIImage(named: "defaultImage") // Replace "defaultImage" with your actual default image asset name
            }
            
            if let postIdInt = Int(postImage.post_id) {
                pullUserSpecificData(postId: postIdInt)
            } else {
                print("Error: post_id could not be converted to Int")
            }
        }
        .alert(isPresented: $showingDeleteConfirmation) {
            Alert(
                title: Text("Are you sure?"),
                message: Text("Do you want to delete this post?"),
                primaryButton: .destructive(Text("Delete")) {
                    self.deletePost()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    func sendActionToLambda(clothingId: Int, action: String, currentState: Bool) {
        guard let url = URL(string: "https://b5aq5lwvq64vj5hzmydlwxuzlm0btrsv.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let payload: [String: Any] = [
            "clothing_id": clothingId,
            "user_action": action,  // 'like', 'dislike', or 'favorite'
            "action_type": currentState ? "remove" : "add",
            "user_id": userData.id
        ]


        // Convert payload to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: Server responded with status code \(httpResponse.statusCode)")
                return
            }
            if let data = data {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response from Lambda: \(responseString)")
                }
            }
        }.resume()
    }

    
    func pullUserSpecificData(postId: Int) {
        guard let url = URL(string: "https://mquvolyqoptsbiold4jgvwzutm0gdmam.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let payload: [String: Any] = [
            "post_id": postId,
            "user_id": userData.id
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: Server responded with status code \(httpResponse.statusCode)")
                return
            }
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(LambdaResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.clothingArticles = decodedResponse.articles
                        self.articleStates = decodedResponse.articles.map { article in
                            ClothingArticleState(isLiked: article.user_upvoted,
                                                 isDisliked: article.user_downvoted,
                                                 isFavorited: article.user_favorited)
                        }
                        self.isPostFavorited = decodedResponse.postFavorited
                        self.comments = decodedResponse.comments // Update the comments state
                    }
                } catch {
                    print("JSON Decoding Failed: \(error)")
                }
            }
        }.resume()
    }


    func addToFavorites(itemType: String, itemId: Int) {
        // URL for your AWS Lambda function that handles favorites
        guard let url = URL(string: "https://rcys4rgg4umanat56f4cnftnue0xxafz.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        // Determine the action type based on the current favorite status
        let actionType = isPostFavorited ? "remove" : "add"

        // Payload including the action type
        let payload: [String: Any] = [
            "itemType": itemType, // Add itemType to the payload
            "itemId": itemId, // Use the generic itemId instead of postId
            "user_id": userData.id,
            "action_type": actionType // Include action type in the payload
        ]

        // Convert payload to JSON data
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        // Send the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: Server responded with status code \(httpResponse.statusCode)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response from Lambda: \(responseString)")
            }

            // Toggle the favorite status after the request
            DispatchQueue.main.async {
                if itemType == "post" {
                    self.isPostFavorited.toggle()
                }
            }
        }.resume()
    }
    
    func submitComment() {
        guard let url = URL(string: "https://5436hoxmpdnejylbdrx3wws5gy0unyvy.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let payload: [String: Any] = [
            "user_id": userData.id, // Assuming userData.username is the current user's username
            "postId": postImage.post_id,
            "commentText": commentText
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: Server responded with status code \(httpResponse.statusCode)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response from Lambda: \(responseString)")
            }

            DispatchQueue.main.async {
                commentText = "" // Clear the comment field after submission
                
                self.pullUserSpecificData(postId: Int(postImage.post_id)!)
            }
        }.resume()
    }
    
    func deleteComment(commentId: Int) {
        guard let url = URL(string: "https://w65i7vjuz7zr6iz4csjmezmxf40qbnqe.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let payload: [String: Any] = [
            "commentId": commentId,
            "postId": postImage.post_id
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error occurred: \(error.localizedDescription)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Error: Server responded with status code \(httpResponse.statusCode)")
                return
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response from Lambda: \(responseString)")
            }

            // Refresh the comments list after deleting a comment
            DispatchQueue.main.async {
                pullUserSpecificData(postId: Int(postImage.post_id)!)
            }
        }.resume()
    }
    
    func deletePost() {
        let lambdaURL = "https://jblksfouax3sxuq7o2dhwvwic40aycnh.lambda-url.us-east-2.on.aws/"

        guard let url = URL(string: lambdaURL) else {
            print("Invalid Lambda URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = ["id": postImage.post_id]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error: Unable to encode payload to JSON")
            return
        }

        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) {data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    print("Error occurred during Lambda invocation: \(error.localizedDescription)")
                    // Optionally handle error, e.g., by showing an alert to the user
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    print("Error: Invalid response received from the server")
                    // Optionally handle the error, e.g., by showing an alert
                }
                return
            }
            if (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    self.presentationMode.wrappedValue.dismiss()
                }
            } else {
                DispatchQueue.main.async {
                    print("Error: Lambda function responded with status code \(httpResponse.statusCode)")
                    // Optionally handle the error, e.g., by showing an alert
                }
            }
        }.resume()
    }
    
    func refreshData() {
        // Reset necessary states if needed
        comments.removeAll()
        clothingArticles.removeAll()
        articleStates.removeAll()
        
        // Call functions to reload data
        pullUserSpecificData(postId: Int(postImage.post_id)!)

    }
    
    func updateUserDataFavorites(favoriteType: String) {
        // Check if the postId exists in the userData.favorites
        if let currentFavorites = userData.favorites[Int(postImage.post_id)!] {
            // Split the current value to check if favoriteType exists
            var favoritesArray = currentFavorites.split(separator: ",").map(String.init)
            
            if let favoriteIndex = favoritesArray.firstIndex(of: favoriteType) {
                // If favoriteType exists, remove it
                favoritesArray.remove(at: favoriteIndex)
            } else {
                // If favoriteType does not exist, add it
                favoritesArray.append(favoriteType)
            }
            
            if favoritesArray.isEmpty {
                // If the array is empty after modification, remove the key from the dictionary
                userData.favorites.removeValue(forKey: Int(postImage.post_id)!)
            } else {
                // Update the dictionary with the new, non-empty value
                userData.favorites[Int(postImage.post_id)!] = favoritesArray.joined(separator: ",")
            }
        } else {
            // If postId does not exist, add it with favoriteType as its value
            userData.favorites[Int(postImage.post_id)!] = favoriteType
        }

        // Print the updated favorites for verification
        print("Updated favorites: \(userData.favorites)")
    }

}

// Custom button style
struct ArticleButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color
    var isClicked: Bool
    var isEnabled: Bool = true // This ensures that the button style changes based on the isEnabled state.

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(5)
            .background(isEnabled ? (isClicked ? backgroundColor : Color.white) : Color.gray) // Use gray color for background if disabled.
            .foregroundColor(isEnabled ? (isClicked ? Color.white : foregroundColor) : Color.white) // Use white color for text if disabled.
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? backgroundColor : Color.gray, lineWidth: 2) // Use gray color for stroke if disabled.
            )
            .cornerRadius(8)
    }
}

struct LambdaResponse: Codable {
    let articles: [ClothingArticle]
    let postFavorited: Bool
    let comments: [Comment] // Add this line to include comments in the response

    enum CodingKeys: String, CodingKey {
        case articles
        case postFavorited = "post_favorited"
        case comments // Add this line to match the JSON response from the Lambda
    }
}


struct Comment: Codable, Identifiable {
    let id: Int
    let text: String
    let owner_id: Int
}

struct PostDetailsAWS_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample PostImage object with dummy data for the preview
        let samplePostImage = PostImage(post_id: "1", image_base64: "HH", owner_id: 1, description: "Sample Description", category: "Sample Category")
        
        // Pass the sample PostImage object to the PostDetailsAWS view
        PostDetailsAWS(postImage: samplePostImage).environmentObject(UserData())
    }
}
