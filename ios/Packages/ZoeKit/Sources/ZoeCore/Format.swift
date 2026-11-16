import Foundation

/// Formati in italiano usati nelle risposte di ZOE.
public enum ZoeFormat {
    public static let locale = Locale(identifier: "it_IT")

    /// 5400 → "1 ora e 30 minuti"
    public static func duration(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s / 60) % 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) " + (h == 1 ? "ora" : "ore")) }
        if m > 0 { parts.append("\(m) " + (m == 1 ? "minuto" : "minuti")) }
        if sec > 0 && h == 0 { parts.append("\(sec) " + (sec == 1 ? "secondo" : "secondi")) }
        return parts.isEmpty ? "0 secondi" : parts.joined(separator: " e ")
    }

    /// 65 → "1:05", 3725 → "1:02:05"
    public static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s / 60) % 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// "18:30"
    public static func hhmm(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// "lunedì 16 novembre"
    public static func longDate(_ date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    /// 144 → "144", 3.5 → "3,5", 1234.5 → "1.234,5"
    public static func number(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f.string(from: NSNumber(value: v)) ?? String(v)
    }

    /// Quando scatta un promemoria: "tra 20 minuti", "oggi alle 18:00", "domani alle 09:00", "20/11/26 alle 10:00".
    public static func when(_ at: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let delta = at.timeIntervalSince(now)
        if delta > 0 && delta < 3600 {
            let rounded = (delta / 60).rounded() * 60
            return "tra " + duration(rounded > 0 ? rounded : 60)
        }
        let day: String
        if calendar.isDate(at, inSameDayAs: now) { day = "oggi" }
        else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(at, inSameDayAs: tomorrow) { day = "domani" }
        else {
            let f = DateFormatter()
            f.locale = locale; f.calendar = calendar; f.timeZone = calendar.timeZone
            f.dateFormat = "d/M/yy"
            day = f.string(from: at)
        }
        return day + " alle " + hhmm(at, calendar: calendar)
    }

    /// "Buongiorno" / "Buon pomeriggio" / "Buonasera"
    public static func greeting(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let h = calendar.component(.hour, from: date)
        return h < 13 ? "Buongiorno" : h < 18 ? "Buon pomeriggio" : "Buonasera"
    }
}
