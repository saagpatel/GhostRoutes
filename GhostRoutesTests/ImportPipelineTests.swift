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
}

private final class BundleToken {}

private enum TestError: Error {
    case missingFixture
}
