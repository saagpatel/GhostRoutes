import CoreLocation
import MapKit
import SwiftUI
import os.log

@MainActor
@Observable
final class MapViewModel {

    var cameraPosition: MapCameraPosition = .automatic
    var ghostLocations: [GhostLocation] = []
    var routeSegments: [RouteSegment] = []
    var visibleGhosts: [GhostLocation] = []
    var visibleRoutes: [RouteSegment] = []
    var isLoading = false

    struct RouteSegment: Identifiable, Sendable {
        let id = UUID()
        let coordinates: [CLLocationCoordinate2D]
        let isGhost: Bool
        let ghostlinessScore: Double?
    }

    func loadData(locationStore: LocationStore, ghostStore: GhostStore) async {
        isLoading = true
        defer { isLoading = false }

        do {
            ghostLocations = try await ghostStore.fetchAll()
            let records = try await locationStore.fetchAllRecords()

            routeSegments = await Task.detached { [ghostLocations = self.ghostLocations] in
                Self.buildRouteSegments(
                    from: records,
                    ghosts: ghostLocations
                )
            }.value

            // Show all data
            visibleGhosts = ghostLocations
            visibleRoutes = routeSegments

            fitCameraToData()

            Logger.map.info(
                "Loaded \(self.ghostLocations.count) ghosts, \(self.routeSegments.count) route segments"
            )
        } catch {
            Logger.map.error("Failed to load map data: \(error)")
        }
    }

    func updateVisibleOverlays(region: MKCoordinateRegion) {
        let tolerance = toleranceForSpan(region.span)
        let paddedRegion = padRegion(region, factor: 1.3)

        visibleGhosts = ghostLocations.filter { ghost in
            paddedRegion.contains(latitude: ghost.clusterLat, longitude: ghost.clusterLng)
        }

        visibleRoutes = routeSegments.compactMap { segment in
            guard segment.coordinates.contains(where: { coord in
                paddedRegion.contains(latitude: coord.latitude, longitude: coord.longitude)
            }) else { return nil }

            let simplified = DouglasPeucker.simplify(segment.coordinates, tolerance: tolerance)
            return RouteSegment(
                coordinates: simplified,
                isGhost: segment.isGhost,
                ghostlinessScore: segment.ghostlinessScore
            )
        }

        // Cap at 500 total overlays
        if visibleRoutes.count > 450 {
            visibleRoutes = Array(visibleRoutes.prefix(450))
        }
    }

    // MARK: - Route Segment Construction

    private nonisolated static func buildRouteSegments(
        from records: [LocationRecord],
        ghosts: [GhostLocation]
    ) -> [RouteSegment] {
        guard records.count >= 2 else { return [] }

        let sorted = records.sorted { $0.timestamp < $1.timestamp }
        var segments: [RouteSegment] = []
        var currentCoords: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: sorted[0].latitude, longitude: sorted[0].longitude)
        ]

        for i in 1..<sorted.count {
            let record = sorted[i]
            let prev = sorted[i - 1]
            let gap = record.timestamp.timeIntervalSince(prev.timestamp)

            let coord = CLLocationCoordinate2D(
                latitude: record.latitude,
                longitude: record.longitude
            )

            if gap > Double(GhostThresholds.routeSegmentGapSeconds) {
                // Time gap — finalize segment
                if currentCoords.count >= 2 {
                    let simplified = DouglasPeucker.simplify(currentCoords, tolerance: 50)
                    let isGhost = isNearGhost(segment: simplified, ghosts: ghosts)
                    let score = nearestGhostScore(segment: simplified, ghosts: ghosts)
                    segments.append(RouteSegment(
                        coordinates: simplified,
                        isGhost: isGhost,
                        ghostlinessScore: score
                    ))
                }
                currentCoords = [coord]
            } else {
                currentCoords.append(coord)
            }
        }

        // Finalize last segment
        if currentCoords.count >= 2 {
            let simplified = DouglasPeucker.simplify(currentCoords, tolerance: 50)
            let isGhost = isNearGhost(segment: simplified, ghosts: ghosts)
            let score = nearestGhostScore(segment: simplified, ghosts: ghosts)
            segments.append(RouteSegment(
                coordinates: simplified,
                isGhost: isGhost,
                ghostlinessScore: score
            ))
        }

        return segments
    }

    private nonisolated static func isNearGhost(
        segment: [CLLocationCoordinate2D],
        ghosts: [GhostLocation]
    ) -> Bool {
        nearestGhostScore(segment: segment, ghosts: ghosts) != nil
    }

    private nonisolated static func nearestGhostScore(
        segment: [CLLocationCoordinate2D],
        ghosts: [GhostLocation]
    ) -> Double? {
        let threshold = 100.0  // meters
        for coord in segment {
            for ghost in ghosts {
                let dist = haversineDistance(
                    lat1: coord.latitude, lng1: coord.longitude,
                    lat2: ghost.clusterLat, lng2: ghost.clusterLng
                )
                if dist <= threshold {
                    return ghost.ghostlinessScore
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func fitCameraToData() {
        var allCoords: [CLLocationCoordinate2D] = ghostLocations.map {
            CLLocationCoordinate2D(latitude: $0.clusterLat, longitude: $0.clusterLng)
        }
        allCoords += routeSegments.flatMap { $0.coordinates }

        guard !allCoords.isEmpty else { return }

        let lats = allCoords.map(\.latitude)
        let lngs = allCoords.map(\.longitude)

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLng = lngs.min(), let maxLng = lngs.max()
        else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLng - minLng) * 1.3
        )

        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func toleranceForSpan(_ span: MKCoordinateSpan) -> Double {
        let metersPerDegree = 111_000.0
        let viewportMeters = span.latitudeDelta * metersPerDegree
        return max(viewportMeters / 500, 5)
    }

    private func padRegion(_ region: MKCoordinateRegion, factor: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * factor,
                longitudeDelta: region.span.longitudeDelta * factor
            )
        )
    }
}

// MARK: - MKCoordinateRegion helpers

extension MKCoordinateRegion {
    func contains(latitude: Double, longitude: Double) -> Bool {
        let latMin = center.latitude - span.latitudeDelta / 2
        let latMax = center.latitude + span.latitudeDelta / 2
        let lngMin = center.longitude - span.longitudeDelta / 2
        let lngMax = center.longitude + span.longitudeDelta / 2
        return latitude >= latMin && latitude <= latMax
            && longitude >= lngMin && longitude <= lngMax
    }
}

extension Logger {
    static let map = Logger(subsystem: "com.ghostroutes.app", category: "map")
}
