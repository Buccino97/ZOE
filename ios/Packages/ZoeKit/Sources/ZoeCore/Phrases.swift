import Foundation

/// Le frasi di ZOE: la stessa personalità della versione desktop.
public enum ZoePhrases {
    public static let jokes = [
        "Perché il computer è andato dal dottore? Aveva un virus… ma non voleva fare il backup!",
        "Sai qual è il colmo per un'assistente digitale? Perdere il filo del discorso… senza Wi-Fi!",
        "Ho provato a contare le stelle, ma alla terza sono andata in risparmio energetico.",
        "Il mio schermo preferito? Quello touch: mi fa sempre il solletico. 😄",
    ]
    public static let thanks = ["Figurati! 💜", "Quando vuoi!", "Per te questo e altro."]
    public static let wakeUp = ["Eh? Ero sveglia, giuro!", "Mi ero solo appisolata un attimo…", "Eccomi!"]
    public static let tickled = ["Ehi, mi fai il solletico! 😆", "Sono qui!", "Che si fa?"]

    public static let help = "So fare timer e focus, promemoria, contare l'acqua, calcoli, password, testa o croce e barzellette. Puoi anche chiedermelo con Siri: «Parla con ZOE». L'IA arriva presto!"
    public static let comfort = "Fai una pausa di 5 minuti: alzati, bevi un po' d'acqua e guarda lontano dallo schermo. Io resto qui 💜"
    public static let unknown = "Non ho capito… L'IA arriva nella prossima versione! Intanto prova «cosa sai fare»."
    public static let waterNudge = "Un bicchiere d'acqua? 💧 Dimmi «ho bevuto» quando hai fatto."

    public static func whoami(_ name: String) -> String {
        "Sono \(name), la tua amica in cima allo schermo… e ora anche in tasca!"
    }

    /// Risposta dopo aver segnato l'acqua (`count` è il totale di oggi).
    public static func water<R: RandomNumberGenerator>(count: Int, using rng: inout R) -> String {
        if count == WaterLog.goal { return "\(WaterLog.goal) bicchieri! Obiettivo di oggi raggiunto 🎉" }
        if count > WaterLog.goal { return "Wow, \(count) bicchieri. Idratazione livello pro 💧" }
        return ["Glu glu! 💧", "Brava/o! Ancora \(WaterLog.goal - count) e ci siamo.", "Segnato: \(count) su \(WaterLog.goal)."]
            .randomElement(using: &rng)!
    }
    public static func water(count: Int) -> String {
        var g = SystemRandomNumberGenerator()
        return water(count: count, using: &g)
    }

    /// Password robusta. Il generatore di sistema è crittograficamente sicuro.
    public static func password(length: Int) -> String {
        let cs = Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*?")
        var g = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in cs.randomElement(using: &g)! })
    }
}

/// Quando mandare i promemoria per l'acqua: ogni ora dall'ultimo bicchiere, solo tra le 9 e le 22,
/// e non più per oggi se hai già raggiunto l'obiettivo. Funzione pura, usata per le notifiche locali.
public enum ZoeWellness {
    public static let startHour = 9, endHour = 22

    public static func waterNudges(lastWater: Date?, countToday: Int, now: Date, max: Int = 16,
                                   calendar: Calendar = .current) -> [Date] {
        var t = (lastWater.map { $0 > now ? now : $0 } ?? now).addingTimeInterval(3600)
        if t <= now { t = now.addingTimeInterval(3600) }
        let limit = now.addingTimeInterval(48 * 3600)
        var out: [Date] = []
        while out.count < max && t < limit {
            let h = calendar.component(.hour, from: t)
            let today = calendar.isDate(t, inSameDayAs: now)
            if h >= startHour && h < endHour && !(today && countToday >= WaterLog.goal) { out.append(t) }
            t = t.addingTimeInterval(3600)
        }
        return out
    }
}
