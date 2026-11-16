#if canImport(SwiftUI)
import SwiftUI
import ZoeCore

// MARK: - Disegno della mascotte (traduzione fedele di app/src/renderer/zoe.js)
//
// Tutto è disegnato nello stesso spazio della versione desktop: viewBox "0 -12 120 112".

struct MascotLayer {
    enum Paint {
        case fill(Color, Double)
        case stroke(Color, CGFloat, Double, CGLineCap)
    }
    enum Role: Equatable {
        case plain
        case eye(Int)    // bianco dell'occhio: sbatte le palpebre
        case pupil(Int)  // pupilla: sbatte e segue lo sguardo
        case antenna     // lucina che pulsa
    }
    var path: Path
    var paint: Paint
    var role: Role = .plain
}

enum MascotRenderer {
    static let width: CGFloat = 120, height: CGFloat = 112, top: CGFloat = -12
    static let eyeCenters = [CGPoint(x: 45, y: 52), CGPoint(x: 75, y: 52)]
    static let dark = ZoePalette.dark

    enum EyeMode { case open, laugh, big, half, closed, heart, wink, star }
    enum Mouth { case path(String), fill, o }
    enum Brows { case angry, sad, think }

    struct Spec {
        var eyes: EyeMode
        var mouth: Mouth
        var cheeks = false
        var brows: Brows? = nil
        var look: CGSize? = nil
        var zzz = false
    }

    static func spec(_ e: ZoeExpression) -> Spec {
        switch e {
        case .felice:     return Spec(eyes: .open, mouth: .path("M50 72 Q60 82 70 72"), cheeks: true)
        case .contenta:   return Spec(eyes: .open, mouth: .path("M53 73 Q60 77 67 73"))
        case .ride:       return Spec(eyes: .laugh, mouth: .fill, cheeks: true)
        case .sorpresa:   return Spec(eyes: .big, mouth: .o)
        case .assonnata:  return Spec(eyes: .half, mouth: .path("M55 76 Q60 74 65 76"))
        case .dorme:      return Spec(eyes: .closed, mouth: .path("M56 76 Q60 78 64 76"), zzz: true)
        case .arrabbiata: return Spec(eyes: .open, mouth: .path("M50 79 Q60 70 70 79"), brows: .angry)
        case .triste:     return Spec(eyes: .open, mouth: .path("M51 79 Q60 71 69 79"), brows: .sad)
        case .innamorata: return Spec(eyes: .heart, mouth: .path("M52 72 Q60 80 68 72"), cheeks: true)
        case .pensierosa: return Spec(eyes: .open, mouth: .path("M53 76 L67 74"), brows: .think, look: CGSize(width: -3, height: -3))
        case .occhiolino: return Spec(eyes: .wink, mouth: .path("M50 72 Q60 81 70 72"), cheeks: true)
        case .emozionata: return Spec(eyes: .star, mouth: .fill, cheeks: true)
        case .confusa:    return Spec(eyes: .open, mouth: .path("M52 76 Q56 73 60 76 Q64 79 68 76"), brows: .think)
        }
    }

    static func eyeSize(_ s: EyeStyle) -> (CGFloat, CGFloat) {
        switch s {
        case .tondi, .stelle: return (9, 11)
        case .grandi: return (11, 13.5)
        case .piccoli: return (6.5, 7.5)
        case .anime: return (10, 13)
        }
    }

    // MARK: Forme di base

