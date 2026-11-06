import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'store.dart';
import 'firebase_options.dart';
import 'data.dart';
import '../screens/calls.dart' show gpixNavigator;
import '../screens/messages.dart' show Chat;
import '../screens/sessions_instants.dart' show InstantsPage;
import '../screens/social.dart' show PostPage, Profile, Activity;
import '../ui/kit.dart' show open, notice;

@pragma('vm:entry-point')
Future<void> gpixBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: Platform.isIOS ? iosFirebaseOptions : androidFirebaseOptions,
    );
  } catch (_) {}
}

class PushService {
  PushService._();
  static final instance = PushService._();
  static const nativePushAvailable = bool.fromEnvironment(
    'GPIX_NATIVE_PUSH',
    defaultValue: true,
  );
  static const _appleRegistration = MethodChannel('GPIX/pushRegistration');
  static const _permissionRequested = 'gpix.pushPermissionRequested';
  String _session = '', _attemptSession = '';
  Future<String>? _automaticCheck;
  DateTime? _lastAttempt;
  GpixStore? _store;
  StreamSubscription<String>? refresh;
  StreamSubscription<RemoteMessage>? opened, foreground;
  void attach(GpixStore s) {
    if (identical(_store, s)) return;
    _store?.removeListener(_changed);
    _store = s;
    s.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (!nativePushAvailable) return;
    final s = _store;
    if (s == null ||
        s.demo ||
        !s.signedIn ||
        s.preferences['pushEnabled'] == false) {
      _session = '';
      return;
    }
    if (!s.foreground ||
        _automaticCheck != null ||
        _session == s.token ||
        (_attemptSession == s.token &&
            _lastAttempt != null &&
            DateTime.now().difference(_lastAttempt!).inSeconds < 30))
      return;
    _lastAttempt = DateTime.now();
    _attemptSession = s.token;
    _automaticCheck = _register(
      s,
      prompt: false,
    ).catchError((Object _) => '').whenComplete(() => _automaticCheck = null);
  }

  Future<String> enable(GpixStore s) async {
    await _automaticCheck;
    return _register(s, prompt: true);
  }

  Future<String> _register(GpixStore s, {required bool prompt}) async {
    if (!nativePushAvailable || (!Platform.isIOS && !Platform.isAndroid)) {
      return 'Le notifiche push non sono disponibili in questa build.';
    }
    if (s.demo || !s.signedIn) {
      return 'Accedi a un account GPIX per attivare le notifiche.';
    }
    if (s.preferences['pushEnabled'] == false) {
      return 'Attiva Ricevi notifiche su questa schermata e riprova.';
    }
    final session = s.token;
    bool currentSession() =>
        s.token == session && s.preferences['pushEnabled'] != false;
    final cfg = await s.api('/push/config');
    final options = Platform.isIOS
        ? iosFirebaseOptions
        : androidFirebaseOptions;
    if (!cfg.flag('configured')) {
      return 'Il backend GPIX non è ancora configurato per le notifiche.';
    }
    final serverProject = cfg
        .obj(Platform.isIOS ? 'ios' : 'android')
        .str('projectId');
    if (serverProject != options.projectId) {
      return 'La configurazione Firebase dell’app e del server non coincide.';
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: options);
    }
    if (Firebase.app().options.projectId != options.projectId) {
      return 'La configurazione Firebase installata non coincide con questa build.';
    }
    FirebaseMessaging.onBackgroundMessage(gpixBackgroundMessage);
    final messaging = FirebaseMessaging.instance;
    var settings = await messaging.getNotificationSettings();
    final alreadyAllowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    final shouldRequest =
        !alreadyAllowed &&
        (prompt || s.prefs?.getBool(_permissionRequested) != true);
    if (shouldRequest) {
      if (!currentSession() || !s.foreground) {
        return 'Riapri GPIX per completare la registrazione.';
      }
      settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await s.prefs?.setBool(_permissionRequested, true);
    }
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      return 'Consenti le notifiche nelle impostazioni del telefono.';
    if (Platform.isIOS && await messaging.getAPNSToken() == null) {
      if (!currentSession() || !s.foreground) {
        return 'Riapri GPIX per completare la registrazione.';
      }
      await _appleRegistration.invokeMethod<void>('register');
      for (var attempt = 0; attempt < 12 && currentSession(); attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        try {
          await _appleRegistration.invokeMethod<void>('failure');
        } on PlatformException catch (error) {
          if (error.code == 'APNS_3000') {
            return 'Firma iOS senza abilitazione Push Notifications (APNs 3000). '
                'Controlla la capability e il profilo della build TestFlight.';
          }
          return 'Registrazione Apple non riuscita (${error.code}). '
              '${error.message ?? 'Riprova più tardi.'}';
        }
        if (await messaging.getAPNSToken() != null) break;
      }
      if (await messaging.getAPNSToken() == null) {
        return 'Apple non ha ancora restituito il token push. Riprova tra poco.';
      }
    }
    final token = await messaging.getToken();
    if (token == null)
      throw Exception('Registrazione notifiche non riuscita. Riprova.');
    if (!currentSession()) return 'La sessione è cambiata. Riprova.';
    await s.api(
      '/push/device',
      payload: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
    );
    if (!currentSession()) return 'La sessione è cambiata. Riprova.';
    _session = session;
    await refresh?.cancel();
    refresh = messaging.onTokenRefresh.listen((token) {
      if (currentSession()) {
        s
            .api(
              '/push/device',
              payload: {
                'token': token,
                'platform': Platform.isIOS ? 'ios' : 'android',
              },
            )
            .catchError((_) => <String, dynamic>{});
      }
    });
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await opened?.cancel();
    opened = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (currentSession()) unawaited(_open(s, m));
    });
    await foreground?.cancel();
    foreground = FirebaseMessaging.onMessage.listen((m) {
      final c = gpixNavigator.currentContext;
      if (!currentSession()) return;
      if (c != null && !Platform.isIOS) {
        notice(c, m.notification?.body ?? 'Nuova attività GPIX');
      }
      unawaited(s.sync(silent: true));
    });
    final first = await messaging.getInitialMessage();
    if (first != null && currentSession()) unawaited(_open(s, first));
    return 'Notifiche attive su questo dispositivo.';
  }

  Future<void> _open(GpixStore s, RemoteMessage m) async {
    if (!s.signedIn) return;
    final session = s.token;
    await s.sync(silent: true);
    if (s.token != session || s.preferences['pushEnabled'] == false) return;
    final c = gpixNavigator.currentContext;
    if (c == null || !c.mounted) return;
    final ref = m.data['ref'] ?? '', kind = m.data['kind'];
    if (kind == 'announcement') {
      final notification = m.notification;
      if (notification == null) return;
      await showDialog<void>(
        context: c,
        builder: (context) => AlertDialog(
          title: Text(notification.title ?? 'GPIX'),
          content: SingleChildScrollView(child: Text(notification.body ?? '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    } else if (kind == 'instant') {
      open(c, const InstantsPage());
    } else if (kind == 'messageReaction') {
      final thread = s.threads
          .where((t) => t.rows('messages').any((x) => x.str('id') == ref))
          .firstOrNull;
      if (thread != null) open(c, Chat(id: thread.str('id')));
    } else if (kind == 'noteLike') {
      open(c, const Activity());
    } else if (kind == 'message' || kind == 'call') {
      if (s.thread(ref).isNotEmpty) open(c, Chat(id: ref));
    } else if (s.post(ref).isNotEmpty) {
      open(c, PostPage(id: ref));
    } else if (s.user(ref).isNotEmpty) {
      open(c, Profile(user: ref));
    }
  }
}
