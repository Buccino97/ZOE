import Foundation

// MARK: - Aspetto della mascotte

/// Le 13 espressioni di ZOE (stessi nomi della versione desktop).
public enum ZoeExpression: String, CaseIterable, Codable, Sendable {
    case felice, contenta, ride, sorpresa, assonnata, dorme, arrabbiata, triste, innamorata, pensierosa, occhiolino, emozionata, confusa
}

/// I 5 stili di occhi.
public enum EyeStyle: String, CaseIterable, Codable, Sendable {
    case tondi, grandi, piccoli, anime, stelle
}

/// I 12 accessori.
public enum ZoeAccessory: String, CaseIterable, Codable, Sendable {
    case nessuno, cappellino, cilindro, corona, fiocco, occhiali
    case occhialiDaSole = "occhiali da sole"
    case cuffie, sciarpa, fiore, antenna, papillon

    public var label: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

public enum ZoePalette {
    /// Gli 8 colori del corpo.
    public static let colors = ["#7c5cff", "#3ee0b0", "#ff7a59", "#ff5d9e", "#4cc3ff", "#ffc93c", "#9aa0c3", "#2f2f3a"]
    public static let dark = "#1b1630"

    /// Schiarisce (amt > 0) o scurisce (amt < 0) un colore esadecimale, come `shade()` in zoe.js.
    public static func shade(_ hex: String, _ amt: Int) -> String {
        let n = Int(hex.dropFirst(), radix: 16) ?? 0
        func c(_ v: Int) -> Int { max(0, min(255, v)) }
        let r = c((n >> 16) + amt), g = c(((n >> 8) & 255) + amt), b = c((n & 255) + amt)
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}

// MARK: - Impostazioni e dati salvati

public struct ZoeSettings: Codable, Equatable, Sendable {
    public var name: String = "ZOE"
    public var color: String = ZoePalette.colors[0]
    public var eyes: EyeStyle = .tondi
    public var accessory: ZoeAccessory = .nessuno
    /// Promemoria benessere (acqua ogni ora tra le 9 e le 22).
    public var wellness: Bool = true

    public init() {}

    // Decodifica tollerante: se in futuro aggiungiamo campi, i vecchi salvataggi restano validi.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "ZOE"
        color = (try? c.decodeIfPresent(String.self, forKey: .color)) ?? ZoePalette.colors[0]
        eyes = (try? c.decodeIfPresent(EyeStyle.self, forKey: .eyes)) ?? .tondi
        accessory = (try? c.decodeIfPresent(ZoeAccessory.self, forKey: .accessory)) ?? .nessuno
        wellness = (try? c.decodeIfPresent(Bool.self, forKey: .wellness)) ?? true
    }
}

public struct WaterLog: Codable, Equatable, Sendable {
    /// Giorno a cui si riferisce il conteggio, es. "2026-11-16".
    public var day: String
    public var count: Int
    /// Ultima volta che hai bevuto (serve per il promemoria benessere).
    public var last: Date?
    public static let goal = 8

    public init(day: String, count: Int = 0, last: Date? = nil) {
        self.day = day; self.count = count; self.last = last
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Lo stesso registro, azzerato se è cambiato il giorno.
    public func current(at date: Date, calendar: Calendar = .current) -> WaterLog {
        let key = Self.dayKey(date, calendar: calendar)
        return key == day ? self : WaterLog(day: key, count: 0, last: last)
    }
}

public struct Reminder: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var at: Date
    public init(id: UUID = UUID(), text: String, at: Date) {
        self.id = id; self.text = text; self.at = at
    }
}

public struct TimerState: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var label: String
    public init(start: Date, end: Date, label: String) {
        self.start = start; self.end = end; self.label = label
    }
    public var total: TimeInterval { end.timeIntervalSince(start) }
    public var isFocus: Bool { label == "Focus" }
}

/// Fotografia dei dati condivisi tra app e widget.
public struct ZoeSnapshot: Equatable, Sendable {
    public var settings: ZoeSettings
    public var water: WaterLog
    public var reminders: [Reminder]
    public var timer: TimerState?

    public init(settings: ZoeSettings, water: WaterLog, reminders: [Reminder], timer: TimerState?) {
        self.settings = settings; self.water = water; self.reminders = reminders; self.timer = timer
    }

    /// Come appaiono i dati in un certo istante: acqua azzerata a mezzanotte, promemoria passati e timer scaduti tolti.
    public func at(_ date: Date, calendar: Calendar = .current) -> ZoeSnapshot {
        ZoeSnapshot(settings: settings,
                    water: water.current(at: date, calendar: calendar),
                    reminders: reminders.filter { $0.at > date }.sorted { $0.at < $1.at },
                    timer: timer.flatMap { $0.end > date ? $0 : nil })
    }

    public var nextReminder: Reminder? { reminders.min { $0.at < $1.at } }

    /// L'espressione da mostrare nei widget.
    public func expression(at date: Date, calendar: Calendar = .current) -> ZoeExpression {
        let h = calendar.component(.hour, from: date)
        if let t = timer, t.end > date { return t.isFocus ? .pensierosa : .occhiolino }
        if h >= 23 || h < 7 { return .dorme }
        if water.count >= WaterLog.goal { return .emozionata }
        if let r = nextReminder, r.at.timeIntervalSince(date) < 15 * 60 { return .sorpresa }
        return h >= 22 ? .assonnata : .felice
    }

    public static let sample = ZoeSnapshot(settings: ZoeSettings(), water: WaterLog(day: "", count: 3), reminders: [], timer: nil)
}
