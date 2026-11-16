import Foundation

/// Ciò che ZOE ha capito di una frase. Traduzione di `parse()` in app/src/renderer/commands.js.
public enum ZoeIntent: Equatable {
    case empty
    case timer(seconds: TimeInterval, label: String)
    case timerIncomplete
    case timerCancel
    case reminder(text: String, at: Date)
    case reminderIncomplete(text: String)
    case reminderClear
    case calc(expr: String, value: Double)
    case water(delta: Int)
    case password(length: Int)
    case time, date, coin, dice, joke, settings, sleep, whoami, help, thanks, comfort, greet
    case unknown(text: String)
}

/// Capisce i comandi in italiano scritti (o detti a Siri) a ZOE.
/// Funzioni pure: niente effetti collaterali, quindi facili da testare.
public enum ZoeCommands {

    // MARK: Numeri e unità

    /// L'ordine conta per l'alternanza nell'espressione regolare (come in JavaScript).
    static let wordNumbers: [(String, Double)] = [
        ("un", 1), ("uno", 1), ("una", 1), ("due", 2), ("tre", 3), ("quattro", 4), ("cinque", 5), ("sei", 6),
        ("sette", 7), ("otto", 8), ("nove", 9), ("dieci", 10), ("undici", 11), ("dodici", 12), ("quindici", 15),
        ("venti", 20), ("trenta", 30), ("quaranta", 40), ("cinquanta", 50),
    ]
    static let unitSeconds: [String: Double] = [
        "secondi": 1, "secondo": 1, "sec": 1, "s": 1,
        "minuti": 60, "minuto": 60, "min": 60, "m": 60,
        "ore": 3600, "ora": 3600, "h": 3600,
    ]
    static let NUM = #"(\d+(?:[.,]\d+)?|"# + wordNumbers.map { $0.0 }.joined(separator: "|") + ")"
    static let UNIT = #"(secondi|secondo|sec|s|minuti|minuto|min|m|ore|ora|h)"#

