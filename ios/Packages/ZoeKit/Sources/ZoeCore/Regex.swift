import Foundation

/// Piccoli aiuti per usare le espressioni regolari (NSRegularExpression) con la stessa
/// sintassi della versione JavaScript di ZOE, così il parser resta una traduzione fedele.
enum Rx {
    static func make(_ pattern: String, ci: Bool = false) -> NSRegularExpression {
        // I pattern sono costanti scritte da noi: se uno è sbagliato è un bug da scoprire subito nei test.
        try! NSRegularExpression(pattern: pattern, options: ci ? [.caseInsensitive] : [])
    }
}

extension String {
    var fullRange: NSRange { NSRange(startIndex..<endIndex, in: self) }

    /// Come `regex.test(str)` in JavaScript.
    func rxTest(_ pattern: String, ci: Bool = false) -> Bool {
        Rx.make(pattern, ci: ci).firstMatch(in: self, range: fullRange) != nil
    }

    /// Come `str.match(regex)` senza flag `g`: [intera corrispondenza, gruppo 1, gruppo 2, …] oppure nil.
    /// I gruppi che non hanno partecipato valgono nil.
    func rxMatch(_ pattern: String, ci: Bool = false) -> [String?]? {
        guard let m = Rx.make(pattern, ci: ci).firstMatch(in: self, range: fullRange) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            guard r.location != NSNotFound, let rr = Range(r, in: self) else { return nil }
            return String(self[rr])
        }
    }

    /// Tutte le corrispondenze (come un ciclo `exec` con flag `g`), ognuna con i suoi gruppi.
    func rxMatches(_ pattern: String, ci: Bool = false) -> [[String?]] {
        Rx.make(pattern, ci: ci).matches(in: self, range: fullRange).map { m in
            (0..<m.numberOfRanges).map { i in
                let r = m.range(at: i)
                guard r.location != NSNotFound, let rr = Range(r, in: self) else { return nil }
                return String(self[rr])
            }
        }
    }

    /// Come `str.replace(regex, template)`: `all` corrisponde al flag `g`. Il modello usa `$1`, `$2`…
    func rxReplace(_ pattern: String, with template: String, ci: Bool = false, all: Bool = true) -> String {
        let re = Rx.make(pattern, ci: ci)
        if all {
            return re.stringByReplacingMatches(in: self, range: fullRange, withTemplate: template)
        }
        guard let m = re.firstMatch(in: self, range: fullRange), let r = Range(m.range, in: self) else { return self }
        let replacement = re.replacementString(for: m, in: self, offset: 0, template: template)
        return replacingCharacters(in: r, with: replacement)
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
