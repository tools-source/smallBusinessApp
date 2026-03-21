import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                HomeFeedView()
            }
            .tag(AppTab.feed)
            .tabItem {
                Label("Feed", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                CreatePostView()
            }
            .tag(AppTab.create)
            .tabItem {
                Label("Create", systemImage: "square.and.pencil")
            }

            NavigationStack {
                ApplicationsView()
            }
            .tag(AppTab.applications)
            .tabItem {
                Label("Applications", systemImage: "tray.full")
            }

            NavigationStack {
                AccountView()
            }
            .tag(AppTab.account)
            .tabItem {
                Label("Account", systemImage: "person.crop.circle")
            }
        }
    }
}
