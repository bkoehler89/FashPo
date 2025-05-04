//
//  Fashion_PoliceApp.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 10/4/23.
//

import SwiftUI

@main
struct Fashion_PoliceApp: App {
    var body: some Scene {
        WindowGroup {
            MainNavigation()
                .environmentObject(MainData()) // Add this line to provide MainData
                .environmentObject(UserData())
        }
    }
}

