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

struct DailyStat: Identifiable {
    let day: Date
    let count: Int
    let activeSeconds: Double

    var id: Date { day }

    var wpm: Double? {
        guard activeSeconds >= 60 else { return nil }
        return (Double(count) / 5) / (activeSeconds / 60)
    }
}

/// All the joke-health stats, computed in one pass over the bucket history.
/// Baseline-dependent gags (hangover detection) stay gated until there's
/// enough data to not fire garbage off a tiny sample.
struct HealthReport {
    static let baselineDays = 14
    /// A day counts toward streaks when it has at least this many keystrokes
    /// (~200 words). Below that you were "resting", per doctor's orders.
    static let activeDayThreshold = 1000

    let daysTracked: Int
    let hourlyToday: [HourStat]
    let todayCount: Int
    let todayWPM: Double?
    let peak: (wpm: Double, date: Date)?
    let nightOwlCount: Int          // all-time keystrokes between 1am and 5am
    let hangoverLine: String

    let daily: [DailyStat]          // one entry per calendar day with data
    let currentStreak: Int
    let longestStreak: Int
    let restDaysThisMonth: Int
    let keyFitScore: Double?        // nil until a week of data
    let keyFitBand: String
    let weeklyLine: String

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

        daily = Self.dailyStats(all, calendar: cal)
        (currentStreak, longestStreak) = Self.streaks(daily, calendar: cal)
        restDaysThisMonth = Self.restDays(daily, calendar: cal)
        (keyFitScore, keyFitBand) = Self.keyFit(daily, currentStreak: currentStreak, calendar: cal)
        weeklyLine = Self.weeklyMessage(daily, calendar: cal)
    }

    // MARK: - Aggregation

    static func dailyStats(_ all: [Store.Bucket], calendar cal: Calendar) -> [DailyStat] {
        var byDay: [Date: (count: Int, active: Double)] = [:]
        for bucket in all {
            let day = cal.startOfDay(for: bucket.date)
            byDay[day, default: (0, 0)].count += bucket.count
            byDay[day, default: (0, 0)].active += bucket.activeSeconds
        }
        return byDay
            .map { DailyStat(day: $0.key, count: $0.value.count, activeSeconds: $0.value.active) }
            .sorted { $0.day < $1.day }
    }

    /// (current, longest). Today only counts once it clears the threshold, and
    /// an under-threshold today doesn't break a streak that ended yesterday.
    private static func streaks(_ daily: [DailyStat], calendar cal: Calendar) -> (Int, Int) {
        let activeDays = Set(daily.filter { $0.count >= activeDayThreshold }.map(\.day))
        var longest = 0
        for day in activeDays where !activeDays.contains(cal.date(byAdding: .day, value: -1, to: day)!) {
            var length = 1
            var next = cal.date(byAdding: .day, value: 1, to: day)!
            while activeDays.contains(next) {
                length += 1
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            longest = max(longest, length)
        }
        var current = 0
        var cursor = cal.startOfDay(for: Date())
        if !activeDays.contains(cursor) {
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        while activeDays.contains(cursor) {
            current += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, longest)
    }

    /// Days this month (before today) below the activity threshold — including
    /// days the Mac never saw a keystroke at all. The app notices. It always notices.
    private static func restDays(_ daily: [DailyStat], calendar cal: Calendar) -> Int {
        let today = cal.startOfDay(for: Date())
        guard let monthStart = cal.dateInterval(of: .month, for: today)?.start else { return 0 }
        let countByDay = Dictionary(uniqueKeysWithValues: daily.map { ($0.day, $0.count) })
        var rest = 0
        var cursor = monthStart
        while cursor < today {
            if countByDay[cursor, default: 0] < activeDayThreshold {
                rest += 1
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return rest
    }

    /// KeyFit Score™: a composite of speed, volume, and consistency with
    /// meaningless single-decimal precision. Not peer-reviewed. Not reviewable.
    private static func keyFit(_ daily: [DailyStat], currentStreak: Int, calendar cal: Calendar) -> (Double?, String) {
        let weekAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: Date()))!
        let week = daily.filter { $0.day >= weekAgo }
        guard daily.count >= 7, !week.isEmpty else {
            return (nil, "Calibrating — a week of typing unlocks your score")
        }
        let count = week.reduce(0) { $0 + $1.count }
        let active = week.reduce(0.0) { $0 + $1.activeSeconds }
        let wpm = active >= 60 ? (Double(count) / 5) / (active / 60) : 0
        let speed = min(wpm / 100, 1)
        let volume = min(Double(count) / Double(week.count) / 10_000, 1)
        let consistency = min(Double(currentStreak) / 14, 1)
        let score = (0.5 * speed + 0.3 * volume + 0.2 * consistency) * 100
        let band: String
        switch score {
        case ..<40: band = "Sedentary typist"
        case ..<60: band = "Average. Painfully average."
        case ..<80: band = "Above average for your age"
        default: band = "Elite. Consider stretching."
        }
        return (score, band)
    }

    /// The week-over-week line used by both the stats window and the Sunday
    /// notification. Passive-aggressive by design; that's the product.
    static func weeklyMessage(_ daily: [DailyStat], calendar cal: Calendar) -> String {
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: today)!
        let thisWeek = daily.filter { $0.day >= weekAgo && $0.day < today }
        let lastWeek = daily.filter { $0.day >= twoWeeksAgo && $0.day < weekAgo }
        let thisCount = thisWeek.reduce(0) { $0 + $1.count }
        let lastCount = lastWeek.reduce(0) { $0 + $1.count }
        guard lastCount >= HealthReport.activeDayThreshold else {
            return "📋 First full week still in progress — your inaugural report arrives Sunday."
        }
        let active = thisWeek.reduce(0.0) { $0 + $1.activeSeconds }
        let wpm = active >= 60 ? Int((Double(thisCount) / 5) / (active / 60)) : 0
        let change = Double(thisCount - lastCount) / Double(lastCount)
        let pct = Int(abs(change) * 100)
        if change < -0.1 {
            return "📉 Typing down \(pct)% this week (avg \(wpm) WPM). Everything okay?"
        }
        if change > 0.1 {
            return "📈 Typing up \(pct)% this week (avg \(wpm) WPM). Your fingers are in the best shape of their lives."
        }
        return "➡️ Typing steady this week (avg \(wpm) WPM). Consistency is the foundation of keyboard cardiovascular health."
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
