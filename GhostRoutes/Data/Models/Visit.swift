import Foundation
import GRDB

struct Visit: Codable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var clusterLat: Double
    var clusterLng: Double
    var arrivedAt: Date
    var departedAt: Date
    var durationSeconds: Int
    var source: LocationRecord.DataSource
    var placeCacheId: Int64?

    static let databaseTableName = "visits"

    enum CodingKeys: String, CodingKey {
        case id
        case clusterLat = "cluster_lat"
        case clusterLng = "cluster_lng"
        case arrivedAt = "arrived_at"
        case departedAt = "departed_at"
        case durationSeconds = "duration_seconds"
        case source
        case placeCacheId = "place_cache_id"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let clusterLat = Column(CodingKeys.clusterLat)
        static let clusterLng = Column(CodingKeys.clusterLng)
        static let arrivedAt = Column(CodingKeys.arrivedAt)
        static let departedAt = Column(CodingKeys.departedAt)
        static let source = Column(CodingKeys.source)
    }

    static let databaseDateDecodingStrategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
    static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