    static func p(_ d: String) -> Path { SVGPath.parse(d) }
    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }
    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path { ellipse(cx, cy, r, r) }
    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat = 0) -> Path {
        r > 0 ? Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .circular)
              : Path(CGRect(x: x, y: y, width: w, height: h))
    }
    static func polygon(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        path.addLines(pts.map { CGPoint(x: $0.0, y: $0.1) })
        path.closeSubpath()
        return path
    }
    static func heart(_ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: cx, y: cy + s * 0.9))
        path.addCurve(to: CGPoint(x: cx, y: cy - s * 0.4),
                      control1: CGPoint(x: cx - s * 1.6, y: cy - s * 0.1),
                      control2: CGPoint(x: cx - s * 0.9, y: cy - s * 1.3))
        path.addCurve(to: CGPoint(x: cx, y: cy + s * 0.9),
                      control1: CGPoint(x: cx + s * 0.9, y: cy - s * 1.3),
                      control2: CGPoint(x: cx + s * 1.6, y: cy - s * 0.1))
        path.closeSubpath()
        return path
    }
    static func star(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        polygon((0..<10).map { i in
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rr = i % 2 == 1 ? r * 0.45 : r
            return (cx + cos(a) * rr, cy + sin(a) * rr)
        })
    }

    static func fill(_ path: Path, _ hex: String, _ opacity: Double = 1, _ role: MascotLayer.Role = .plain) -> MascotLayer {
        MascotLayer(path: path, paint: .fill(Color(hex: hex), opacity), role: role)
    }
    static func stroke(_ path: Path, _ hex: String, _ w: CGFloat, opacity: Double = 1, cap: CGLineCap = .round) -> MascotLayer {
        MascotLayer(path: path, paint: .stroke(Color(hex: hex), w, opacity, cap))
    }

    // MARK: Occhi

    static func eye(_ idx: Int, mode: EyeMode, style: EyeStyle, color: String) -> [MascotLayer] {
        let cx = eyeCenters[idx].x, cy = eyeCenters[idx].y
        var (rx, ry) = eyeSize(style)
        if mode == .big { rx *= 1.15; ry *= 1.2 }
        switch mode {
        case .closed:
            return [stroke(p("M\(cx - rx) \(cy) Q\(cx) \(cy + 6) \(cx + rx) \(cy)"), dark, 3)]
        case .laugh:
            return [stroke(p("M\(cx - rx) \(cy + 3) Q\(cx) \(cy - 7) \(cx + rx) \(cy + 3)"), dark, 3)]
        case .wink where idx == 1:
            return [stroke(p("M\(cx - rx) \(cy + 3) Q\(cx) \(cy - 7) \(cx + rx) \(cy + 3)"), dark, 3)]
        case .heart:
            return [fill(heart(cx, cy, rx * 0.85), "#ff4d8d")]
        default:
            break
        }
        let pr = style == .piccoli ? rx * 0.7 : rx * 0.55
        var out = [fill(ellipse(cx, cy, rx, ry), "#ffffff", 1, .eye(idx))]
        if mode == .star || style == .stelle {
            out.append(fill(star(cx, cy, pr * 1.3), "#ffc93c", 1, .pupil(idx)))
        } else {
            out.append(fill(circle(cx, cy, pr), dark, 1, .pupil(idx)))
            out.append(fill(circle(cx - pr * 0.4, cy - pr * 0.5, pr * 0.35), "#ffffff", 1, .pupil(idx)))
            if style == .anime { out.append(fill(circle(cx + pr * 0.4, cy + pr * 0.4, pr * 0.18), "#ffffff", 1, .pupil(idx))) }
        }
        if mode == .half {
            out.append(fill(rect(cx - rx - 2, cy - ry - 2, rx * 2 + 4, ry + 2), color))
            out.append(stroke(p("M\(cx - rx) \(cy) H\(cx + rx)"), dark, 3))
        }
        return out
    }

    // MARK: Accessori

    static func accessory(_ a: ZoeAccessory, color: String) -> [MascotLayer] {
        switch a {
        case .nessuno:
            return []
        case .cappellino:
            return [fill(p("M30 30 Q34 4 60 4 Q86 4 90 30 Z"), "#ffb547"),
                    fill(p("M60 26 H100 Q104 30 98 32 H60 Z"), "#e8962a"),
                    fill(circle(60, 5, 4), "#e8962a")]
        case .cilindro:
            return [fill(rect(44, -10, 32, 30, 3), "#22223a"),
                    fill(rect(44, 12, 32, 5), "#ff5d9e"),
                    fill(rect(34, 18, 52, 6, 3), "#22223a")]
        case .corona:
            let crown = polygon([(42, 26), (42, 8), (51, 17), (60, 3), (69, 17), (78, 8), (78, 26)])
            return [fill(crown, "#ffc93c"), stroke(crown, "#e0a400", 2), fill(circle(60, 18, 3), "#ff5d9e")]
        case .fiocco:
            let t = CGAffineTransform(translationX: 84, y: 24).rotated(by: .pi * 15 / 180)
            let bow = p("M0 0 L-14 -9 L-14 9 Z M0 0 L14 -9 L14 9 Z").applying(t)
            return [fill(bow, "#ff5d9e"), stroke(bow, "#e03c80", 2), fill(circle(0, 0, 4).applying(t), "#e03c80")]
        case .occhiali:
            return [stroke(circle(45, 52, 14), dark, 3, cap: .butt),
                    stroke(circle(75, 52, 14), dark, 3, cap: .butt),
                    stroke(p("M59 50 Q60 47 61 50"), dark, 3, cap: .butt),
                    stroke(p("M31 50 L18 46 M89 50 L102 46"), dark, 3, cap: .butt)]
        case .occhialiDaSole:
            return [fill(rect(29, 42, 30, 20, 8), "#111111"),
                    fill(rect(61, 42, 30, 20, 8), "#111111"),
                    stroke(p("M59 48 H61"), "#111111", 4, cap: .butt),
                    stroke(p("M34 47 l8 0 M66 47 l8 0"), "#ffffff", 3, opacity: 0.5)]
        case .cuffie:
            return [stroke(p("M20 54 Q18 6 60 6 Q102 6 100 54"), "#2f2f3a", 7),
                    fill(rect(9, 44, 15, 26, 7), "#2f2f3a"), fill(rect(96, 44, 15, 26, 7), "#2f2f3a"),
                    fill(rect(12, 49, 9, 16, 4), "#3ee0b0"), fill(rect(99, 49, 9, 16, 4), "#3ee0b0")]
        case .sciarpa:
            return [fill(rect(22, 80, 76, 12, 6), "#ff5a5a"),
                    fill(p("M78 86 L86 102 L96 100 L90 86 Z"), "#e04444"),
                    stroke(p("M30 83 v6 M40 83 v6 M50 83 v6"), "#ffffff", 3, opacity: 0.35, cap: .butt)]
        case .fiore:
            var out: [MascotLayer] = (0..<5).map { i in
                let a = CGFloat(i) * 72 * .pi / 180
                return fill(circle(84 + cos(a) * 6, 22 + sin(a) * 6, 5), "#ffffff")
            }
            out.append(fill(circle(84, 22, 4), "#ffc93c"))
            return out
        case .antenna:
            return [stroke(p("M60 20 Q58 10 62 2"), ZoePalette.shade(color, -40), 3, cap: .butt),
                    fill(circle(62, 0, 5), "#3ee0b0", 1, .antenna)]
        case .papillon:
            let t = CGAffineTransform(translationX: 60, y: 88)
            let bow = p("M0 0 L-13 -8 L-13 8 Z M0 0 L13 -8 L13 8 Z").applying(t)
            return [fill(bow, "#ff5d9e"), stroke(bow, "#c93578", 2), fill(circle(60, 88, 3.5), "#c93578")]
        }
    }

    // MARK: Tutto il personaggio

    static func layers(color c: String, eyes: EyeStyle, accessory acc: ZoeAccessory, expression: ZoeExpression) -> [MascotLayer] {
        let e = spec(expression)
        let behind = acc == .cuffie
        var o: [MascotLayer] = []
        o.append(fill(ellipse(60, 96, 34, 4), "#000000", 0.25))
        o.append(fill(ellipse(42, 91, 11, 6), ZoePalette.shade(c, -40)))
        o.append(fill(ellipse(78, 91, 11, 6), ZoePalette.shade(c, -40)))
        if behind { o += accessory(acc, color: c) }
        o.append(fill(rect(15, 20, 90, 72, 36), c))
        o.append(fill(ellipse(44, 32, 20, 9), "#ffffff", 0.16))
        if e.cheeks {
            o.append(fill(ellipse(31, 66, 7, 4), "#ff7aa8", 0.55))
            o.append(fill(ellipse(89, 66, 7, 4), "#ff7aa8", 0.55))
        }
        o += eye(0, mode: e.eyes, style: eyes, color: c)
        o += eye(1, mode: e.eyes, style: eyes, color: c)
        switch e.brows {
        case .angry: o.append(stroke(p("M34 36 L52 42 M86 36 L68 42"), dark, 3))
        case .sad:   o.append(stroke(p("M35 42 L52 36 M85 42 L68 36"), dark, 3))
        case .think: o.append(stroke(p("M36 38 L52 38 M68 36 Q76 30 85 35"), dark, 3))
        case nil:    break
        }
        switch e.mouth {
        case .fill:
            o.append(fill(p("M48 70 Q60 88 72 70 Z"), dark))
            o.append(fill(p("M54 79 Q60 84 66 79 Q60 76 54 79Z"), "#ff6b8b"))
        case .o:
            o.append(fill(ellipse(60, 76, 5, 6.5), dark))
        case .path(let d):
            o.append(stroke(p(d), dark, 3))
        }
        if !behind { o += accessory(acc, color: c) }
        return o
    }
}

