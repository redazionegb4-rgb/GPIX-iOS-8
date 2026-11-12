import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'test/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('GPIX/gallery'),
          (call) async => call.method == 'recent' ? [] : null,
        );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  Future<void> showSignup(WidgetTester t, GpixStore s) async {
    await t.pumpWidget(GpixApp(store: s));
    await t.pumpAndSettle();
    expect(find.text('Esplora la demo'), findsNothing);
    await t.ensureVisible(find.text('Crea un account'));
    await t.tap(find.text('Crea un account'));
    await t.pumpAndSettle();
  }

  Future<void> press(WidgetTester t, String label) async {
    final target = find.text(label);
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, String key, String value) async {
    final target = find.byKey(ValueKey(key));
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.enterText(target, value);
  }

  testWidgets('Registration validates fields without network or server input', (
    t,
  ) async {
    var requests = 0;
    final s = GpixStore(
      client: MockClient((r) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    await showSignup(t, s);
    expect(find.textContaining('Server'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(5));
    await press(t, 'Crea account');
    expect(find.text('Inserisci il tuo nome'), findsOneWidget);
    expect(requests, 0);
    await fill(t, 'auth-Nome', 'Dmb');
    await fill(t, 'auth-Nome utente', 'dmb');
    await fill(t, 'auth-Email', 'bad-email');
    await fill(t, 'auth-password', '123');
    await fill(t, 'auth-confirmation', 'different');
    await press(t, 'Crea account');
    expect(find.text('Inserisci un indirizzo email valido'), findsOneWidget);
    expect(find.text('Le password non coincidono'), findsOneWidget);
    expect(requests, 0);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Registration posts normalized data to gpix.cc and opens Home', (
    t,
  ) async {
    final seed = GpixStore()..startTestDemo();
    final state = jsonDecode(jsonEncode(seed.state));
    seed.dispose();
    final requests = <http.Request>[];
    final s = GpixStore(
      client: MockClient((r) async {
        requests.add(r);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'token': 'registered-token', 'state': state}),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await showSignup(t, s);
    await fill(t, 'auth-Nome', ' Dmb ');
    await fill(t, 'auth-Nome utente', 'DMB.New');
    await fill(t, 'auth-Email', 'DMB@EXAMPLE.COM');
    await fill(t, 'auth-password', 'StrongPass1234');
    await fill(t, 'auth-confirmation', 'StrongPass1234');
    await t.ensureVisible(find.text('Crea account'));
    await t.tap(find.text('Crea account'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Salvare i dati di accesso?'), findsOneWidget);
    await t.tap(find.text('Non ora'));
    await t.pumpAndSettle();
    expect(s.savedAccounts, isEmpty);
    expect(requests.single.url.toString(), 'https://gpix.cc/auth/register');
    final payload = jsonDecode(requests.single.body) as Map;
    expect(payload['username'], 'dmb.new');
    expect(payload['email'], 'dmb@example.com');
    expect(payload['name'], 'Dmb');
    expect(payload.containsKey('confirmation'), isFalse);
    expect(s.demo, isFalse);
    expect(
      s.signedIn,
      isTrue,
      reason: t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' | '),
    );
    expect(find.byType(HomeShell), findsOneWidget);
    expect(await s.vault.read(key: 'gpix.token'), 'registered-token');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  test(
    'Login restores the session after restart and logout clears it',
    () async {
      final seed = GpixStore()..startTestDemo();
      final state = jsonDecode(jsonEncode(seed.state));
      seed.dispose();
      final requests = <http.Request>[];
      final client = MockClient((r) async {
        requests.add(r);
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(
              r.url.path == '/auth/login'
                  ? {'token': 'login-token', 'state': state}
                  : {'state': state},
            ),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final s = GpixStore(client: client);
      s.prefs = await SharedPreferences.getInstance();
      await s.authenticate(login: ' dmb ', password: 'CorrectPassword123');
      expect(s.signedIn, isTrue);
      expect(requests.single.url.toString(), 'https://gpix.cc/auth/login');
      expect((jsonDecode(requests.single.body) as Map)['login'], 'dmb');
      final next = GpixStore(
        client: MockClient(
          (r) async => http.Response.bytes(
            utf8.encode(jsonEncode({'state': state})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await next.init();
      expect(next.signedIn, isTrue);
      expect(next.token, 'login-token');
      await next.logout(remote: false);
      expect(await next.vault.read(key: 'gpix.token'), isNull);
      expect(next.signedIn, isFalse);
      next.dispose();
      s.dispose();
    },
  );
  testWidgets(
    'Saved access survives logout and removing the last profile restores welcome',
    (t) async {
      int revision = 0;
      final store = GpixStore(
        client: MockClient((request) async {
          if (request.url.path != '/auth/login')
            return http.Response('{}', 200);
          final login = (jsonDecode(request.body) as Map)['login'] as String;
          return http.Response(
            jsonEncode({
              'token': 'session-${revision++}',
              'state': {
                'me': {
                  'id': login,
                  'username': login,
                  'name': login,
                  'avatar': '/media/$login.png',
                },
              },
            }),
            200,
          );
        }),
      );
      await store.authenticate(
        login: 'primo',
        password: 'secret-password-one',
        remember: () async => true,
      );
      await store.authenticate(
        login: 'secondo',
        password: 'secret-password-two',
        remember: () async => true,
      );
      expect(store.savedAccounts.map((a) => a['id']), ['secondo', 'primo']);
      expect(
        store.savedAccounts.any((a) => a.containsKey('password')),
        isFalse,
      );
      await t.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.dark),
            home: const Profile(user: 'secondo'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(
        find.descendant(of: find.byType(AppBar), matching: find.text('secondo')),
      );
      await t.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(find.text('Cambia account'), findsOneWidget);
      expect(
        t
            .widgetList<Avatar>(
              find.descendant(of: sheet, matching: find.byType(Avatar)),
            )
            .map((avatar) => avatar.image),
        ['/media/secondo.png', '/media/primo.png'],
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await store.useSavedAccount('primo');
      expect(store.myId, 'primo');
      store.me['avatar'] = '/media/primo-nuovo.png';
      await store.logout();
      expect(store.savedAccounts.first['avatar'], '/media/primo-nuovo.png');
      expect(store.signedIn, isFalse);
      await t.pumpWidget(GpixApp(store: store));
      await t.pumpAndSettle();
      expect(find.text('Accedi con un altro account'), findsOneWidget);
      expect(
        t.widgetList<Avatar>(find.byType(Avatar)).map((avatar) => avatar.image),
        ['/media/primo-nuovo.png', '/media/secondo.png'],
      );
      for (var i = 0; i < 2; i++) {
        final menu = find.byTooltip('Opzioni profilo salvato').first;
        await t.ensureVisible(menu);
        await t.tap(menu);
        await t.pumpAndSettle();
        await press(t, 'Rimuovi accesso salvato');
      }
      expect(store.savedAccounts, isEmpty);
      expect(await store.vault.read(key: 'gpix.savedAccounts.v1'), isNull);
      expect(find.text('Accedi'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('Login errors remain inline and password visibility works', (
    t,
  ) async {
    final requests = <http.Request>[];
    final s = GpixStore(
      client: MockClient((r) async {
        requests.add(r);
        return http.Response('{"detail":"Credenziali non valide"}', 401);
      }),
    );
    await t.pumpWidget(GpixApp(store: s));
    await t.pumpAndSettle();
    await press(t, 'Accedi');
    await fill(t, 'auth-Email o nome utente', 'dmb');
    await fill(t, 'auth-password', 'wrong');
    await t.tap(find.byTooltip('Mostra password'));
    await t.pump();
    expect(
      t
          .widget<TextFormField>(find.byKey(const ValueKey('auth-password')))
          .controller!
          .text,
      'wrong',
    );
    await press(t, 'Accedi');
    expect(find.text('Credenziali non valide'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(requests.single.url.toString(), 'https://gpix.cc/auth/login');
    expect(s.signedIn, isFalse);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Registration duplicate shows backend response and keeps entered values',
    (t) async {
      final s = GpixStore(
        client: MockClient(
          (r) async => http.Response(
            '{"detail":"Email o username già utilizzato"}',
            409,
          ),
        ),
      );
      await showSignup(t, s);
      await fill(t, 'auth-Nome', 'Dmb');
      await fill(t, 'auth-Nome utente', 'dmb');
      await fill(t, 'auth-Email', 'dmb@example.com');
      await fill(t, 'auth-password', 'StrongPass1234');
      await fill(t, 'auth-confirmation', 'StrongPass1234');
      await press(t, 'Crea account');
      expect(find.text('Email o username già utilizzato'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-Nome utente')), findsOneWidget);
      expect(s.demo, isFalse);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  for (final width in [320.0, 390.0, 430.0])
    testWidgets('Auth light/dark and keyboard layouts fit at $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = GpixStore();
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GpixApp(store: s),
        ),
      );
      await t.pumpAndSettle();
      Future<void> capture(String name) async {
        if (width != 390) return;
        await t.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('QA/auth30').create(recursive: true);
          await File(
            'QA/auth30/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('welcome-light');
      await press(t, 'Crea un account');
      await capture('register-light');
      await s.setAppearance('dark');
      await t.pumpAndSettle();
      await capture('register-dark');
      t.view.viewInsets = const FakeViewPadding(bottom: 340);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('auth-confirmation')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pumpWidget(const SizedBox());
      s.dispose();
    });
}
