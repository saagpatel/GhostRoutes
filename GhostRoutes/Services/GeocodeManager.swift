import CoreLocation
import Foundation
import os.log

actor GeocodeManager {
    private let geocoder = CLGeocoder()
    private let ghostStore: GhostStore
    private var lastCallTime: ContinuousClock.Instant?
    private let minInterval: Duration = .milliseconds(1100)

    init(ghostStore: GhostStore) {
        self.ghostStore = ghostStore
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> String {
        // Check cache first
        let cacheKey = PlaceCache.makeCacheKey(latitude: latitude, longitude: longitude)
        if let cached = try await ghostStore.fetchPlace(byCacheKey: cacheKey) {
            Logger.geocode.debug("Cache hit for \(cacheKey)")
            return cached.displayName
        }

        // Rate limit — wait if needed
        if let last = lastCallTime {
            let elapsed = ContinuousClock.now - last
            if elapsed < minInterval {
                try await Task.sleep(for: minInterval - elapsed)
            }
        }
        lastCallTime = .now

        // Geocode
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let name = placemarks.first?.name
            ?? placemarks.first?.locality
            ?? "Near \(String(format: "%.4f", latitude))°N"

        // Cache the result
        let place = PlaceCache(
            latitude: latitude,
            longitude: longitude,
            displayName: name,
            locality: placemarks.first?.locality,
            geocodedAt: Date(),
            cacheKey: cacheKey
        )
        _ = try await ghostStore.upsertPlace(place)

        Logger.geocode.info("Geocoded \(cacheKey) → \(name)")
        return name
    }
}

extension Logger {
    static let geocode = Logger(subsystem: "com.ghostroutes.app", category: "geocode")
}
