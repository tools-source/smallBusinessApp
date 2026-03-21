import CloudKit
import Foundation

@MainActor
final class CloudKitManager: ObservableObject {
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    private let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    func refreshAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
        } catch {
            accountStatus = .couldNotDetermine
        }
    }
}
