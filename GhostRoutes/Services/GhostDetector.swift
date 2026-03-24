import Foundation
import os.log

struct GhostDetector: Sendable {

    struct VisitCluster: Sendable {
        var centroidLat: Double
        var centroidLng: Double
        var visits: [Visit]
        var totalVisitCount: Int { visits.count }
    }

    /// Detect ghost locations from a set of visits.
    /// - Parameters:
    ///   - visits: All visits to analyze.
    ///   - referenceDate: The "now" date for analysis (injectable for testing).
    /// - Returns: Ghost locations sorted by ghostliness score descending.
    static func detect(
        visits: [Visit],
        referenceDate: Date = Date()
    ) -> [GhostLocation] {
        guard !visits.isEmpty else { return [] }

        // Check minimum history
        let sortedVisits = visits.sorted { $0.arrivedAt < $1.arrivedAt }
        guard let earliest = sortedVisits.first?.arrivedAt else { return [] }

        let totalDays = Calendar.current.dateComponents(
            [.day], from: earliest, to: referenceDate
        ).day ?? 0
        guard totalDays >= GhostThresholds.minDaysOfHistory else {
            Logger.ghostDetector.info(
                "Insufficient history: \(totalDays) days (need \(GhostThresholds.minDaysOfHistory))"
            )
            return []
        }

        // Phase 1: Grid bucketing
        let buckets = bucketVisits(sortedVisits)

        // Phase 2: Cluster merging
        let clusters = mergeClusters(from: buckets)

        // Phase 3+4: Frequency analysis + ghost scoring
        let ghosts = analyzeAndScore(clusters: clusters, referenceDate: referenceDate)

        Logger.ghostDetector.info(
            "Detected \(ghosts.count) ghosts from \(clusters.count) clusters (\(visits.count) visits)"
        )

        return ghosts.sorted { $0.ghostlinessScore > $1.ghostlinessScore }
    }

    // MARK: - Phase 1: Grid Bucketing

    private static func gridKey(lat: Double, lng: Double) -> String {
        let latKey = Int(floor(lat * 2000))
        let lngKey = Int(floor(lng * 2000))
        return "\(latKey),\(lngKey)"
    }

    private static func bucketVisits(_ visits: [Visit]) -> [String: [Visit]] {
        var buckets: [String: [Visit]] = [:]
        for visit in visits {
            let key = gridKey(lat: visit.clusterLat, lng: visit.clusterLng)
            buckets[key, default: []].append(visit)
        }
        return buckets
    }

    // MARK: - Phase 2: Cluster Merging

    private static func neighborKeys(for key: String) -> [String] {
        let parts = key.split(separator: ",")
        guard parts.count == 2,
              let latKey = Int(parts[0]),
              let lngKey = Int(parts[1])
        else { return [key] }

        var keys: [String] = []
        for dLat in -1...1 {
            for dLng in -1...1 {
                keys.append("\(latKey + dLat),\(lngKey + dLng)")
            }
        }
        return keys
    }

    private static func mergeClusters(from buckets: [String: [Visit]]) -> [VisitCluster] {
        var clusters: [VisitCluster] = []
        var processedKeys: Set<String> = []

        for key in buckets.keys {
            if processedKeys.contains(key) { continue }

            // Collect visits from this cell and all neighbors
            let neighborVisits = neighborKeys(for: key).flatMap { neighborKey in
                buckets[neighborKey] ?? []
            }

            // Mark neighbor keys as processed to avoid double-processing
            for neighborKey in neighborKeys(for: key) where buckets[neighborKey] != nil {
                processedKeys.insert(neighborKey)
            }

            // Greedy centroid clustering within this neighborhood
            var localClusters: [VisitCluster] = []
            for visit in neighborVisits {
                var merged = false
                for i in localClusters.indices {
                    let dist = haversineDistance(
                        lat1: localClusters[i].centroidLat,
                        lng1: localClusters[i].centroidLng,
                        lat2: visit.clusterLat,
                        lng2: visit.clusterLng
                    )
                    if dist <= GhostThresholds.clusterRadiusMeters {
                        // Update centroid as weighted average
                        let count = Double(localClusters[i].visits.count)
                        localClusters[i].centroidLat =
                            (localClusters[i].centroidLat * count + visit.clusterLat) / (count + 1)
                        localClusters[i].centroidLng =
                            (localClusters[i].centroidLng * count + visit.clusterLng) / (count + 1)
                        localClusters[i].visits.append(visit)
                        merged = true
                        break
                    }
                }
                if !merged {
                    localClusters.append(VisitCluster(
                        centroidLat: visit.clusterLat,
                        centroidLng: visit.clusterLng,
                        visits: [visit]
                    ))
                }
            }

            clusters.append(contentsOf: localClusters)
        }

        return clusters
    }

