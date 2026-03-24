import CoreLocation
import MapKit
import SwiftUI
import os.log

@MainActor
@Observable
final class ComparisonViewModel {
    var periodAStart: Date = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
    var periodAEnd: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    var periodBStart: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    var periodBEnd: Date = Date()

    var periodARoutes: [MapViewModel.RouteSegment] = []
    var periodBRoutes: [MapViewModel.RouteSegment] = []
    var cameraPosition: MapCameraPosition = .automatic
    var isLoading = false

    func loadComparison(locationStore: LocationStore, ghostStore: GhostStore) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let ghosts = try await ghostStore.fetchAll()
            let recordsA = try await locationStore.fetchRecords(from: periodAStart, to: periodAEnd)
            let recordsB = try await locationStore.fetchRecords(from: periodBStart, to: periodBEnd)

            periodARoutes = await Task.detached {
                MapViewModel.buildRouteSegments(from: recordsA, ghosts: ghosts)
            }.value

            periodBRoutes = await Task.detached {
                MapViewModel.buildRouteSegments(from: recordsB, ghosts: ghosts)
            }.value

            fitCamera()
        } catch {
            Logger.map.error("Comparison load failed: \(error)")
        }
    }

    private func fitCamera() {
        let allCoords = (periodARoutes + periodBRoutes).flatMap(\.coordinates)
        guard !allCoords.isEmpty else { return }

        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max()
        else { return }

        cameraPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLng + maxLng) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: (maxLat - minLat) * 1.3,
                longitudeDelta: (maxLng - minLng) * 1.3
            )
        ))
    }
}
