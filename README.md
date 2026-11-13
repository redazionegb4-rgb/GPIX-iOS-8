# GPIX 2.24.0 · Build 102

Sorgenti Flutter per Android e iOS. Il progetto usa Flutter 3.38.9 e l’identificativo `app.gpix.gpix`.

## Android

Da questa cartella, con Flutter, JDK 17 e Android SDK 36 già disponibili:

```sh
bash build-android.sh
```

L’APK viene generato in `build/app/outputs/flutter-apk/app-release.apk` e usa la firma beta GPIX. L’APK distribuito include ARM64, ARMv7 e x86_64. La chiave beta nel progetto serve per aggiornare le installazioni con la stessa firma.

## iOS

Su macOS con Xcode, dalla radice del progetto:

```sh
bash ci_scripts/ci_post_clone.sh
open GPIX.xcworkspace
```

In Xcode scegli lo schema condiviso **GPIX**, il team Apple di GPIX e **Product → Archive**. In Xcode Cloud usa il workspace `GPIX.xcworkspace`, lo schema `GPIX` e il branch configurato nel workflow. Il progetto include il file Firebase client per `app.gpix.gpix`. Xcode Cloud usa il numero della propria build. Su macOS la configurazione locale usa 102.

## Backend

L’archivio `GPIX-Backend2.24.13.zip` contiene il server, il pannello admin e l’aggiornamento per il VPS. La versione 2.24.13 abilita la modifica e l’eliminazione di gruppi, momenti, eventi e discussioni per gli account autorizzati.