    static func toNumber(_ tok: String) -> Double {
        if let w = wordNumbers.first(where: { $0.0 == tok }) { return w.1 }
        return Double(tok.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    // MARK: Normalizzazione

    /// Minuscolo, senza accenti, apostrofi uniformati, spazi compattati, senza punteggiatura finale.
    public static func normalize(_ text: String) -> String {
        text.lowercased()
            .decomposedStringWithCanonicalMapping
            .rxReplace(#"[̀-ͯ]"#, with: "")
            .rxReplace(#"[’`]"#, with: "'")
            .rxReplace(#"\b(un|mezz|quest|dell|all|d)'"#, with: "$1 ")
            .rxReplace(#"\s+"#, with: " ")
            .rxReplace(#"[!?.]+$"#, with: "")
            .trimmed
    }

    // MARK: Durate e orari

    /// Durata totale in secondi trovata nel testo ("1 ora e 30 minuti", "mezz'ora", "90 sec"), oppure 0.
    public static func parseDuration(_ text: String) -> TimeInterval {
        let t = normalize(text)
        var s: Double = 0
        for m in t.rxMatches(#"\b"# + NUM + #"\s*"# + UNIT + #"\b"#) {
            if let n = m[1], let u = m[2], let k = unitSeconds[u] { s += toNumber(n) * k }
        }
        if t.rxTest(#"\bmezz ?ora\b"#) { s += 30 * 60 }
        if t.rxTest(#"\b(un )?quarto d ?ora\b"#) { s += 15 * 60 }
        if t.rxTest(#"\b(ora|ore) e mezz[ao]\b"#) { s += 30 * 60 }
        return (s * 1000).rounded() / 1000
    }

    /// "alle 18", "alle 18:30", "alle 7.15", "domani alle 9" → il prossimo momento così, oppure nil.
    public static func parseClock(_ text: String, now: Date, calendar: Calendar = .current) -> Date? {
        let t = normalize(text)
        guard let m = t.rxMatch(#"\b(?:alle|all|per le)\s+(\d{1,2})(?:[:.](\d{2}))?(?:\s+e\s+(mezza|un quarto|quarto))?"#),
              let hs = m[1], let h = Int(hs) else { return nil }
        let minute: Int
        if let mm = m[2], let v = Int(mm) { minute = v }
        else if let q = m[3] { minute = q == "mezza" ? 30 : 15 }
        else { minute = 0 }
        if h > 23 || minute > 59 { return nil }

        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = h; comps.minute = minute; comps.second = 0
        guard var d = calendar.date(from: comps) else { return nil }
        if t.rxTest(#"\bdomani\b"#) {
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
        } else if d <= now {
            // "alle 6" detto alle 15:00 quasi sicuramente vuol dire le 18:00, altrimenti domani.
            if h < 12 && h + 12 > calendar.component(.hour, from: now) {
                comps.hour = h + 12
                d = calendar.date(from: comps) ?? d
            } else {
                d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
            }
        }
        return d
    }

    // MARK: Calcolatrice

    /// Aritmetica sicura: numeri, + - * / x : ^ % e parentesi. Restituisce un numero oppure nil.
    public static func calculate(_ expr: String) -> Double? {
        let src = Array(expr.lowercased()
            .rxReplace(#"\bper\b|x|×"#, with: "*")
            .rxReplace(#"\bdiviso\b|:|÷"#, with: "/")
            .rxReplace(#"\bpiu\b|\bpiù\b"#, with: "+")
            .rxReplace(#"\bmeno\b"#, with: "-")
            .rxReplace(#"(\d),(\d)"#, with: "$1.$2")
            .rxReplace(#"\s+"#, with: ""))
        if src.isEmpty || String(src).rxTest(#"[^0-9.+\-*/^%()]"#) { return nil }
        var p = Calc(src: src)
        guard let v = try? p.sum(), p.i == src.count, v.isFinite else { return nil }
        return (v * 1e10 + 0.5).rounded(.down) / 1e10
    }

    private struct Calc {
        struct Bad: Error {}
        let src: [Character]
        var i = 0
        var peek: Character? { i < src.count ? src[i] : nil }

        mutating func number() throws -> Double {
            let start = i
            while let c = peek, c.isASCII, c.isNumber { i += 1 }
            let hadInt = i > start
            if peek == ".", i + 1 < src.count, src[i + 1].isASCII, src[i + 1].isNumber {
                i += 1
                while let c = peek, c.isASCII, c.isNumber { i += 1 }
            } else if !hadInt {
                throw Bad()
            }
            guard var v = Double(String(src[start..<i])) else { throw Bad() }
            if peek == "%" { i += 1; v /= 100 }
            return v
        }
        mutating func factor() throws -> Double {
            if peek == "-" { i += 1; return -(try factor()) }
            if peek == "+" { i += 1; return try factor() }
            var v: Double
            if peek == "(" {
                i += 1; v = try sum()
                guard peek == ")" else { throw Bad() }
                i += 1
            } else {
                v = try number()
            }
            if peek == "^" { i += 1; v = pow(v, try factor()) }
            return v
        }
        mutating func product() throws -> Double {
            var v = try factor()
            while let op = peek, op == "*" || op == "/" {
                i += 1
                let r = try factor()
                v = op == "*" ? v * r : v / r
            }
            return v
        }
        mutating func sum() throws -> Double {
            var v = try product()
            while let op = peek, op == "+" || op == "-" {
                i += 1
                let r = try product()
                v = op == "+" ? v + r : v - r
            }
            return v
        }
    }

    // MARK: Parser

    public static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> ZoeIntent {
        let raw = text.trimmed
        let t = normalize(raw)
        if t.isEmpty { return .empty }

        if t.rxTest(#"^(annulla|ferma|stop|basta)\b"#) && !t.rxTest("promemoria") { return .timerCancel }
        if t.rxTest(#"^(annulla|cancella|elimina) (i |il |tutti i )?promemoria"#) { return .reminderClear }

        // Promemoria: "ricordami di X alle 18", "tra 10 minuti ricordami di X", "ricordami alle 9 di X"
        if t.rxTest(#"\bricordami\b|\bricorda(mi)? di\b|\bpromemoria\b"#) {
            var at = parseClock(t, now: now, calendar: calendar)
            if at == nil {
                let d = parseDuration(t)
                if d > 0 && t.rxTest(#"\b(tra|fra|in|dopo)\b"#) { at = now.addingTimeInterval(d) }
            }
            // Toglie le parole del "quando" dal testo originale, così il promemoria tiene le maiuscole ("chiamare Luca").
            let keep = raw.rxReplace(#"[’`]"#, with: "'").rxReplace(#"\s+"#, with: " ").rxReplace(#"[!?.]+$"#, with: "")
            let what = keep
                .rxReplace(#"\b(domani )?(alle|all|per le)\s+\d{1,2}([:.]\d{2})?(\s+e\s+(mezza|un quarto|quarto))?"#, with: " ", ci: true, all: false)
                .rxReplace(#"\b(tra|fra|in|dopo)\s+("# + NUM + #"['\s]*"# + UNIT + #"(\s+e\s+(mezz[ao]\b)?)?)+"#, with: " ", ci: true)
                .rxReplace(#"\b(tra|fra) (mezz['\s]?ora|un quarto d['\s]?ora)"#, with: " ", ci: true, all: false)
                .rxReplace(#"\b(metti un |crea un |imposta un )?promemoria( per)?\b|\bricordami\b|\bricorda di\b"#, with: " ", ci: true)
                .rxReplace(#"\bdomani\b"#, with: " ", ci: true, all: false)
                .rxReplace(#"\s+"#, with: " ").trimmed
                .rxReplace(#"^(di|che|per)\s+"#, with: "", ci: true).trimmed
            guard let when = at else { return .reminderIncomplete(text: what) }
            return .reminder(text: what.isEmpty ? "il tuo promemoria" : what, at: when)
        }

        if t.rxTest(#"\b(pomodoro|focus|concentrar(mi|si)|studiare|studio)\b"#) {
            let d = parseDuration(t)
            return .timer(seconds: d > 0 ? d : 25 * 60, label: "Focus")
        }

        let dur = parseDuration(t)
        if t.rxTest(#"\b(timer|conto alla rovescia|sveglia|avvisami|countdown)\b"#)
            || (dur > 0 && t.rxTest(#"^(\d|un|uno|una|due|tre|cinque|dieci|mezz)"#)) {
            if dur == 0 { return .timerIncomplete }
            let label = t.rxMatch(#"\bper (la |il |lo |le |i |l )?([a-z ]{3,30})$"#)?[2]?.trimmed
            return .timer(seconds: dur, label: label ?? "Timer")
        }

        if let calc = t.rxMatch(#"^(?:quanto fa|quanto e|calcola|calcolami)\s+(.+)$"#), let expr = calc[1] {
            guard let v = calculate(expr) else { return .unknown(text: raw) }
            return .calc(expr: expr, value: v)
        }
        if t.rxTest(#"^[\d\s.,+\-*/x:^%()]+$"#) && t.rxTest(#"\d\s*[+\-*/x:^]\s*\d"#), let v = calculate(t) {
            return .calc(expr: t, value: v)
        }

        if t.rxTest(#"\b(ho bevuto|bevuto|bicchier[ei]|acqua)\b"#) {
            let n = t.rxMatch(#"\b(\d+|un|uno|due|tre|quattro|cinque)\s+bicchier"#)?[1]
            return .water(delta: n.map { Int(toNumber($0)) } ?? 1)
        }
        if t.rxTest(#"\bpassword\b"#) {
            let n = t.rxMatch(#"\b(\d{1,2})\b"#)?[1].flatMap { Int($0) } ?? 16
            return .password(length: min(64, max(8, n)))
        }
        if t.rxTest(#"\bche (ore|ora) (sono|e)\b|\bche ora\b|\bche ore\b"#) { return .time }
        if t.rxTest(#"\bche giorno\b|\bche data\b|\bdata di oggi\b"#) { return .date }
        if t.rxTest(#"\b(lancia|tira)\b.*\bmoneta\b|\btesta o croce\b"#) { return .coin }
        if t.rxTest(#"\b(lancia|tira)\b.*\bdad[oi]\b"#) { return .dice }
        if t.rxTest(#"\b(barzellett[ae]|battuta|fammi ridere)\b"#) { return .joke }
        if t.rxTest(#"\b(personalizza|impostazioni|cambia colore|cambia look)\b"#) { return .settings }
        if t.rxTest(#"\b(buonanotte|vai a dormire|dormi|riposati)\b"#) { return .sleep }
        if t.rxTest(#"\b(come ti chiami|chi sei|cosa sei)\b"#) { return .whoami }
        if t.rxTest(#"\b(cosa sai fare|aiuto|help|comandi)\b"#) { return .help }
        if t.rxTest(#"\b(grazie|grazie mille|ti adoro|sei brava|brava)\b"#) { return .thanks }
        if t.rxTest(#"\b(stanc[oa]|triste|stress|ansia|giu di morale)\b"#) { return .comfort }
        if t.rxTest(#"^(ciao|ehi|hey|buongiorno|buonasera|salve|we)\b"#) { return .greet }
        return .unknown(text: raw)
    }
}
