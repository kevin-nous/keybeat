import Foundation

struct HourStat: Identifiable {
    let hour: Int
    let count: Int
    let activeSeconds: Double

    var id: Int { hour }

    /// Needs at least 30s of active typing in the hour to say anything.
    var wpm: Double? {
        guard activeSeconds >= 30 else { return nil }
        return (Double(count) / 5) / (activeSeconds / 60)
    }
}

/// All the joke-health stats, computed in one pass over the bucket history.
/// Baseline-dependent gags (hangover detection) stay gated until there's
/// enough data to not fire garbage off a tiny sample.
struct HealthReport {
    static let baselineDays = 14

    let daysTracked: Int
    let hourlyToday: [HourStat]
    let todayCount: Int
    let todayWPM: Double?
    let peak: (wpm: Double, date: Date)?
    let nightOwlCount: Int          // all-time keystrokes between 1am and 5am
    let hangoverLine: String

    init(store: Store) {
        let all = store.allBuckets()
        let cal = Calendar.current

        daysTracked = Set(all.map { cal.startOfDay(for: $0.date) }).count

        let today = all.filter { cal.isDateInToday($0.date) }
        todayCount = today.reduce(0) { $0 + $1.count }
        let todayActive = today.reduce(0.0) { $0 + $1.activeSeconds }
        todayWPM = todayActive >= 60 ? (Double(todayCount) / 5) / (todayActive / 60) : nil

        var byHour: [Int: (count: Int, active: Double)] = [:]
        for bucket in today {
            let hour = cal.component(.hour, from: bucket.date)
            byHour[hour, default: (0, 0)].count += bucket.count
            byHour[hour, default: (0, 0)].active += bucket.activeSeconds
        }
        hourlyToday = (0..<24).map {
            HourStat(hour: $0, count: byHour[$0]?.count ?? 0, activeSeconds: byHour[$0]?.active ?? 0)
        }

        peak = all
            .filter { $0.activeSeconds >= 15 }
            .map { (wpm: min((Double($0.count) / 5) / (max($0.activeSeconds, 15) / 60), 300), date: $0.date) }
            .max { $0.wpm < $1.wpm }

        nightOwlCount = all
            .filter { (1..<5).contains(cal.component(.hour, from: $0.date)) }
            .reduce(0) { $0 + $1.count }

        hangoverLine = Self.diagnoseHangover(all, daysTracked: daysTracked, calendar: cal)
    }

    private static func diagnoseHangover(_ all: [Store.Bucket], daysTracked: Int, calendar cal: Calendar) -> String {
        guard daysTracked >= baselineDays else {
            return "🩺 Calibrating baseline — \(baselineDays - daysTracked) more days until hangover detection comes online. Keep typing."
        }
        func morningWPM(weekend: Bool) -> Double? {
            let buckets = all.filter {
                let hour = cal.component(.hour, from: $0.date)
                return (8..<12).contains(hour) && cal.isDateInWeekend($0.date) == weekend
            }
            let count = buckets.reduce(0) { $0 + $1.count }
            let active = buckets.reduce(0.0) { $0 + $1.activeSeconds }
            guard active >= 300 else { return nil }
            return (Double(count) / 5) / (active / 60)
        }
        guard let weekday = morningWPM(weekend: false), let weekend = morningWPM(weekend: true) else {
            return "🩺 Not enough morning typing to diagnose anything. Suspicious in itself."
        }
        let ratio = weekend / weekday
        if ratio < 0.75 {
            return "🥴 Weekend-morning WPM is \(Int((1 - ratio) * 100))% below your weekday baseline. Rough nights detected."
        }
        return "🍀 Weekend mornings within \(Int(abs(1 - ratio) * 100))% of baseline. No hangovers detected. Hydration icon."
    }
}
