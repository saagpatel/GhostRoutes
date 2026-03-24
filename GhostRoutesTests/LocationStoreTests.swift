import Testing
import Foundation
import GRDB
@testable import GhostRoutes

@Suite("LocationStore")
struct LocationStoreTests {

    private func makeTestDatabase() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    // MARK: - LocationRecord CRUD

    @Test("Insert and fetch a single record with all fields")
    func insertAndFetchRecord() async throws {
        let db = try makeTestDatabase()
        let store = LocationStore(database: db)

        let timestamp = Date(timeIntervalSince1970: 1672531200) // 2023-01-01
        let record = LocationRecord(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: timestamp,
            accuracyMeters: 20.0,
            source: .takeout
        )

        let inserted = try await store.insert(record)
        #expect(inserted.id != nil)

        let fetched = try await store.fetchAllRecords()
        #expect(fetched.count == 1)

        let first = fetched[0]
        #expect(abs(first.latitude - 37.7749) < 0.0001)
        #expect(abs(first.longitude - (-122.4194)) < 0.0001)
        #expect(first.source == .takeout)
    }

    // MARK: - Batch Insert

    @Test("Batch insert 100 records and verify count")
    func batchInsert() async throws {
        let db = try makeTestDatabase()
        let store = LocationStore(database: db)

        let records = (0..<100).map { i in
            LocationRecord(
                latitude: 37.77 + Double(i) * 0.001,
                longitude: -122.42,
                timestamp: Date(timeIntervalSince1970: 1672531200 + Double(i) * 3600),
                source: .takeout
            )
        }

        try await store.insertBatch(records)
        let count = try await store.recordCount()
        #expect(count == 100)
    }

    // MARK: - Date Range Filtering

    @Test("Fetch records within a date range")
    func dateRangeFiltering() async throws {
        let db = try makeTestDatabase()
        let store = LocationStore(database: db)

        let jan = Date(timeIntervalSince1970: 1672531200)        // 2023-01-01
        let feb = Date(timeIntervalSince1970: 1675209600)        // 2023-02-01
        let mar = Date(timeIntervalSince1970: 1677628800)        // 2023-03-01

        let records = [
            LocationRecord(latitude: 37.77, longitude: -122.42, timestamp: jan, source: .takeout),
            LocationRecord(latitude: 37.78, longitude: -122.42, timestamp: feb, source: .takeout),
            LocationRecord(latitude: 37.79, longitude: -122.42, timestamp: mar, source: .takeout),
        ]
        try await store.insertBatch(records)

        let febOnly = try await store.fetchRecords(from: feb, to: feb)
        #expect(febOnly.count == 1)
        #expect(abs(febOnly[0].latitude - 37.78) < 0.001)
    }

    // MARK: - Visit CRUD

    @Test("Insert and fetch a visit")
    func insertAndFetchVisit() async throws {
        let db = try makeTestDatabase()
        let store = LocationStore(database: db)

        let arrived = Date(timeIntervalSince1970: 1672531200)
        let departed = Date(timeIntervalSince1970: 1672534800)

        let visit = Visit(
            clusterLat: 37.7749,
            clusterLng: -122.4194,
            arrivedAt: arrived,
            departedAt: departed,
            durationSeconds: 3600,
            source: .clvisit
        )

        let inserted = try await store.insertVisit(visit)
        #expect(inserted.id != nil)

        let fetched = try await store.fetchAllVisits()
        #expect(fetched.count == 1)
        #expect(fetched[0].source == .clvisit)
        #expect(fetched[0].durationSeconds == 3600)
    }

    // MARK: - Timestamp Precision

    @Test("Date round-trips with second precision")
    func timestampRoundTrip() async throws {
        let db = try makeTestDatabase()
        let store = LocationStore(database: db)

        let precise = Date(timeIntervalSince1970: 1710512551.0) // 2024-03-15T14:22:31Z
        let record = LocationRecord(
            latitude: 37.77,
            longitude: -122.42,
            timestamp: precise,
            source: .takeout
        )

        _ = try await store.insert(record)
        let fetched = try await store.fetchAllRecords()

        #expect(fetched.count == 1)
        // Unix epoch seconds — should round-trip within 1 second
        #expect(abs(fetched[0].timestamp.timeIntervalSince(precise)) < 1.0)
    }
}
