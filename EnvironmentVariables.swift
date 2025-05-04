//
//  EnvironmentVariables.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 2/12/24.
//

import Foundation
import SwiftUI

class UserData: ObservableObject {
    @Published var username: String = "Benjamin"
    @Published var id: Int = 1
    @Published var age: Int = 45
    @Published var height: Int = 68
    @Published var gender: String = "Male"
    @Published var categories: [Int: String] = [1:"Formal",2:"Business Casual"]
    @Published var favorites: [Int: String] = [1:"Post",30:"Post,Hat"]
}

class MainData: ObservableObject {
    @Published var categories: [Int: String] = [
        1: "Formal",
        2: "Business Casual",
        3: "Dating",
        4: "Casual",
        5: "Bumming",
        6: "Athletic",
        7: "Ski/Snowboard"
    ]
}

// Define a struct to match the JSON structure returned by your Lambda function
struct PostImage: Decodable {
    let post_id: String
    let image_base64: String
    let owner_id: Int    // Assuming owner_id is an integer
    let description: String
    let category: String
}
