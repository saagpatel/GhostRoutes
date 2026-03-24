import SwiftUI

struct GhostInboxView: View {
    @Environment(\.appDatabase) private var appDatabase
    @State private var ghosts: [GhostLocation] = []

    var body: some View {
        NavigationStack {
            Group {
                if ghosts.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(ghosts) { ghost in
                            GhostInboxRow(ghost: ghost) {
                                await dismissGhost(ghost)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ghost Inbox")
            .task { await loadGhosts() }
            .refreshable { await loadGhosts() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Ghost Alerts",
            systemImage: "bell.slash",
            description: Text(
                "Ghost alerts appear here when you stop visiting places you used to frequent."
            )
        )
    }

    private func loadGhosts() async {
        guard let db = appDatabase else { return }
        let store = GhostStore(database: db)
        do {
            ghosts = try await store.fetchUndismissed()
        } catch {
            ghosts = []
        }
    }

    private func dismissGhost(_ ghost: GhostLocation) async {
        guard let db = appDatabase, let ghostId = ghost.id else { return }
        let store = GhostStore(database: db)
        do {
            try await store.dismiss(ghostId)
            ghosts.removeAll { $0.id == ghostId }
        } catch {
            // Dismiss failed silently
        }
    }
}

// MARK: - Row

struct GhostInboxRow: View {
    let ghost: GhostLocation
    let onDismiss: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(ghostOpacity))

            VStack(alignment: .leading, spacing: 4) {
                Text(ghost.cachedDisplayName ?? "Unknown Place")
                    .font(.headline)

                Text("Last visited \(weeksAgo) weeks ago")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score badge
            Text(String(format: "%.1f", ghost.ghostlinessScore))
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: .capsule)

            Button {
                Task { await onDismiss() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var weeksAgo: Int {
        Int(Date().timeIntervalSince(ghost.lastVisitAt) / (7 * 86400))
    }

    private var ghostOpacity: Double {
        min(0.15 + ghost.ghostlinessScore * 0.05, 0.65)
    }
}
