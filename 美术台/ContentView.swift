import SwiftUI

struct ContentView: View {
    @Bindable var store: ArtDepartmentV2Store

    var body: some View {
        ArtDepartmentV2RootView(store: store)
    }
}

#Preview {
    ContentView(store: ArtDepartmentV2Store())
        .frame(width: 1360, height: 860)
}
