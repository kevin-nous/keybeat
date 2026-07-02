import Charts
import SwiftUI

struct StatsView: View {
    @ObservedObject private var engine = WPMEngine.shared
    @State private var report: HealthReport?

    var body: some View {
        ScrollView {
            if let report {
                VStack(alignment: .leading, spacing: 20) {
                    vitals(report)
                    fitness(report)
                    chart(report)
                    trends(report)
                    diagnoses(report)
                }
                .padding(20)
            } else {
                ProgressView()
                    .padding(60)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .onAppear(perform: refresh)
    }

    private func refresh() {
        engine.flush()
        report = HealthReport(store: engine.store)
    }

    private func vitals(_ report: HealthReport) -> some View {
        HStack(spacing: 24) {
            vital("Today", report.todayWPM.map { "\(Int($0)) WPM" } ?? "—")
            vital("Keystrokes", "\(report.todayCount)")
            vital("Peak", report.peak.map { "\(Int($0.wpm)) WPM" } ?? "—",
                  caption: report.peak.map { $0.date.formatted(date: .abbreviated, time: .shortened) })
            vital("Days tracked", "\(report.daysTracked)")
        }
    }

    private func vital(_ title: String, _ value: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func fitness(_ report: HealthReport) -> some View {
        HStack(spacing: 24) {
            vital("KeyFit Score™",
                  report.keyFitScore.map { String(format: "%.1f", $0) } ?? "—",
                  caption: report.keyFitBand)
            vital("Streak",
                  report.currentStreak > 0 ? "🔥 \(report.currentStreak) days" : "—",
                  caption: report.longestStreak > 0 ? "best: \(report.longestStreak)" : nil)
            vital("Rest days",
                  "\(report.restDaysThisMonth) this month",
                  caption: report.restDaysThisMonth == 0 ? "Impressive. Concerning." : "We noticed.")
        }
    }

    private func trends(_ report: HealthReport) -> some View {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: Date()))!
        let recent = report.daily.filter { $0.day >= cutoff }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Fitness trend — last 30 days")
                .font(.headline)
            if recent.count < 2 {
                Text("Your trend line appears once there's more than one day of history. Rome wasn't typed in a day.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Chart(recent) { day in
                    BarMark(
                        x: .value("Day", day.day, unit: .day),
                        y: .value("WPM", day.wpm ?? 0)
                    )
                    .foregroundStyle(.pink.gradient)
                }
                .frame(height: 140)
            }
        }
    }

    private func chart(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's rhythm")
                .font(.headline)
            if report.todayCount == 0 {
                Text("Nothing yet — type something and check back. Your pulse chart fills in by the hour.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(report.hourlyToday) { stat in
                    BarMark(
                        x: .value("Hour", stat.hour),
                        y: .value("WPM", stat.wpm ?? 0)
                    )
                    .foregroundStyle(.pink.gradient)
                }
                .chartXScale(domain: 0...24)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24])
                }
                .frame(height: 160)
            }
        }
    }

    private func diagnoses(_ report: HealthReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnoses")
                .font(.headline)
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(report.weeklyLine)
                    Text(report.hangoverLine)
                    if report.nightOwlCount > 0 {
                        Text("🦉 REM typing: \(report.nightOwlCount) keystrokes between 1–5am. Seek sunlight.")
                    } else {
                        Text("😴 No 1–5am typing on record. Your circadian rhythm thanks you.")
                    }
                }
                .font(.callout)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Not medical advice. Not medical anything.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
