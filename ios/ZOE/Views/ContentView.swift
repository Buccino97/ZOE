import SwiftUI
import ZoeCore
import ZoeUI

enum Theme {
    static let bg = Color(hex: "#0a0b16")
    static let surface = Color(hex: "#1a1e35")
    static let surface2 = Color(hex: "#252a4a")
    static let line = Color(hex: "#2e3458")
    static let text = Color(hex: "#eef0ff")
    static let muted = Color(hex: "#9aa0c3")
    static let accent = Color(hex: "#7c5cff")
    static let mint = Color(hex: "#3ee0b0")
    static let water = Color(hex: "#6cc8ff")
}

/// Schermata principale: ZOE in alto, i "widget" di stato, la chat e la barra per scrivere.
struct ContentView: View {
    @EnvironmentObject private var store: ZoeStore
    @State private var input = ""
    @FocusState private var typing: Bool
    @State private var look: CGSize = .zero
    @State private var dragging = false
    @State private var showReminders = false

    private let ticker = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private struct Quick: Hashable { let label: String, command: String, run: Bool }
    /// Comandi rapidi: quelli con `run` partono subito, gli altri riempiono la barra di scrittura.
    private let quick: [Quick] = [
        Quick(label: "⏱ Timer 10 min", command: "timer 10 minuti", run: true),
        Quick(label: "🎯 Focus 25", command: "focus 25 minuti", run: true),
        Quick(label: "💧 Ho bevuto", command: "ho bevuto", run: true),
        Quick(label: "📌 Promemoria…", command: "ricordami di ", run: false),
        Quick(label: "🧮 Calcola…", command: "quanto fa ", run: false),
        Quick(label: "🕒 Che ore sono?", command: "che ore sono", run: true),
        Quick(label: "🪙 Testa o croce", command: "testa o croce", run: true),
        Quick(label: "🎲 Dado", command: "tira un dado", run: true),
        Quick(label: "😄 Barzelletta", command: "raccontami una barzelletta", run: true),
        Quick(label: "❓ Cosa sai fare", command: "cosa sai fare", run: true),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                statusRow
                chat
                quickRow
                inputBar
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.showSettings = true } label: { Image(systemName: "paintpalette.fill") }
                        .accessibilityLabel("Personalizza ZOE")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text(Date(), style: .time).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.muted)
                }
            }
            .sheet(isPresented: $store.showSettings) { SettingsView().environmentObject(store) }
            .sheet(isPresented: $showReminders) { RemindersView().environmentObject(store) }
            .onReceive(ticker) { store.tick(now: $0) }
            .task { await store.requestPermissions() }
        }
        .tint(Theme.accent)
    }

    // MARK: Mascotte e nuvoletta

    private var header: some View {
        VStack(spacing: 6) {
            if !store.bubble.isEmpty {
                Text(store.bubble)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color(hex: "#1b1630"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .id(store.bubble)
            }
            GeometryReader { geo in
                ZoeMascotView(settings: store.settings, expression: store.expression,
                              look: typing && !dragging ? CGSize(width: -1, height: 3.2) : look)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                dragging = true
                                look = gaze(from: v.location, in: geo.size)
                            }
                            .onEnded { v in
                                dragging = false
                                if hypot(v.translation.width, v.translation.height) < 10 { store.tickle() }
                                withAnimation(.easeOut(duration: 0.3)) { look = .zero }
                            }
                    )
            }
            .frame(width: 150, height: 140)
            .phaseAnimator([0.0, -8.0, 1.5, 0.0], trigger: store.hop) { view, y in
                view.offset(y: y)
            } animation: { _ in .spring(duration: 0.18) }
        }
        .padding(.top, 4)
        .animation(.easeOut(duration: 0.2), value: store.bubble)
    }

    /// Le pupille seguono il dito (come seguono il mouse su PC).
    private func gaze(from p: CGPoint, in size: CGSize) -> CGSize {
        let dx = p.x - size.width / 2, dy = p.y - size.height * 0.45
        let d = max(1, hypot(dx, dy)), m = min(1, d / 120) * 3.6
        return CGSize(width: dx / d * m, height: dy / d * m)
    }

    // MARK: Stato: timer, acqua, promemoria

    private var statusRow: some View {
        HStack(spacing: 8) {
            card {
                if let t = store.timer {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            caption(t.label == "Timer" ? "Timer" : t.label)
                            Text(timerInterval: t.start...t.end, countsDown: true)
                                .font(.headline.monospacedDigit()).foregroundStyle(Theme.text)
                        }
                        Spacer(minLength: 0)
                        Button { store.run("stop timer") } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundStyle(Theme.muted)
                            .accessibilityLabel("Ferma il timer")
                    }
                    ProgressView(timerInterval: t.start...t.end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                        .tint(Theme.mint)
                } else {
                    caption("Timer")
                    Button { store.send("focus 25 minuti") } label: {
                        Text("Avvia focus").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.mint)
                }
            }
            card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        caption("Acqua")
                        Text("💧 \(store.water.count)/\(WaterLog.goal)").font(.headline.monospacedDigit()).foregroundStyle(Theme.text)
                    }
                    Spacer(minLength: 0)
                    Button { store.addWater(-1) } label: { Image(systemName: "minus.circle") }
                        .foregroundStyle(Theme.muted).accessibilityLabel("Togli un bicchiere")
                    Button { store.send("ho bevuto") } label: { Image(systemName: "plus.circle.fill") }
                        .foregroundStyle(Theme.water).accessibilityLabel("Aggiungi un bicchiere")
                }
                ProgressView(value: min(Double(store.water.count), Double(WaterLog.goal)), total: Double(WaterLog.goal))
                    .tint(Theme.water)
            }
            Button { showReminders = true } label: {
                card {
                    caption("Promem.")
                    Text("📌 \(store.reminders.count)").font(.headline).foregroundStyle(Theme.text)
                }
            }
            .frame(width: 84)
            .buttonStyle(.plain)
        }
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func caption(_ s: String) -> some View {
        Text(s.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(Theme.muted).lineLimit(1)
    }

    // MARK: Chat

    private var chat: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.messages) { m in
                        HStack {
                            if m.fromUser { Spacer(minLength: 40) }
                            Text(m.text)
                                .foregroundStyle(m.fromUser ? .white : Theme.text)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(m.fromUser ? Theme.accent : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
                                .textSelection(.enabled)
                            if !m.fromUser { Spacer(minLength: 40) }
                        }
                        .id(m.id)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.count) {
                if let last = store.messages.last {
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Comandi rapidi e barra di scrittura

    private var quickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quick, id: \.label) { q in
                    Button {
                        if q.run { store.send(q.command) } else { input = q.command; typing = true }
                    } label: {
                        Text(q.label).font(.footnote.weight(.medium))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.surface, in: Capsule())
                            .overlay(Capsule().stroke(Theme.line))
                    }
                    .foregroundStyle(Theme.text)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("", text: $input, prompt: Text("Scrivi a \(store.name)… es. «ricordami di chiamare Luca alle 18»").foregroundStyle(Theme.muted))
                .focused($typing)
                .submitLabel(.send)
                .onSubmit(submit)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(typing ? Theme.accent : Theme.line))
                .foregroundStyle(Theme.text)
                .onChange(of: input) { store.wake() }
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Invia")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func submit() {
        let text = input
        input = ""
        store.send(text)
        typing = true
    }
}
