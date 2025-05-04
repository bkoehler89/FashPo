import SwiftUI

struct ExploreCategoriesAWS: View {
    @EnvironmentObject var mainData: MainData
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Explore Categories")
                    .font(.largeTitle)
                    .padding()
                
                // Iterate only over categories from MainData
                ForEach(Array(mainData.categories.keys).sorted(), id: \.self) { key in
                    if let name = mainData.categories[key] {
                        categoryButton(name: name, id: String(key))
                    }
                }
            }
        }
    }
    
    // Reusable button view for category
    @ViewBuilder
    private func categoryButton(name: String, id: String) -> some View {
        NavigationLink(destination: CategoryViewAWS(categoryId: id, categoryTitle: name)) {
            Text(name)
                .foregroundColor(.white)
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
}

struct ExploreCategoriesAWS_Previews: PreviewProvider {
    static var previews: some View {
        ExploreCategoriesAWS()
            .environmentObject(MainData())
            .environmentObject(UserData())
    }
}
