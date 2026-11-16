#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import ZoeCore

/// I dati della Live Activity del timer: ZOE nella Dynamic Island e nella schermata di blocco.
public struct ZoeTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var start: Date
        public var end: Date
        public var label: String
        public var expression: String
        public var finished: Bool

        public init(start: Date, end: Date, label: String, expression: String, finished: Bool = false) {
            self.start = start; self.end = end; self.label = label; self.expression = expression; self.finished = finished
        }
        public var mood: ZoeExpression { ZoeExpression(rawValue: expression) ?? .felice }
    }

    public var name: String
    public var color: String
    public var eyes: String
    public var accessory: String

    public init(settings: ZoeSettings) {
        name = settings.name; color = settings.color; eyes = settings.eyes.rawValue; accessory = settings.accessory.rawValue
    }

    /// Le impostazioni della mascotte al momento dell'avvio.
    public var settings: ZoeSettings {
        var s = ZoeSettings()
        s.name = name; s.color = color
        s.eyes = EyeStyle(rawValue: eyes) ?? .tondi
        s.accessory = ZoeAccessory(rawValue: accessory) ?? .nessuno
        return s
    }
}

public enum ZoeLiveActivities {
    public static var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Avvia (o sostituisce) la Live Activity per il timer.
    public static func start(_ timer: TimerState, settings: ZoeSettings) async {
        await endAll()
        guard enabled else { return }
        let state = ZoeTimerAttributes.ContentState(
            start: timer.start, end: timer.end, label: timer.label,
            expression: (timer.isFocus ? ZoeExpression.pensierosa : .occhiolino).rawValue)
        do {
            _ = try Activity.request(attributes: ZoeTimerAttributes(settings: settings),
                                     content: ActivityContent(state: state, staleDate: timer.end),
                                     pushType: nil)
        } catch {
            print("ZOE: Live Activity non avviata:", error)
        }
    }

    /// Il timer è finito: ZOE festeggia per qualche minuto, poi la Live Activity sparisce.
    public static func finishAll() async {
        for activity in Activity<ZoeTimerAttributes>.activities {
            var s = activity.content.state
            s.finished = true
            s.expression = ZoeExpression.emozionata.rawValue
            await activity.end(ActivityContent(state: s, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(5 * 60)))
        }
    }

    public static func endAll() async {
        for activity in Activity<ZoeTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Chiude le Live Activity rimaste aperte di timer già scaduti (es. se l'app era chiusa).
    public static func cleanUp(now: Date = Date()) async {
        for activity in Activity<ZoeTimerAttributes>.activities where activity.content.state.end <= now && !activity.content.state.finished {
            var s = activity.content.state
            s.finished = true
            s.expression = ZoeExpression.emozionata.rawValue
            await activity.end(ActivityContent(state: s, staleDate: nil), dismissalPolicy: .after(s.end.addingTimeInterval(5 * 60)))
        }
    }
}
#endif
