import Foundation

struct UserRating: Identifiable, Codable, Equatable {
    let id: UUID
    let raterUserID: String
    let targetUserID: String
    var score: Int
    var comment: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case raterUserID
        case targetUserID
        case score
        case comment
        case createdAt
    }

    init(
        id: UUID,
        raterUserID: String,
        targetUserID: String,
        score: Int,
        comment: String = "",
        createdAt: Date
    ) {
        self.id = id
        self.raterUserID = raterUserID
        self.targetUserID = targetUserID
        self.score = score
        self.comment = comment
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        raterUserID = try container.decode(String.self, forKey: .raterUserID)
        targetUserID = try container.decode(String.self, forKey: .targetUserID)
        score = try container.decode(Int.self, forKey: .score)
        comment = try container.decodeIfPresent(String.self, forKey: .comment) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
