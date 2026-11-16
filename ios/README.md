# ZOE per iPhone 📱

La versione iPhone di ZOE: stessa mascotte, stessa personalità, stessi comandi in italiano della versione per PC.
È un'app nativa scritta in **SwiftUI**.

## Cosa fa (e cosa cambia rispetto al PC)

Su iPhone nessuna app può restare sopra le altre come la barra di ZOE su PC. Quindi ZOE usa i posti "ufficiali" di iOS:

| Su PC | Su iPhone |
|---|---|
| Barra in alto, sempre visibile | **Dynamic Island** e **schermata di blocco** (Live Activity) mentre scorre un timer o un focus, con il pulsante Stop |
| Mascotte sempre a portata | **Widget** per la schermata Home (piccolo e medio, con il pulsante 💧 +1) e per la schermata di blocco |
| Ctrl+Shift+Spazio | **Siri**: «Ehi Siri, parla con ZOE», «avvia un timer con ZOE», «modalità focus con ZOE», «ho bevuto con ZOE» |
| Promemoria e acqua | **Notifiche** che arrivano anche ad app chiusa, senza server |
| Pannello con chat | App con ZOE grande (le pupille seguono il dito, si addormenta dopo 3 minuti), chat, comandi rapidi, personalizzazione |

Comandi che puoi scrivere (o dire a Siri dopo «parla con ZOE»):

- `timer 10 minuti` · `metti un timer di 8 minuti per la pasta` · `focus 50 minuti` · `stop`
- `ricordami di chiamare Luca alle 18` · `tra 20 minuti ricordami di spegnere il forno` · `domani alle 9 ricordami di pagare la bolletta`
- `ho bevuto` · `ho bevuto 2 bicchieri`
- `quanto fa 12 per 12` · `15 * 4` · `generami una password di 24 caratteri`
- `che ore sono?` · `che giorno è oggi` · `testa o croce` · `tira un dado` · `raccontami una barzelletta` · `personalizza` · `buonanotte` · `cosa sai fare?`

Tutto resta sul telefono: niente account, niente server, niente dati inviati.

---

## Come provarla sul tuo iPhone, passo passo

### Cosa ti serve

- Un **Mac** con macOS 14.5 o più recente.
- **Xcode 16** o più recente (gratuito, dal Mac App Store).
- Un **iPhone con iOS 17** o più recente e il suo cavo. La Dynamic Island c'è su iPhone 14 Pro e modelli successivi; sugli altri iPhone il timer compare comunque nella schermata di blocco.
- Il tuo account **Apple Developer Program** (quello da 99 $/anno).

### 1. Installa Xcode

1. Apri l'**App Store** sul Mac, cerca **Xcode** e installalo. Pesa parecchio, ci vuole un po'.
2. Aprilo una volta e accetta tutto quello che chiede (licenza, componenti aggiuntivi).
3. In Xcode vai su **Xcode → Settings… → Accounts**, premi **+** in basso, scegli **Apple ID** e accedi con l'account sviluppatore.

### 2. Installa XcodeGen (serve una volta sola)

XcodeGen crea il progetto Xcode a partire dal file `project.yml`. Apri l'app **Terminale** (la trovi con Spotlight: ⌘ + Spazio, scrivi "Terminale").

Se non hai Homebrew, installalo incollando questa riga e premendo Invio (ti chiederà la password del Mac; mentre la scrivi non si vede nulla, è normale):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Alla fine Homebrew potrebbe mostrare due o tre righe sotto **"Next steps"**: copiale e incollale nel Terminale. Poi installa XcodeGen:

```bash
brew install xcodegen
```

### 3. Scarica il progetto

Nel Terminale (sostituisci il nome del branch se è cambiato):

```bash
cd ~/Desktop
git clone https://github.com/Buccino97/ZOE.git
cd ZOE
git checkout claude/vibrant-lovelace-zoo9eq
```

(Se il Mac chiede di installare gli "strumenti da riga di comando", accetta e poi ripeti il comando.)

### 4. Metti i tuoi dati in `Config.xcconfig`

Apri il file `ZOE/ios/Config.xcconfig` con TextEdit (clic destro → Apri con → TextEdit) e cambia le due righe:

