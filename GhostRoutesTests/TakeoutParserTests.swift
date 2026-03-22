import Testing
import Foundation
@testable import GhostRoutes

@Suite("TakeoutParser")
struct TakeoutParserTests {

    private func fixtureURL(_ name: String) -> URL {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("Missing fixture file: \(name).json")
        }
        return url
    }

    // MARK: - Schema V1

    @Test("Parses v1 schema (timestampMs) with 100 records")
    func parseV1Schema() throws {
        let result = try TakeoutParser.parse(fileURL: fixtureURL("takeout_v1"))

        #expect(result.records.count == 100)
        #expect(result.skippedCount == 0)

        // All records should be takeout source
        #expect(result.records.allSatisfy { $0.source == .takeout })

        // Coordinates should be in SF range
        for record in result.records {
            #expect(record.latitude > 37.0 && record.latitude < 38.0)
            #expect(record.longitude > -123.0 && record.longitude < -122.0)
        }

        // Timestamps should be in January 2023 (UTC)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        if let first = result.records.first {
            let comps = utcCalendar.dateComponents([.year, .month], from: first.timestamp)
            #expect(comps.year == 2023)
            #expect(comps.month == 1)
        }
    }

    // MARK: - Schema V2

    @Test("Parses v2 schema (ISO 8601 timestamp) with 100 records")
    func parseV2Schema() throws {
        let result = try TakeoutParser.parse(fileURL: fixtureURL("takeout_v2"))

        #expect(result.records.count == 100)
        #expect(result.skippedCount == 0)

        // Timestamps should be in February 2023 (UTC)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        if let first = result.records.first {
            let comps = utcCalendar.dateComponents([.year, .month], from: first.timestamp)
            #expect(comps.year == 2023)
            #expect(comps.month == 2)
        }
    }

    // MARK: - Malformed Records

    @Test("Skips malformed record and parses remaining 99")
    func parseMalformed() throws {
        let result = try TakeoutParser.parse(fileURL: fixtureURL("takeout_malformed"))

        #expect(result.records.count == 99)
        #expect(result.skippedCount == 1)
    }

    // MARK: - Edge Cases

    @Test("Parses empty locations array without crashing")
    func parseEmpty() throws {
        let json = #"{"locations": []}"#
        let data = json.data(using: .utf8)!
        let result = try TakeoutParser.parse(data: data)

        #expect(result.records.count == 0)
        #expect(result.skippedCount == 0)
    }

    // MARK: - Coordinate Conversion

    @Test("Converts E7 coordinates correctly")
    func coordinateConversion() throws {
        let json = #"""
        {
            "locations": [{
                "latitudeE7": 377749000,
                "longitudeE7": -1224194000,
                "accuracy": 20,
                "timestampMs": "1672531200000"
            }]
        }
        """#
        let data = json.data(using: .utf8)!
        let result = try TakeoutParser.parse(data: data)

        #expect(result.records.count == 1)
        let record = result.records[0]
        #expect(abs(record.latitude - 37.7749) < 0.0001)
        #expect(abs(record.longitude - (-122.4194)) < 0.0001)
    }

    // MARK: - Timestamp Conversion

    @Test("Converts timestampMs correctly")
    func timestampMsConversion() throws {
        let json = #"""
        {
            "locations": [{
                "latitudeE7": 377749000,
                "longitudeE7": -1224194000,
                "accuracy": 20,
                "timestampMs": "1710512551000"
            }]
        }
        """#
        let data = json.data(using: .utf8)!
        let result = try TakeoutParser.parse(data: data)

        let record = result.records[0]
        // 1710512551000ms = 2024-03-15T14:22:31Z
        let expected = Date(timeIntervalSince1970: 1710512551.0)
        #expect(abs(record.timestamp.timeIntervalSince(expected)) < 1.0)
    }

    @Test("Converts ISO 8601 timestamp correctly")
    func timestampISOConversion() throws {
        let json = #"""
        {
            "locations": [{
                "latitudeE7": 377749000,
                "longitudeE7": -1224194000,
                "accuracy": 20,
                "timestamp": "2024-03-15T14:22:31.000Z"
            }]
        }
        """#
        let data = json.data(using: .utf8)!
        let result = try TakeoutParser.parse(data: data)

        let record = result.records[0]
        let expected = Date(timeIntervalSince1970: 1710512551.0)
        #expect(abs(record.timestamp.timeIntervalSince(expected)) < 1.0)
    }

    @Test("Handles ISO 8601 without fractional seconds")
    func timestampISONoFraction() throws {
        let json = #"""
        {
            "locations": [{
                "latitudeE7": 377749000,
                "longitudeE7": -1224194000,
                "accuracy": 20,
                "timestamp": "2024-03-15T14:22:31Z"
            }]
        }
        """#
        let data = json.data(using: .utf8)!
        let result = try TakeoutParser.parse(data: data)

        #expect(result.records.count == 1)
        let expected = Date(timeIntervalSince1970: 1710512551.0)
        #expect(abs(result.records[0].timestamp.timeIntervalSince(expected)) < 1.0)
    }
}

// Helper to locate test bundle
private final class BundleToken {}
