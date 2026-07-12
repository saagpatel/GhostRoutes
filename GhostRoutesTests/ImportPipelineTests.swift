import Testing
import Foundation
import GRDB
@testable import GhostRoutes

@Suite("ImportPipeline")
struct ImportPipelineTests {

    private func makeTestDatabase() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    @Test("Import with valid fixture reaches complete state")
    @MainActor
    func importCompletes() async throws {
        let db = try makeTestDatabase()
        let pipeline = ImportPipeline()

        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "takeout_v2", withExtension: "json") else {
            throw TestError.missingFixture
        }

        await pipeline.importFile(url: url, database: db)

        if case .complete(let recordCount, let visitCount, _, let skipped) = pipeline.state {
            #expect(recordCount == 100)
            #expect(skipped == 0)
            #expect(visitCount >= 0)  // depends on clustering
        } else {
            #expect(Bool(false), "Expected .complete state, got \(pipeline.state)")
        }
    }

    @Test("Import with invalid URL reaches failed state")
    @MainActor
    func importFailsOnBadURL() async throws {
        let db = try makeTestDatabase()
        let pipeline = ImportPipeline()

        let badURL = URL(fileURLWithPath: "/nonexistent/file.json")
        await pipeline.importFile(url: badURL, database: db)

        if case .failed = pipeline.state {
            // Expected
        } else {
            #expect(Bool(false), "Expected .failed state, got \(pipeline.state)")
        }
    }

    @Test("Reimport replaces Takeout data without deleting CLVisit records")
    @MainActor
    func reimportIsIdempotent() async throws {
        let db = try makeTestDatabase()
        let pipeline = ImportPipeline()
        let store = LocationStore(database: db)
        let liveRecord = LocationRecord(
            latitude: 37.0,
            longitude: -122.0,
            timestamp: .now,
            accuracyMeters: 10,
            source: .clvisit
        )
        _ = try await store.insert(liveRecord)

        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: "takeout_v2", withExtension: "json") else {
            throw TestError.missingFixture
        }

        await pipeline.importFile(url: url, database: db)
        await pipeline.importFile(url: url, database: db)

        let records = try await store.fetchAllRecords()
        #expect(records.filter { $0.source == .takeout }.count == 100)
        #expect(records.filter { $0.source == .clvisit }.count == 1)
    }
}

private final class BundleToken {}

private enum TestError: Error {
    case missingFixture
}
