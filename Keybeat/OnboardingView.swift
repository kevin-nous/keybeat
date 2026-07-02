import SwiftUI

/// First-run window. Its whole job is to get the one permission granted and
/// explain honestly what is (and isn't) being monitored.
struct OnboardingView: View {
    @ObservedObject private var engine = WPMEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 44))
                .foregroundStyle(.pink)
            Text("Keybeat")
                .font(.largeTitle.bold())
            Text("A heart-rate monitor for your typing.")
                .foregroundStyle(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Counts keystrokes. Never records which key.", systemImage: "number")
                    Label("Passwords are invisible to it — macOS blocks secure input at the OS level.", systemImage: "lock.fill")
                    Label("All data stays on this Mac. No network, no analytics.", systemImage: "externaldrive.fill")
                }
                .font(.callout)
                .padding(6)
            }

            switch engine.permission {
            case .needed, .unknown:
                VStack(spacing: 8) {
                    Text("To take your typing pulse, macOS requires you to grant **Input Monitoring** — the same permission class a keylogger would need, which is why you have to flip the switch yourself.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                    Button("Strap on the monitor") {
                        engine.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    Text("System Settings → Privacy & Security → Input Monitoring → enable Keybeat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Flipped the toggle already? Relaunch Keybeat") {
                        WPMEngine.relaunch()
                    }
                }
            case .needsRelaunch:
                VStack(spacing: 8) {
                    Text("Permission granted ✓ — one relaunch and we're live.")
                        .font(.callout)
                    Button("Relaunch Keybeat") {
                        WPMEngine.relaunch()
                    }
                    .buttonStyle(.borderedProminent)
                }
            case .tracking:
                VStack(spacing: 8) {
                    Text("You're live. Current heart rate: \(engine.liveWPM.map { "\($0) WPM" } ?? "resting") ❤️")
                        .font(.callout)
                    Button("Start typing") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 440)
    }
}
