import Foundation
import GRDB

struct PlaceCache: Codable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var latitude: Double
    var longitude: Double
    var displayName: String
    var locality: String?
    var geocodedAt: Date
    var cacheKey: String

    static let databaseTableName = "place_cache"

    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case displayName = "display_name"
        case locality
        case geocodedAt = "geocoded_at"
        case cacheKey = "cache_key"
    }

    static let databaseDateDecodingStrategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
    static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970

    static func makeCacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f_%.4f", latitude, longitude)
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
