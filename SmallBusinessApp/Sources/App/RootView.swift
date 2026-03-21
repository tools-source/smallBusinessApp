import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.currentUser == nil {
                AuthenticationView()
            } else {
                MainTabView()
            }
        }
    }
}
