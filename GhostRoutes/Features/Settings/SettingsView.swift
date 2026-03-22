import SwiftUI

struct SettingsView: View {
    @Environment(\.appDatabase) private var appDatabase
    @State private var showDocumentPicker = false
    @State private var showDeleteConfirmation = false
    @State private var importPipeline = ImportPipeline()
    @State private var showImportProgress = false
    @State private var recordCount = 0
    @State private var visitCount = 0
    @State private var ghostCount = 0

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Import
                Section("Import") {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Import Google Takeout JSON", systemImage: "square.and.arrow.down")
                    }
                }

                // MARK: - Data
                Section("Data") {
                    LabeledContent("Location records", value: "\(recordCount)")
                    LabeledContent("Visits", value: "\(visitCount)")
                    LabeledContent("Ghost locations", value: "\(ghostCount)")
                }

                // MARK: - Danger Zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                } footer: {
                    Text("This permanently removes all imported location data, visits, and detected ghost locations from this device.")
                }

                // MARK: - About
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    Text("Ghost Routes keeps all data on-device. No data is ever sent to any server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .task { await refreshCounts() }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    showImportProgress = true
                    guard let db = appDatabase else { return }
                    Task {
                        guard url.startAccessingSecurityScopedResource() else { return }
                        defer { url.stopAccessingSecurityScopedResource() }
                        await importPipeline.importFile(url: url, database: db)
                        await refreshCounts()
                    }
                }
            }
            .sheet(isPresented: $showImportProgress) {
                NavigationStack {
                    ImportProgressView(pipeline: importPipeline) {
                        showImportProgress = false
                    }
                    .navigationTitle("Import")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all location records, visits, and ghost locations. This cannot be undone.")
            }
        }
    }

    private func refreshCounts() async {
        guard let db = appDatabase else { return }
        let locationStore = LocationStore(database: db)
        let ghostStore = GhostStore(database: db)

        do {
            recordCount = try await locationStore.recordCount()
            visitCount = try await locationStore.visitCount()
            ghostCount = try await ghostStore.fetchAll().count
        } catch {
            // Counts stay at 0
        }
    }

    private func deleteAllData() async {
        guard let db = appDatabase else { return }
        do {
            try await db.resetAllData()
            await refreshCounts()
        } catch {
            // Log handled by AppDatabase
        }
    }
}
