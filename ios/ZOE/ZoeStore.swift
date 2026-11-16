import SwiftUI
import UIKit
import WidgetKit
import ZoeCore
import ZoeShared

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let fromUser: Bool
    let text: String
}

/// Il "cervello" dell'app: umore della mascotte, chat, timer, promemoria, acqua.
/// È la traduzione per iPhone di app/src/renderer/renderer.js. Lo usano sia la chat sia Siri.
@MainActor
final class ZoeStore: ObservableObject {
    static let shared = ZoeStore()

    @Published var settings: ZoeSettings {
        didSet {
            guard settings != oldValue else { return }
            ZoeStorage.settings = settings
            if settings.wellness != oldValue.wellness { ZoeNotifier.rescheduleWater(water, enabled: settings.wellness) }
            reloadWidgets()
        }
    }
    @Published private(set) var water: WaterLog
    @Published private(set) var reminders: [Reminder]
    @Published private(set) var timer: TimerState?
    @Published private(set) var messages: [ChatMessage] = []
    /// L'ultima cosa detta da ZOE, mostrata nella nuvoletta sopra la mascotte.
    @Published private(set) var bubble = ""
    @Published private(set) var mood: ZoeExpression = .felice
    @Published private(set) var sleeping = false
    /// Cambia ogni volta che ZOE deve fare un saltello.
    @Published private(set) var hop = 0
    @Published var showSettings = false
    @Published private(set) var notificationsAllowed = true

    var expression: ZoeExpression { sleeping ? .dorme : mood }
    var name: String { settings.name.trimmingCharacters(in: .whitespaces).isEmpty ? "ZOE" : settings.name }

    static let sleepAfter: TimeInterval = 3 * 60

    private var moodTask: Task<Void, Never>?
    private var lastActivity = Date()
    private var lastNudge = Date()
    private var observer: NSObjectProtocol?

    private init() {
        settings = ZoeStorage.settings
        water = ZoeStorage.water
        reminders = ZoeStorage.reminders
        timer = ZoeStorage.timer
        // Un widget o Siri hanno cambiato i dati: rileggili.
        observer = NotificationCenter.default.addObserver(forName: ZoeStorage.didChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        say("\(ZoeFormat.greeting())! Sono \(name) 👋 Scrivimi qui sotto, oppure di' a Siri «Parla con ZOE».", .ride, for: 7)
    }

    // MARK: - Ciclo di vita

    func requestPermissions() async {
        notificationsAllowed = await ZoeNotifier.requestAuthorization()
        ZoeNotifier.rescheduleWater(water, enabled: settings.wellness)
    }

    /// L'app torna in primo piano.
    func becameActive() {
        reload()
        wake()
        tick()
        Task {
            notificationsAllowed = await ZoeNotifier.isAuthorized()
            await ZoeLiveActivities.cleanUp()
        }
    }

    func reload() {
        let s = ZoeStorage.settings
        if s != settings { settings = s }
        water = ZoeStorage.water
        reminders = ZoeStorage.reminders
        timer = ZoeStorage.timer
    }

    private func reloadWidgets() { WidgetCenter.shared.reloadAllTimelines() }

    // MARK: - Mascotte

    func setMood(_ expr: ZoeExpression, for seconds: Double? = nil) {
        mood = expr
        moodTask?.cancel()
        guard let seconds else { return }
        moodTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.mood = .felice
        }
    }

    func wake() {
        lastActivity = Date()
        if sleeping {
            sleeping = false
            setMood(.sorpresa, for: 1.2)
            bubble = ZoePhrases.wakeUp.randomElement()!
        }
    }

    /// Hai toccato ZOE.
    func tickle() {
        wake()
        setMood([.ride, .occhiolino, .innamorata, .emozionata].randomElement()!, for: 1.5)
        bubble = ZoePhrases.tickled.randomElement()!
        hop += 1
    }

