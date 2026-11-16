#if canImport(UserNotifications)
import Foundation
import UserNotifications
import ZoeCore

/// Notifiche locali: timer, promemoria e acqua. Arrivano anche ad app chiusa, senza server.
public enum ZoeNotifier {
    static var center: UNUserNotificationCenter { .current() }
    static let timerID = "zoe.timer"
    static let waterPrefix = "zoe.water."

    @discardableResult
    public static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public static func isAuthorized() async -> Bool {
        let s = await center.notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    private static func add(_ id: String, title: String, body: String, at date: Date, sound: Bool = true) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: Timer

    public static func scheduleTimer(_ t: TimerState) {
        cancelTimer()
        add(timerID,
            title: "⏰ " + (t.label == "Timer" ? "Timer finito" : t.label),
            body: t.isFocus ? "Sessione finita! Ti meriti 5 minuti di pausa." : "Il tempo è scaduto!",
            at: t.end)
    }

    public static func cancelTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [timerID])
    }

    // MARK: Promemoria

    public static func schedule(_ r: Reminder) {
        add("zoe.reminder." + r.id.uuidString, title: "📌 Promemoria", body: r.text, at: r.at)
    }

    public static func cancel(reminders ids: [UUID]) {
        center.removePendingNotificationRequests(withIdentifiers: ids.map { "zoe.reminder." + $0.uuidString })
    }

    // MARK: Acqua

    /// Riprogramma i promemoria per l'acqua (ogni ora dall'ultimo bicchiere, tra le 9 e le 22).
    public static func rescheduleWater(_ log: WaterLog, enabled: Bool, now: Date = Date()) {
        Task {
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(waterPrefix) })
            guard enabled else { return }
            for (i, date) in ZoeWellness.waterNudges(lastWater: log.last, countToday: log.count, now: now).enumerated() {
                add(waterPrefix + String(i), title: "💧 Un bicchiere d'acqua?", body: "Dimmi «ho bevuto» quando hai fatto.", at: date, sound: false)
            }
        }
    }
}
#endif
