import Foundation

enum GhostThresholds {
    static let minDaysOfHistory: Int = 90
    static let rollingWindowDays: Int = 90
    static let ghostThresholdRatio: Double = 0.20
    static let minPeakSustainedWeeks: Int = 4
    static let clusterRadiusMeters: Double = 50.0
    static let ghostlinessAlertThreshold: Double = 5.0
    static let alertCooldownDays: Int = 30
    static let visitGapSeconds: Int = 1800          // 30 min — max gap between records in same visit
    static let visitMinDurationSeconds: Int = 300   // 5 min — minimum visit duration to count
    static let routeSegmentGapSeconds: Int = 3600   // 1 hour — gap that splits route segments
}
