import SwiftUI
import UIKit
import ZoeCore
import ZoeUI

/// Personalizzazione: nome, colore, occhi, accessorio, benessere. Più i consigli per Siri e i widget.
struct SettingsView: View {
    @EnvironmentObject private var store: ZoeStore
    @Environment(\.dismiss) private var dismiss
    @State private var preview: ZoeExpression = .felice

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZoeMascotView(settings: store.settings, expression: preview)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { preview = ZoeExpression.allCases.randomElement()! }
                        .listRowBackground(Color.clear)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ZoeExpression.allCases, id: \.self) { e in
                                Button { preview = e } label: {
                                    VStack(spacing: 2) {
                                        ZoeMascotView(settings: store.settings, expression: e, animated: false, showsAccessory: false)
                                            .frame(width: 44)
                                        Text(e.rawValue).font(.caption2).foregroundStyle(e == preview ? Theme.text : Theme.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Le 13 facce di ZOE. Tocca per provarle.")
                }

                Section("Nome") {
                    TextField("ZOE", text: $store.settings.name)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }

                Section("Colore") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                        ForEach(ZoePalette.colors, id: \.self) { c in
                            Button { store.settings.color = c } label: {
                                Circle().fill(Color(hex: c))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(.white, lineWidth: store.settings.color == c ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colore \(c)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Occhi") {
                    Picker("Occhi", selection: $store.settings.eyes) {
                        ForEach(EyeStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Accessorio") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72))], spacing: 10) {
                        ForEach(ZoeAccessory.allCases, id: \.self) { a in
                            Button { store.settings.accessory = a } label: {
                                VStack(spacing: 2) {
                                    ZoeMascotView(color: store.settings.color, eyes: store.settings.eyes, accessory: a, animated: false)
                                        .frame(width: 52)
                                    Text(a.label).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 12)
                                    .stroke(store.settings.accessory == a ? Theme.accent : Theme.line, lineWidth: store.settings.accessory == a ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Promemoria acqua", isOn: $store.settings.wellness)
                } header: {
                    Text("Benessere")
                } footer: {
                    Text("Un promemoria all'ora per bere, tra le 9 e le 22, finché non arrivi a 8 bicchieri.")
                }

                Section("Notifiche") {
                    if store.notificationsAllowed {
                        Label("Attive: timer e promemoria arrivano anche ad app chiusa.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.mint)
                    } else {
                        Label("Disattivate: ZOE non può avvisarti ad app chiusa.", systemImage: "bell.slash.fill")
                            .foregroundStyle(.orange)
                        Button("Apri Impostazioni") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }

                Section {
                    tip("mic.fill", "«Ehi Siri, parla con ZOE»", "poi dille ad esempio «ricordami di chiamare Luca alle 18».")
                    tip("timer", "«Ehi Siri, avvia un timer con ZOE»", "lo vedi nella Dynamic Island e nella schermata di blocco.")
                    tip("brain.head.profile", "«Ehi Siri, modalità focus con ZOE»", "25 minuti di concentrazione.")
                    tip("drop.fill", "«Ehi Siri, ho bevuto con ZOE»", "segna un bicchiere d'acqua.")
                    tip("square.grid.2x2.fill", "Widget", "tieni premuto sulla schermata Home → «+» → cerca ZOE. C'è anche per la schermata di blocco.")
                } header: {
                    Text("Siri, Dynamic Island e widget")
                }

                Section {
                    Text("ZOE v0.1 per iPhone · Tutto resta sul tuo telefono: niente account, niente server.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Personalizza")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            if store.settings.name.trimmingCharacters(in: .whitespaces).isEmpty { store.settings.name = "ZOE" }
        }
    }

    private func tip(_ icon: String, _ title: String, _ detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(Theme.muted)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
    }
}
