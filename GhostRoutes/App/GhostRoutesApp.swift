import SwiftUI

@main
struct GhostRoutesApp: App {
    let appDatabase: AppDatabase

    init() {
        do {
            appDatabase = try AppDatabase.makeShared()
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDatabase, appDatabase)
        }
    }
}
