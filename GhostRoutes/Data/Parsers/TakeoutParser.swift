import Foundation
import os.log

struct TakeoutParser: Sendable {
    struct ParseResult: Sendable {
        let records: [LocationRecord]
        let skippedCount: Int
    }

    static func parse(fileURL: URL) throws -> ParseResult {
        let data = try Data(contentsOf: fileURL)
        return try parse(data: data)
    }

    static func parse(data: Data) throws -> ParseResult {
        let file = try JSONDecoder().decode(TakeoutFile.self, from: data)

        var records: [LocationRecord] = []
        records.reserveCapacity(file.locations.count)
        var skipped = 0

        for location in file.locations {
            guard let record = location.toLocationRecord() else {
                skipped += 1
                Logger.parser.warning("Skipped malformed record: missing required fields")
                continue
            }
            records.append(record)
        }

        Logger.parser.info(
            "Parsed \(records.count) records, skipped \(skipped) from \(file.locations.count) total"
        )

        return ParseResult(records: records, skippedCount: skipped)
    }
}

// MARK: - Internal types

private struct TakeoutFile: Decodable, Sendable {
    let locations: [TakeoutLocation]
}

private struct TakeoutLocation: Decodable, Sendable {
    let latitudeE7: Int?
    let longitudeE7: Int?
    let timestamp: String?
    let timestampMs: String?
    let accuracy: Int?

    private nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var resolvedDate: Date? {
        if let ts = timestamp {
            return Self.isoFormatter.date(from: ts)
                ?? Self.isoFormatterNoFraction.date(from: ts)
        } else if let ms = timestampMs, let epoch = Double(ms) {
            return Date(timeIntervalSince1970: epoch / 1000.0)
        }
        return nil
    }

    func toLocationRecord() -> LocationRecord? {
        guard let latE7 = latitudeE7,
              let lngE7 = longitudeE7,
              let date = resolvedDate
        else {
            return nil
        }

        return LocationRecord(
            latitude: Double(latE7) / 1e7,
            longitude: Double(lngE7) / 1e7,
            timestamp: date,
            accuracyMeters: accuracy.map { Double($0) },
            source: .takeout
        )
    }
}

// MARK: - Logger

extension Logger {
    static let parser = Logger(subsystem: "com.ghostroutes.app", category: "parser")
}
