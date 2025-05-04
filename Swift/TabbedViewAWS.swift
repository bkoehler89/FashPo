//
//  TabbedViewAWS.swift
//  Fashion Police
//
//  Created by Benjamin Koehler on 1/24/24.
//

import SwiftUI

struct TabbedViewAWS: View {
    @EnvironmentObject var userData: UserData
    @EnvironmentObject var mainData: MainData
    var onSignOut: () -> Void

    var body: some View {
        TabView {
            MyCategoriesAWS()
                .tabItem {
                    Image(systemName: "1.square")
                    Text("Cat")
                }
                .tag(1)

            CreatePostAWS()
                .environmentObject(userData)
                .environmentObject(SharedFormData())
                .tabItem {
                    Image(systemName: "2.square")
                    Text("Post")
                }
                .tag(2)
                .background(Color.orange)

            ProfileAWS(onSignOut: onSignOut)
                .tabItem {
                    Image(systemName: "3.square")
                    Text("Me")
                }
                .tag(3)
        }
    }
}

struct TabbedViewAWS_Previews: PreviewProvider {
    static var previews: some View {
        TabbedViewAWS(onSignOut: { })
            .environmentObject(UserData())
            .environmentObject(MainData())
    }
}
