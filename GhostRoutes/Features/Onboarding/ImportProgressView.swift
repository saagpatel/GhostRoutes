import SwiftUI

struct ImportProgressView: View {
    let pipeline: ImportPipeline
    var onComplete: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            switch pipeline.state {
            case .idle:
                EmptyView()

            case .parsing:
                progressRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Reading Takeout data...",
                    indeterminate: true
                )

            case .insertingRecords(let progress):
                progressRow(
                    icon: "square.and.arrow.down",
                    title: "Importing locations...",
                    progress: progress
                )

            case .clusteringVisits:
                progressRow(
                    icon: "mappin.and.ellipse",
                    title: "Clustering visits...",
                    indeterminate: true
                )

            case .detectingGhosts:
                progressRow(
                    icon: "eye.trianglebadge.exclamationmark",
                    title: "Detecting ghost locations...",
                    indeterminate: true
                )

            case .geocoding(let completed, let total):
                progressRow(
                    icon: "map",
                    title: "Naming places... \(completed)/\(total)",
                    progress: Double(completed) / Double(max(total, 1))
                )

            case .complete(let records, let visits, let ghosts, let skipped):
                completeSummary(
                    records: records,
                    visits: visits,
                    ghosts: ghosts,
                    skipped: skipped
                )

            case .failed(let message):
                errorView(message: message)
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private func progressRow(icon: String, title: String, indeterminate: Bool = false, progress: Double? = nil) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            if indeterminate {
                ProgressView()
                    .controlSize(.large)
            } else if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func completeSummary(records: Int, visits: Int, ghosts: Int, skipped: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Import Complete")
                .font(.title2)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                summaryRow("Locations imported", value: "\(records)")
                summaryRow("Visits detected", value: "\(visits)")
                summaryRow("Ghost locations", value: "\(ghosts)")
                if skipped > 0 {
                    summaryRow("Records skipped", value: "\(skipped)")
                }
            }

            if let onComplete {
                Button("View Ghost Map") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Import Failed")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
