import Foundation
import GRDB

struct GhostLocation: Codable, Identifiable, Sendable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var clusterLat: Double
    var clusterLng: Double
    var placeCacheId: Int64?
    var peakVisitsPerMonth: Double
    var currentVisitsPerMonth: Double
    var ghostlinessScore: Double
    var peakPeriodStart: Date
    var peakPeriodEnd: Date
    var lastVisitAt: Date
    var alertSentAt: Date?
    var isDismissed: Bool
    var cachedDisplayName: String?
    var detectedAt: Date?

    static let databaseTableName = "ghost_locations"

    enum CodingKeys: String, CodingKey {
        case id
        case clusterLat = "cluster_lat"
        case clusterLng = "cluster_lng"
        case placeCacheId = "place_cache_id"
        case peakVisitsPerMonth = "peak_visits_per_month"
        case currentVisitsPerMonth = "current_visits_per_month"
        case ghostlinessScore = "ghostliness_score"
        case peakPeriodStart = "peak_period_start"
        case peakPeriodEnd = "peak_period_end"
        case lastVisitAt = "last_visit_at"
        case alertSentAt = "alert_sent_at"
        case isDismissed = "is_dismissed"
        case cachedDisplayName = "cached_display_name"
        case detectedAt = "detected_at"
    }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let ghostlinessScore = Column(CodingKeys.ghostlinessScore)
        static let isDismissed = Column(CodingKeys.isDismissed)
        static let alertSentAt = Column(CodingKeys.alertSentAt)
    }

    static let databaseDateDecodingStrategy: DatabaseDateDecodingStrategy = .timeIntervalSince1970
    static let databaseDateEncodingStrategy: DatabaseDateEncodingStrategy = .timeIntervalSince1970

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