/// Una forma disegnata nello spazio 120×112 della mascotte, scalata alla dimensione della vista.
struct DesignShape: Shape {
    var path: Path
    func path(in rect: CGRect) -> Path {
        let s = rect.width / MascotRenderer.width
        return path.applying(CGAffineTransform(scaleX: s, y: s).translatedBy(x: 0, y: -MascotRenderer.top))
    }
}

// MARK: - Vista pubblica

/// ZOE, la mascotte. Usala ovunque: app, widget, Dynamic Island.
///
///     ZoeMascotView(settings: store.settings, expression: .ride)
///         .frame(width: 140)
public struct ZoeMascotView: View {
    var color: String
    var eyes: EyeStyle
    var accessory: ZoeAccessory
    var expression: ZoeExpression
    /// Dove guardano le pupille, in unità della mascotte (massimo circa ±3.6).
    var look: CGSize
    /// Sbattere di palpebre, "z" che salgono e antenna che pulsa. Disattivalo nei widget.
    var animated: Bool

    public init(color: String = ZoePalette.colors[0], eyes: EyeStyle = .tondi, accessory: ZoeAccessory = .nessuno,
                expression: ZoeExpression = .felice, look: CGSize = .zero, animated: Bool = true) {
        self.color = color; self.eyes = eyes; self.accessory = accessory
        self.expression = expression; self.look = look; self.animated = animated
    }

