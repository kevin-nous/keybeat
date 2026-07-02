import AppKit
import Combine
import Foundation

/// Turns the raw "+1 keystroke" stream into per-minute buckets, active-time
/// accounting, and the live WPM shown in the menu bar. Main-thread only.
///
/// WPM uses the standard typing-tool definition: 5 keystrokes = 1 "word",
/// so WPM = keystrokes / 5 / active minutes. Gaps longer than `idleGap`
/// between keystrokes don't count as typing time — coffee breaks aren't slow
/// typing, they're not typing.
final class WPMEngine: ObservableObject {
    static let shared = WPMEngine()

    enum Permission: Equatable {
        case unknown
        case needed          // Input Monitoring not granted yet
        case needsRelaunch   // granted, but this process must relaunch to attach
        case tracking
    }

    @Published private(set) var permission: Permission = .unknown
    @Published private(set) var liveWPM: Int?          // nil while resting
    @Published private(set) var todayKeystrokes = 0
    @Published private(set) var todayActiveMinutes = 0.0

    let store: Store

    /// Inter-keystroke gaps longer than this are idle, not typing. A design
    /// choice, not a standard — tune to taste.
    static let idleGap: TimeInterval = 5

    private let monitor = KeystrokeMonitor()
    private var lastKeystroke: Date?
    private var recent: [Date] = []                    // rolling 60s window for live WPM
    private var smoothedWPM: Double?                   // EMA state for the displayed rate
    private var bucketMinute: Int64 = 0
    private var bucketCount = 0
    private var bucketActive: TimeInterval = 0
    private var ticker: Timer?
    private var todayKey: Date

    private init() {
        store = Store()
        todayKey = Calendar.current.startOfDay(for: Date())
        monitor.onKeystroke = { [weak self] in self?.recordKeystroke() }
        reloadToday()
    }

    // MARK: - Lifecycle

    func startTracking() {
        guard permission != .tracking else { return }
        guard KeystrokeMonitor.hasPermission() else {
            permission = .needed
            return
        }
        permission = monitor.start() ? .tracking : .needsRelaunch
        if permission == .tracking, ticker == nil {
            ticker = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.tick()
            }
            WeeklyReportScheduler.refresh(store: store)
        }
    }

    /// Surfaces the system prompt, opens the right Settings pane, and polls
    /// until the user flips the toggle — then tries to attach live.
    func requestPermission() {
        KeystrokeMonitor.requestPermission()
        KeystrokeMonitor.openSettingsPane()
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            if KeystrokeMonitor.hasPermission() {
                timer.invalidate()
                self.startTracking()
            }
        }
    }

    static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    /// Persist the in-progress minute (called on quit and before reading stats).
    func flush() {
        flushBucket()
    }

    // MARK: - Keystroke stream

    private func recordKeystroke() {
        let now = Date()
        let minute = Int64(now.timeIntervalSince1970 / 60)
        if minute != bucketMinute {
            flushBucket()
            bucketMinute = minute
        }
        if let last = lastKeystroke {
            let gap = now.timeIntervalSince(last)
            if gap <= Self.idleGap {
                bucketActive += gap
                todayActiveMinutes += gap / 60
            }
        }
        bucketCount += 1
        todayKeystrokes += 1
        lastKeystroke = now
        recent.append(now)
        // Display updates happen on the 2s tick, not per keystroke — a fixed
        // cadence keeps the EMA time-consistent and the menu bar calm.
    }

    private func tick() {
        let cutoff = Date().addingTimeInterval(-60)
        recent.removeAll { $0 < cutoff }
        liveWPM = computeLiveWPM()

        // Persist a finished minute even when no new keystroke has arrived.
        if bucketCount > 0, Int64(Date().timeIntervalSince1970 / 60) != bucketMinute {
            flushBucket()
        }
        // Day rollover: reset the "today" numbers and re-arm Sunday's report.
        let today = Calendar.current.startOfDay(for: Date())
        if today != todayKey {
            todayKey = today
            reloadToday()
            WeeklyReportScheduler.refresh(store: store)
        }
    }

    /// Instantaneous rate from the last ~30 keystrokes, then smoothed with an
    /// EMA (~5s time constant at the 2s tick) so the menu bar reads like a
    /// heart rate, not a seismograph.
    private func computeLiveWPM() -> Int? {
        guard let last = lastKeystroke, Date().timeIntervalSince(last) <= Self.idleGap else {
            smoothedWPM = nil
            return nil
        }
        guard recent.count >= 8 else { return smoothedWPM.map { Int($0.rounded()) } }
        let window = recent.suffix(30)
        var active: TimeInterval = 0
        for (a, b) in zip(window, window.dropFirst()) {
            let gap = b.timeIntervalSince(a)
            if gap <= Self.idleGap {
                active += gap
            }
        }
        // Warm-up: a fresh burst has a tiny denominator and reads absurdly
        // high. Say nothing until there's ~2s of real typing to rate.
        guard active >= 2 else { return smoothedWPM.map { Int($0.rounded()) } }
        let raw = min((Double(window.count) / 5) / (active / 60), 300)
        let alpha = 0.4
        let smoothed = smoothedWPM.map { $0 + alpha * (raw - $0) } ?? raw
        smoothedWPM = smoothed
        return Int(smoothed.rounded())
    }

    private func flushBucket() {
        guard bucketCount > 0 else { return }
        store.add(minute: bucketMinute, count: bucketCount, activeSeconds: bucketActive)
        bucketCount = 0
        bucketActive = 0
    }

    private func reloadToday() {
        let start = Calendar.current.startOfDay(for: Date())
        let buckets = store.buckets(from: start, to: Date().addingTimeInterval(60))
        todayKeystrokes = buckets.reduce(0) { $0 + $1.count }
        todayActiveMinutes = buckets.reduce(0) { $0 + $1.activeSeconds } / 60
    }
}
