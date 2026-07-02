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
                    chart(report)
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
