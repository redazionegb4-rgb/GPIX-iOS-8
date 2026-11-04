# GPIX iPhone Swift — 2.24.0, build 54

Apri GPIX.xcodeproj. Non devi creare un workspace, installare CocoaPods o usare Flutter. GPIX.xcworkspace è incluso ma facoltativo. Team B8SC92LPR5 recuperato dal progetto PRISM; se utilizzi un altro account scegli il Team corrispondente. Bundle identifier app.gpix.gpix. Xcode 15.2 o successivo; iOS 17 o successivo.

## Aggiornamenti
Carica il CONTENUTO di GPIX-iOS nello stesso repository iPhone: GPIX.xcodeproj, GPIX, Config e ci_scripts devono restare affiancati. Non caricare lo ZIP come singolo file. Il workflow Xcode Cloud usa schema GPIX e Archive; conserva Team e bundle identifier. Il numero build deve superare l’ultima versione già caricata. Il progetto Android non viene modificato.

## Revisione grafica
Il riferimento è il codice Flutter 2.24, non un nuovo stile autonomo:
- Roboto originale incluso nell’app, font e pesi condivisi fra tutte le schermate; palette ink/muted/soft/violet ripresa da kit.dart.
- Icone vettoriali principali trascritte da icons.dart, con le stesse coordinate e spessore.
- Schermata iniziale distinta da login/registrazione, testi, dimensioni, campi con icone e conferma password dell’originale.
- Raccolta istantanee con titolo Nuovi momenti, scheda creazione a gradiente, filtri Tutte/Da aprire/Le tue, griglia a due colonne raggruppata per amico, card personali con scadenza e collegamento all’archivio. Le anteprime ricevute usano l’endpoint protetto di preview.
- Profilo con avatar di 80 punti, nota sopra la foto, pulsante per creare una storia, link e pulsanti con gli stessi riferimenti di stile.
- Menu Crea come pannello inferiore con righe di 55 punti, invece del menu a comparsa.
- Conservate le correzioni dei media, i caroselli, le impostazioni, la pila istantanee flottante e la navigazione delle versioni precedenti. Le pagine secondarie condividono font, colori, icone e righe senza gruppi di schede standard iOS.

## Verifiche e limiti
Parsing di tutti i 12 sorgenti con compilatore Swift 5.9.2, riferimenti progetto, XML, plist, font registrato e sintassi JavaScript controllati. I 32 sorgenti Dart originali sono stati confrontati byte per byte e lasciati invariati.
Questo ambiente non dispone dell’SDK iOS o di un simulatore Apple. NON è stata eseguita una compilazione Xcode completa né una verifica visiva delle schermate su iPhone. La corrispondenza grafica e funzionale completa con Android non è certificata da questi controlli. Non confondere il parsing con la compilazione dell’app.

Le credenziali Flutter non sono importate: accedi nuovamente oppure usa Esplora la demo. I dati reali usano https://gpix.cc e il backend 2.24 già consegnato. Firebase push è ancora da configurare; chiamate/dirette WebRTC richiedono prova su due dispositivi. iOS può oscurare registrazione/duplicazione e reagire allo screenshot ma non garantisce il blocco del primo screenshot. Le bozze sono locali alla versione Swift.
