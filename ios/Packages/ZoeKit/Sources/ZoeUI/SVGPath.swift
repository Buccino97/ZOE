#if canImport(SwiftUI)
import SwiftUI

/// Converte un percorso SVG ("M50 72 Q60 82 70 72") in un `Path` di SwiftUI.
/// Supporta i comandi usati dalla mascotte: M L H V Q C Z (assoluti) e m l h v (relativi).
enum SVGPath {
    private enum Token { case cmd(Character), num(CGFloat) }

    static func parse(_ d: String) -> Path {
        let tokens = tokenize(d)
        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero

        func num() -> CGFloat {
            guard i < tokens.count, case .num(let v) = tokens[i] else { return 0 }
            i += 1
            return v
        }
        func point() -> CGPoint { let x = num(); return CGPoint(x: x, y: num()) }

        while i < tokens.count {
            if case .cmd(let c) = tokens[i] { cmd = c; i += 1 }
            switch cmd {
            case "M": cur = point(); start = cur; path.move(to: cur); cmd = "L"
            case "m": let p = point(); cur = CGPoint(x: cur.x + p.x, y: cur.y + p.y); start = cur; path.move(to: cur); cmd = "l"
            case "L": cur = point(); path.addLine(to: cur)
            case "l": let p = point(); cur = CGPoint(x: cur.x + p.x, y: cur.y + p.y); path.addLine(to: cur)
            case "H": cur.x = num(); path.addLine(to: cur)
            case "h": cur.x += num(); path.addLine(to: cur)
            case "V": cur.y = num(); path.addLine(to: cur)
            case "v": cur.y += num(); path.addLine(to: cur)
            case "Q": let c1 = point(); cur = point(); path.addQuadCurve(to: cur, control: c1)
            case "C": let c1 = point(), c2 = point(); cur = point(); path.addCurve(to: cur, control1: c1, control2: c2)
            case "Z", "z":
                path.closeSubpath(); cur = start
                if i < tokens.count, case .num = tokens[i] { i += 1 } // numero fuori posto: lo salta
            default: i += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        let chars = Array(d)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if "MmLlHhVvQqCcZz".contains(c) { out.append(.cmd(c)); i += 1; continue }
            if c.isNumber || c == "-" || c == "+" || c == "." {
                var j = i + 1
                var seenDot = c == "."
                while j < chars.count {
                    let n = chars[j]
                    if n.isNumber { j += 1 }
                    else if n == "." && !seenDot { seenDot = true; j += 1 }
                    else { break }
                }
                out.append(.num(CGFloat(Double(String(chars[i..<j])) ?? 0)))
                i = j
                continue
            }
            i += 1 // spazi e virgole
        }
        return out
    }
}

public extension Color {
    /// Colore da stringa esadecimale "#7c5cff".
    init(hex: String) {
        let n = Int(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((n >> 16) & 255) / 255,
                  green: Double((n >> 8) & 255) / 255,
                  blue: Double(n & 255) / 255,
                  opacity: 1)
    }
}
#endif
