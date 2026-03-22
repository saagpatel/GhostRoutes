import Foundation
import GRDB
import os.log

actor GhostStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - GhostLocation

    func replaceAll(_ ghosts: [GhostLocation]) async throws {
        try await database.writer.write { db in
            try GhostLocation.deleteAll(db)
            for var ghost in ghosts {
                try ghost.insert(db)
            }
        }
        Logger.database.info("Replaced ghost locations with \(ghosts.count) entries")
    }

    func fetchAll() async throws -> [GhostLocation] {
        try await database.writer.read { db in
            try GhostLocation
                .order(GhostLocation.Columns.ghostlinessScore.desc)
                .fetchAll(db)
        }
    }

    func fetchUndismissed() async throws -> [GhostLocation] {
        try await database.writer.read { db in
            try GhostLocation
                .filter(GhostLocation.Columns.isDismissed == false)
                .order(GhostLocation.Columns.ghostlinessScore.desc)
                .fetchAll(db)
        }
    }

    func dismiss(_ ghostId: Int64) async throws {
        try await database.writer.write { db in
            if var ghost = try GhostLocation.fetchOne(db, id: ghostId) {
                ghost.isDismissed = true
                try ghost.update(db)
            }
        }
    }

    // MARK: - LifeChapter

    func insertChapter(_ chapter: LifeChapter) async throws -> LifeChapter {
        try await database.writer.write { db in
            var chapter = chapter
            try chapter.insert(db)
            return chapter
        }
    }

    func replaceAllChapters(_ chapters: [LifeChapter]) async throws {
        try await database.writer.write { db in
            try LifeChapter.deleteAll(db)
            for var chapter in chapters {
                try chapter.insert(db)
            }
        }
    }

    func fetchAllChapters() async throws -> [LifeChapter] {
        try await database.writer.read { db in
            try LifeChapter
                .order(Column("starts_at"))
                .fetchAll(db)
        }
    }

    // MARK: - PlaceCache

    func upsertPlace(_ place: PlaceCache) async throws -> PlaceCache {
        try await database.writer.write { db in
            var place = place
            try place.save(db)
            return place
        }
    }

    func fetchPlace(byCacheKey key: String) async throws -> PlaceCache? {
        try await database.writer.read { db in
            try PlaceCache.filter(Column("cache_key") == key).fetchOne(db)
        }
    }
}
