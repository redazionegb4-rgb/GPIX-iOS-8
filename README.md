# GPIX Aura Glass · 2.24.0 build 61

Progetto Flutter di GPIX per iOS e Android. Include il codice Dart, gli asset, i progetti nativi e i test.

Aura Glass abbina il Feed Livelli alle Storie e alla barra Incastro. Il Feed mostra l’autore sopra la foto e le azioni in una capsula separata. Le Storie hanno miniature quadrate arrotondate. La barra flottante ha un incavo centrale e il pulsante Crea rialzato. Il tema condiviso usa bianco puro in chiaro e nero puro in scuro, con superfici neutre e accenti blu. Le preferenze di aspetto salvate continuano a essere applicate.

La build 51 introduce la barra flottante compatta e mostra lo stato di scrittura o registrazione audio nella lista Messaggi e sopra il campo di scrittura della chat.

La build 52 aggiorna Attività e Cerca e apre un nuovo pannello di creazione a schermo intero.

La build 53 ridisegna Attività, aggiunge lo scorrimento tra le modalità di creazione e mostra l’ultimo accesso su una riga dedicata nella chat. La trascrizione dei vocali è manuale, in italiano e sul dispositivo. Su Android richiede Android 13 o successivo e un servizio locale compatibile con i file audio. Su iOS richiede l’autorizzazione al riconoscimento vocale e il supporto del dispositivo per l’italiano.

La build 54 aggiorna il profilo con anteprime rettangolari delle storie in evidenza, riorganizza Impostazioni e attività in sei aree e introduce i campi in linea in Modifica profilo. Il menu Condividi profilo è ancorato al pulsante.

La build 55 sposta i contatori accanto all’avatar e aggiorna l’editor dei collegamenti con selettore della piattaforma e anteprima.

La build 56 separa le storie in evidenza dalle schede dei post e mostra i social in una griglia nell’editor dei collegamenti.

La build 57 usa accenti blu, sposta Esci nel piè di pagina delle impostazioni e aggiorna le proporzioni delle foto nel profilo e nel feed.

La build 58 mostra le foto singole a tutta larghezza nel feed, anche quando sono più alte del formato 3:4.

La build 59 abilita Firebase nelle build Xcode Cloud e mostra l’esito della registrazione in Notifiche push. Gli annunci aperti dalla notifica mostrano titolo e messaggio dentro GPIX. Consulta la guida nel pacchetto Sito 4.1 e Backend 2.24.2 per configurare FCM e provare la consegna.

La build 60 include i file client Firebase Android e iOS e verifica che il progetto configurato sul server coincida con quello dell’app. Le credenziali di invio e la chiave APNs si configurano separatamente nel pannello GPIX e in Firebase.

## Verifica locale

Dalla cartella `GPIX`, con Flutter 3.38.9 nel PATH:

```sh
flutter pub get
flutter analyze lib
flutter test
```

La build 61 richiede un account per entrare e registra automaticamente le notifiche dopo l’accesso, se autorizzate dal dispositivo.

## Android

Su una macchina configurata con Android SDK, esegui `bash build-android.sh` dalla cartella del progetto. L’APK release beta viene creato in `build/app/outputs/flutter-apk/app-release.apk`.

## iOS e Xcode Cloud

Apri `GPIX.xcworkspace` e seleziona lo schema Runner. Usa il Team e il bundle ID esistenti. Per Xcode Cloud, aggiorna il repository con il contenuto della cartella GPIX e mantieni i punti di ingresso `ci_scripts` e `ios/ci_scripts`. Il bootstrap prepara Flutter 3.38.9 e CocoaPods. Per TestFlight, usa 61 come prossimo numero di build Cloud, oppure un numero superiore se 61 è già stato caricato su App Store Connect. Per la build locale serve macOS con Xcode e CocoaPods.

### File Firebase richiesto in Xcode Cloud

Il file client `ios/Runner/GoogleService-Info.plist` deve essere presente nel
commit che Xcode Cloud compila. Verifica il branch nel workflow e, dalla
radice del repository iOS, esegui `git ls-files -- ios/Runner/GoogleService-Info.plist`.
Se il file c’è sul disco ma è ancora ignorato da una configurazione Git
locale, aggiungilo esplicitamente con `git add -f -- ios/Runner/GoogleService-Info.plist`.
Il JSON privato del service account e la chiave APNs .p8 restano separati.
