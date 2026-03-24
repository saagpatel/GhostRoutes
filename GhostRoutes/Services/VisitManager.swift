import CoreLocation
import os.log

@MainActor
@Observable
final class VisitManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let database: AppDatabase
    private(set) var isMonitoring = false
    private(set) var lastVisitDate: Date?

    init(database: AppDatabase) {
        self.database = database
        super.init()
        locationManager.delegate = self
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard locationManager.authorizationStatus == .authorizedAlways
            || locationManager.authorizationStatus == .authorizedWhenInUse
        else {
            Logger.visitManager.warning("Skipping visit monitoring: not authorized")
            return
        }
        locationManager.startMonitoringVisits()
        isMonitoring = true
        Logger.visitManager.info("Started monitoring visits")
    }

    func stopMonitoring() {
        locationManager.stopMonitoringVisits()
        isMonitoring = false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Skip in-progress visits (departure not yet known)
        guard visit.departureDate != .distantFuture else { return }

        let record = LocationRecord(
            latitude: visit.coordinate.latitude,
            longitude: visit.coordinate.longitude,
            timestamp: visit.arrivalDate,
            accuracyMeters: visit.horizontalAccuracy,
            source: .clvisit
        )

        let visitRecord = Visit(
            clusterLat: visit.coordinate.latitude,
            clusterLng: visit.coordinate.longitude,
            arrivedAt: visit.arrivalDate,
            departedAt: visit.departureDate,
            durationSeconds: Int(visit.departureDate.timeIntervalSince(visit.arrivalDate)),
            source: .clvisit
        )

        Task { @MainActor in
            await self.persistVisit(record: record, visit: visitRecord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            Logger.visitManager.error("Location error: \(error)")
        }
    }

    // MARK: - Persistence

    private func persistVisit(record: LocationRecord, visit: Visit) async {
        let locationStore = LocationStore(database: database)
        do {
            _ = try await locationStore.insert(record)
            _ = try await locationStore.insertVisit(visit)
            lastVisitDate = visit.arrivedAt
            Logger.visitManager.info(
                "Saved CLVisit at \(record.latitude), \(record.longitude) (\(visit.durationSeconds)s)"
            )
        } catch {
            Logger.visitManager.error("Failed to persist CLVisit: \(error)")
        }
    }
}

extension Logger {
    static let visitManager = Logger(subsystem: "com.ghostroutes.app", category: "visitManager")
}
