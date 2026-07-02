import AppKit
import SwiftUI

@main
struct KeybeatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Window("Keybeat — Full Health Report", id: "stats") {
            StatsView()
        }
        .defaultSize(width: 560, height: 560)

        Window("Welcome to Keybeat", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        WPMEngine.shared.flush()
    }
}

private struct MenuBarLabel: View {
    @ObservedObject private var engine = WPMEngine.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
            Text(labelText)
                .font(.body.monospacedDigit())
        }
        .onAppear {
            engine.startTracking()
            // Menu-bar-only app: without this, first run is a dormant glyph
            // and a permission that never gets granted. Drive the user to it.
            if engine.permission != .tracking {
                openWindow(id: "onboarding")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private var labelText: String {
        switch engine.permission {
        case .tracking:
            return engine.liveWPM.map(String.init) ?? "–"
        case .needed, .needsRelaunch, .unknown:
            return "!"
        }
    }
}
