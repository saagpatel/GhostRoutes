import Foundation
import UserNotifications
import os.log

@MainActor
struct AlertsManager {

    static var isMindfulModeActive: Bool {
        let pauseUntil = UserDefaults.standard.double(forKey: "mindfulModePauseUntil")
        guard pauseUntil > 0 else { return false }
        return Date().timeIntervalSince1970 < pauseUntil
    }

    /// Schedule ghost alerts for qualifying ghosts. Skips if Mindful Mode is active.
    static func scheduleGhostAlerts(ghostStore: GhostStore) async {
        guard !isMindfulModeActive else {
            Logger.alerts.info("Mindful Mode active — skipping ghost alerts")
            return
        }

        do {
            let ghosts = try await ghostStore.fetchAlertable()
            guard !ghosts.isEmpty else {
                Logger.alerts.info("No alertable ghosts found")
                return
            }

            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                Logger.alerts.warning("Notifications not authorized")
                return
            }

            for ghost in ghosts {
                let content = UNMutableNotificationContent()
                content.title = ghost.cachedDisplayName ?? "A place you used to visit"

                let weeks = Int(Date().timeIntervalSince(ghost.lastVisitAt) / (7 * 86400))
                content.body = "You haven't been here in \(weeks) weeks"
                content.sound = .default

                #if DEBUG
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                #else
                // Sunday at 9 AM
                var dateComponents = DateComponents()
                dateComponents.weekday = 1  // Sunday
                dateComponents.hour = 9
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: false
                )
                #endif

                let identifier = "ghost-alert-\(ghost.id ?? 0)"
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                    if let ghostId = ghost.id {
                        try await ghostStore.markAlertSent(ghostId: ghostId)
                    }
                    Logger.alerts.info(
                        "Scheduled alert for ghost: \(ghost.cachedDisplayName ?? "unknown")"
                    )
                } catch {
                    Logger.alerts.error("Failed to schedule alert: \(error)")
                }
            }
        } catch {
            Logger.alerts.error("Failed to fetch alertable ghosts: \(error)")
        }
    }

    /// Cancel all pending ghost notifications.
    static func cancelAllAlerts() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Logger.alerts.info("Cancelled all pending ghost alerts")
    }
}

extension Logger {
    static let alerts = Logger(subsystem: "com.ghostroutes.app", category: "alerts")
}
