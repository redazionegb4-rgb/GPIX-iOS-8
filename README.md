# GPIX Aura Glass · 2.24.0 build 53

Progetto Flutter di GPIX per iOS e Android. Include il codice Dart, gli asset, i progetti nativi e i test.

Aura Glass abbina il Feed Livelli alle Storie e alla barra Incastro. Il Feed mostra l’autore sopra la foto e le azioni in una capsula separata. Le Storie hanno miniature quadrate arrotondate. La barra flottante ha un incavo centrale e il pulsante Crea rialzato. Il tema condiviso usa bianco puro in chiaro e nero puro in scuro, con superfici neutre e accenti blu. Le preferenze di aspetto salvate continuano a essere applicate.

La build 51 introduce la barra flottante compatta e mostra lo stato di scrittura o registrazione audio nella lista Messaggi e sopra il campo di scrittura della chat.

La build 52 aggiorna Attività e Cerca e apre un nuovo pannello di creazione a schermo intero.

La build 53 ridisegna Attività, aggiunge lo scorrimento tra le modalità di creazione e mostra l’ultimo accesso su una riga dedicata nella chat. La trascrizione dei vocali è manuale, in italiano e sul dispositivo. Su Android richiede Android 13 o successivo e un servizio locale compatibile con i file audio. Su iOS richiede l’autorizzazione al riconoscimento vocale e il supporto del dispositivo per l’italiano.

## Verifica locale

Dalla cartella `GPIX`, con Flutter 3.38.9 nel PATH:

```sh
flutter pub get
flutter analyze lib
flutter test
```

Per esplorare i flussi con dati locali, usa la modalità demo dalla schermata iniziale.

## Android

Su una macchina configurata con Android SDK, esegui `bash build-android.sh` dalla cartella del progetto. L’APK release beta viene creato in `build/app/outputs/flutter-apk/app-release.apk`.

## iOS e Xcode Cloud

Apri `GPIX.xcworkspace` e seleziona lo schema Runner. Usa il Team e il bundle ID esistenti. Per Xcode Cloud, aggiorna il repository con il contenuto della cartella GPIX e mantieni i punti di ingresso `ci_scripts` e `ios/ci_scripts`. Il bootstrap prepara Flutter 3.38.9 e CocoaPods. Per TestFlight, usa 53 come prossimo numero di build Cloud, oppure un numero superiore se 53 è già stato caricato su App Store Connect. Per la build locale serve macOS con Xcode e CocoaPods.
