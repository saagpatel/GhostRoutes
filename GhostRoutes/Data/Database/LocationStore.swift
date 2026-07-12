import Foundation
import GRDB
import os.log

actor LocationStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - LocationRecord

    func insert(_ record: LocationRecord) async throws -> LocationRecord {
        try await database.writer.write { db in
            var record = record
            try record.insert(db)
            return record
        }
    }

    func insertBatch(_ records: [LocationRecord]) async throws {
        try await database.writer.write { db in
            for var record in records {
                try record.insert(db)
            }
        }
        Logger.database.info("Batch inserted \(records.count) location records")
    }

    func fetchRecords(from start: Date, to end: Date) async throws -> [LocationRecord] {
        try await database.writer.read { db in
            try LocationRecord
                .filter(LocationRecord.Columns.timestamp >= start
                    && LocationRecord.Columns.timestamp <= end)
                .order(LocationRecord.Columns.timestamp)
                .fetchAll(db)
        }
    }

    func fetchAllRecords() async throws -> [LocationRecord] {
        try await database.writer.read { db in
            try LocationRecord
                .order(LocationRecord.Columns.timestamp)
                .fetchAll(db)
        }
    }

    func recordCount() async throws -> Int {
        try await database.writer.read { db in
            try LocationRecord.fetchCount(db)
        }
    }

    // MARK: - Visit

    func insertVisit(_ visit: Visit) async throws -> Visit {
        try await database.writer.write { db in
            var visit = visit
            try visit.insert(db)
            return visit
        }
    }

    func insertVisitBatch(_ visits: [Visit]) async throws {
        try await database.writer.write { db in
            for var visit in visits {
                try visit.insert(db)
            }
        }
        Logger.database.info("Batch inserted \(visits.count) visits")
    }

    func fetchVisits(from start: Date, to end: Date) async throws -> [Visit] {
        try await database.writer.read { db in
            try Visit
                .filter(Visit.Columns.arrivedAt >= start && Visit.Columns.arrivedAt <= end)
                .order(Visit.Columns.arrivedAt)
                .fetchAll(db)
        }
    }

    func fetchAllVisits() async throws -> [Visit] {
        try await database.writer.read { db in
            try Visit
                .order(Visit.Columns.arrivedAt)
                .fetchAll(db)
        }
    }

    func visitCount() async throws -> Int {
        try await database.writer.read { db in
            try Visit.fetchCount(db)
        }
    }

    // MARK: - Chunked Insert (for progress reporting)

    func insertBatchChunked(
        _ records: [LocationRecord],
        chunkSize: Int = 500,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        let total = records.count
        var inserted = 0

        for chunkStart in stride(from: 0, to: total, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, total)
            let chunk = Array(records[chunkStart..<chunkEnd])

            try await database.writer.write { db in
                for var record in chunk {
                    try record.insert(db)
                }
            }

            inserted += chunk.count
            onProgress(Double(inserted) / Double(total))
        }

        Logger.database.info("Chunked insert: \(total) records in \(total / chunkSize + 1) chunks")
    }

    /// Replaces the previous Google Takeout snapshot while preserving passive
    /// CLVisit data. A full Takeout export is a snapshot, not an append-only feed.
    func replaceTakeoutRecords(
        with records: [LocationRecord],
        chunkSize: Int = 500,
        onProgress: @Sendable (Double) -> Void
    ) async throws {
        try await database.writer.write { db in
            _ = try LocationRecord
                .filter(LocationRecord.Columns.source == LocationRecord.DataSource.takeout)
                .deleteAll(db)

            for (index, var record) in records.enumerated() {
                try record.insert(db)
                if (index + 1).isMultiple(of: chunkSize) || index + 1 == records.count {
                    onProgress(Double(index + 1) / Double(max(records.count, 1)))
                }
            }
        }
    }

    func replaceTakeoutVisits(with visits: [Visit]) async throws {
        try await database.writer.write { db in
            _ = try Visit
                .filter(Visit.Columns.source == LocationRecord.DataSource.takeout)
                .deleteAll(db)
            for var visit in visits {
                try visit.insert(db)
            }
        }
    }

    // MARK: - Deletion

    func deleteAllRecords() async throws {
        _ = try await database.writer.write { db -> Int in
            try LocationRecord.deleteAll(db)
        }
    }

    func deleteAllVisits() async throws {
        _ = try await database.writer.write { db -> Int in
            try Visit.deleteAll(db)
        }
    }
}
