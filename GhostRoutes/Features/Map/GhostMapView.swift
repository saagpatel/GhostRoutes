import MapKit
import SwiftUI

struct GhostMapView: View {
    @State private var viewModel = MapViewModel()
    @State private var animationState = AnimationState()
    @State private var isAnimating = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TimelineView(.animation(paused: !animationState.isPlaying)) { _ in
                    let cutoff = animationCutoff

                    Map(position: $viewModel.cameraPosition) {
                        // Ghost location circles
                        ForEach(ghostsToShow(cutoff: cutoff)) { ghost in
                            MapCircle(
                                center: CLLocationCoordinate2D(
                                    latitude: ghost.clusterLat,
                                    longitude: ghost.clusterLng
                                ),
                                radius: 30
                            )
                            .foregroundStyle(
                                .white.opacity(ghostOpacity(ghost.ghostlinessScore) * 0.3)
                            )
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
                        ForEach(routesToShow(cutoff: cutoff)) { segment in
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
                }

                // Chapters scrubber at top
                VStack {
                    ChaptersView(chapters: viewModel.chapters) { chapter in
                        navigateToChapter(chapter)
                    }
                    Spacer()
                }

                // Animation controls at bottom
                VStack {
                    Spacer()
                    if !viewModel.routeSegments.isEmpty {
                        AnimationControlsView(state: animationState)
                    }
                }

                // Loading overlay
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { exportMap() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
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
    }

    // MARK: - Animation Helpers

    private var animationCutoff: Date {
        guard let earliest = viewModel.routeSegments.map(\.startDate).min(),
              let latest = viewModel.routeSegments.map(\.startDate).max()
        else { return .distantFuture }

        return animationState.cutoffDate(earliest: earliest, latest: latest)
    }

    private func ghostsToShow(cutoff: Date) -> [GhostLocation] {
        if animationState.progress < 1.0 && animationState.isPlaying {
            return viewModel.visibleGhostsForAnimation(cutoff: cutoff)
        }
        return viewModel.visibleGhosts
    }

    private func routesToShow(cutoff: Date) -> [MapViewModel.RouteSegment] {
        if animationState.progress < 1.0 && animationState.isPlaying {
            return viewModel.visibleSegmentsForAnimation(cutoff: cutoff)
        }
        return viewModel.visibleRoutes
    }

    // MARK: - Chapters

    private func navigateToChapter(_ chapter: LifeChapter) {
        guard let latMin = chapter.boundingLatMin,
              let latMax = chapter.boundingLatMax,
              let lngMin = chapter.boundingLngMin,
              let lngMax = chapter.boundingLngMax
        else { return }

        withAnimation(.easeInOut(duration: 0.5)) {
            viewModel.cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (latMin + latMax) / 2,
                    longitude: (lngMin + lngMax) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: (latMax - latMin) * 1.3,
                    longitudeDelta: (lngMax - lngMin) * 1.3
                )
            ))
        }
    }

    // MARK: - Export

    private func exportMap() {
        Task {
            // Build a region from current visible data
            let allCoords = viewModel.visibleGhosts.map {
                CLLocationCoordinate2D(latitude: $0.clusterLat, longitude: $0.clusterLng)
            } + viewModel.visibleRoutes.flatMap(\.coordinates)

            guard !allCoords.isEmpty else { return }

            let lats = allCoords.map(\.latitude)
            let lngs = allCoords.map(\.longitude)
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (lats.min()! + lats.max()!) / 2,
                    longitude: (lngs.min()! + lngs.max()!) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: (lats.max()! - lats.min()!) * 1.3,
                    longitudeDelta: (lngs.max()! - lngs.min()!) * 1.3
                )
            )

            shareImage = await ExportService.renderSnapshot(
                ghosts: viewModel.visibleGhosts,
                routes: viewModel.visibleRoutes,
                region: region
            )
            showShareSheet = shareImage != nil
        }
    }

    private func ghostOpacity(_ score: Double) -> Double {
        min(0.15 + score * 0.05, 0.65)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
