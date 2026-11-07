# GPIX 2.24.0 · build 71

- Storia: anteprima a tutto schermo, controlli e pubblicazione sovrapposti, senza pannello bianco inferiore.
- Diretta: anteprima a tutto schermo e avvio sovrapposto; video live esteso al viewport e campo commenti leggibile.
- Unificata anche la modalità Diretta dello studio di creazione.
- Post: card con profondità, media incorniciati, conteggi e attribuzione Mi piace nel feed. Conservati apertura foto, carousel, doppio tocco, pubblico e proporzioni originali.
- Messaggi: nuova gerarchia, conversazioni in card, filtri Tutti / Da leggere / Gruppi, collegamento Istantanee e richieste.
- Istantanee: il pulsante apre la raccolta rinnovata; da qui si aprono le card ricevute e l’archivio privato.
- Attività: filtri reali, richieste evidenziate e raggruppamento temporale; conferma/elimina e lettura invariati.
- Popup: pannelli di scrittura più ampi con gestione tastiera; sondaggio con validazione dei campi.
- Feed: schede navigabili di Momenti e gruppi social restituiti dal server. I gruppi delle chat private non vengono pubblicati nel feed.

## Verifica e compilazione

Il progetto include Android e iOS. L’APK Android è compilato e firmato; la compilazione iOS va eseguita in Xcode su macOS.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Le configurazioni Firebase e i file di firma già presenti sono conservati. Nessun cambiamento al backend è richiesto per i record community già esposti dal backend 2.24.7.
