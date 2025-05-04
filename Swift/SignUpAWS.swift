//
//  SignInView.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 10/9/23.
//

import SwiftUI
import Security

struct SignUpAWS: View {
    @EnvironmentObject var userData: UserData
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var gender: String = "Male"
    @State private var age: String = ""
    @State private var height: String = ""
    @State private var usernameStatus: UsernameStatus?
    @State private var emailStatus: EmailStatus?
    @State private var ageValidationMessage: String = ""
    @State private var heightValidationMessage: String = ""
    @State private var navigateToProfileTabbedView = false
    @State private var isEmailChecked: Bool = false
    @State private var isEmailValid: Bool = true
    var switchToSignIn: () -> Void
    var switchToTabbedView: () -> Void
    
    @State private var isPasswordLengthValid: Bool = false
    @State private var isPasswordCaseValid: Bool = false
    @State private var containsNumber: Bool = false
    @State private var containsSpecialCharacter: Bool = false
    @State private var passwordsMatch: Bool = false
    @State private var isPasswordValidationFailed: Bool = false
    @State private var isPasswordVisible: Bool = false
    @State private var isConfirmPasswordVisible: Bool = false



    let genderOptions = ["Male", "Female", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Creation")) {
                    HStack {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Check Availability") {
                            checkUsernameAvailability()
                        }
                        .padding(.leading, 10)
                    }
                    
                    if let status = usernameStatus {
                        Text(status.message)
                            .foregroundColor(status.color)
                    }
                    
