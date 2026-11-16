# ZOE: app desktop (prototipo)

ZOE vive in una barra sottile in alto al centro dello schermo. Passaci sopra col mouse e si apre; premi **Ctrl+Shift+Spazio** (⌘+Shift+Spazio su Mac) per scriverle subito.

## Avviare

```bash
cd app
npm install
npm start
```

Test del riconoscimento comandi: `npm test`

## Cosa sa fare (v0.1)

| Scrivi… | Succede |
| --- | --- |
| `timer 10 minuti per la pasta` | conto alla rovescia nella barra + notifica alla fine |
| `focus` / `pomodoro` / `focus 50 minuti` | sessione di concentrazione (25' di default) |
| `ricordami di chiamare Luca alle 18` | promemoria con notifica (anche `tra 20 minuti`, `domani alle 9`, `alle 7 e mezza`) |
| `ho bevuto` / `ho bevuto 2 bicchieri` | contatore acqua del giorno (obiettivo 8) |
| `quanto fa 12 per 12` | calcolatrice |
| `password` / `password di 24 caratteri` | password sicura copiata negli appunti |
| `che ore sono`, `che giorno è` | ora e data |
| `lancia una moneta`, `tira un dado`, `barzelletta` | per svago |
| `personalizza` | colore, occhi, accessorio, nome |
| `stop`, `cancella tutti i promemoria`, `buonanotte`, `cosa sai fare` | … |

E poi:

- La barra è sempre in primo piano, ma lascia passare i clic dove non c'è niente.
- Gli occhi seguono il mouse. Ogni tanto arriva una mosca da inseguire, e dopo 3 minuti senza di te si addormenta.
- Ogni ora, se non hai bevuto, ti propone un bicchiere d'acqua (si disattiva in *Personalizza*).
- Icona nella barra di sistema: chiedi, personalizza, mostra/nascondi, avvio automatico, esci.
- Tutto è salvato in locale, in `zoe.json` dentro la cartella dati dell'app.

## Struttura

```
src/main.js              finestra trasparente, click-through, tray, scorciatoia, notifiche
src/preload.js           ponte sicuro main ↔ interfaccia (contextIsolation, sandbox)
src/store.js             salvataggio JSON locale
src/renderer/zoe.js      la mascotte in SVG (espressioni, occhi, accessori)
src/renderer/commands.js interpretazione dei comandi in italiano (funzione pura, testata)
src/renderer/renderer.js logica della barra: hover, timer, promemoria, acqua, umore
test/                    test dei comandi (node --test)
```

## Creare l'installer

```bash
npm run dist:win   # ZOE-Setup-x.y.z.exe (da Windows)
npm run dist:mac   # .dmg (da macOS)
```

Senza firma digitale Windows mostrerà l'avviso SmartScreen e macOS Gatekeeper.

## Prossimi passi

1. **Voce offline**: parola d'attivazione "Ehi ZOE" e push-to-talk con Vosk, risposte parlate con Piper.
2. **Cervello IA**: quando un comando non viene capito, chiedere a un modello (chiave dell'utente o IA locale).
3. **Musica**: controllo di Spotify e dei tasti multimediali.
4. **Desktop**: riordino dei file con conferma, ricerca file, apertura app, spegnimento programmato.
5. Nascondersi da sola con giochi e video a schermo intero, e scelta del monitor.
6. Licenze e attivazione con chiave, aggiornamenti automatici.
