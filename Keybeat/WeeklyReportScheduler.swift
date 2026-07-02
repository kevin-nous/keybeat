import Foundation
import UserNotifications

/// Schedules the Sunday 6pm "Weekly Health Report" notification — the same
/// week-over-week line shown in the stats window, delivered with the loving
/// passive-aggression of a fitness wearable.
///
/// Local notifications carry static content, so the message is computed when
/// scheduled, not when delivered. We reschedule on every launch and at each
/// day rollover, so it's never more than a day stale.
enum WeeklyReportScheduler {
    private static let identifier = "keybeat.weekly-report"

    static func refresh(store: Store) {
        // Compute on the caller's (main) thread — Store isn't thread-safe.
        let daily = HealthReport.dailyStats(store.allBuckets(), calendar: Calendar.current)
        let message = HealthReport.weeklyMessage(daily, calendar: Calendar.current)

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Keybeat Weekly Health Report"
            content.body = message

            var components = DateComponents()
            components.weekday = 1   // Sunday
            components.hour = 18
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }
}