    // MARK: - Phase 3+4: Frequency Analysis + Ghost Scoring

    private static func analyzeAndScore(
        clusters: [VisitCluster],
        referenceDate: Date
    ) -> [GhostLocation] {
        let calendar = Calendar.current
        var ghosts: [GhostLocation] = []

        for cluster in clusters {
            guard cluster.visits.count >= 2 else { continue }

            let sortedVisits = cluster.visits.sorted { $0.arrivedAt < $1.arrivedAt }
            guard let firstVisit = sortedVisits.first,
                  let lastVisit = sortedVisits.last
            else { continue }

            // Bucket visits by year-month
            var monthBuckets: [String: Int] = [:]
            for visit in sortedVisits {
                let comps = calendar.dateComponents([.year, .month], from: visit.arrivedAt)
                let key = "\(comps.year ?? 0)-\(comps.month ?? 0)"
                monthBuckets[key, default: 0] += 1
            }

            // Find peak sustained period (rolling window of minPeakSustainedWeeks)
            let monthlyVisits = monthBuckets.values.sorted(by: >)
            let peakMonths = min(
                max(GhostThresholds.minPeakSustainedWeeks / 4, 1),
                monthlyVisits.count
            )
            let peakVisitsPerMonth: Double = if peakMonths > 0 {
                Double(monthlyVisits.prefix(peakMonths).reduce(0, +)) / Double(peakMonths)
            } else {
                0
            }

            guard peakVisitsPerMonth > 0 else { continue }

            // Find actual peak period date range
            let sortedMonthEntries = monthBuckets.sorted { $0.value > $1.value }
            let peakPeriodStart = findDateForMonthKey(
                sortedMonthEntries.last?.key ?? "", calendar: calendar
            ) ?? firstVisit.arrivedAt
            let peakPeriodEnd = findDateForMonthKey(
                sortedMonthEntries.first?.key ?? "", calendar: calendar
            ) ?? lastVisit.arrivedAt

            // Current visit rate (trailing rolling window)
            let windowStart = calendar.date(
                byAdding: .day,
                value: -GhostThresholds.rollingWindowDays,
                to: referenceDate
            ) ?? referenceDate

            let recentVisits = sortedVisits.filter { $0.arrivedAt >= windowStart }
            let windowMonths = Double(GhostThresholds.rollingWindowDays) / 30.0
            let currentVisitsPerMonth = Double(recentVisits.count) / windowMonths

            // Ghost detection: current < threshold ratio of peak
            let isGhost = currentVisitsPerMonth < GhostThresholds.ghostThresholdRatio * peakVisitsPerMonth

            guard isGhost else { continue }

            // Ghost scoring
            let daysSinceLastVisit = calendar.dateComponents(
                [.day], from: lastVisit.arrivedAt, to: referenceDate
            ).day ?? 0
            let weeksSinceLastVisit = Double(daysSinceLastVisit) / 7.0

            let ghostlinessScore =
                (peakVisitsPerMonth / max(currentVisitsPerMonth, 0.01)) * weeksSinceLastVisit

            ghosts.append(GhostLocation(
                clusterLat: cluster.centroidLat,
                clusterLng: cluster.centroidLng,
                peakVisitsPerMonth: peakVisitsPerMonth,
                currentVisitsPerMonth: currentVisitsPerMonth,
                ghostlinessScore: ghostlinessScore,
                peakPeriodStart: peakPeriodStart,
                peakPeriodEnd: peakPeriodEnd,
                lastVisitAt: lastVisit.arrivedAt,
                isDismissed: false
            ))
        }

        return ghosts
    }

    private static func findDateForMonthKey(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }
}

// MARK: - Logger

extension Logger {
    static let ghostDetector = Logger(subsystem: "com.ghostroutes.app", category: "ghostDetector")
}
