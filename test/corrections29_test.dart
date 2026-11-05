import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/ui/kit.dart';
import 'package:gpix/screens/giphy.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/calls.dart';

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('QA/corrections29').create(recursive: true);
    await File(
      'QA/corrections29/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

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
  testWidgets(
    'Demo requests online GIPHY without key or account and sends selected result',
    (t) async {
      final requests = <http.Request>[];
      String selected = '';
      final s = GpixStore(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'remote',
                  'images': {
                    'fixed_height': {
                      'url': 'https://media.giphy.com/media/sample/giphy.gif',
                    },
                    'original': {
                      'url': 'https://media.giphy.com/media/sample/giphy.gif',
                    },
                  },
                },
              ],
              'pagination': {'total_count': 1},
            }),
            200,
          );
        }),
      )..startTestDemo();
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GiphyGallery(
                  onSelected: (url) => selected = url,
                  onImport: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        requests.single.url.toString(),
        startsWith('https://gpix.cc/giphy/demo'),
      );
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(
        requests.single.url.queryParameters.containsKey('api_key'),
        isFalse,
      );
      await t.tap(find.byKey(const ValueKey('gif-remote')));
      expect(selected, 'https://media.giphy.com/media/sample/giphy.gif');
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('Offline demo GIFs animate, search and can be sent', (t) async {
    final s = GpixStore(
      client: MockClient(
        (r) async => http.Response('{"detail":"offline"}', 503),
      ),
    )..startTestDemo();
    String selected = '';
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GiphyGallery(
                onSelected: (url) => selected = url,
                onImport: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(MediaView), findsNWidgets(6));
    await t.enterText(find.byType(TextField), 'amore');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.byType(MediaView), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('gif-demo-1')));
    expect(selected, 'gif1.gif');
      await s.act('message',{'id':'t0','kind':'gif','media':selected});
      expect(s.thread('t0').rows('messages').last.str('media'),'gif1.gif');
    final bytes = await rootBundle.load('assets/media/gif1.gif');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    expect(codec.frameCount, greaterThan(1));
    codec.dispose();
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  for (final width in [320.0, 390.0, 430.0])
    testWidgets(
      'Inbox reference structure and request acceptance fit at $width',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        final key = GlobalKey();
        s.state['notes'] = [
          for (final id in [s.myId, 'u0', 'u2', 'u3'])
            {
              'owner': id,
              'text': id == s.myId
                  ? 'Prossima tappa? Milano 😄'
                  : id == 'u0'
                  ? 'Monachopsis time'
                  : 'Una nuova giornata ☀',
              'expires': now + 3600,
              'audience': 'mutual',
            },
        ];
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Messaggi'));
        await t.pumpAndSettle();
        expect(find.text('Tutti'), findsNothing);
        expect(find.text('Non letti'), findsNothing);
        expect(find.byTooltip('Fotocamera'), findsNothing);
        expect(find.text('Richieste (1)'), findsOneWidget);
        if (width == 390) await capture(t, key, 'inbox-light');
        await t.tap(find.text('Richieste (1)'));
        await t.pumpAndSettle();
        expect(find.text('Alex Rivera'), findsOneWidget);
        await t.tap(find.text('Accetta'));
        await t.pumpAndSettle();
        expect(s.requestedThreads, isEmpty);
        expect(s.inboxThreads.length, 2);
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        if (width == 390) {
          await s.setAppearance('dark');
          await t.pumpAndSettle();
          await capture(t, key, 'inbox-dark');
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  testWidgets(
    'Short caption moves across entire photo and reaches all four edges',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = GpixStore()..startTestDemo(), key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GpixApp(store: s),
        ),
      );
      await t.pumpAndSettle();
      gpixNavigator.currentState!.push(
        MaterialPageRoute(
          builder: (_) => PostComposer(
            initialFiles: [File('assets/media/post0.jpg').absolute.path],
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Avanti'));
      await t.pumpAndSettle();
      await t.tap(find.text('Testo'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Ciao');
      await t.tap(find.text('Fine'));
      await t.pumpAndSettle();
      final label = find.byKey(const ValueKey('post-draggable-text'));
      expect(t.getSize(label).width, lessThan(100));
      final start = t.getCenter(label);
      await t.drag(label, const Offset(450, -450));
      await t.pumpAndSettle();
      final topRight = t.getRect(label);
      expect(topRight.right, closeTo(390, 2));
      expect(topRight.center.dx - start.dx, greaterThan(120));
      await t.drag(label, const Offset(-450, 450));
      await t.pumpAndSettle();
      final bottomLeft = t.getRect(label);
      expect(bottomLeft.left, closeTo(0, 2));
      expect(bottomLeft.top - topRight.top, greaterThan(200));
      await capture(t, key, 'text-bottom-left');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
