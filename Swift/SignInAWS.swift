import SwiftUI
import Combine

// SignInAws View
struct SignInAWS: View {
    @State private var inputUsername: String = ""
    @State private var inputPassword: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var authenticationFailed: Bool = false
    @EnvironmentObject var userData: UserData
    var switchToSignUp: () -> Void
    var switchToTabbedView: () -> Void

    var body: some View {
        VStack {
            Text("Welcome to Fashion Police!")
                .font(.largeTitle)
                .foregroundColor(.green)
                .padding()
            TextField("Username", text: $inputUsername)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                if isPasswordVisible {
                    TextField("Password", text: $inputPassword) // Shows password as plain text
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    SecureField("Password", text: $inputPassword) // Hides password
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button(action: {
                    isPasswordVisible.toggle() // Step 3: Toggle password visibility
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill") // Changes the icon based on visibility
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            if authenticationFailed { // Step 3: Conditionally display the error message
                Text("Username or Password Incorrect")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Button(action: {
                authenticateUser()
            }) {
                Text("Sign In")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .background(Color.blue)
                    .cornerRadius(5)
            }
            .padding()
            
            Button(action: {switchToSignUp()}) {
                Text("Sign Up")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .background(Color.green)
                    .cornerRadius(5)
            }
            .padding()
        }
    }
    
    private func authenticateUser() {
        guard let url = URL(string: "https://ctkdsod7xb6gjo6p53tvqth74y0jkkki.lambda-url.us-east-2.on.aws/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["username": inputUsername, "password": inputPassword]
        guard let httpBody = try? JSONEncoder().encode(payload) else { return }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.authenticationFailed = false // Reset on successful authentication
                    self.signInWithLambda()
                }
            } else {
                DispatchQueue.main.async {
                    self.authenticationFailed = true // Step 2: Update this variable on authentication failure
                }
            }
        }.resume()
    }
    
    // New method to handle sign-in using Lambda
    private func signInWithLambda() {
        guard let url = URL(string: "https://yo2xyjulaxueaj4fwjwkl4zk3y0cqgkv.lambda-url.us-east-2.on.aws/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["username": inputUsername]
        guard let httpBody = try? JSONEncoder().encode(payload) else { return }
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    // Decode the JSON response
                    let decodedResponse = try JSONDecoder().decode(SignInLambdaResponse.self, from: data)
                    DispatchQueue.main.async {
                        // Assuming the Lambda response includes the necessary fields
                        self.userData.id = decodedResponse.id
                        self.userData.username = self.inputUsername 
                        self.userData.gender = decodedResponse.gender
                        self.userData.age = decodedResponse.age
                        self.userData.height = decodedResponse.height
                        self.userData.categories = decodedResponse.categories
                        self.userData.favorites = decodedResponse.favorites
                        
                        self.inputUsername = ""
                        self.inputPassword = ""
                        
                        self.switchToTabbedView()
                    }
                } catch {
                    print("Error decoding response: \(error)")
                }
            }
        }.resume()
    }
}

struct SignInLambdaResponse: Codable {
    var id: Int
    var gender: String
    var age: Int
    var height: Int
    var categories: [Int: String]
    var favorites: [Int: String]
}

// SignInAws Previews
struct SignInAWS_Previews: PreviewProvider {
    static var previews: some View {
        SignInAWS(switchToSignUp: { }, switchToTabbedView: { }).environmentObject(UserData())
    }
}
