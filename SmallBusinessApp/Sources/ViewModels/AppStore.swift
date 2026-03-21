import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct RatingSummary {
    let average: Double
    let count: Int

    var compactText: String {
        guard count > 0 else { return "New" }
        return String(format: "%.1f (%d)", average, count)
    }

    var detailText: String {
        guard count > 0 else { return "No ratings yet" }
        return String(format: "%.1f from %d %@", average, count, count == 1 ? "rating" : "ratings")
    }
}

enum AppTab: Hashable {
    case feed
    case create
    case applications
    case account
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    @Published private(set) var posts: [JobPost] = []
    @Published private(set) var ratings: [UserRating] = []
    @Published private(set) var applications: [JobApplication] = []
    @Published private(set) var currentUser: AppUser?
    @Published var selectedTab: AppTab = .feed

    private let storage = JSONStorage.shared
    private let usersFile = "users.json"
    private let postsFile = "posts.json"
    private let ratingsFile = "ratings.json"
    private let applicationsFile = "applications.json"
    private let sessionFile = "session.json"

    init() {
        users = storage.load([AppUser].self, fileName: usersFile, defaultValue: [])
        posts = storage.load([JobPost].self, fileName: postsFile, defaultValue: [])
        ratings = storage.load([UserRating].self, fileName: ratingsFile, defaultValue: [])
        applications = storage.load([JobApplication].self, fileName: applicationsFile, defaultValue: [])

        let session = storage.load(StoredSession?.self, fileName: sessionFile, defaultValue: nil)
        if let userID = session?.userID {
            currentUser = users.first(where: { $0.id == userID })
        }
    }

    var sortedPosts: [JobPost] {
        posts
            .filter(\.isVisibleInFeed)
            .sorted { $0.createdAt > $1.createdAt }
    }

