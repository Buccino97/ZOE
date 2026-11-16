import AppIntents
import SwiftUI
import WidgetKit
import ZoeCore
import ZoeShared
import ZoeUI

// MARK: - Dati del widget

struct ZoeEntry: TimelineEntry {
    let date: Date
    let snap: ZoeSnapshot
}

struct ZoeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZoeEntry {
        ZoeEntry(date: Date(), snap: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZoeEntry) -> Void) {
        completion(ZoeEntry(date: Date(), snap: context.isPreview ? .sample : ZoeStorage.snapshot()))
    }

    /// Prepara in anticipo come apparirà il widget nelle prossime ore:
    /// quando finisce il timer, quando scatta un promemoria, e ogni ora (ZOE si addormenta alle 23).
    func getTimeline(in context: Context, completion: @escaping (Timeline<ZoeEntry>) -> Void) {
        let now = Date()
        let raw = ZoeSnapshot(settings: ZoeStorage.settings, water: ZoeStorage.water,
                              reminders: ZoeStorage.reminders, timer: ZoeStorage.timer)
        var dates: Set<Date> = [now]
        if let t = raw.timer, t.end > now { dates.insert(t.end) }
        for r in raw.reminders where r.at > now {
            dates.insert(r.at)
            let soon = r.at.addingTimeInterval(-15 * 60)
            if soon > now { dates.insert(soon) }
        }
        var hour = now
        for _ in 0..<12 {
            guard let next = Calendar.current.nextDate(after: hour, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) else { break }
            dates.insert(next)
            hour = next
        }
        let entries = dates.filter { $0 <= now.addingTimeInterval(12 * 3600) }.sorted().map { ZoeEntry(date: $0, snap: raw.at($0)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Aspetto

private enum W {
    static let bg = Color(hex: "#0a0b16")
    static let bg2 = Color(hex: "#1a1e35")
    static let text = Color(hex: "#eef0ff")
    static let muted = Color(hex: "#9aa0c3")
    static let mint = Color(hex: "#3ee0b0")
    static let water = Color(hex: "#6cc8ff")
}

struct ZoeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ZoeEntry

    private var snap: ZoeSnapshot { entry.snap }
    private var mood: ZoeExpression { snap.expression(at: entry.date) }
    private var mascot: some View {
        ZoeMascotView(settings: snap.settings, expression: mood, animated: false)
    }

    var body: some View {
        content.containerBackground(for: .widget) {
            if isAccessory { Color.clear } else { LinearGradient(colors: [W.bg2, W.bg], startPoint: .top, endPoint: .bottom) }
        }
    }

    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // Home, piccolo: ZOE, l'acqua con il pulsante +1 e la cosa più importante.
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                mascot.frame(width: 64)
                Spacer(minLength: 0)
                waterButton
            }
            Spacer(minLength: 0)
            Text("💧 \(snap.water.count)/\(WaterLog.goal)")
                .font(.headline.monospacedDigit()).foregroundStyle(W.text)
            statusLine.font(.caption).lineLimit(2)
        }
    }

    // Home, medio: ZOE grande a sinistra, i dettagli a destra.
    private var medium: some View {
        HStack(spacing: 14) {
            mascot.frame(width: 110)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(snap.settings.name).font(.headline).foregroundStyle(W.text)
                    Spacer(minLength: 0)
                    waterButton
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("💧 \(snap.water.count) su \(WaterLog.goal) bicchieri").font(.subheadline.monospacedDigit()).foregroundStyle(W.text)
                    ProgressView(value: Double(min(snap.water.count, WaterLog.goal)), total: Double(WaterLog.goal)).tint(W.water)
                }
                if let t = snap.timer {
                    HStack(spacing: 4) {
                        Text(t.isFocus ? "🎯" : "⏱")
                        Text(timerInterval: t.start...t.end, countsDown: true).monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(W.mint)
                }
                if let r = snap.nextReminder {
                    Text("📌 \(r.text) · \(ZoeFormat.hhmm(r.at))").font(.caption).foregroundStyle(W.muted).lineLimit(1)
                } else if snap.timer == nil {
                    statusLine.font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let t = snap.timer {
            HStack(spacing: 4) {
                Text(t.isFocus ? "🎯" : "⏱")
                Text(timerInterval: t.start...t.end, countsDown: true).monospacedDigit()
            }
            .foregroundStyle(W.mint)
        } else if let r = snap.nextReminder {
            Text("📌 \(r.text) · \(ZoeFormat.hhmm(r.at))").foregroundStyle(W.muted)
        } else {
            Text(mood == .dorme ? "Zzz… buonanotte" : "Tocca per parlarmi").foregroundStyle(W.muted)
        }
    }

    private var waterButton: some View {
        Button(intent: AddWaterIntent()) {
            Image(systemName: "drop.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(W.bg)
                .frame(width: 32, height: 32)
                .background(W.water, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ho bevuto un bicchiere")
    }

    // Schermata di blocco
    private var circular: some View {
        Gauge(value: Double(min(snap.water.count, WaterLog.goal)), in: 0...Double(WaterLog.goal)) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(snap.water.count)")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            mascot.frame(width: 38)
            VStack(alignment: .leading, spacing: 1) {
                if let t = snap.timer {
                    Text(t.isFocus ? "Focus" : t.label).font(.headline)
                    Text(timerInterval: t.start...t.end, countsDown: true).monospacedDigit()
                } else if let r = snap.nextReminder {
                    Text(r.text).font(.headline).lineLimit(1)
                    Text(ZoeFormat.when(r.at, now: entry.date)).font(.caption)
                } else {
                    Text(snap.settings.name).font(.headline)
                    Text("💧 \(snap.water.count)/\(WaterLog.goal) bicchieri").font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let t = snap.timer {
            Text("⏱ ") + Text(timerInterval: t.start...t.end, countsDown: true)
        } else if let r = snap.nextReminder {
            Text("📌 \(ZoeFormat.hhmm(r.at)) \(r.text)")
        } else {
            Text("💧 \(snap.water.count)/\(WaterLog.goal) · \(snap.settings.name)")
        }
    }
}

struct ZoeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZoeWidget", provider: ZoeProvider()) { entry in
            ZoeWidgetView(entry: entry)
        }
        .configurationDisplayName("ZOE")
        .description("ZOE con l'acqua di oggi, il timer e il prossimo promemoria.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemMedium) {
    ZoeWidget()
} timeline: {
    ZoeEntry(date: .now, snap: .sample)
}
