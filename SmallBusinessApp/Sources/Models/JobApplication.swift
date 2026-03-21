import Foundation

enum ApplicationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case reviewed
    case contacted
    case hired
    case declined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .reviewed: return "Reviewed"
        case .contacted: return "Contacted"
        case .hired: return "Hired"
        case .declined: return "Declined"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: return "hourglass"
        case .reviewed: return "doc.text.magnifyingglass"
        case .contacted: return "phone.badge.waveform"
        case .hired: return "checkmark.seal.fill"
        case .declined: return "xmark.seal"
        }
    }
}

struct JobApplication: Identifiable, Codable, Equatable {
    let id: UUID
    let postID: UUID
    let postTitle: String
    let businessUserID: String
    let businessName: String
    var businessContact: String?
    let workerUserID: String
    let workerName: String
    let workerEmail: String
    var workerContact: String
    var postLocation: String
    var postPayOrRate: String
    var postSchedule: String
    var workerProfileImageFileName: String?
    var workerIDImageFileName: String?
    var message: String
    var status: ApplicationStatus
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postID
        case postTitle
        case businessUserID
        case businessName
        case businessContact
        case workerUserID
        case workerName
        case workerEmail
        case workerContact
        case postLocation
        case postPayOrRate
        case postSchedule
        case workerProfileImageFileName
        case workerIDImageFileName
        case message
        case status
        case createdAt
        case updatedAt
    }

    init(
        id: UUID,
        postID: UUID,
        postTitle: String,
        businessUserID: String,
        businessName: String,
        businessContact: String? = nil,
        workerUserID: String,
        workerName: String,
        workerEmail: String,
        workerContact: String,
        postLocation: String = "",
        postPayOrRate: String = "",
        postSchedule: String = "",
        workerProfileImageFileName: String? = nil,
        workerIDImageFileName: String? = nil,
        message: String,
        status: ApplicationStatus,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.postID = postID
        self.postTitle = postTitle
        self.businessUserID = businessUserID
        self.businessName = businessName
        self.businessContact = businessContact
        self.workerUserID = workerUserID
        self.workerName = workerName
        self.workerEmail = workerEmail
        self.workerContact = workerContact
        self.postLocation = postLocation
        self.postPayOrRate = postPayOrRate
        self.postSchedule = postSchedule
        self.workerProfileImageFileName = workerProfileImageFileName
        self.workerIDImageFileName = workerIDImageFileName
        self.message = message
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postID = try container.decode(UUID.self, forKey: .postID)
        postTitle = try container.decode(String.self, forKey: .postTitle)
        businessUserID = try container.decode(String.self, forKey: .businessUserID)
        businessName = try container.decode(String.self, forKey: .businessName)
        businessContact = try container.decodeIfPresent(String.self, forKey: .businessContact)
        workerUserID = try container.decode(String.self, forKey: .workerUserID)
        workerName = try container.decode(String.self, forKey: .workerName)
        workerEmail = try container.decode(String.self, forKey: .workerEmail)
        workerContact = try container.decode(String.self, forKey: .workerContact)
        postLocation = try container.decodeIfPresent(String.self, forKey: .postLocation) ?? ""
        postPayOrRate = try container.decodeIfPresent(String.self, forKey: .postPayOrRate) ?? ""
        postSchedule = try container.decodeIfPresent(String.self, forKey: .postSchedule) ?? ""
        workerProfileImageFileName = try container.decodeIfPresent(String.self, forKey: .workerProfileImageFileName)
        workerIDImageFileName = try container.decodeIfPresent(String.self, forKey: .workerIDImageFileName)
        message = try container.decode(String.self, forKey: .message)
        status = try container.decode(ApplicationStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
