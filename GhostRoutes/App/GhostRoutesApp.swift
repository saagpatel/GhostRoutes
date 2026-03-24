import SwiftUI

@main
struct GhostRoutesApp: App {
    let appDatabase: AppDatabase
    let visitManager: VisitManager

    init() {
        do {
            let db = try AppDatabase.makeShared()
            appDatabase = db
            visitManager = VisitManager(database: db)
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDatabase, appDatabase)
                .task { @MainActor in
                    visitManager.startMonitoring()
                }
        }
    }
}
