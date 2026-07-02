import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject private var engine = WPMEngine.shared
    @Environment(\.openWindow) private var openWindow

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
        }
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
