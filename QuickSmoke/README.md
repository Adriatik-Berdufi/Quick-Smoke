# QuickSmoke

App iOS (SwiftUI) per ridurre e smettere di fumare con un approccio pratico:
- timer tra una sigaretta e l'altra
- tracking giornaliero
- badge/record
- modalità emergenza craving
- mini giochi di distrazione
- backup/import dati

## Obiettivo dell'app

QuickSmoke aiuta a:
1. allungare progressivamente il tempo tra una sigaretta e la successiva
2. tenere traccia dei progressi reali (fumate, evitate, streak)
3. offrire strumenti immediati nei momenti critici (respirazione guidata + distrazioni)

## Come funziona

### 1) Setup iniziale (da Impostazioni)
Alla prima apertura l'app apre direttamente la schermata **Impostazioni**.
L'utente imposta:
- sigarette al giorno
- orario sonno
- orario sveglia
- modalità (`Graduale`, `Medio`, `Intenso`)
- costo pacchetto / sigarette per pacchetto
- motivazione personale

Le **ore di sonno** sono calcolate automaticamente da:
`orario sonno -> orario sveglia`.

### 2) Timer principale
Nella dashboard c'è il countdown della prossima sigaretta consentita.

Pulsanti principali:
- `Fumo`
- `Fumo prima`
- `Resisti`
- `Ho voglia di fumare` (apre modalità emergenza)

### 3) Progressione modalità
Riduzione sigarette target:

- **Primo step**
  - Graduale: `-15%`
  - Medio: `-25%`
  - Intenso: `-35%`

- **Dal secondo step in poi**
  - Graduale: `-10%`
  - Medio: `-20%`
  - Intenso: `-30%`

Da queste sigarette target si calcola l'intervallo medio tra sigarette in base alle ore di veglia.

## Schermate principali

### Dashboard
- countdown principale
- obiettivi giornalieri
- statistiche giornaliere
- barra recupero corpo (timeline: 20 min, 8h, 48h, 2 settimane)
- conferma anti-click accidentale su azioni fumo

### Progressi
- grafici separati:
  - sigarette fumate
  - sigarette evitate
- range: `Oggi`, `7 giorni`, `30 giorni`, `6 mesi`, `1 anno`, `Tutto`
- drill-down sui grafici (tap) e ritorno (doppio tap)
- range avanzati visibili solo quando ci sono abbastanza giorni di utilizzo

### Record / Badge
- badge raggiunti
- badge da raggiungere
- record personali
- streak obiettivi giornalieri

### Impostazioni
- modifica parametri sfida
- salvataggio con stato (`Salva` in alto a destra)
- reset sfida con conferma
- export/import backup

## Modalità emergenza craving

Include:
- respirazione guidata
- frase motivazionale casuale
- accesso ai mini giochi di distrazione

## Mini giochi

Attualmente disponibili:
- Tris (con modalità vs CPU)
- Memory
- 2048

## Backup dati

Da Impostazioni:
- **Esporta backup (Condividi)**: genera JSON e apre la share sheet iOS
- **Importa backup**: ripristina da file JSON

## Stack tecnico

- SwiftUI
- Charts
- UserDefaults per persistenza locale profilo/statistiche
- Notifiche locali con `UserNotifications`

## Note

- Il progetto contiene sia `.gitignore` in root repo sia in `QuickSmoke/` per visibilità in Xcode.
- `OnboardingView` è presente nel progetto ma il flusso attuale parte direttamente da `Impostazioni`.