    @discardableResult
    private func say(_ text: String, _ expr: ZoeExpression? = nil, for seconds: Double = 6) -> String {
        messages.append(ChatMessage(fromUser: false, text: text))
        if messages.count > 200 { messages.removeFirst(messages.count - 200) }
        bubble = text
        if let expr { setMood(expr, for: seconds) }
        hop += 1
        return text
    }

    // MARK: - Comandi

    /// Un messaggio scritto nella chat (o detto a Siri). Restituisce la risposta di ZOE.
    @discardableResult
    func send(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        messages.append(ChatMessage(fromUser: true, text: t))
        return run(t)
    }

    @discardableResult
    func run(_ text: String) -> String {
        let intent = ZoeCommands.parse(text)
        wake()
        switch intent {
        case .empty:
            return ""
        case .timer(let seconds, let label):
            startTimer(seconds: seconds, label: label)
            let focus = label == "Focus"
            return say((focus ? "Modalità focus: " : "Timer di ") + ZoeFormat.duration(seconds) + ". Ti avviso io ⏱️",
                       focus ? .pensierosa : .occhiolino)
        case .timerIncomplete:
            return say("Di quanto? Per esempio «timer 10 minuti».", .confusa)
        case .timerCancel:
            guard timer != nil else { return say("Non c'è nessun timer attivo.", .pensierosa) }
            stopTimer()
            return say("Timer annullato.", .contenta)
        case .reminder(let what, let at):
            addReminder(what, at: at)
            return say("Segnato! " + ZoeFormat.when(at).capitalizedFirst + " ti ricordo: " + what + " 📌", .occhiolino)
        case .reminderIncomplete:
            return say("Quando te lo ricordo? Per esempio «… alle 18» o «… tra 20 minuti».", .confusa)
        case .reminderClear:
            clearReminders()
            return say("Ho cancellato tutti i promemoria.", .contenta)
        case .calc(let expr, let value):
            return say(expr + " = " + ZoeFormat.number(value), .pensierosa)
        case .water(let delta):
            return addWater(delta)
        case .password(let length):
            let pw = ZoePhrases.password(length: length)
            UIPasteboard.general.string = pw
            return say("Fatto, l'ho copiata negli appunti 🔐 " + pw, .occhiolino, for: 9)
        case .time:
            return say("Sono le " + ZoeFormat.hhmm(Date()) + ".", .contenta)
        case .date:
            return say("Oggi è " + ZoeFormat.longDate(Date()) + ".", .contenta)
        case .coin:
            return say(["Testa!", "Croce!"].randomElement()! + " 🪙", .emozionata)
        case .dice:
            return say("È uscito \(Int.random(in: 1...6))! 🎲", .emozionata)
        case .joke:
            return say(ZoePhrases.jokes.randomElement()!, .ride, for: 9)
        case .settings:
            showSettings = true
            return say("Ecco come puoi cambiarmi look ✨", .emozionata)
        case .sleep:
            let reply = say("Buonanotte… 💤", .assonnata, for: 1.5)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                self?.sleeping = true
            }
            return reply
        case .whoami:
            return say(ZoePhrases.whoami(name), .innamorata)
        case .help:
            return say(ZoePhrases.help, .felice, for: 9)
        case .thanks:
            return say(ZoePhrases.thanks.randomElement()!, .innamorata)
        case .comfort:
            return say(ZoePhrases.comfort, .triste, for: 8)
        case .greet:
            return say(ZoeFormat.greeting() + "! Cosa facciamo?", .ride, for: 3)
        case .unknown:
            return say(ZoePhrases.unknown, .confusa)
        }
    }

    // MARK: - Timer

    func startTimer(seconds: TimeInterval, label: String) {
        let now = Date()
        let t = TimerState(start: now, end: now.addingTimeInterval(max(1, seconds)), label: label)
        timer = t
        ZoeStorage.timer = t
        ZoeNotifier.scheduleTimer(t)
        let s = settings
        Task { await ZoeLiveActivities.start(t, settings: s) }
        reloadWidgets()
    }

    func stopTimer() {
        timer = nil
        ZoeStorage.timer = nil
        ZoeNotifier.cancelTimer()
        Task { await ZoeLiveActivities.endAll() }
        reloadWidgets()
    }

    /// Da Siri: "Avvia un timer con ZOE".
    func startTimerFromSiri(minutes requested: Int, label: String?) -> String {
        let minutes = min(600, max(1, requested))
        let l = label?.trimmingCharacters(in: .whitespaces) ?? ""
        let text = "timer \(minutes) minuti" + (l.isEmpty ? "" : " per " + l)
        messages.append(ChatMessage(fromUser: true, text: text))
        startTimer(seconds: TimeInterval(minutes * 60), label: l.isEmpty ? "Timer" : l)
        return say("Timer di " + ZoeFormat.duration(TimeInterval(minutes * 60)) + ". Ti avviso io ⏱️", .occhiolino)
    }

    // MARK: - Promemoria

    func addReminder(_ text: String, at: Date) {
        let r = Reminder(text: text, at: at)
        reminders.append(r)
        reminders.sort { $0.at < $1.at }
        ZoeStorage.reminders = reminders
        ZoeNotifier.schedule(r)
        reloadWidgets()
    }

    func deleteReminder(_ r: Reminder) {
        reminders.removeAll { $0.id == r.id }
        ZoeStorage.reminders = reminders
        ZoeNotifier.cancel(reminders: [r.id])
        reloadWidgets()
    }

    func clearReminders() {
        ZoeNotifier.cancel(reminders: reminders.map(\.id))
        reminders = []
        ZoeStorage.reminders = []
        reloadWidgets()
    }

    // MARK: - Acqua

    @discardableResult
    func addWater(_ n: Int) -> String {
        water = ZoeStorage.addWater(n)
        ZoeNotifier.rescheduleWater(water, enabled: settings.wellness)
        reloadWidgets()
        guard n > 0 else { return "" }
        let c = water.count
        return say(ZoePhrases.water(count: c), c == WaterLog.goal ? .emozionata : .ride, for: c >= WaterLog.goal ? 6 : 3)
    }

    // MARK: - Orologio interno (ogni mezzo secondo mentre l'app è aperta)

    func tick(now: Date = Date()) {
        let w = water.current(at: now)
        if w != water { water = w; ZoeStorage.water = w }

        if let t = timer, now >= t.end {
            timer = nil
            ZoeStorage.timer = nil
            Task { await ZoeLiveActivities.finishAll() }
            reloadWidgets()
            wake()
            say(t.isFocus ? "Focus finito! Pausa di 5 minuti? ☕" : "Tempo scaduto! ⏰", .emozionata, for: 10)
        }

        let due = reminders.filter { $0.at <= now }
        if !due.isEmpty {
            reminders.removeAll { $0.at <= now }
            ZoeStorage.reminders = reminders
            reloadWidgets()
            wake()
            say("Ehi! Ricordati: " + due.map(\.text).joined(separator: ", "), .sorpresa, for: 12)
        }

        let h = Calendar.current.component(.hour, from: now)
        let sinceWater = now.timeIntervalSince(water.last ?? lastNudge)
        if settings.wellness, h >= ZoeWellness.startHour, h < ZoeWellness.endHour, water.count < WaterLog.goal,
           sinceWater > 3600, now.timeIntervalSince(lastNudge) > 3600 {
            lastNudge = now
            say(ZoePhrases.waterNudge, .occhiolino, for: 9)
        }

        if !sleeping && timer == nil && now.timeIntervalSince(lastActivity) > Self.sleepAfter {
            sleeping = true
        }
    }
}

extension String {
    /// "oggi alle 18:00" → "Oggi alle 18:00"
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
