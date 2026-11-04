## Correzione 50
Il dettaglio archivio riceve item.row, anziché il contenitore IdentifiedRow. Controllati gli altri passaggi sheet/fullScreenCover. Parsing Swift5.9.2 superato; compilazione iOS da verificare.

## Correzioni 49
Scomposti viewer e griglia archivio in espressioni minori; callback istantanee MainActor; permesso microfono asincrono iOS17; cattura immutabile nel timer del registratore. Parsing Swift5.9.2 superato. La compilazione con SDK iOS resta da verificare.

## Correzioni 48
Riordino griglia: concatenazione esplicita di due array, senza operatore unario a inizio riga. Quattro casi del blocco effettivo compilati ed eseguiti con Swift 5.9.2. Aggiornati onChange alla firma iOS 17 e tre callback WebKit alle chiamate asincrone. Parsing dei 12 file riuscito; compilazione con SDK iOS ancora da verificare.

# Correzione 48 — progetto Xcode diretto

Apri **GPIX.xcodeproj**. Non devi creare un workspace né installare strumenti.
Il workspace già incluso è facoltativo. Aggiornamenti: sostituisci il contenuto dello stesso repository GitHub, come per PRISM.

Corretto l’errore nel dizionario degli attributi di disegno del testo in Composer.swift: una closure immediata era separata dalla sua chiamata. Ora usa un oggetto NSShadow esplicito. Tutti i 12 sorgenti superano il parser del compilatore Swift 5.9.2. Conservate le correzioni Build46 di pulsanti e delegate WebKit. Config/App.xcconfig riprende il formato di PRISM e il tuo Team. Il compilatore Linux non include SwiftUI/UIKit: questa verifica non equivale a una build iOS completa.

# GPIX iPhone — Swift / SwiftUI — versione 2.24, build 50

## Apri in Xcode
1. Estrai lo ZIP in una cartella NUOVA. Non sovrapporlo alla vecchia cartella Flutter.
2. Apri GPIX.xcworkspace (oppure GPIX.xcodeproj). Schema e target: GPIX.
3. La firma automatica usa il Team B8SC92LPR5 presente nel tuo progetto PRISM. Se usi un altro account, scegli il relativo Team in Signing & Capabilities. Bundle identifier: app.gpix.gpix, da conservare se corrisponde alla tua app.
4. Per una build locale seleziona un simulatore iOS 17 o un dispositivo generico iOS e usa Product → Build. Non servono Terminale, Homebrew, Ruby, CocoaPods, Flutter o Generated.xcconfig.
5. Per provare senza account tocca “Esplora la demo” all’avvio. Gli account reali usano sempre https://gpix.cc.

Requisiti del sorgente: Xcode 15.2 o successivo; iPhone con iOS 17 o successivo. Il tuo vecchio Xcode non può eseguire direttamente un iPhone con una versione iOS molto più recente del proprio SDK; in quel caso usa TestFlight tramite Cloud.

## GitHub e aggiornamenti
Crea una cartella/repository dedicato alla versione iPhone Swift e carica il CONTENUTO di GPIX-iOS: GPIX.xcodeproj, GPIX.xcworkspace, GPIX, ci_scripts e la documentazione. Non usare il vecchio workspace Runner del progetto Flutter.
Configura una volta Xcode Cloud per il nuovo workspace GPIX.xcworkspace, schema GPIX, azione Archive, ramo principale e post-action TestFlight. Scegli un runner con Xcode 26 e SDK iOS 26 o successivi per le consegne attuali ad Apple. Imposta Next Build Number maggiore dell’ultima build già caricata (almeno 50 per questa consegna).
Da quel momento sostituisci i file con quelli degli ZIP successivi nello STESSO repository e conferma il commit/push. Conserva il tuo Team, il bundle identifier e il workflow. Non devi reinstallare strumenti a ogni aggiornamento.
Non caricare lo ZIP come singolo file: carica i file estratti. Gli eventuali script Flutter rimasti da un vecchio repository non devono essere usati; ci_post_clone.sh in questa consegna non installa nulla.

## Contenuti
Interfaccia SwiftUI, login/registrazione/recupero/verifica email, demo locale, feed e caroselli, storie e raccolte, reel verticali, profili/modifica/link social e sito, richieste con segui anche tu, commenti con eliminazione e nascondi, note 60 caratteri/24 ore, chat con vocali/foto/GIF/reazioni/risposte/modifica/eliminazione, presenza e digitazione, richieste nascoste, scadenza dopo lettura, gruppi, privacy, dispositivi, editor Core Image (20 filtri e 12 regolazioni), testo trascinabile, ritaglio e bozze persistenti, musica dal catalogo del server, istantanee con anteprime/visualizzazione/archivio/contatori/riepilogo, chiamate e dirette tramite WebRTC incorporato per evitare dipendenze esterne.
Le informazioni e i contenuti reali vengono dal backend 2.24 già consegnato. Non occorre un nuovo APK né un aggiornamento backend per il solo passaggio di interfaccia a Swift. Le credenziali salvate da Flutter non vengono migrate: accedi nuovamente nell’app Swift.

## Verifica effettuata e stato della consegna
Sono stati eseguiti il parsing con il compilatore ufficiale Swift 5.9.2 (stessa versione linguaggio di Xcode 15.2), controlli strutturali progetto/workspace/risorse, sintassi JavaScript WebRTC e test locali dei payload contro il backend. Il parsing NON è una compilazione SwiftUI e i test API NON sono test dell’interfaccia iPhone.
Non sono disponibili Mac/Xcode o il tuo account Apple in questo ambiente: questo ZIP è il PROGETTO SORGENTE, non un IPA compilato, e non è ancora una build iOS verificata. La prima compilazione Xcode/Cloud, la firma e la resa grafica su dispositivo restano da controllare. Non è stata verificata una corrispondenza grafica e funzionale completa con Android.

Limiti espliciti di questa prima riscrittura:
- Le schermate e le animazioni sono ricostruite in SwiftUI; non sono state confrontate pixel per pixel con Flutter su iPhone.
- iOS permette di oscurare quando rileva registrazione/duplicazione e dopo la notifica di screenshot; non è garantito impedire il primo screenshot. Il viewer nasconde anche quando l’app lascia il primo piano. La protezione non è DRM.
- Le chiamate/dirette usano WebRTC in un componente WKWebView all’interno delle schermate Swift. Audio/video, autorizzazioni e interoperabilità con Android devono essere provati su due dispositivi. Non c’è CallKit o ricezione chiamate a processo chiuso.
- Push Firebase native non attivate, come concordato in attesa della configurazione.
- Le bozze nuove sono locali alla versione Swift e non importano quelle Flutter. Non vengono salvate automaticamente durante l’arresto forzato; il pulsante Salva bozza è sempre disponibile.
- Il catalogo musicale è esclusivamente quello autorizzato e configurato dal server, non il catalogo commerciale di Instagram.

## Android
APK 2.24 originale lasciato invariato. SHA-256:
f418e058c8897d154f735ae503a9568bc2766debaf47702e60cb3e9977c5dbac
