import Foundation
import os.log

struct ChapterDetector: Sendable {

    private static let windowDays = 30
    private static let shiftThresholdMeters = 2000.0  // 2km centroid shift = chapter boundary
    private static let minChapterDays = 60

    /// Detect life chapter boundaries from visit history.
    static func detect(visits: [Visit]) -> [LifeChapter] {
        guard visits.count >= 2 else { return [] }

        let sorted = visits.sorted { $0.arrivedAt < $1.arrivedAt }
        guard let earliest = sorted.first?.arrivedAt,
              let latest = sorted.last?.arrivedAt
        else { return [] }

        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: earliest, to: latest).day ?? 0
        guard totalDays >= minChapterDays else { return [] }

        // Compute window centroids
        var windowCentroids: [(date: Date, lat: Double, lng: Double)] = []
        var windowStart = earliest

        while windowStart < latest {
            guard let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: windowStart)
            else { break }

            let windowVisits = sorted.filter { $0.arrivedAt >= windowStart && $0.arrivedAt < windowEnd }

            if !windowVisits.isEmpty {
                let avgLat = windowVisits.map(\.clusterLat).reduce(0, +) / Double(windowVisits.count)
                let avgLng = windowVisits.map(\.clusterLng).reduce(0, +) / Double(windowVisits.count)
                windowCentroids.append((date: windowStart, lat: avgLat, lng: avgLng))
            }

            guard let nextWindow = calendar.date(byAdding: .day, value: windowDays, to: windowStart)
            else { break }
            windowStart = nextWindow
        }

        guard windowCentroids.count >= 2 else {
            return [makeChapter(visits: sorted, start: earliest, end: nil, changeScore: 0)]
        }

        // Find boundaries where centroid shifts > threshold
        var boundaries: [Date] = [earliest]

        for i in 1..<windowCentroids.count {
            let prev = windowCentroids[i - 1]
            let curr = windowCentroids[i]
            let shift = haversineDistance(
                lat1: prev.lat, lng1: prev.lng,
                lat2: curr.lat, lng2: curr.lng
            )

            if shift > shiftThresholdMeters {
                boundaries.append(curr.date)
            }
        }

        // Build chapters from boundaries
        var chapters: [LifeChapter] = []

        for i in 0..<boundaries.count {
            let start = boundaries[i]
            let end: Date? = (i + 1 < boundaries.count) ? boundaries[i + 1] : nil

            let chapterVisits = sorted.filter { visit in
                visit.arrivedAt >= start && (end == nil || visit.arrivedAt < end!)
            }
            guard !chapterVisits.isEmpty else { continue }

            // Check minimum duration
            let chapterDays = calendar.dateComponents(
                [.day],
                from: start,
                to: end ?? latest
            ).day ?? 0

            if chapterDays < minChapterDays && chapters.count > 0 {
                // Merge short chapter into previous
                continue
            }

            let shift: Double = if i > 0, i - 1 < windowCentroids.count, i < windowCentroids.count {
                haversineDistance(
                    lat1: windowCentroids[i - 1].lat, lng1: windowCentroids[i - 1].lng,
                    lat2: windowCentroids[i].lat, lng2: windowCentroids[i].lng
                )
            } else {
                0
            }

            chapters.append(makeChapter(
                visits: chapterVisits,
                start: start,
                end: end,
                changeScore: shift
            ))
        }

        // If no boundaries found, return single chapter
        if chapters.isEmpty {
            chapters.append(makeChapter(visits: sorted, start: earliest, end: nil, changeScore: 0))
        }

        Logger.chapterDetector.info("Detected \(chapters.count) chapters from \(visits.count) visits")
        return chapters
    }

    private static func makeChapter(
        visits: [Visit],
        start: Date,
        end: Date?,
        changeScore: Double
    ) -> LifeChapter {
        let lats = visits.map(\.clusterLat)
        let lngs = visits.map(\.clusterLng)

        return LifeChapter(
            startsAt: start,
            endsAt: end,
            changeScore: changeScore,
            boundingLatMin: lats.min(),
            boundingLatMax: lats.max(),
            boundingLngMin: lngs.min(),
            boundingLngMax: lngs.max()
        )
    }
}

extension Logger {
    static let chapterDetector = Logger(subsystem: "com.ghostroutes.app", category: "chapterDetector")
}
