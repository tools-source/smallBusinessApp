import GoogleSignIn
import SwiftUI

@main
struct SmallBusinessApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var locationManager = AppLocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(locationManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