    public init(settings: ZoeSettings, expression: ZoeExpression = .felice, look: CGSize = .zero,
                animated: Bool = true, showsAccessory: Bool = true) {
        self.init(color: settings.color, eyes: settings.eyes, accessory: showsAccessory ? settings.accessory : .nessuno,
                  expression: expression, look: look, animated: animated)
    }

    public var body: some View {
        let layers = MascotRenderer.layers(color: color, eyes: eyes, accessory: accessory, expression: expression)
        let spec = MascotRenderer.spec(expression)
        let gaze = spec.look ?? look
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: false)) { ctx in
                    canvas(layers, spec: spec, gaze: gaze, time: ctx.date.timeIntervalSinceReferenceDate)
                }
            } else {
                canvas(layers, spec: spec, gaze: gaze, time: nil)
            }
        }
        .aspectRatio(MascotRenderer.width / MascotRenderer.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("ZOE, \(expression.rawValue)"))
    }

    private func canvas(_ layers: [MascotLayer], spec: MascotRenderer.Spec, gaze: CGSize, time: Double?) -> some View {
        GeometryReader { geo in
            let s = geo.size.width / MascotRenderer.width
            ZStack(alignment: .topLeading) {
                ForEach(layers.indices, id: \.self) { i in
                    layerView(layers[i], scale: s, gaze: gaze, time: time)
                }
                if spec.zzz { zzz(scale: s, time: time) }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private func layerView(_ l: MascotLayer, scale s: CGFloat, gaze: CGSize, time: Double?) -> AnyView {
        let shape = DesignShape(path: l.path)
        var v: AnyView
        switch l.paint {
        case .fill(let c, let o):
            v = AnyView(shape.fill(c).opacity(o))
        case .stroke(let c, let w, let o, let cap):
            v = AnyView(shape.stroke(c, style: StrokeStyle(lineWidth: w * s, lineCap: cap, lineJoin: .round)).opacity(o))
        }
        switch l.role {
        case .plain:
            return v
        case .eye(let idx):
            return AnyView(v.scaleEffect(x: 1, y: blink(time, idx), anchor: anchor(idx)))
        case .pupil(let idx):
            return AnyView(v.offset(x: gaze.width * s, y: gaze.height * s)
                .scaleEffect(x: 1, y: blink(time, idx), anchor: anchor(idx)))
        case .antenna:
            guard let t = time else { return v }
            let phase = t.truncatingRemainder(dividingBy: 1.6) / 1.6
            return AnyView(v.opacity(1 - 0.6 * sin(phase * .pi)))
        }
    }

    private func anchor(_ idx: Int) -> UnitPoint {
        let c = MascotRenderer.eyeCenters[idx]
        return UnitPoint(x: c.x / MascotRenderer.width, y: (c.y - MascotRenderer.top) / MascotRenderer.height)
    }

    /// Ogni 5 secondi un battito di ciglia rapidissimo (come l'animazione CSS "blink").
    private func blink(_ time: Double?, _ idx: Int) -> CGFloat {
        guard let t = time else { return 1 }
        let local = t - (idx == 1 ? 0.05 : 0)
        let p = (local.truncatingRemainder(dividingBy: 5) + 5).truncatingRemainder(dividingBy: 5) / 5
        if p < 0.94 { return 1 }
        if p < 0.96 { return 1 - CGFloat((p - 0.94) / 0.02) * 0.92 }
        return 0.08 + CGFloat((p - 0.96) / 0.04) * 0.92
    }

    @ViewBuilder
    private func zzz(scale s: CGFloat, time: Double?) -> some View {
        let tint = Color(hex: "#eef0ff")
        // Due "z" che salgono e svaniscono, la seconda in ritardo di un secondo.
        let p1 = time.map { $0.truncatingRemainder(dividingBy: 2) / 2 } ?? 0.125
        let p2 = time.map { (($0 + 1).truncatingRemainder(dividingBy: 2)) / 2 } ?? 0.22
        let y1 = 24 - 16 * p1, y2 = 14 - 18 * p2
        Text("z").font(.system(size: 14 * s, weight: .bold)).foregroundStyle(tint)
            .opacity(time == nil ? 1 : 1 - p1)
            .position(x: 98 * s, y: (y1 - MascotRenderer.top - 5) * s)
        Text("z").font(.system(size: 10 * s, weight: .bold)).foregroundStyle(tint)
            .opacity(time == nil ? 1 : 1 - p2)
            .position(x: 105 * s, y: (y2 - MascotRenderer.top - 3.5) * s)
    }
}

#Preview("Espressioni") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))]) {
            ForEach(ZoeExpression.allCases, id: \.self) { e in
                VStack {
                    ZoeMascotView(expression: e).frame(width: 80)
                    Text(e.rawValue).font(.caption).foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
    .background(Color(hex: "#0a0b16"))
}
#endif
