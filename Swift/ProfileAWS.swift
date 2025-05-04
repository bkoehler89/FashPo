
import SwiftUI

struct ProfileAWS: View {
    @EnvironmentObject var userData: UserData
    var onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("My Info")
                            .bold()
                            .underline()
                            .font(.title)
                        
                        Text("Gender")
                            .bold()
                        Text(userData.gender)
                        
                        Text("Age")
                            .bold()
                        Text("\(userData.age)")
                        
                        Text("Height")
                            .bold()
                        Text("\(userData.height)")
                        
                        Text("User ID")
                            .bold()
                        Text("\(userData.id)")
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    
                    VStack(spacing: 20) {
                        NavigationLink(destination: UserPostsAWS()) {
                            VStack {
                                Text("My")
                                    .bold()
                                Text("Posts")
                                    .bold()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        
                        NavigationLink(destination: FavoritePostsAWS()) {
                            VStack {
                                Text("Favorite")
                                    .bold()
                                Text("Posts")
                                    .bold()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.trailing)
                }
                .navigationBarTitle(Text(userData.username))
                
                Spacer()
                
                Button("Sign Out") {
                    onSignOut()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)  // Make button span the width of the screen
                .padding()  // Padding inside the button for the text
                .background(Color.red)  // Red background for the button
                .cornerRadius(8)  // Rounded corners for the button
                .padding(.horizontal)  // Padding on the sides of the button to not touch the screen edges
                .padding(.bottom)
            }
        }
    }
}

struct ProfileAWS_Previews: PreviewProvider {
    static var previews: some View {
        ProfileAWS(onSignOut: { }).environmentObject(UserData())
    }
}
