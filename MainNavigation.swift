//
//  MainNavigation.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 2/12/24.
//

import SwiftUI

struct MainNavigation: View {
    @State private var currentScreen: Screen = .signIn
    @EnvironmentObject var userData: UserData
    @EnvironmentObject var mainData: MainData

    var body: some View {
        VStack {
            switch currentScreen {
            case .signIn:
                SignInAWS(
                    switchToSignUp: { currentScreen = .signUp },
                    switchToTabbedView: { currentScreen = .tabbedView }
                ).environmentObject(userData)
            case .signUp:
                SignUpAWS(
                    switchToSignIn: { currentScreen = .signIn },
                    switchToTabbedView: { currentScreen = .tabbedView }
                ).environmentObject(userData)
            case .tabbedView:
                TabbedViewAWS(onSignOut: { self.currentScreen = .signIn })
                    .environmentObject(userData)
                    .environmentObject(mainData)
            }
        }
    }
}

struct MainNavigation_Previews: PreviewProvider {
    static var previews: some View {
        MainNavigation()
            .environmentObject(UserData())
            .environmentObject(MainData())
    }
}


enum Screen {
    case signIn
    case signUp
    case tabbedView
    // Add more cases here as you add more screens
}
