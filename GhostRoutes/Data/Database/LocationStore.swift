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
}