```
ZOE_BUNDLE_PREFIX = com.mariorossi.zoe
DEVELOPMENT_TEAM = AB12CD34EF
```

- **ZOE_BUNDLE_PREFIX**: un identificativo che sia solo tuo, al contrario come un indirizzo web, tutto minuscolo e senza spazi. Esempio: `com.nomecognome.zoe`.
- **DEVELOPMENT_TEAM**: il tuo Team ID di 10 caratteri. Lo trovi su [developer.apple.com/account](https://developer.apple.com/account), alla voce *Membership details*. Se non lo trovi, lascialo vuoto: lo sceglierai in Xcode al passo 6.

Salva il file.

### 5. Genera il progetto e aprilo

Nel Terminale:

```bash
cd ~/Desktop/ZOE/ios
xcodegen
open ZOE.xcodeproj
```

Xcode si apre e scarica da solo le parti interne del progetto (in basso a sinistra vedi "Resolving packages…"). Aspetta che finisca.

> Ogni volta che scarichi una versione nuova del progetto o cambi `Config.xcconfig`, ripeti `xcodegen`.

### 6. Controlla la firma (una volta sola)

1. Nella colonna di sinistra clicca sull'icona blu **ZOE** in cima.
2. Sotto **TARGETS** seleziona **ZOE**, poi la scheda **Signing & Capabilities**.
3. Controlla che **Automatically manage signing** sia spuntato e che in **Team** ci sia il tuo nome o la tua azienda. Se è vuoto, sceglilo dal menu.
4. Più in basso deve esserci **App Groups** con `group.com.tuonome.zoe` spuntato. Se è rosso, premi la freccina di aggiornamento accanto.
5. Ripeti i punti 2-4 per il target **ZOEWidgets**.

### 7. Prepara l'iPhone

1. Collega l'iPhone al Mac con il cavo. Sull'iPhone tocca **Autorizza** e inserisci il codice.
2. Attiva la **Modalità sviluppatore**: sull'iPhone vai su **Impostazioni → Privacy e sicurezza → Modalità sviluppatore**, attivala e riavvia quando lo chiede. Se la voce non c'è, compare dopo il passo 8: riprova.

### 8. Avvia ZOE

1. In alto al centro di Xcode, accanto a "ZOE", scegli il **tuo iPhone** dall'elenco dei dispositivi.
2. Premi il triangolo **▶︎** (oppure ⌘R).
3. La prima volta può volerci qualche minuto. Se l'iPhone dice "Sviluppatore non autorizzato", vai su **Impostazioni → Generali → VPN e gestione dispositivi**, tocca il tuo account e scegli **Autorizza**, poi premi ▶︎ di nuovo.

ZOE si apre e ti chiede il permesso per le notifiche: tocca **Consenti**.

Da questo momento l'app resta sull'iPhone anche quando scolleghi il cavo. Con l'account a pagamento dura un anno; dopo basta ripetere il passo 8.

### 9. Cosa provare

- **Chat**: scrivi `timer 1 minuto`, poi torna alla schermata Home. ZOE compare nella **Dynamic Island**; tienila premuta per vederla grande, con il pulsante Stop. Allo scadere arriva la notifica.
- **Schermata di blocco**: blocca l'iPhone mentre scorre un timer.
- **Widget**: sulla schermata Home tieni premuto su uno spazio vuoto → **Modifica** → **Aggiungi widget** → cerca **ZOE**. Il pulsante 💧 segna un bicchiere senza aprire l'app. Ci sono anche i widget per la schermata di blocco.
- **Siri**: «Ehi Siri, parla con ZOE» → «ricordami di bere alle 18». Le frasi funzionano con Siri impostata in italiano e a volte serve un minuto dopo l'installazione. Le trovi anche nell'app **Comandi rapidi**.
- **Personalizza** (icona 🎨 in alto a destra): nome, colore, occhi, accessorio, le 13 espressioni.
- **Tocca ZOE**: fa il solletico. Trascina il dito sopra di lei e le pupille ti seguono.

---

## Far girare i test

Il "cervello" che capisce i comandi è nel pacchetto `Packages/ZoeKit` e ha i suoi test, con gli stessi casi della versione PC. Per lanciarli, dal Terminale:

```bash
cd ~/Desktop/ZOE/ios/Packages/ZoeKit
swift test
```

Oppure in Xcode: **File → Open…**, scegli `ios/Packages/ZoeKit/Package.swift`, in alto scegli **My Mac** e premi **⌘U**.

Su GitHub gli stessi test, più la compilazione completa dell'app, girano da soli a ogni modifica della cartella `ios/` (scheda **Actions**, flusso "iOS").

---

## Problemi comuni

| Problema | Soluzione |
|---|---|
| `xcodegen: command not found` | Rifai il passo 2. Se Homebrew aveva mostrato i "Next steps", eseguili. |
| "Failed to register bundle identifier" / "not available" | L'identificativo è già usato da qualcun altro: cambia `ZOE_BUNDLE_PREFIX`, poi `xcodegen` e di nuovo ▶︎. |
| Errore su "App Groups" o "provisioning profile" | Passo 6: controlla il Team in **entrambi** i target e premi la freccina accanto ad App Groups. |
| "No such module 'ZoeCore'" | In Xcode: **File → Packages → Reset Package Caches**, poi ▶︎. |
| La Dynamic Island non compare | Sull'iPhone: **Impostazioni → ZOE → Attività Live** deve essere attivo. |
| Non arrivano le notifiche | **Impostazioni → Notifiche → ZOE → Consenti notifiche**. |
| Siri non capisce la frase | Siri deve essere in italiano. Apri ZOE almeno una volta e controlla nell'app Comandi rapidi che ci siano le azioni di ZOE. |

---

## Come è fatto il progetto

```
ios/
├── project.yml            ← descrizione del progetto per XcodeGen
├── Config.xcconfig        ← il tuo identificativo e il tuo Team (da modificare)
├── Packages/ZoeKit/       ← codice condiviso (pacchetto Swift)
│   ├── Sources/ZoeCore/   ← parser dei comandi, formati, frasi, modelli (traduzione di commands.js)
│   ├── Sources/ZoeUI/     ← la mascotte in SwiftUI (traduzione fedele di zoe.js)
│   ├── Sources/ZoeShared/ ← dati condivisi app↔widget, notifiche, Live Activity
│   └── Tests/             ← test del parser (stessi casi di app/test/commands.test.js)
├── Shared/                ← azioni usate sia dall'app sia dai widget (💧 +1, Stop)
├── ZOE/                   ← l'app: chat, personalizzazione, promemoria, Siri
└── ZOEWidgets/            ← widget e Live Activity (Dynamic Island)
```

- La mascotte è disegnata con gli stessi percorsi e le stesse coordinate di `app/src/renderer/zoe.js`: 13 espressioni, 5 stili di occhi, 12 accessori, 8 colori. Così è identica su PC e su iPhone.
- Il parser dei comandi è una traduzione riga per riga di `app/src/renderer/commands.js`. Se aggiungi un comando su PC, aggiungilo anche in `ZoeCore/Commands.swift` e nei test.
- App e widget si scambiano i dati tramite un **App Group** (`group.<tuo identificativo>`).

## Pubblicare su TestFlight / App Store

Senza Mac: segui [TESTFLIGHT.md](TESTFLIGHT.md), GitHub compila e carica l'app per te.

Dal Mac:

1. In Xcode, in alto scegli **Any iOS Device (arm64)** e poi **Product → Archive**.
2. Nella finestra che si apre: **Distribute App → App Store Connect → Upload**.
3. Su [appstoreconnect.apple.com](https://appstoreconnect.apple.com) crea l'app con lo stesso identificativo e aggiungi i tester in **TestFlight**.

## Cosa manca rispetto al PC (prossimi passi)

- La mosca che ZOE insegue (easter egg).
- Il cervello IA per i comandi non capiti (lo stesso previsto su PC).
- La voce sempre in ascolto "Ehi ZOE": su iPhone non è permessa alle app, al suo posto c'è Siri.
- Sincronizzazione tra PC e iPhone.
