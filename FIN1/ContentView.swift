import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("\(AppBrand.appName) App")
            .font(ResponsiveDesign.titleFont())
            .foregroundColor(.primary)
    }
}

#Preview {
    ContentView()
}
