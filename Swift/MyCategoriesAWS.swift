import SwiftUI

struct MyCategoriesAWS: View {
    @EnvironmentObject var userData: UserData
    @EnvironmentObject var mainData: MainData
    @State private var navigateToExploreCategories = false // State to control navigation

    var body: some View {
        NavigationStack {
            VStack {
                // Hidden NavigationLink that is activated when navigateToExploreCategories is true
                NavigationLink(destination: ExploreCategoriesAWS(), isActive: $navigateToExploreCategories) { EmptyView() }
                    .padding()
                Button(action: {
                    // Update the state to trigger navigation
                    self.navigateToExploreCategories = true
                }) {
                    Text("Find New Categories")
                        .foregroundColor(.white)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Text("My Categories")
                    .font(.largeTitle)
                    .padding()
                
                if userData.categories.isEmpty {
                    Text("You have not subscribed to any categories.")
                        .foregroundColor(.red)
                        .padding()
                } else {
                    // Iterate over userData.categories to create navigation links for each category
                    ForEach(userData.categories.keys.sorted(), id: \.self) { key in
                        NavigationLink(destination: CategoryViewAWS(categoryId: String(key), categoryTitle: userData.categories[key, default: ""])) {
                            Text(userData.categories[key, default: ""])
                                .foregroundColor(.white)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                }
                Spacer()
            }
        }
    }
}

struct MyCategoriesAWS_Previews: PreviewProvider {
    static var previews: some View {
        MyCategoriesAWS()
            .environmentObject(UserData())
            .environmentObject(MainData())
    }
}
