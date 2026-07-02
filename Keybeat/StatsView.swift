import Charts
import SwiftUI

struct StatsView: View {
    @ObservedObject private var engine = WPMEngine.shared
    @State private var report: HealthReport?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            if let report {
                VStack(alignment: .leading, spacing: 24) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        MetricCard(icon: "heart.fill", tint: .pink, title: "Today",
                                   value: report.todayWPM.map { "\(Int($0)) WPM" } ?? "—",
                                   caption: "average while typing")
                        MetricCard(icon: "keyboard.fill", tint: .blue, title: "Keystrokes",
                                   value: report.todayCount.formatted(),
                                   caption: "today")
                        MetricCard(icon: "bolt.fill", tint: .orange, title: "Peak",
                                   value: report.peak.map { "\(Int($0.wpm)) WPM" } ?? "—",
                                   caption: report.peak.map { $0.date.formatted(date: .abbreviated, time: .shortened) } ?? "no record yet")
                        MetricCard(icon: "calendar", tint: .green, title: "Tracked",
                                   value: "\(report.daysTracked) \(report.daysTracked == 1 ? "day" : "days")",
                                   caption: "of typing history")
                        MetricCard(icon: "figure.run", tint: .purple, title: "KeyFit Score™",
                                   value: report.keyFitScore.map { String(format: "%.1f", $0) } ?? "—",
                                   caption: report.keyFitBand)
                        MetricCard(icon: "flame.fill", tint: .red, title: "Streak",
                                   value: report.currentStreak > 0
                                       ? "\(report.currentStreak) \(report.currentStreak == 1 ? "day" : "days")"
                                       : "—",
                                   caption: report.longestStreak > 0 ? "best: \(report.longestStreak)" : "1,000 keystrokes starts one")
                        MetricCard(icon: "bed.double.fill", tint: .teal, title: "Rest days",
                                   value: "\(report.restDaysThisMonth)",
                                   caption: report.restDaysThisMonth == 0 ? "this month. Concerning." : "this month. We noticed.")
                        MetricCard(icon: "moon.stars.fill", tint: .indigo, title: "REM typing",
                                   value: report.nightOwlCount > 0 ? report.nightOwlCount.formatted() : "0",
                                   caption: report.nightOwlCount > 0 ? "keystrokes, 1–5am. Seek sunlight." : "keystrokes between 1–5am")
                    }

                    section("Today's rhythm") {
                        if report.todayCount == 0 {
                            emptyState("Nothing yet — type something and check back. Your pulse chart fills in by the hour.")
                        } else {
                            Chart(report.hourlyToday) { stat in
                                BarMark(
                                    x: .value("Hour", stat.hour),
                                    y: .value("WPM", stat.wpm ?? 0),
                                    width: .ratio(0.6)
                                )
                                .foregroundStyle(.pink.gradient)
                                .cornerRadius(3)
                            }
                            .chartXScale(domain: 0...24)
                            .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 24]) }
                            .frame(height: 150)
                        }
                    }

                    section("Fitness trend — last 30 days") {
                        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: Date()))!
                        let recent = report.daily.filter { $0.day >= cutoff }
                        if recent.count < 2 {
                            emptyState("Your trend line appears once there's more than one day of history. Rome wasn't typed in a day.")
                        } else {
                            Chart(recent) { day in
                                BarMark(
                                    x: .value("Day", day.day, unit: .day),
                                    y: .value("WPM", day.wpm ?? 0),
                                    width: .ratio(0.6)
                                )
                                .foregroundStyle(.pink.gradient)
                                .cornerRadius(3)
                            }
                            .frame(height: 140)
                        }
                    }

                    section("Diagnoses") {
                        VStack(alignment: .leading, spacing: 10) {
                            diagnosis(report.weeklyLine)
                            diagnosis(report.hangoverLine)
                        }
                        Text("Not medical advice. Not medical anything.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
                .padding(20)
            } else {
                ProgressView()
                    .padding(60)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        engine.flush()
        report = HealthReport(store: engine.store)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 90)
    }

    private func diagnosis(_ line: String) -> some View {
        Text(line)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricCard: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.4)))
    }
}
