# Provare ZOE sull'iPhone senza Mac (TestFlight)

Un Mac di GitHub compila ZOE, la firma con il tuo account sviluppatore e la manda su **TestFlight**, l'app di Apple per le versioni di prova. Tu la installi dall'iPhone. Tutti i passi si fanno dal browser del telefono.

Dati del progetto:
- **Team ID:** `A74WU5KVZW`
- **App:** `com.buccino97.zoe`
- **Widget:** `com.buccino97.zoe.widgets`
- **App Group:** `group.com.buccino97.zoe`

---

## A. Registra gli identificativi (una volta sola)

Vai su [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list) (sezione *Certificati, identificatori e profili*).

1. **App Group.** Premi **+** → **App Groups** → Continua.
   - Descrizione: `ZOE`
   - Identificatore: `group.com.buccino97.zoe`

   Premi Continua e poi Registra.
2. **ID dell'app.** Premi **+** → **App IDs** → **App** → Continua.
   - Descrizione: `ZOE`
   - Bundle ID: **Explicit** → `com.buccino97.zoe`
   - Nell'elenco *Capabilities* spunta **App Groups**, premi **Configure** e scegli `group.com.buccino97.zoe`.

   Premi Continua e poi Registra.
3. **ID dei widget.** Ripeti il punto 2 con:
   - Descrizione: `ZOE Widget`
   - Bundle ID: `com.buccino97.zoe.widgets`
   - Anche qui **App Groups** con lo stesso gruppo.

## B. Crea l'app su App Store Connect

Su [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **App** → **+** → **Nuova app**.

| Campo | Cosa mettere |
|---|---|
| Piattaforme | iOS |
| Nome | il nome pubblico, es. `ZOE Assistente`. Deve essere unico su tutto l'App Store; "ZOE" da solo è quasi certamente già preso. Puoi cambiarlo più avanti |
| Lingua primaria | Italiano |
| ID pacchetto | `com.buccino97.zoe` (compare nel menu dopo il passo A) |
| SKU | un codice interno a piacere, es. `zoe-ios` |
| Accesso utenti | Accesso illimitato |

## C. Crea la chiave API

App Store Connect → **Utenti e accessi** → scheda **Integrazioni** → **App Store Connect API** → **Chiavi del team**.

1. La prima volta premi **Richiedi accesso** e accetta.
2. Premi **+** (o **Genera chiave API**).
   - Nome: `GitHub ZOE`
   - Accesso: **Amministratore**. Serve perché GitHub possa creare da solo i certificati di firma.
3. Annota due codici:
   - l'**ID emittente** (Issuer ID), in alto nella pagina: una sequenza lunga con i trattini;
   - l'**ID chiave** (Key ID), nella riga della chiave: 10 caratteri.
4. Premi **Scarica chiave API**. Si può scaricare **una volta sola**. Il file `AuthKey_XXXXXXXXXX.p8` finisce nell'app **File**, cartella *Download*.
5. Per copiarne il testo: nell'app File tieni premuto sul file → **Rinomina** → cambia la fine da `.p8` a `.txt`. Aprilo, tieni premuto sul testo → **Seleziona tutto** → **Copia**. Il testo inizia con `-----BEGIN PRIVATE KEY-----` e finisce con `-----END PRIVATE KEY-----`.

## D. Metti la chiave su GitHub

Apri [github.com/Buccino97/ZOE/settings/secrets/actions](https://github.com/Buccino97/ZOE/settings/secrets/actions). Se dal telefono la pagina non mostra le impostazioni, nel menu di Safari scegli **Richiedi sito desktop**.

Premi **New repository secret** tre volte:

| Name | Secret |
|---|---|
| `ASC_KEY_ID` | l'ID chiave (10 caratteri) |
| `ASC_ISSUER_ID` | l'ID emittente |
| `ASC_KEY_P8` | tutto il testo del file `.p8`, comprese le righe BEGIN e END |

I secret sono cifrati: dopo il salvataggio nessuno può più leggerli, nemmeno tu.

## E. Avvia e installa

1. Apri [github.com/Buccino97/ZOE/actions/workflows/testflight.yml](https://github.com/Buccino97/ZOE/actions/workflows/testflight.yml), tocca l'esecuzione più recente e premi **Re-run all jobs**. Ci vogliono circa 10 minuti.
2. Dopo 10-30 minuti Apple ha elaborato la versione. Su App Store Connect → la tua app → **TestFlight** → **Test interno** → **+**, crea un gruppo e aggiungiti come tester.
3. Sull'iPhone installa l'app **TestFlight** dall'App Store. Apri l'invito che ti arriva per email e premi **Installa**.

Per il test interno non c'è revisione di Apple. Da qui in poi, ogni modifica alla cartella `ios/` produce da sola una nuova versione su TestFlight.

## Se qualcosa va storto

Apri l'esecuzione rossa in **Actions** e mandami uno screenshot dell'errore.

| Errore | Causa probabile |
|---|---|
| `No profiles for 'com.buccino97.zoe'` | Manca il passo A, oppure la chiave non è "Amministratore" |
| `Authentication failed` | Uno dei tre secret è sbagliato. Spesso è `ASC_KEY_P8` incompleto: devono esserci anche le righe BEGIN e END |
| `No suitable application records were found` | Manca il passo B, oppure l'ID pacchetto è diverso |
