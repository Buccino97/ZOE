import Foundation
import ZoeCore

/// Dati salvati in un "App Group": uno spazio condiviso tra l'app e i widget.
/// Il nome del gruppo è nella chiave `ZoeAppGroup` dell'Info.plist (viene da Config.xcconfig).
public enum ZoeStorage {
    public static let didChange = Notification.Name("ZoeStorageDidChange")

    public static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "ZoeAppGroup") as? String
    }

    public static var defaults: UserDefaults {
        if let g = appGroup, !g.isEmpty, let d = UserDefaults(suiteName: g) { return d }
        return .standard
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }

    public static var settings: ZoeSettings {
        get { load("settings") ?? ZoeSettings() }
        set { save(newValue, "settings") }
    }
    public static var water: WaterLog {
        get { (load("water") ?? WaterLog(day: WaterLog.dayKey(Date()))).current(at: Date()) }
        set { save(newValue, "water") }
    }
    public static var reminders: [Reminder] {
        get { load("reminders") ?? [] }
        set { save(newValue.sorted { $0.at < $1.at }, "reminders") }
    }
    public static var timer: TimerState? {
        get { load("timer") }
        set { save(newValue, "timer") }
    }

    /// Segna `n` bicchieri d'acqua e restituisce il registro aggiornato.
    @discardableResult
    public static func addWater(_ n: Int, now: Date = Date()) -> WaterLog {
        var w = water.current(at: now)
        w.count = max(0, w.count + n)
        if n > 0 { w.last = now }
        water = w
        return w
    }

    public static func snapshot(at date: Date = Date()) -> ZoeSnapshot {
        ZoeSnapshot(settings: settings, water: water, reminders: reminders, timer: timer).at(date)
    }

    /// Avvisa l'app (se è aperta) che i dati sono cambiati da fuori, per esempio da un widget o da Siri.
    public static func notifyChange() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
