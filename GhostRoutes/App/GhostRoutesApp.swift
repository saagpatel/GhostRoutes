import SwiftUI

@main
struct GhostRoutesApp: App {
    let appDatabase: AppDatabase?
    let visitManager: VisitManager?
    let startupError: String?

    init() {
        do {
            let db = try AppDatabase.makeShared()
            appDatabase = db
            visitManager = VisitManager(database: db)
            startupError = nil
        } catch {
            appDatabase = nil
            visitManager = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let appDatabase {
                    ContentView()
                        .environment(\.appDatabase, appDatabase)
                        .task { @MainActor in
                            visitManager?.startMonitoring()
                        }
                } else {
                    ContentUnavailableView(
                        "Ghost Routes Couldn’t Start",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(startupError ?? "The local database could not be opened. Relaunch the app to try again.")
                    )
                }
            }
        }
    }
}
