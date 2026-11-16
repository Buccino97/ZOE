import AppIntents
import Foundation

// Azioni che Siri e l'app Comandi rapidi possono usare.
// Sono LiveActivityIntent così possono avviare il timer nella Dynamic Island anche ad app chiusa.

/// "Ehi Siri, parla con ZOE" → Siri chiede cosa dire, ZOE risponde come nella chat.
struct AskZoeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Parla con ZOE"
    static var description = IntentDescription("Di' qualcosa a ZOE: timer, promemoria, acqua, calcoli, barzellette…")

    @Parameter(title: "Frase", requestValueDialog: IntentDialog("Dimmi pure!"))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = ZoeStore.shared.send(text)
        return .result(dialog: "\(reply.isEmpty ? "Sono qui!" : reply)")
    }
}

/// "Ehi Siri, avvia un timer con ZOE" → "Di quanti minuti?"
struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Avvia un timer con ZOE"
    static var description = IntentDescription("Avvia un timer che vedi nella Dynamic Island.")

    @Parameter(title: "Minuti", requestValueDialog: IntentDialog("Di quanti minuti?"))
    var minutes: Int

    @Parameter(title: "Per cosa")
    var label: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = ZoeStore.shared.startTimerFromSiri(minutes: minutes, label: label)
        return .result(dialog: "\(reply)")
    }
}

/// "Ehi Siri, modalità focus con ZOE" → 25 minuti di concentrazione.
struct StartFocusIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Modalità focus con ZOE"
    static var description = IntentDescription("Una sessione di concentrazione (pomodoro).")

    @Parameter(title: "Minuti", default: 25)
    var minutes: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let reply = ZoeStore.shared.send("focus \(min(240, max(1, minutes))) minuti")
        return .result(dialog: "\(reply)")
    }
}

/// Le frasi per Siri. Funzionano subito dopo l'installazione, senza configurare nulla.
struct ZoeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AskZoeIntent(),
                    phrases: ["Parla con \(.applicationName)", "Chiedi a \(.applicationName)", "Di' a \(.applicationName)"],
                    shortTitle: "Parla con ZOE",
                    systemImageName: "bubble.left.and.bubble.right.fill")
        AppShortcut(intent: StartTimerIntent(),
                    phrases: ["Avvia un timer con \(.applicationName)", "Timer con \(.applicationName)"],
                    shortTitle: "Timer",
                    systemImageName: "timer")
        AppShortcut(intent: StartFocusIntent(),
                    phrases: ["Modalità focus con \(.applicationName)", "Avvia un pomodoro con \(.applicationName)"],
                    shortTitle: "Focus",
                    systemImageName: "brain.head.profile")
        AppShortcut(intent: AddWaterIntent(),
                    phrases: ["Ho bevuto con \(.applicationName)", "Segna un bicchiere d'acqua con \(.applicationName)"],
                    shortTitle: "Ho bevuto",
                    systemImageName: "drop.fill")
        AppShortcut(intent: StopTimerIntent(),
                    phrases: ["Ferma il timer di \(.applicationName)"],
                    shortTitle: "Ferma timer",
                    systemImageName: "stop.circle")
    }

    static var shortcutTileColor: ShortcutTileColor = .purple
}
