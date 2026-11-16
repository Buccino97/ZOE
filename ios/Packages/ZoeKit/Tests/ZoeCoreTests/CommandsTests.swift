import XCTest
@testable import ZoeCore

/// Stessi casi di app/test/commands.test.js, più qualche test specifico per iPhone.
final class CommandsTests: XCTestCase {
    // Calendario fisso, così i test danno lo stesso risultato ovunque.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()
    var cal: Calendar { Self.cal }

    /// Sabato 15 novembre 2026, ore 15:00.
    let NOW = at(15, 15)

    static func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }
    func at(_ d: Int, _ h: Int, _ m: Int = 0) -> Date { Self.at(d, h, m) }
    func parse(_ s: String) -> ZoeIntent { ZoeCommands.parse(s, now: NOW, calendar: cal) }

    func testDurations() {
        XCTAssertEqual(ZoeCommands.parseDuration("10 minuti"), 600)
        XCTAssertEqual(ZoeCommands.parseDuration("1 ora e 30 minuti"), 5400)
        XCTAssertEqual(ZoeCommands.parseDuration("mezz'ora"), 1800)
        XCTAssertEqual(ZoeCommands.parseDuration("un'ora e mezza"), 5400)
        XCTAssertEqual(ZoeCommands.parseDuration("90 sec"), 90)
        XCTAssertEqual(ZoeCommands.parseDuration("cinque minuti"), 300)
        XCTAssertEqual(ZoeCommands.parseDuration("ciao"), 0)
    }

    func testTimers() {
        XCTAssertEqual(parse("timer 10 minuti"), .timer(seconds: 600, label: "Timer"))
        XCTAssertEqual(parse("Metti un timer di 8 minuti per la pasta"), .timer(seconds: 480, label: "pasta"))
        XCTAssertEqual(parse("5 minuti"), .timer(seconds: 300, label: "Timer"))
        XCTAssertEqual(parse("avvia un pomodoro"), .timer(seconds: 25 * 60, label: "Focus"))
        XCTAssertEqual(parse("focus 50 minuti"), .timer(seconds: 50 * 60, label: "Focus"))
        XCTAssertEqual(parse("timer"), .timerIncomplete)
        XCTAssertEqual(parse("stop timer"), .timerCancel)
        XCTAssertEqual(parse("Annulla"), .timerCancel)
    }

    func testReminders() {
        XCTAssertEqual(parse("Ricordami di chiamare la mamma alle 18"), .reminder(text: "chiamare la mamma", at: at(15, 18)))
        XCTAssertEqual(parse("ricordami di comprare il latte alle 18:30"), .reminder(text: "comprare il latte", at: at(15, 18, 30)))
        XCTAssertEqual(parse("ricordami tra 20 minuti di spegnere il forno"), .reminder(text: "spegnere il forno", at: NOW.addingTimeInterval(20 * 60)))
        XCTAssertEqual(parse("domani alle 9 ricordami di pagare la bolletta"), .reminder(text: "pagare la bolletta", at: at(16, 9)))
        XCTAssertEqual(parse("ricordami di uscire alle 7 e mezza"), .reminder(text: "uscire", at: at(15, 19, 30)))
        // Alle 15 "alle 10" vuol dire le 22.
        XCTAssertEqual(parse("ricordami di dormire alle 10"), .reminder(text: "dormire", at: at(15, 22)))
        XCTAssertEqual(parse("ricordami alle 14 di bere"), .reminder(text: "bere", at: at(16, 14)))
        XCTAssertEqual(parse("Ricordami di chiamare Luca alle 18"), .reminder(text: "chiamare Luca", at: at(15, 18)))
        XCTAssertEqual(parse("tra un'ora ricordami di scrivere a Giulia"), .reminder(text: "scrivere a Giulia", at: NOW.addingTimeInterval(3600)))
        XCTAssertEqual(parse("ricordami tra mezz'ora di uscire"), .reminder(text: "uscire", at: NOW.addingTimeInterval(1800)))
        XCTAssertEqual(parse("ricordami di chiamare Luca"), .reminderIncomplete(text: "chiamare Luca"))
        XCTAssertEqual(parse("cancella tutti i promemoria"), .reminderClear)
    }

    func testCalculator() {
        XCTAssertEqual(ZoeCommands.calculate("2+2*3"), 8)
        XCTAssertEqual(ZoeCommands.calculate("(2+2)*3"), 12)
        XCTAssertEqual(ZoeCommands.calculate("10 x 3"), 30)
        XCTAssertEqual(ZoeCommands.calculate("7 diviso 2"), 3.5)
        XCTAssertEqual(ZoeCommands.calculate("2^10"), 1024)
        XCTAssertEqual(ZoeCommands.calculate("20% * 50"), 10)
        XCTAssertEqual(ZoeCommands.calculate("3,5 + 1,5"), 5)
        XCTAssertEqual(ZoeCommands.calculate("-3 + 1"), -2)
        XCTAssertNil(ZoeCommands.calculate("alert(1)"))
        XCTAssertNil(ZoeCommands.calculate("2+"))
        XCTAssertNil(ZoeCommands.calculate("1/0"))
        XCTAssertEqual(parse("quanto fa 12 per 12"), .calc(expr: "12 per 12", value: 144))
        XCTAssertEqual(parse("15 * 4"), .calc(expr: "15 * 4", value: 60))
    }

    func testOtherIntents() {
        XCTAssertEqual(parse("ho bevuto un bicchiere"), .water(delta: 1))
        XCTAssertEqual(parse("ho bevuto 2 bicchieri d’acqua"), .water(delta: 2))
        XCTAssertEqual(parse("generami una password di 24 caratteri"), .password(length: 24))
        XCTAssertEqual(parse("password"), .password(length: 16))
        XCTAssertEqual(parse("che ore sono?"), .time)
        XCTAssertEqual(parse("che giorno è oggi"), .date)
        XCTAssertEqual(parse("lancia una moneta"), .coin)
        XCTAssertEqual(parse("tira un dado"), .dice)
        XCTAssertEqual(parse("raccontami una barzelletta"), .joke)
        XCTAssertEqual(parse("Ciao!"), .greet)
        XCTAssertEqual(parse("grazie mille"), .thanks)
        XCTAssertEqual(parse("sono stanco"), .comfort)
        XCTAssertEqual(parse("cosa sai fare?"), .help)
        XCTAssertEqual(parse("buonanotte"), .sleep)
        XCTAssertEqual(parse("personalizza"), .settings)
        XCTAssertEqual(parse("qual è il senso della vita"), .unknown(text: "qual è il senso della vita"))
        XCTAssertEqual(parse("   "), .empty)
    }

    func testFormatting() {
        XCTAssertEqual(ZoeFormat.duration(5400), "1 ora e 30 minuti")
        XCTAssertEqual(ZoeFormat.duration(1500), "25 minuti")
        XCTAssertEqual(ZoeFormat.duration(45), "45 secondi")
        XCTAssertEqual(ZoeFormat.clock(65), "1:05")
        XCTAssertEqual(ZoeFormat.clock(3725), "1:02:05")
        XCTAssertEqual(ZoeFormat.hhmm(at(15, 9, 5), calendar: cal), "09:05")
        XCTAssertEqual(ZoeFormat.number(3.5), "3,5")
        XCTAssertEqual(ZoeFormat.when(NOW.addingTimeInterval(20 * 60), now: NOW, calendar: cal), "tra 20 minuti")
        XCTAssertEqual(ZoeFormat.when(at(15, 18), now: NOW, calendar: cal), "oggi alle 18:00")
        XCTAssertEqual(ZoeFormat.when(at(16, 9), now: NOW, calendar: cal), "domani alle 09:00")
        XCTAssertEqual(ZoeFormat.greeting(at(15, 9), calendar: cal), "Buongiorno")
        XCTAssertEqual(ZoeFormat.greeting(NOW, calendar: cal), "Buon pomeriggio")
    }

    func testPasswordAndShade() {
        let pw = ZoePhrases.password(length: 24)
        XCTAssertEqual(pw.count, 24)
        XCTAssertNotEqual(pw, ZoePhrases.password(length: 24))
        XCTAssertEqual(ZoePalette.shade("#7c5cff", -40), "#5434d7")
        XCTAssertEqual(ZoePalette.shade("#ffffff", 40), "#ffffff")
    }

    func testWaterLogResetsAtMidnight() {
        let log = WaterLog(day: WaterLog.dayKey(NOW, calendar: cal), count: 5)
        XCTAssertEqual(log.current(at: at(15, 23), calendar: cal).count, 5)
        XCTAssertEqual(log.current(at: at(16, 8), calendar: cal).count, 0)
    }

    func testWaterNudges() {
        // Ultimo bicchiere alle 15: promemoria alle 16, 17 … 21, poi domani dalle 9.
        let n = ZoeWellness.waterNudges(lastWater: NOW, countToday: 3, now: NOW, max: 8, calendar: cal)
        XCTAssertEqual(n.first, at(15, 16))
        XCTAssertEqual(n[5], at(15, 21))
        XCTAssertEqual(cal.component(.hour, from: n[6]), 9)
        XCTAssertTrue(cal.isDate(n[6], inSameDayAs: at(16, 9)))
        // Obiettivo raggiunto: niente più promemoria oggi.
        let done = ZoeWellness.waterNudges(lastWater: NOW, countToday: 8, now: NOW, calendar: cal)
        XCTAssertTrue(done.allSatisfy { !cal.isDate($0, inSameDayAs: NOW) })
    }

    func testWidgetExpression() {
        var s = ZoeSnapshot.sample
        XCTAssertEqual(s.expression(at: at(15, 10), calendar: cal), .felice)
        XCTAssertEqual(s.expression(at: at(15, 23, 30), calendar: cal), .dorme)
        s.timer = TimerState(start: NOW, end: NOW.addingTimeInterval(600), label: "Focus")
        XCTAssertEqual(s.expression(at: NOW, calendar: cal), .pensierosa)
        XCTAssertNil(s.at(NOW.addingTimeInterval(601), calendar: cal).timer)
    }
}
