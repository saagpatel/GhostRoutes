import CoreLocation
import UserNotifications
import os.log

@MainActor
@Observable
final class PermissionManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    var locationStatus: CLAuthorizationStatus = .notDetermined
    var notificationGranted = false

    private var locationContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus
    }

    func requestLocationAlways() async {
        guard locationStatus == .notDetermined else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            locationContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }

    func requestNotifications() async {
        do {
            notificationGranted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            Logger.permissions.info("Notification permission: \(self.notificationGranted)")
        } catch {
            Logger.permissions.error("Notification permission error: \(error)")
            notificationGranted = false
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.locationStatus = status
            if status != .notDetermined {
                locationContinuation?.resume()
                locationContinuation = nil
            }
            Logger.permissions.info("Location authorization: \(String(describing: status))")
        }
    }
}

extension Logger {
    static let permissions = Logger(subsystem: "com.ghostroutes.app", category: "permissions")
}
