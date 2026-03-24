import MapKit
import SwiftUI

struct ComparisonView: View {
    @State private var viewModel = ComparisonViewModel()
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date range pickers
                periodPickers
                    .padding()
                    .background(.ultraThinMaterial)

                // Map with two-color routes
                ZStack {
                    Map(position: $viewModel.cameraPosition) {
                        // Period A routes — cyan
                        ForEach(viewModel.periodARoutes) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(
                                    Color(red: 0, green: 0.898, blue: 1.0),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                        }

                        // Period B routes — amber
                        ForEach(viewModel.periodBRoutes) { segment in
                            MapPolyline(coordinates: segment.coordinates)
                                .stroke(
                                    Color(red: 1.0, green: 0.584, blue: 0),  // #FF9500
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted))

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .padding()
                            .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                    }
                }
            }
            .navigationTitle("Compare")
            .task { await loadData() }
            .onChange(of: viewModel.periodAStart) { _, _ in Task { await loadData() } }
            .onChange(of: viewModel.periodAEnd) { _, _ in Task { await loadData() } }
            .onChange(of: viewModel.periodBStart) { _, _ in Task { await loadData() } }
            .onChange(of: viewModel.periodBEnd) { _, _ in Task { await loadData() } }
        }
    }

    private var periodPickers: some View {
        VStack(spacing: 12) {
            HStack {
                Circle().fill(Color(red: 0, green: 0.898, blue: 1.0)).frame(width: 10, height: 10)
                Text("Period A")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                DatePicker("", selection: $viewModel.periodAStart, displayedComponents: .date)
                    .labelsHidden()
                Text("—")
                DatePicker("", selection: $viewModel.periodAEnd, displayedComponents: .date)
                    .labelsHidden()
            }

            HStack {
                Circle().fill(Color(red: 1.0, green: 0.584, blue: 0)).frame(width: 10, height: 10)
                Text("Period B")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                DatePicker("", selection: $viewModel.periodBStart, displayedComponents: .date)
                    .labelsHidden()
                Text("—")
                DatePicker("", selection: $viewModel.periodBEnd, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    private func loadData() async {
        guard let db = appDatabase else { return }
        let locationStore = LocationStore(database: db)
        let ghostStore = GhostStore(database: db)
        await viewModel.loadComparison(
            locationStore: locationStore,
            ghostStore: ghostStore
        )
    }
}
