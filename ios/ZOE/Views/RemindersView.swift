import SwiftUI
import ZoeCore
import ZoeUI

/// Elenco dei promemoria, con scorrimento a sinistra per eliminarli.
struct RemindersView: View {
    @EnvironmentObject private var store: ZoeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.reminders.isEmpty {
                    VStack(spacing: 12) {
                        ZoeMascotView(settings: store.settings, expression: .pensierosa).frame(width: 110)
                        Text("Nessun promemoria.").font(.headline)
                        Text("Prova a scrivere «ricordami di chiamare Luca alle 18» o «tra 20 minuti ricordami di spegnere il forno».")
                            .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(store.reminders) { r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.text).font(.body)
                                Text(ZoeFormat.when(r.at)).font(.footnote.monospacedDigit()).foregroundStyle(Theme.mint)
                            }
                            .listRowBackground(Theme.surface)
                        }
                        .onDelete { idx in idx.map { store.reminders[$0] }.forEach(store.deleteReminder) }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.bg)
            .navigationTitle("Promemoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
                if !store.reminders.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Cancella tutti", role: .destructive) { store.clearReminders() }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
