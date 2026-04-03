import Foundation

enum AuthProvider: String, Codable, CaseIterable {
    case manual
    case apple
    case google

    var displayName: String {
        switch self {
        case .manual: return "Email"
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case worker
    case business

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worker: return "Worker"
        case .business: return "Business"
        }
    }

    var portalTitle: String {
        switch self {
        case .worker: return "Workers"
        case .business: return "Businesses"
        }
    }

    var subtitle: String {
        switch self {
        case .worker:
            return "Workers sign in to find jobs, post their profile, and build a trusted rating."
        case .business:
            return "Small businesses sign in to hire workers, post openings, and build a trusted rating."
        }
    }

    var icon: String {
        switch self {
        case .worker: return "person.crop.circle"
        case .business: return "building.2.crop.circle"
        }
    }

    var accountNameLabel: String {
        switch self {
        case .worker: return "Full Name"
        case .business: return "Business Name"
        }
    }

    var ratingLabel: String {
        switch self {
        case .worker: return "Worker Rating"
        case .business: return "Business Rating"
        }
    }

    var allowedPostType: PostType {
        switch self {
        case .worker: return .workerSeeking
        case .business: return .employerHiring
        }
    }

    var createButtonTitle: String {
        switch self {
        case .worker: return "Publish Worker Profile"
        case .business: return "Publish Job Opening"
        }
    }
}

struct AppUser: Identifiable, Codable, Equatable {
    let id: String
    var fullName: String
    var email: String
    var publicEmail: String?
    var passwordHash: String?
    var profileImageFileName: String?
    var workerAddress: String?
    var workerPhone: String?
    var businessName: String?
    var businessAddress: String?
    var businessPhone: String?
    var role: UserRole
    var authProvider: AuthProvider
    var createdAt: Date

    var displayName: String {
        switch role {
        case .worker:
            return fullName
        case .business:
            return Self.trimmedValue(businessName) ?? fullName
        }
    }

    var marketplaceEmail: String? {
        if let publicEmail = Self.trimmedValue(publicEmail) {
            return publicEmail
        }
        guard let email = Self.trimmedValue(email), !Self.isPrivateRelayEmail(email) else {
            return nil
        }
        return email
    }

    var emailDisplayText: String {
        marketplaceEmail ?? "No public email on file"
    }

    var hasHiddenAppleEmail: Bool {
        authProvider == .apple && (marketplaceEmail == nil || Self.isPrivateRelayEmail(email))
    }

    var workerProfileIsComplete: Bool {
        guard role == .worker else { return true }
        return missingWorkerFields.isEmpty
    }

    var businessProfileIsComplete: Bool {
        guard role == .business else { return true }
        return missingBusinessFields.isEmpty
    }

    var postingProfileIsComplete: Bool {
        switch role {
        case .worker:
            return workerProfileIsComplete
        case .business:
            return businessProfileIsComplete
        }
    }

    var missingPostingFields: [String] {
        switch role {
        case .worker:
            return missingWorkerFields
        case .business:
            return missingBusinessFields
        }
    }

    var preferredPhone: String? {
        switch role {
        case .worker:
            return Self.trimmedValue(workerPhone)
        case .business:
            return Self.trimmedValue(businessPhone)
        }
    }

    var preferredAddress: String? {
        switch role {
        case .worker:
            return Self.trimmedValue(workerAddress)
        case .business:
            return Self.trimmedValue(businessAddress)
        }
    }

    var missingWorkerFields: [String] {
        guard role == .worker else { return [] }

        var fields: [String] = []
        if Self.trimmedValue(workerAddress) == nil {
            fields.append("address")
        }
        if Self.trimmedValue(workerPhone) == nil {
            fields.append("phone number")
        }
        return fields
    }

    var missingBusinessFields: [String] {
        guard role == .business else { return [] }

        var fields: [String] = []
        if Self.trimmedValue(businessName) == nil {
            fields.append("business name")
        }
        if Self.trimmedValue(businessAddress) == nil {
            fields.append("business address")
        }
        if Self.trimmedValue(businessPhone) == nil {
            fields.append("business phone")
        }
        return fields
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fullName
        case email
        case publicEmail
        case passwordHash
        case profileImageFileName
        case workerAddress
        case workerPhone
        case businessName
        case businessAddress
        case businessPhone
        case role
        case authProvider
        case createdAt
    }

    init(
        id: String,
        fullName: String,
        email: String,
        publicEmail: String? = nil,
        passwordHash: String?,
        profileImageFileName: String? = nil,
        workerAddress: String? = nil,
        workerPhone: String? = nil,
        businessName: String? = nil,
        businessAddress: String? = nil,
        businessPhone: String? = nil,
        role: UserRole,
        authProvider: AuthProvider,
        createdAt: Date
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.publicEmail = publicEmail
        self.passwordHash = passwordHash
        self.profileImageFileName = profileImageFileName
        self.workerAddress = workerAddress
        self.workerPhone = workerPhone
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.businessPhone = businessPhone
        self.role = role
        self.authProvider = authProvider
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        email = Self.trimmedValue(try container.decode(String.self, forKey: .email)) ?? ""
        publicEmail = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .publicEmail))
        passwordHash = try container.decodeIfPresent(String.self, forKey: .passwordHash)
        profileImageFileName = try container.decodeIfPresent(String.self, forKey: .profileImageFileName)
        workerAddress = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .workerAddress))
        workerPhone = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .workerPhone))
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .worker
        businessName = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .businessName))
        businessAddress = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .businessAddress))
        businessPhone = Self.trimmedValue(try container.decodeIfPresent(String.self, forKey: .businessPhone))
        authProvider = try container.decode(AuthProvider.self, forKey: .authProvider)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        if publicEmail == nil, !Self.isPrivateRelayEmail(email) {
            publicEmail = Self.trimmedValue(email)
        }
        if role == .business, businessName == nil {
            businessName = Self.trimmedValue(fullName)
        }
    }

    static func isPrivateRelayEmail(_ email: String?) -> Bool {
        guard let email = trimmedValue(email)?.lowercased() else { return false }
        return email.contains("privaterelay.appleid.com")
    }

    private static func trimmedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
