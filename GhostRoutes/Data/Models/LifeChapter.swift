import Foundation
import GRDB

struct LifeChapter: Codable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var startsAt: Date
    var endsAt: Date?
    var label: String?
    var changeScore: Double
    var boundingLatMin: Double?
    var boundingLatMax: Double?
    var boundingLngMin: Double?
    var boundingLngMax: Double?

    static let databaseTableName = "life_chapters"

    enum CodingKeys: String, CodingKey {
        case id
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case label
        case changeScore = "change_score"
        case boundingLatMin = "bounding_lat_min"
        case boundingLatMax = "bounding_lat_max"
        case boundingLngMin = "bounding_lng_min"
        case boundingLngMax = "bounding_lng_max"
    }

    static let databaseDateDecodingStrategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
    static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
