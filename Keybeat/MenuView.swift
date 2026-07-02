import AppKit
import Charts
import SwiftUI

private struct MinuteTick: Identifiable {
    let offset: Int       // 0 = an hour ago … 59 = current minute
    let wpm: Double       // words typed in that minute
    var id: Int { offset }
}

struct MenuView: View {
    @ObservedObject private var engine = WPMEngine.shared
    @Environment(\.openWindow) private var openWindow
    @State private var sparkline: [MinuteTick] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch engine.permission {
            case .tracking:
                trackingBody
            case .needed, .unknown:
                permissionBody
            case .needsRelaunch:
                relaunchBody
            }
            Divider()
            HStack {
                Button("Full Health Report") {
                    openWindow(id: "stats")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var trackingBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(engine.liveWPM.map(String.init) ?? "–")
                    .font(.system(size: 34, weight: .bold).monospacedDigit())
                Text(engine.liveWPM == nil ? "resting" : "WPM")
                    .foregroundStyle(.secondary)
            }
            Text("Today: \(engine.todayKeystrokes) keystrokes · \(Int(engine.todayActiveMinutes)) active min")
                .font(.caption)
                .foregroundStyle(.secondary)
            // Last-hour ECG strip: one bar per minute, axes hidden.
            Chart(sparkline) { tick in
                BarMark(
                    x: .value("Minute", tick.offset),
                    y: .value("WPM", tick.wpm),
                    width: .fixed(2)
                )
                .foregroundStyle(.pink.gradient)
            }
            .chartXScale(domain: 0...59)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 36)
            .padding(.top, 4)
            .onAppear(perform: loadSparkline)
        }
    }

    /// Words-per-minute for each of the last 60 minutes, zeros included —
    /// the flatlines between bursts are part of the ECG look.
    private func loadSparkline() {
        engine.flush()
        let now = Date()
        let nowMinute = Int64(now.timeIntervalSince1970 / 60)
        let buckets = engine.store.buckets(from: now.addingTimeInterval(-3600), to: now.addingTimeInterval(60))
        var byOffset: [Int: Double] = [:]
        for bucket in buckets {
            let age = Int(nowMinute - bucket.minute)
            if (0..<60).contains(age) {
                byOffset[59 - age] = Double(bucket.count) / 5
            }
        }
        sparkline = (0..<60).map { MinuteTick(offset: $0, wpm: byOffset[$0] ?? 0) }
    }

    private var permissionBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monitor not attached")
                .font(.headline)
            Text("Keybeat needs Input Monitoring to count keystrokes.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Grant Input Monitoring…") {
                engine.requestPermission()
            }
            // macOS won't apply the grant to a running process, and the
            // permission check can keep reporting stale state until relaunch —
            // so always offer the way out.
            Button("Already granted it? Relaunch") {
                WPMEngine.relaunch()
            }
        }
    }

    private var relaunchBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permission granted ✓")
                .font(.headline)
            Text("macOS applies it on next launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Relaunch Keybeat") {
                WPMEngine.relaunch()
            }
        }
    }
}
