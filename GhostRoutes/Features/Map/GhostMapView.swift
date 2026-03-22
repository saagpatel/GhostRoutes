import MapKit
import SwiftUI

struct GhostMapView: View {
    @State private var viewModel = MapViewModel()
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        ZStack {
            Map(position: $viewModel.cameraPosition) {
                // Ghost location circles
                ForEach(viewModel.visibleGhosts) { ghost in
                    MapCircle(
                        center: CLLocationCoordinate2D(
                            latitude: ghost.clusterLat,
                            longitude: ghost.clusterLng
                        ),
                        radius: 30
                    )
                    .foregroundStyle(.white.opacity(ghostOpacity(ghost.ghostlinessScore) * 0.3))
                    .stroke(
                        .white.opacity(ghostOpacity(ghost.ghostlinessScore)),
                        style: StrokeStyle(lineWidth: 2, dash: [5, 5])
                    )

                    Annotation(
                        ghost.cachedDisplayName ?? "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: ghost.clusterLat,
                            longitude: ghost.clusterLng
                        )
                    ) {
                        GhostAnnotationView(ghost: ghost)
                    }
                }

                // Route polylines
                ForEach(viewModel.visibleRoutes) { segment in
                    MapPolyline(coordinates: segment.coordinates)
                        .stroke(
                            segment.isGhost
                                ? Color.white.opacity(
                                    ghostOpacity(segment.ghostlinessScore ?? 1.0)
                                )
                                : Color(red: 0, green: 0.898, blue: 1.0),
                            style: StrokeStyle(
                                lineWidth: segment.isGhost ? 2 : 3,
                                lineCap: .round,
                                dash: segment.isGhost ? [6, 4] : []
                            )
                        )
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted))
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.updateVisibleOverlays(region: context.region)
            }

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
        .task {
            guard let db = appDatabase else { return }
            let locationStore = LocationStore(database: db)
            let ghostStore = GhostStore(database: db)
            await viewModel.loadData(
                locationStore: locationStore,
                ghostStore: ghostStore
            )
        }
    }

    private func ghostOpacity(_ score: Double) -> Double {
        min(0.15 + score * 0.05, 0.65)
    }
}