    var myPosts: [JobPost] {
        guard let currentUser else { return [] }
        return posts
            .filter { $0.authorID == currentUser.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var mySubmittedApplications: [JobApplication] {
        guard let currentUser else { return [] }
        return applications
            .filter { $0.workerUserID == currentUser.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var myReceivedApplications: [JobApplication] {
        guard let currentUser else { return [] }
        return applications
            .filter { $0.businessUserID == currentUser.id }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func user(for userID: String) -> AppUser? {
        users.first(where: { $0.id == userID })
    }

    func profileImageFileName(for userID: String) -> String? {
        user(for: userID)?.profileImageFileName
    }

    func phone(for userID: String) -> String? {
        user(for: userID)?.preferredPhone
    }

    func address(for userID: String) -> String? {
        user(for: userID)?.preferredAddress
    }

    func imageData(fileName: String?) -> Data? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return storage.loadData(fileName: fileName)
    }

    func post(for postID: UUID) -> JobPost? {
        posts.first(where: { $0.id == postID })
    }

    func application(with applicationID: UUID) -> JobApplication? {
        applications.first(where: { $0.id == applicationID })
    }

    func applications(for postID: UUID) -> [JobApplication] {
        applications
            .filter { $0.postID == postID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func applicationCount(for postID: UUID) -> Int {
        applications.reduce(into: 0) { count, application in
            if application.postID == postID {
                count += 1
            }
        }
    }

    func ratingSummary(for userID: String) -> RatingSummary {
        let receivedRatings = ratings.filter { $0.targetUserID == userID }
        guard !receivedRatings.isEmpty else {
            return RatingSummary(average: 0, count: 0)
        }

        let total = receivedRatings.reduce(0) { $0 + $1.score }
        let average = Double(total) / Double(receivedRatings.count)
        return RatingSummary(average: average, count: receivedRatings.count)
    }

    func ratingsReceived(for userID: String) -> [UserRating] {
        ratings
            .filter { $0.targetUserID == userID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func currentUserRatingEntry(for targetUserID: String) -> UserRating? {
        guard let currentUser else { return nil }
        return ratings.first {
            $0.raterUserID == currentUser.id && $0.targetUserID == targetUserID
        }
    }

    func currentUserRating(for targetUserID: String) -> Int? {
        currentUserRatingEntry(for: targetUserID)?.score
    }

    func currentUserApplication(for postID: UUID) -> JobApplication? {
        guard let currentUser else { return nil }
        return applications.first {
            $0.postID == postID && $0.workerUserID == currentUser.id
        }
    }

    func canCurrentUserRate(targetUserID: String, targetRole: UserRole) -> Bool {
        guard let currentUser else { return false }
        guard currentUser.id != targetUserID else { return false }
        return currentUser.role != targetRole
    }

    func canCurrentUserApply(to post: JobPost) -> Bool {
        guard let currentUser else { return false }
        guard currentUser.role == .worker else { return false }
        guard post.postType == .employerHiring else { return false }
        guard post.isActive else { return false }
        guard post.authorID != currentUser.id else { return false }
        guard posts.contains(where: { $0.id == post.id }) else { return false }
        return currentUserApplication(for: post.id) == nil
    }

    var canCurrentUserPublishPosts: Bool {
        guard let currentUser else { return false }
        return currentUser.postingProfileIsComplete
    }

    func signUp(fullName: String, email: String, password: String, role: UserRole) throws {
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else { throw AppError.missingField(role.accountNameLabel) }
        guard Validator.isValidEmail(cleanEmail) else { throw AppError.invalidEmail }
        guard cleanPassword.count >= 6 else { throw AppError.weakPassword }
        guard users.first(where: { $0.email == cleanEmail }) == nil else { throw AppError.accountExists }

        let user = AppUser(
            id: UUID().uuidString,
            fullName: cleanName,
            email: cleanEmail,
            publicEmail: cleanEmail,
            passwordHash: Self.hash(cleanPassword),
            businessName: role == .business ? cleanName : nil,
            role: role,
            authProvider: .manual,
            createdAt: Date()
        )
        users.append(user)
        persistUsers()
        setCurrentUser(user)
    }

    func login(email: String, password: String, role: UserRole) throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Validator.isValidEmail(cleanEmail) else { throw AppError.invalidEmail }

        guard let user = users.first(where: { $0.email == cleanEmail }) else {
            throw AppError.accountNotFound
        }

        guard user.role == role else {
            throw AppError.portalMismatch(expected: user.role)
        }

        guard user.authProvider == .manual else {
            throw AppError.useAppleSignIn
        }

        guard user.passwordHash == Self.hash(cleanPassword) else {
            throw AppError.invalidCredentials
        }

        setCurrentUser(user)
    }

    func signInWithApple(
        userID: String,
        fullName: PersonNameComponents?,
        email: String?,
        role: UserRole
    ) throws {
        if var existingUser = users.first(where: { $0.id == userID }) {
            guard existingUser.role == role else {
                throw AppError.portalMismatch(expected: existingUser.role)
            }

            let nameValue = Self.fullName(from: fullName)
            if !nameValue.isEmpty, existingUser.role == .worker {
                existingUser.fullName = nameValue
            }
            if let actualEmail = Self.usableAppleEmail(email) {
                existingUser.email = actualEmail
                existingUser.publicEmail = actualEmail
            }

            if let index = users.firstIndex(where: { $0.id == existingUser.id }) {
                users[index] = existingUser
                persistUsers()
                setCurrentUser(existingUser)
                return
            }
        }

        let actualEmail = Self.usableAppleEmail(email)
        if let actualEmail,
           users.contains(where: { ($0.email == actualEmail || $0.publicEmail == actualEmail) && $0.id != userID }) {
            throw AppError.accountExists
        }

        let resolvedName = {
            let name = Self.fullName(from: fullName)
            if !name.isEmpty {
                return name
            }
            return role == .business ? "New Business" : "Apple User"
        }()

        let newUser = AppUser(
            id: userID,
            fullName: resolvedName,
            email: actualEmail ?? "",
            publicEmail: actualEmail,
            passwordHash: nil,
            role: role,
            authProvider: .apple,
            createdAt: Date()
        )
        users.append(newUser)
        persistUsers()
        setCurrentUser(newUser)
    }

    func logout() {
        currentUser = nil
        storage.remove(fileName: sessionFile)
    }

    func deleteCurrentAccount() throws {
        guard let currentUser else { throw AppError.notAuthenticated }

        if let profileImageFileName = currentUser.profileImageFileName {
            storage.removeData(fileName: profileImageFileName)
        }

        let removedPostIDs = Set(posts.filter { $0.authorID == currentUser.id }.map(\.id))
        let removedApplications = applications.filter {
            $0.workerUserID == currentUser.id
                || $0.businessUserID == currentUser.id
                || removedPostIDs.contains($0.postID)
        }

        let removedMediaFileNames = Set(
            removedApplications.compactMap(\.workerProfileImageFileName)
                + removedApplications.compactMap(\.workerIDImageFileName)
        )
        removedMediaFileNames.forEach { storage.removeData(fileName: $0) }

        posts.removeAll { $0.authorID == currentUser.id }
        ratings.removeAll {
            $0.raterUserID == currentUser.id || $0.targetUserID == currentUser.id
        }
        applications.removeAll { application in
            removedApplications.contains(where: { $0.id == application.id })
        }
        users.removeAll { $0.id == currentUser.id }

        persistPosts()
        persistRatings()
        persistApplications()
        persistUsers()
        logout()
    }

    func updateCurrentAccountProfile(
        fullName: String,
        publicEmail: String,
        workerAddress: String,
        workerPhone: String,
        businessName: String,
        businessAddress: String,
        businessPhone: String
    ) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard let index = users.firstIndex(where: { $0.id == currentUser.id }) else {
            throw AppError.accountNotFound
        }

        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPublicEmail = publicEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanWorkerAddress = workerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanWorkerPhone = workerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBusinessName = businessName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBusinessAddress = businessAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBusinessPhone = businessPhone.trimmingCharacters(in: .whitespacesAndNewlines)

        var updatedUser = currentUser

        if !cleanPublicEmail.isEmpty {
            guard Validator.isValidEmail(cleanPublicEmail) else { throw AppError.invalidEmail }
            guard !users.contains(where: {
                $0.id != currentUser.id && ($0.email == cleanPublicEmail || $0.publicEmail == cleanPublicEmail)
            }) else {
                throw AppError.accountExists
            }
            updatedUser.publicEmail = cleanPublicEmail
            if updatedUser.authProvider == .manual || updatedUser.email.isEmpty || AppUser.isPrivateRelayEmail(updatedUser.email) {
                updatedUser.email = cleanPublicEmail
            }
        } else {
            if updatedUser.authProvider == .manual {
                throw AppError.missingField("Email")
            }
            updatedUser.publicEmail = nil
        }

        switch currentUser.role {
        case .worker:
            guard !cleanFullName.isEmpty else { throw AppError.missingField("Full Name") }
            updatedUser.fullName = cleanFullName
            updatedUser.workerAddress = cleanWorkerAddress.isEmpty ? nil : cleanWorkerAddress
            updatedUser.workerPhone = cleanWorkerPhone.isEmpty ? nil : cleanWorkerPhone
        case .business:
            updatedUser.businessName = cleanBusinessName.isEmpty ? nil : cleanBusinessName
            updatedUser.businessAddress = cleanBusinessAddress.isEmpty ? nil : cleanBusinessAddress
            updatedUser.businessPhone = cleanBusinessPhone.isEmpty ? nil : cleanBusinessPhone
        }

        users[index] = updatedUser
        self.currentUser = updatedUser
        syncPublishedIdentity(for: updatedUser)
        persistUsers()
    }

    func createPost(
        postType: PostType,
        category: BusinessCategory,
        title: String,
        details: String,
        location: String,
        payOrRate: String,
        schedule: String,
        contact: String
    ) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard currentUser.role.allowedPostType == postType else {
            throw AppError.invalidPostTypeForRole(currentUser.role)
        }
        try ensureUserCanPublishPosts(for: currentUser)

        let draft = try validatedPostDraft(
            title: title,
            details: details,
            location: location,
            payOrRate: payOrRate,
            schedule: schedule,
            contact: contact
        )

        let post = JobPost(
            id: UUID(),
            authorID: currentUser.id,
            authorName: currentUser.displayName,
            authorContact: draft.contact,
            authorRole: currentUser.role,
            postType: postType,
            category: category,
            title: draft.title,
            details: draft.details,
            location: draft.location,
            payOrRate: draft.payOrRate,
            schedule: draft.schedule,
            createdAt: Date()
        )

        posts.append(post)
        persistPosts()
    }

    func updatePost(
        postID: UUID,
        category: BusinessCategory,
        title: String,
        details: String,
        location: String,
        payOrRate: String,
        schedule: String,
        contact: String
    ) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            throw AppError.postUnavailable
        }
        guard posts[index].authorID == currentUser.id else {
            throw AppError.postAccessDenied
        }
        guard posts[index].authorRole == currentUser.role else {
            throw AppError.invalidPostTypeForRole(currentUser.role)
        }
        try ensureUserCanPublishPosts(for: currentUser)

        let draft = try validatedPostDraft(
            title: title,
            details: details,
            location: location,
            payOrRate: payOrRate,
            schedule: schedule,
            contact: contact
        )

        posts[index].authorName = currentUser.displayName
        posts[index].authorContact = draft.contact
        posts[index].category = category
        posts[index].title = draft.title
        posts[index].details = draft.details
        posts[index].location = draft.location
        posts[index].payOrRate = draft.payOrRate
        posts[index].schedule = draft.schedule
        persistPosts()
    }

    func updateCurrentWorkerProfilePhoto(with imageData: Data) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard currentUser.role == .worker else { throw AppError.onlyWorkersCanSetProfilePhoto }

        guard let normalizedData = Self.normalizedJPEGData(from: imageData, compressionQuality: 0.82) else {
            throw AppError.invalidImageSelection
        }

        let newFileName = "worker-profile-\(currentUser.id)-\(UUID().uuidString).jpg"
        do {
            try storage.saveData(normalizedData, fileName: newFileName)
        } catch {
            throw AppError.mediaSaveFailed
        }

        if let previousFileName = currentUser.profileImageFileName {
            storage.removeData(fileName: previousFileName)
        }

        var updatedUser = currentUser
        updatedUser.profileImageFileName = newFileName

        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        }
        self.currentUser = updatedUser
        persistUsers()
    }

    func removeCurrentWorkerProfilePhoto() throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard currentUser.role == .worker else { throw AppError.onlyWorkersCanSetProfilePhoto }
        guard let existingFileName = currentUser.profileImageFileName else { return }

        storage.removeData(fileName: existingFileName)

        var updatedUser = currentUser
        updatedUser.profileImageFileName = nil

        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        }
        self.currentUser = updatedUser
        persistUsers()
    }

    func applyToPost(post: JobPost, message: String, contact: String, workerIDImageData: Data?) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard currentUser.role == .worker else { throw AppError.onlyWorkersCanApply }
        guard post.postType == .employerHiring else { throw AppError.invalidApplicationTarget }
        guard post.isActive else { throw AppError.postUnavailable }
        guard posts.contains(where: { $0.id == post.id }) else { throw AppError.postUnavailable }
        guard user(for: post.authorID)?.role == .business else { throw AppError.applicationTargetMissing }
        guard currentUser.id != post.authorID else { throw AppError.invalidApplicationTarget }
        guard currentUserApplication(for: post.id) == nil else { throw AppError.alreadyApplied }

        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanMessage.isEmpty else { throw AppError.missingField("Application Message") }
        guard !cleanContact.isEmpty else { throw AppError.missingField("Contact") }
        guard let workerIDImageData else { throw AppError.workerIDRequired }
        guard let normalizedIDData = Self.normalizedJPEGData(from: workerIDImageData, compressionQuality: 0.9) else {
            throw AppError.invalidImageSelection
        }

        let applicationID = UUID()
        let workerIDFileName = "worker-id-\(applicationID.uuidString).jpg"
        let workerProfileFileName = "worker-profile-application-\(applicationID.uuidString).jpg"
        var applicationProfileFileName: String?

        do {
            try storage.saveData(normalizedIDData, fileName: workerIDFileName)

            if let existingProfileFileName = currentUser.profileImageFileName,
               let existingProfileData = storage.loadData(fileName: existingProfileFileName) {
                try storage.saveData(existingProfileData, fileName: workerProfileFileName)
                applicationProfileFileName = workerProfileFileName
            }
        } catch {
            storage.removeData(fileName: workerIDFileName)
            if applicationProfileFileName != nil {
                storage.removeData(fileName: workerProfileFileName)
            }
            throw AppError.mediaSaveFailed
        }

        applications.append(
            JobApplication(
                id: applicationID,
                postID: post.id,
                postTitle: post.title,
                businessUserID: post.authorID,
                businessName: post.authorName,
                businessContact: post.authorContact,
                workerUserID: currentUser.id,
                workerName: currentUser.displayName,
                workerEmail: currentUser.marketplaceEmail ?? "",
                workerContact: cleanContact,
                postLocation: post.location,
                postPayOrRate: post.payOrRate,
                postSchedule: post.schedule,
                workerProfileImageFileName: applicationProfileFileName,
                workerIDImageFileName: workerIDFileName,
                message: cleanMessage,
                status: .pending,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        persistApplications()
    }

    func submitRating(score: Int, comment: String, for targetUserID: String) throws {
        guard (1...5).contains(score) else { throw AppError.invalidRatingScore }
        guard let currentUser else { throw AppError.notAuthenticated }
        guard let targetUser = user(for: targetUserID) else { throw AppError.ratingTargetMissing }
        guard currentUser.id != targetUser.id else { throw AppError.cannotRateYourself }
        guard currentUser.role != targetUser.role else { throw AppError.ratingRequiresOppositeRole }
        let cleanComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanComment.isEmpty else { throw AppError.ratingCommentRequired }

        if let index = ratings.firstIndex(where: {
            $0.raterUserID == currentUser.id && $0.targetUserID == targetUserID
        }) {
            ratings[index].score = score
            ratings[index].comment = cleanComment
            ratings[index].createdAt = Date()
        } else {
            ratings.append(
                UserRating(
                    id: UUID(),
                    raterUserID: currentUser.id,
                    targetUserID: targetUserID,
                    score: score,
                    comment: cleanComment,
                    createdAt: Date()
                )
            )
        }

        persistRatings()
    }

    func updateApplicationStatus(_ application: JobApplication, status: ApplicationStatus) throws {
        guard let currentUser else { throw AppError.notAuthenticated }
        guard currentUser.role == .business else { throw AppError.onlyBusinessesCanManageApplications }
        guard application.businessUserID == currentUser.id else { throw AppError.applicationAccessDenied }

        guard let index = applications.firstIndex(where: { $0.id == application.id }) else {
            throw AppError.applicationMissing
        }
        if post(for: application.postID) == nil, status != applications[index].status {
            throw AppError.hireAlreadyFinalized
        }

        let timestamp = Date()
        applications[index].status = status
        applications[index].updatedAt = timestamp

        if status == .hired {
            for otherIndex in applications.indices where applications[otherIndex].postID == application.postID && applications[otherIndex].id != application.id {
                applications[otherIndex].status = .declined
                applications[otherIndex].updatedAt = timestamp
            }
            deletePostsAfterHire(hiredApplication: applications[index])
        }

        persistApplications()
    }

    func deletePost(_ post: JobPost) {
        let applicationMediaFileNames = Set(
            applications
                .filter { $0.postID == post.id }
                .compactMap(\.workerProfileImageFileName)
                + applications
                    .filter { $0.postID == post.id }
                    .compactMap(\.workerIDImageFileName)
        )
        applicationMediaFileNames.forEach { storage.removeData(fileName: $0) }
        posts.removeAll { $0.id == post.id }
        applications.removeAll { $0.postID == post.id }
        persistPosts()
        persistApplications()
    }

    private func setCurrentUser(_ user: AppUser) {
        currentUser = user
        storage.save(StoredSession(userID: user.id), fileName: sessionFile)
    }

    private func persistUsers() {
        storage.save(users, fileName: usersFile)
    }

    private func persistPosts() {
        storage.save(posts, fileName: postsFile)
    }

    private func persistRatings() {
        storage.save(ratings, fileName: ratingsFile)
    }

    private func persistApplications() {
        storage.save(applications, fileName: applicationsFile)
    }

    private func validatedPostDraft(
        title: String,
        details: String,
        location: String,
        payOrRate: String,
        schedule: String,
        contact: String
    ) throws -> (title: String, details: String, location: String, payOrRate: String, schedule: String, contact: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPay = payOrRate.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSchedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else { throw AppError.missingField("Title") }
        guard !cleanDetails.isEmpty else { throw AppError.missingField("Details") }
        guard !cleanLocation.isEmpty else { throw AppError.missingField("Location") }
        guard !cleanContact.isEmpty else { throw AppError.missingField("Contact") }

        return (
            title: cleanTitle,
            details: cleanDetails,
            location: cleanLocation,
            payOrRate: cleanPay,
            schedule: cleanSchedule,
            contact: cleanContact
        )
    }

    private func ensureUserCanPublishPosts(for user: AppUser) throws {
        switch user.role {
        case .business:
            guard user.businessProfileIsComplete else {
                throw AppError.businessProfileIncomplete(fields: user.missingBusinessFields)
            }
        case .worker:
            guard user.workerProfileIsComplete else {
                throw AppError.workerProfileIncomplete(fields: user.missingWorkerFields)
            }
        }
    }

    private func deletePostsAfterHire(hiredApplication: JobApplication) {
        posts.removeAll { post in
            if post.id == hiredApplication.postID {
                return true
            }
            return post.authorID == hiredApplication.workerUserID && post.postType == .workerSeeking
        }
        persistPosts()
    }

    private func syncPublishedIdentity(for user: AppUser) {
        var didUpdatePosts = false
        for index in posts.indices where posts[index].authorID == user.id {
            posts[index].authorName = user.displayName
            didUpdatePosts = true
        }

        if didUpdatePosts {
            persistPosts()
        }
    }

    private static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func fullName(from components: PersonNameComponents?) -> String {
        guard let components else { return "" }
        return PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedEmailValue(_ value: String?) -> String? {
        value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func usableAppleEmail(_ email: String?) -> String? {
        guard let normalizedEmail = normalizedEmailValue(email),
              !normalizedEmail.isEmpty,
              !AppUser.isPrivateRelayEmail(normalizedEmail) else {
            return nil
        }
        return normalizedEmail
    }

    private static func normalizedJPEGData(from data: Data, compressionQuality: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: compressionQuality)
    }
}

private struct StoredSession: Codable {
    let userID: String
}

enum AppError: LocalizedError {
    case missingField(String)
    case invalidEmail
    case weakPassword
    case accountExists
    case accountNotFound
    case invalidCredentials
    case useAppleSignIn
    case notAuthenticated
    case portalMismatch(expected: UserRole)
    case invalidPostTypeForRole(UserRole)
    case businessProfileIncomplete(fields: [String])
    case workerProfileIncomplete(fields: [String])
    case invalidRatingScore
    case ratingCommentRequired
    case cannotRateYourself
    case ratingRequiresOppositeRole
    case ratingTargetMissing
    case deleteAccountFailed
    case onlyWorkersCanApply
    case invalidApplicationTarget
    case applicationTargetMissing
    case postUnavailable
    case alreadyApplied
    case onlyBusinessesCanManageApplications
    case applicationAccessDenied
    case applicationMissing
    case postAccessDenied
    case hireAlreadyFinalized
    case onlyWorkersCanSetProfilePhoto
    case workerIDRequired
    case invalidImageSelection
    case mediaSaveFailed

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "\(field) is required."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .accountExists:
            return "An account with this email already exists."
        case .accountNotFound:
            return "No account found with that email."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .useAppleSignIn:
            return "This account uses Apple Sign In. Use the Apple button below."
        case .notAuthenticated:
            return "Please sign in first."
        case .portalMismatch(let expected):
            return "This account belongs to the \(expected.title) portal. Switch portals and try again."
        case .invalidPostTypeForRole(let role):
            switch role {
            case .worker:
                return "Worker accounts can only publish worker profile posts."
            case .business:
                return "Business accounts can only publish hiring posts."
            }
        case .businessProfileIncomplete(let fields):
            let joined = fields.joined(separator: ", ")
            return "Complete your business profile before posting. Missing: \(joined)."
        case .workerProfileIncomplete(let fields):
            let joined = fields.joined(separator: ", ")
            return "Complete your worker profile before posting. Missing: \(joined)."
        case .invalidRatingScore:
            return "Please choose a rating from 1 to 5."
        case .ratingCommentRequired:
            return "Please add a comment with your rating."
        case .cannotRateYourself:
            return "You can't rate your own account."
        case .ratingRequiresOppositeRole:
            return "Ratings can only be left between workers and businesses."
        case .ratingTargetMissing:
            return "This account is no longer available."
        case .deleteAccountFailed:
            return "Your account could not be deleted right now."
        case .onlyWorkersCanApply:
            return "Only worker accounts can apply for jobs."
        case .invalidApplicationTarget:
            return "Applications can only be sent to active business job posts."
        case .applicationTargetMissing:
            return "This business is no longer available."
        case .postUnavailable:
            return "This job post is no longer available."
        case .alreadyApplied:
            return "You already applied to this job."
        case .onlyBusinessesCanManageApplications:
            return "Only businesses can update application statuses."
        case .applicationAccessDenied:
            return "You don't have access to manage this application."
        case .applicationMissing:
            return "This application is no longer available."
        case .postAccessDenied:
            return "You can only manage posts that belong to your account."
        case .hireAlreadyFinalized:
            return "This hire is finalized. The related posts were already removed."
        case .onlyWorkersCanSetProfilePhoto:
            return "Only workers can add a worker profile photo."
        case .workerIDRequired:
            return "Upload a photo of your ID before sending the application."
        case .invalidImageSelection:
            return "The selected image could not be used. Try another photo."
        case .mediaSaveFailed:
            return "The selected photo could not be saved right now."
        }
    }
}

private enum Validator {
    static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
}