                    TextField("Email address", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if let status = emailStatus {
                        Text(status.message)
                            .foregroundColor(status.color)
                    }
                    
                    HStack {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Button(action: {
                            // Toggle the password visibility
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .onChange(of: password) { _ in
                        updatePasswordValidation()
                    }

                    HStack {
                        if isConfirmPasswordVisible {
                            TextField("Re-enter Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            SecureField("Re-enter Password", text: $confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        Button(action: {
                            // Toggle the visibility of the confirm password field
                            isConfirmPasswordVisible.toggle()
                        }) {
                            Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .onChange(of: confirmPassword) { _ in
                        updatePasswordValidation()
                    }

                    
                    VStack(alignment: .leading) {
                        Text("Password at least 6 characters")
                            .foregroundColor(isPasswordLengthValid ? .green : .gray)
                            .font(.caption)
                        Text("Contains one upper and one lower case letter")
                            .foregroundColor(isPasswordCaseValid ? .green : .gray)
                            .font(.caption)
                        Text("Contains a number")
                            .foregroundColor(containsNumber ? .green : .gray)
                            .font(.caption)
                        Text("Contains a special character")
                            .foregroundColor(containsSpecialCharacter ? .green : .gray)
                            .font(.caption)
                        Text("Passwords match")
                            .foregroundColor(passwordsMatch ? .green : .gray)
                            .font(.caption)
                        if isPasswordValidationFailed {
                            Text("Password not valid")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                    .padding(.leading)
                }

                Section(header: Text("Personal Details")) {
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    TextField("Age", text: $age)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    if !ageValidationMessage.isEmpty {
                        Text(ageValidationMessage)
                            .foregroundColor(.red)
                    }

                    TextField("Height (inches)", text: $height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                    if !heightValidationMessage.isEmpty {
                        Text(heightValidationMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button("Submit") {
                        checkUsernameAvailability()
                        submitForm()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Sign Up")
        }
        .padding(.horizontal)
    }
    
    private func submitForm() {
        // Initial state reset
        self.ageValidationMessage = ""
        self.heightValidationMessage = ""
        self.isPasswordValidationFailed = false
        self.usernameStatus = nil
        self.emailStatus = nil
        self.isEmailValid = true // Assume email is valid until checked
        self.isEmailChecked = false // Indicates if the email has been checked yet

        // Start off by assuming the submission is valid
        var isValid = true

        if password != confirmPassword {
            print("Passwords do not match.")
            isValid = false // This will prevent the form from submitting
        }

        let areAllPasswordConditionsMet = isPasswordLengthValid &&
                                           isPasswordCaseValid &&
                                           containsNumber &&
                                           containsSpecialCharacter &&
                                           passwordsMatch

        if !areAllPasswordConditionsMet {
            self.isPasswordValidationFailed = true // Show password validation failure message
            return
        }
        
        // Validate age
        if let ageNumber = Int(age), ageNumber >= 18, ageNumber <= 100 {
            // Age is valid
        } else {
            self.ageValidationMessage = "Enter a number between 18 and 100"
            isValid = false
        }

        // Validate height
        if let heightNumber = Int(height), heightNumber >= 36, heightNumber <= 96 {
            // Height is valid
        } else {
            self.heightValidationMessage = "Enter a number between 36 and 96"
            isValid = false
        }

        // If any of the validations above failed, return early
        if !isValid {
            print("Validation failed before email check")
            return
        }

        // Proceed to check the email, this is asynchronous
        checkEmail()

        // Use a Timer to poll `isEmailChecked` to determine when the email check is complete
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in

            // Once the email has been checked...
            if self.isEmailChecked {
                timer.invalidate() // Stop the timer

                // Check the result of the email validation
                if !self.isEmailValid {
                    // Email is not valid, handle it accordingly
                    print("Email is not valid")
                    return
                }

                // If all validations pass, proceed to create the user profile
                self.createProfile()

                // Update the username in userData and navigate to the profile view
                userData.username = self.username
                userData.age = Int(age)! 
                userData.height = Int(height)!
                userData.gender = gender
                userData.categories = [:]
                userData.favorites = [:]
                self.navigateToProfileTabbedView = true
                switchToTabbedView()
            }
        }
    }

    func checkUsernameAvailability() {
        guard let url = URL(string: "https://zto26ts3qdfcjllrnc72osjmcu0lbgxr.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }
        
        let parameters: [String: Any] = ["username": username]
        let finalBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = finalBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                if let responseString = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.handleResponse(responseString)
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    func handleResponse(_ response: String) {
        if let data = response.data(using: .utf8) {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let dictionary = json as? [String: String],
               let message = dictionary["message"] {
                if message.contains("exists") {
                    usernameStatus = .taken(username)
                } else {
                    usernameStatus = .available(username)
                }
            }
        }
    }
    
    func checkEmail() {
        // Ensure we start with the email check not done
        self.isEmailChecked = false
        self.isEmailValid = true // Assume true until proven otherwise

        guard let url = URL(string: "https://yodljmqdb22ecm4dzzixac6niu0ojqnt.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let parameters: [String: Any] = ["email": email]
        let finalBody = try? JSONSerialization.data(withJSONObject: parameters)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = finalBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let data = data {
                if let responseString = String(data: data, encoding: .utf8),
                   let responseData = responseString.data(using: .utf8) {
                    do {
                        // Decode the JSON response
                        let responseDict = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: String]
                        let message = responseDict?["message"] ?? ""
                        
                        // Update the UI based on the response
                        DispatchQueue.main.async {
                            if message.contains("in use") {
                                self.emailStatus = .inUse(self.email)
                                self.isEmailValid = false
                            } else {
                                self.emailStatus = .notInUse
                                self.isEmailValid = true
                            }
                            self.isEmailChecked = true // Indicate that the email check is complete
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.emailStatus = EmailStatus.none
                            print("JSON error: \(error.localizedDescription)")
                            self.isEmailValid = false
                            self.isEmailChecked = true // Indicate completion with an error
                        }
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    print("Error: \(error.localizedDescription)")
                    self.emailStatus = EmailStatus.none
                    self.isEmailValid = false
                    self.isEmailChecked = true // Indicate completion with an error
                }
            }
        }.resume()
    }
    
    func createProfile() {
        guard let url = URL(string: "https://po5zb5alussgg7qv63r5j3zdna0vneuo.lambda-url.us-east-2.on.aws/") else {
            print("Invalid URL")
            return
        }

        let parameters: [String: Any] = [
            "username": username,
            "email": email,
            "password": password,
            "gender": gender,
            "age": age,
            "height": height
        ]

        let finalBody = try? JSONSerialization.data(withJSONObject: parameters)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = finalBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                if let responseString = String(data: data, encoding: .utf8),
                   let responseData = responseString.data(using: .utf8) {
                    do {
                        // Decode the JSON response
                        if let responseDict = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                            // Set the ID in the userData if it's present in the response
                            if let id = responseDict["id"] as? Int {
                                DispatchQueue.main.async {
                                    userData.id = id
                                    print(userData.id)
                                }
                            }
                            
                            // Extract message or any other response data if necessary
                            let message = responseDict["message"] as? String ?? "No message in response"
                            print("Response from CreateProfile: \(message)")
                            
                            // Proceed with navigation or other actions based on the response
                            DispatchQueue.main.async {
                                self.navigateToProfileTabbedView = true
                            }
                        }
                    } catch {
                        print("JSON error: \(error.localizedDescription)")
                    }
                }
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
                // Handle the error here
                DispatchQueue.main.async {
                    // Possibly update the UI to indicate an error to the user
                }
            }
        }.resume()
    }

    private func containsUpperAndLowerCase(_ value: String) -> Bool {
        let upperCase = CharacterSet.uppercaseLetters
        let lowerCase = CharacterSet.lowercaseLetters
        return value.rangeOfCharacter(from: upperCase) != nil && value.rangeOfCharacter(from: lowerCase) != nil
    }
    
    func updatePasswordValidation() {
        isPasswordLengthValid = password.count >= 6
        isPasswordCaseValid = containsUpperAndLowerCase(password)
        containsNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        containsSpecialCharacter = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:'\",.<>/?\\~")) != nil
        passwordsMatch = password == confirmPassword
    }
}

enum UsernameStatus {
    case taken(String), available(String), none

    var message: String {
        switch self {
        case .taken(let username): return "Username \(username) taken."
        case .available(let username): return "Username \(username) available."
        case .none: return ""
        }
    }

    var color: Color {
        switch self {
        case .taken: return .red
        case .available: return .green
        case .none: return .clear
        }
    }
}

enum EmailStatus {
    case inUse(String), notInUse, none

    var message: String {
        switch self {
        case .inUse(let email): return "Email \(email) in use."
        case .notInUse: return ""
        case .none: return ""
        }
    }

    var color: Color {
        switch self {
        case .inUse: return .red
        case .notInUse, .none: return .clear
        }
    }
}

struct SignUpAWS_Previews: PreviewProvider {
    static var previews: some View {
        SignUpAWS(switchToSignIn: { }, switchToTabbedView: { }).environmentObject(UserData())
    }
}
