import Foundation
import os.log

struct VisitClusterer: Sendable {

    /// Cluster sequential location records into visits using temporal-spatial sweep.
    /// Records within 50m and 30-min gaps are grouped. Visits shorter than 5 min are discarded.
    static func cluster(_ records: [LocationRecord]) -> [Visit] {
        guard records.count >= 2 else { return [] }

        let sorted = records.sorted { $0.timestamp < $1.timestamp }
        var visits: [Visit] = []

        var clusterRecords: [LocationRecord] = [sorted[0]]
        var centroidLat = sorted[0].latitude
        var centroidLng = sorted[0].longitude

        for i in 1..<sorted.count {
            let record = sorted[i]
            let lastRecord = clusterRecords.last!

            let timeGap = record.timestamp.timeIntervalSince(lastRecord.timestamp)
            let distance = haversineDistance(
                lat1: centroidLat, lng1: centroidLng,
                lat2: record.latitude, lng2: record.longitude
            )

            if timeGap <= Double(GhostThresholds.visitGapSeconds)
                && distance <= GhostThresholds.clusterRadiusMeters
            {
                // Same visit — update centroid as weighted average
                let count = Double(clusterRecords.count)
                centroidLat = (centroidLat * count + record.latitude) / (count + 1)
                centroidLng = (centroidLng * count + record.longitude) / (count + 1)
                clusterRecords.append(record)
            } else {
                // Finalize current cluster
                if let visit = finalizeCluster(clusterRecords, centroidLat: centroidLat, centroidLng: centroidLng) {
                    visits.append(visit)
                }
                // Start new cluster
                clusterRecords = [record]
                centroidLat = record.latitude
                centroidLng = record.longitude
            }
        }

        // Finalize last cluster
        if let visit = finalizeCluster(clusterRecords, centroidLat: centroidLat, centroidLng: centroidLng) {
            visits.append(visit)
        }

        Logger.visitClusterer.info("Clustered \(records.count) records into \(visits.count) visits")
        return visits
    }

    private static func finalizeCluster(
        _ records: [LocationRecord],
        centroidLat: Double,
        centroidLng: Double
    ) -> Visit? {
        guard records.count >= 2,
              let first = records.first,
              let last = records.last
        else { return nil }

        let duration = Int(last.timestamp.timeIntervalSince(first.timestamp))
        guard duration >= GhostThresholds.visitMinDurationSeconds else { return nil }

        return Visit(
            clusterLat: centroidLat,
            clusterLng: centroidLng,
            arrivedAt: first.timestamp,
            departedAt: last.timestamp,
            durationSeconds: duration,
            source: first.source
        )
    }
}

extension Logger {
    static let visitClusterer = Logger(subsystem: "com.ghostroutes.app", category: "visitClusterer")
}
