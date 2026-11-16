import AppIntents
import Foundation
import WidgetKit
import ZoeCore
import ZoeShared

// Questo file è compilato sia nell'app sia nell'estensione dei widget: così i pulsanti
// dei widget e della Dynamic Island funzionano, e Siri trova le stesse azioni.

/// "Ho bevuto": segna un bicchiere d'acqua. Usata dal pulsante 💧 dei widget e da Siri.
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Ho bevuto un bicchiere"
    static var description = IntentDescription("Segna un bicchiere d'acqua con ZOE.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let log = ZoeStorage.addWater(1)
        ZoeNotifier.rescheduleWater(log, enabled: ZoeStorage.settings.wellness)
        WidgetCenter.shared.reloadAllTimelines()
        ZoeStorage.notifyChange()
        return .result(dialog: "\(ZoePhrases.water(count: log.count))")
    }
}

/// Ferma il timer. È una LiveActivityIntent, quindi gira nell'app anche se la tocchi dalla Dynamic Island.
struct StopTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ferma il timer di ZOE"
    static var description = IntentDescription("Ferma il timer o la sessione di focus.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wasRunning = ZoeStorage.timer != nil
        ZoeStorage.timer = nil
        ZoeNotifier.cancelTimer()
        await ZoeLiveActivities.endAll()
        WidgetCenter.shared.reloadAllTimelines()
        ZoeStorage.notifyChange()
        let reply = wasRunning ? "Timer annullato." : "Non c'è nessun timer attivo."
        return .result(dialog: "\(reply)")
    }
}
