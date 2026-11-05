# GPIX Aura Glass · 2.24.0 build 46

Progetto Flutter di GPIX per iOS e Android. Include il codice Dart, gli asset, i progetti nativi e i test.

Aura Glass usa superfici azzurro ghiaccio, bordi luminosi e accenti blu e lilla. Il Feed ha il marchio GPIX nell’intestazione, con accesso ad Attività, Messaggi e ai filtri Per te e Seguiti. La barra fluttuante raccoglie Home, Cerca, Crea, Reel e Profilo. Il tema chiaro è predefinito per le nuove installazioni. Le preferenze di aspetto già salvate continuano a essere applicate.

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

Apri `GPIX.xcworkspace` e seleziona lo schema Runner. Usa il Team e il bundle ID esistenti. Per Xcode Cloud, aggiorna il repository con il contenuto della cartella GPIX e mantieni i punti di ingresso `ci_scripts` e `ios/ci_scripts`. Il bootstrap prepara Flutter 3.38.9 e CocoaPods. Per TestFlight, usa un numero di build Cloud superiore all’ultimo già caricato su App Store Connect. Per la build locale serve macOS con Xcode e CocoaPods.
