import Foundation
import os.log

@MainActor
@Observable
final class ImportPipeline {

    enum State: Sendable, Equatable {
        case idle
        case parsing
        case insertingRecords(progress: Double)
        case clusteringVisits
        case detectingGhosts
        case geocoding(completed: Int, total: Int)
        case complete(recordCount: Int, visitCount: Int, ghostCount: Int, skipped: Int)
        case failed(String)
    }

    private(set) var state: State = .idle

    func importFile(url: URL, database: AppDatabase) async {
        let locationStore = LocationStore(database: database)
        let ghostStore = GhostStore(database: database)

        do {
            // 1. Parse
            state = .parsing
            let parseResult = try await Task.detached {
                try TakeoutParser.parse(fileURL: url)
            }.value

            Logger.import.info("Parsed \(parseResult.records.count) records")

            // 2. Insert records in chunks with progress
            state = .insertingRecords(progress: 0)
            try await locationStore.insertBatchChunked(
                parseResult.records,
                chunkSize: 500
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.state = .insertingRecords(progress: progress)
                }
            }

            // 3. Cluster into visits
            state = .clusteringVisits
            let visits = await Task.detached {
                VisitClusterer.cluster(parseResult.records)
            }.value

            try await locationStore.insertVisitBatch(visits)

            // 4. Detect ghosts
            state = .detectingGhosts
            let allVisits = try await locationStore.fetchAllVisits()
            let ghosts = await Task.detached {
                GhostDetector.detect(visits: allVisits)
            }.value

            try await ghostStore.replaceAll(ghosts)

            // 5. Geocode ghost locations (non-blocking — fires and continues)
            if !ghosts.isEmpty {
                state = .geocoding(completed: 0, total: ghosts.count)
                let geocoder = GeocodeManager(ghostStore: ghostStore)
                let total = ghosts.count
                for (index, ghost) in ghosts.enumerated() {
                    do {
                        let name = try await geocoder.reverseGeocode(
                            latitude: ghost.clusterLat,
                            longitude: ghost.clusterLng
                        )
                        if let ghostId = ghost.id {
                            try await ghostStore.updateDisplayName(ghostId: ghostId, name: name)
                        }
                    } catch {
                        Logger.import.warning("Geocoding failed for ghost at \(ghost.clusterLat), \(ghost.clusterLng): \(error)")
                    }
                    state = .geocoding(completed: index + 1, total: total)
                }
            }

            // 6. Complete
            state = .complete(
                recordCount: parseResult.records.count,
                visitCount: visits.count,
                ghostCount: ghosts.count,
                skipped: parseResult.skippedCount
            )

            Logger.import.info(
                "Import complete: \(parseResult.records.count) records, \(visits.count) visits, \(ghosts.count) ghosts"
            )

        } catch {
            state = .failed(error.localizedDescription)
            Logger.import.error("Import failed: \(error)")
        }
    }
}

extension Logger {
    static let `import` = Logger(subsystem: "com.ghostroutes.app", category: "import")
}
