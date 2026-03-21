import Foundation

enum PostType: String, Codable, CaseIterable, Identifiable {
    case employerHiring
    case workerSeeking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .employerHiring: return "Hiring"
        case .workerSeeking: return "Looking For Work"
        }
    }

    var subtitle: String {
        switch self {
        case .employerHiring: return "Business is hiring staff"
        case .workerSeeking: return "Worker is looking for a job"
        }
    }

    var icon: String {
        switch self {
        case .employerHiring: return "building.2.crop.circle"
        case .workerSeeking: return "person.crop.circle.badge.checkmark"
        }
    }
}

enum BusinessCategory: String, Codable, CaseIterable, Identifiable {
    case grocery
    case deli
    case restaurant
    case dollarStore
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grocery: return "Grocery"
        case .deli: return "Deli"
        case .restaurant: return "Restaurant"
        case .dollarStore: return "99 Cents Store"
        case .other: return "Other"
        }
    }
}

struct JobPost: Identifiable, Codable, Equatable {
    let id: UUID
    let authorID: String
    var authorName: String
    var authorContact: String
    var authorRole: UserRole
    var postType: PostType
    var category: BusinessCategory
    var title: String
    var details: String
    var location: String
    var payOrRate: String
    var schedule: String
    var isActive: Bool
    var closedAt: Date?
    var filledWorkerID: String?
    var createdAt: Date

    var isVisibleInFeed: Bool {
        postType == .employerHiring ? isActive : true
    }

    enum CodingKeys: String, CodingKey {
        case id
        case authorID
        case authorName
        case authorContact
        case authorRole
        case postType
        case category
        case title
        case details
        case location
        case payOrRate
        case schedule
        case isActive
        case closedAt
        case filledWorkerID
        case createdAt
    }

    init(
        id: UUID,
        authorID: String,
        authorName: String,
        authorContact: String,
        authorRole: UserRole,
        postType: PostType,
        category: BusinessCategory,
        title: String,
        details: String,
        location: String,
        payOrRate: String,
        schedule: String,
        isActive: Bool = true,
        closedAt: Date? = nil,
        filledWorkerID: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.authorID = authorID
        self.authorName = authorName
        self.authorContact = authorContact
        self.authorRole = authorRole
        self.postType = postType
        self.category = category
        self.title = title
        self.details = details
        self.location = location
        self.payOrRate = payOrRate
        self.schedule = schedule
        self.isActive = isActive
        self.closedAt = closedAt
        self.filledWorkerID = filledWorkerID
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        authorID = try container.decode(String.self, forKey: .authorID)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorContact = try container.decode(String.self, forKey: .authorContact)
        postType = try container.decode(PostType.self, forKey: .postType)
        authorRole = try container.decodeIfPresent(UserRole.self, forKey: .authorRole)
            ?? (postType == .employerHiring ? .business : .worker)
        category = try container.decode(BusinessCategory.self, forKey: .category)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decode(String.self, forKey: .details)
        location = try container.decode(String.self, forKey: .location)
        payOrRate = try container.decode(String.self, forKey: .payOrRate)
        schedule = try container.decode(String.self, forKey: .schedule)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        closedAt = try container.decodeIfPresent(Date.self, forKey: .closedAt)
        filledWorkerID = try container.decodeIfPresent(String.self, forKey: .filledWorkerID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
