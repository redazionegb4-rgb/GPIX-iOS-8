import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'store.dart';
import 'data.dart';
import '../screens/calls.dart' show gpixNavigator;
import '../screens/messages.dart' show Chat;
import '../screens/sessions_instants.dart' show InstantsPage;
import '../screens/social.dart' show PostPage, Profile, Activity;
import '../ui/kit.dart' show open, notice;

@pragma('vm:entry-point')
Future<void> gpixBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class PushService {
  PushService._();
  static final instance = PushService._();
  static const nativePushAvailable = bool.fromEnvironment(
    'GPIX_NATIVE_PUSH',
    defaultValue: true,
  );
  String _session = '';
  bool _checking = false;
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
    if (s == null || s.demo || !s.signedIn || s.me['emailVerified'] == false) {
      _session = '';
      return;
    }
    if (_checking ||
        _session == s.token ||
        (_lastAttempt != null &&
            DateTime.now().difference(_lastAttempt!).inSeconds < 30))
      return;
    _lastAttempt = DateTime.now();
    _checking = true;
    enable(s, prompt: false)
        .catchError((Object e) => e.toString())
        .whenComplete(() => _checking = false);
  }

  Future<String> enable(GpixStore s, {bool prompt = true}) async {
    if (!nativePushAvailable)
      return 'Le notifiche push non sono incluse in questo APK di prova. Richiedono una nuova build nativa con Firebase.';
    if (s.demo) return 'Accedi a un account GPIX per attivare le notifiche.';
    final cfg = await s.api('/push/config');
    final options = cfg.obj(Platform.isIOS ? 'ios' : 'android');
    if (!cfg.flag('configured') || options.isEmpty)
      return 'Le notifiche devono essere configurate dall’amministratore.';
    if (Firebase.apps.isEmpty)
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: options.str('apiKey'),
          appId: options.str('appId'),
          messagingSenderId: options.str('messagingSenderId'),
          projectId: options.str('projectId'),
          iosBundleId: options.str('iosBundleId').isEmpty
              ? null
              : options.str('iosBundleId'),
        ),
      );
    FirebaseMessaging.onBackgroundMessage(gpixBackgroundMessage);
    final messaging = FirebaseMessaging.instance;
    final settings = prompt
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await messaging.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional)
      return 'Consenti le notifiche nelle impostazioni del telefono.';
    if (Platform.isIOS && await messaging.getAPNSToken() == null) {
      return 'Attendi la registrazione Apple e riprova tra poco.';
    }
    final token = await messaging.getToken();
    if (token == null)
      throw Exception('Registrazione notifiche non riuscita. Riprova.');
    await s.api(
      '/push/device',
      payload: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
    );
    _session = s.token;
    await refresh?.cancel();
    refresh = messaging.onTokenRefresh.listen((token) {
      if (s.signedIn && !s.demo) {
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
    opened = FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(s, m));
    await foreground?.cancel();
    foreground = FirebaseMessaging.onMessage.listen((m) {
      final c = gpixNavigator.currentContext;
      if (c != null && s.signedIn) {
        notice(c, m.notification?.body ?? 'Nuova attività GPIX');
        s.sync();
      }
    });
    final first = await messaging.getInitialMessage();
    if (first != null) await _open(s, first);
    return 'Notifiche attive su questo dispositivo.';
  }

  Future<void> _open(GpixStore s, RemoteMessage m) async {
    if (!s.signedIn) return;
    await s.sync();
    final c = gpixNavigator.currentContext;
    if (c == null || !c.mounted) return;
    final ref = m.data['ref'] ?? '', kind = m.data['kind'];
    if (kind == 'instant') {
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
