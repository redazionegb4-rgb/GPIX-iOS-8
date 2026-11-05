# GPIX Aura Glass · 2.24.0 build 48

Progetto Flutter di GPIX per iOS e Android. Include il codice Dart, gli asset, i progetti nativi e i test.

Aura Glass abbina il Feed Livelli alle Storie e alla barra Incastro. Il Feed mostra l’autore sopra la foto e le azioni in una capsula separata. Le Storie hanno miniature quadrate arrotondate. La barra flottante ha un incavo centrale e il pulsante Crea rialzato. Il tema condiviso usa bianco puro in chiaro e nero puro in scuro, con superfici neutre e accenti blu. Le preferenze di aspetto salvate continuano a essere applicate.

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

Apri `GPIX.xcworkspace` e seleziona lo schema Runner. Usa il Team e il bundle ID esistenti. Per Xcode Cloud, aggiorna il repository con il contenuto della cartella GPIX e mantieni i punti di ingresso `ci_scripts` e `ios/ci_scripts`. Il bootstrap prepara Flutter 3.38.9 e CocoaPods. Per TestFlight, usa 48 come prossimo numero di build Cloud, oppure un numero superiore se 48 è già stato caricato su App Store Connect. Per la build locale serve macOS con Xcode e CocoaPods.
