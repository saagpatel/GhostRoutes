import Foundation
import GRDB
import os.log

final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try migrator.migrate(writer)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // 1. place_cache — referenced by visits and ghost_locations
        migrator.registerMigration("createPlaceCache") { db in
            try db.create(table: "place_cache") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("display_name", .text).notNull()
                t.column("locality", .text)
                t.column("geocoded_at", .integer).notNull()
                t.column("cache_key", .text).notNull().unique()
            }
        }

        // 2. location_records — raw ingested points
        migrator.registerMigration("createLocationRecords") { db in
            try db.create(table: "location_records") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("timestamp", .integer).notNull()
                t.column("accuracy_meters", .double)
                t.column("source", .text).notNull()
                    .check { $0 == "takeout" || $0 == "clvisit" }
                t.column("raw_json", .text)
                t.column("created_at", .integer)
                    .defaults(sql: "(strftime('%s', 'now'))")
            }
            try db.create(
                index: "idx_location_timestamp",
                on: "location_records",
                columns: ["timestamp"]
            )
            try db.create(
                index: "idx_location_coords",
                on: "location_records",
                columns: ["latitude", "longitude"]
            )
        }

        // 3. visits — clustered place visits
        migrator.registerMigration("createVisits") { db in
            try db.create(table: "visits") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cluster_lat", .double).notNull()
                t.column("cluster_lng", .double).notNull()
                t.column("arrived_at", .integer).notNull()
                t.column("departed_at", .integer).notNull()
                t.column("duration_seconds", .integer).notNull()
                t.column("source", .text).notNull()
                    .check { $0 == "takeout" || $0 == "clvisit" }
                t.column("place_cache_id", .integer)
                    .references("place_cache", onDelete: .setNull)
            }
            try db.create(
                index: "idx_visits_cluster",
                on: "visits",
                columns: ["cluster_lat", "cluster_lng"]
            )
            try db.create(
                index: "idx_visits_arrived",
                on: "visits",
                columns: ["arrived_at"]
            )
        }

        // 4. ghost_locations — detected ghosts
        migrator.registerMigration("createGhostLocations") { db in
            try db.create(table: "ghost_locations") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cluster_lat", .double).notNull()
                t.column("cluster_lng", .double).notNull()
                t.column("place_cache_id", .integer)
                    .references("place_cache", onDelete: .setNull)
                t.column("peak_visits_per_month", .double).notNull()
                t.column("current_visits_per_month", .double).notNull()
                t.column("ghostliness_score", .double).notNull()
                t.column("peak_period_start", .integer).notNull()
                t.column("peak_period_end", .integer).notNull()
                t.column("last_visit_at", .integer).notNull()
                t.column("alert_sent_at", .integer)
                t.column("is_dismissed", .integer).notNull().defaults(to: 0)
                t.column("cached_display_name", .text)
                t.column("detected_at", .integer)
                    .defaults(sql: "(strftime('%s', 'now'))")
            }
            try db.create(
                index: "idx_ghost_score",
                on: "ghost_locations",
                columns: ["ghostliness_score"]
            )
        }

        // 5. life_chapters — detected chapter boundaries
        migrator.registerMigration("createLifeChapters") { db in
            try db.create(table: "life_chapters") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("starts_at", .integer).notNull()
                t.column("ends_at", .integer)
                t.column("label", .text)
                t.column("change_score", .double).notNull()
                t.column("bounding_lat_min", .double)
                t.column("bounding_lat_max", .double)
                t.column("bounding_lng_min", .double)
                t.column("bounding_lng_max", .double)
            }
        }

        return migrator
    }

    static func makeShared() throws -> AppDatabase {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("GhostRoutes", isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        // Exclude from iCloud backup — location data must never leave device
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = directoryURL
        try mutableURL.setResourceValues(resourceValues)

        // Encrypt at rest when device is locked (real device only)
        #if !targetEnvironment(simulator)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: directoryURL.path
        )
        #endif

        let databasePath = directoryURL.appendingPathComponent("db.sqlite").path
        let pool = try DatabasePool(path: databasePath)

        Logger.database.debug("Database opened successfully")

        return try AppDatabase(pool)
    }

    /// Delete all data and recreate tables (for "Delete All Data" in settings).
    func resetAllData() async throws {
        try await writer.write { db in
            try db.drop(table: "life_chapters")
            try db.drop(table: "ghost_locations")
            try db.drop(table: "visits")
            try db.drop(table: "location_records")
            try db.drop(table: "place_cache")
        }
        try self.migrator.migrate(writer)
        Logger.database.info("All data deleted and tables recreated")
    }
}

// MARK: - SwiftUI Environment

import SwiftUI

private struct AppDatabaseKey: EnvironmentKey {
    static let defaultValue: AppDatabase? = nil
}

extension EnvironmentValues {
    var appDatabase: AppDatabase? {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}

// MARK: - Logger

extension Logger {
    static let database = Logger(subsystem: "com.ghostroutes.app", category: "database")
}
