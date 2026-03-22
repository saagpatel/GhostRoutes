import Foundation
import GRDB

struct LocationRecord: Codable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var accuracyMeters: Double?
    var source: DataSource
    var rawJson: String?
    var createdAt: Date?

    enum DataSource: String, Codable, Sendable, DatabaseValueConvertible {
        case takeout
        case clvisit
    }

    static let databaseTableName = "location_records"

    enum CodingKeys: String, CodingKey {
        case id
        case latitude
        case longitude
        case timestamp
        case accuracyMeters = "accuracy_meters"
        case source
        case rawJson = "raw_json"
        case createdAt = "created_at"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let timestamp = Column(CodingKeys.timestamp)
        static let accuracyMeters = Column(CodingKeys.accuracyMeters)
        static let source = Column(CodingKeys.source)
    }

    static let databaseDateDecodingStrategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
    static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
