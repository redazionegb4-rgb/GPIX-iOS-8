import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/screens/messages.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'test/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  test(
    'Group shares, private archive and feedback use authenticated APIs',
    () async {
      final calls = <String>[];
      final s = GpixStore(
        client: MockClient((r) async {
          calls.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer session37');
          if (r.url.path == '/instants/send') {
            final p = jsonDecode(r.body);
            expect(p['audience'], 'close');
            expect(p['recipients'], isEmpty);
            return http.Response('{"id":"i37"}', 200);
          }
          if (r.url.path == '/instants/archive')
            return http.Response('{"items":[]}', 200);
          if (r.url.path.endsWith('archive-photo')) {
            expect(r.method, 'GET');
            return http.Response.bytes([1, 2, 3], 200);
          }
          if (r.url.path.endsWith('feedback')) {
            expect(jsonDecode(r.body)['requestKey'], 'reply37');
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('{"state":{}}', 200);
        }),
      )..token = 'session37';
      expect(
        await s.sendInstant(
          'm',
          [],
          'caption',
          audience: 'close',
          requestKey: 'send37',
        ),
        'i37',
      );
      expect(await s.instantArchive(), isEmpty);
      expect(await s.instantBytes('i37', archive: true), [1, 2, 3]);
      await s.instantFeedback('i37', 'reply', 'Ciao', 'reply37');
      expect(calls, contains('/instants/i37/feedback'));
      s.dispose();
    },
  );
  testWidgets('Camera opens once immediately; no per-person checklist', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    var captures = 0;
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: InstantComposer(
            autoCapture: true,
            capture: () async {
              captures++;
              return null;
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(captures, 1);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Amici'), findsOneWidget);
    await t.ensureVisible(find.text('Amici'));
    await t.pumpAndSettle();
    await t.tap(find.text('Amici'));
    await t.pumpAndSettle();
    expect(find.text('Amici più stretti'), findsOneWidget);
    Navigator.of(t.element(find.text('Amici più stretti'))).pop();
    await t.pumpAndSettle();
    expect(find.text('Galleria'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Inbox has discreet top photo access; pause and resume are persisted',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = GpixStore()..startTestDemo();
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: const Inbox()),
        ),
      );
      await t.pumpAndSettle();
      final pile = find.byType(InstantPile);
      expect(pile, findsOneWidget);
      expect(t.getCenter(pile).dx, greaterThan(300));
      expect(t.getCenter(pile).dy, greaterThan(650));
      await t.longPress(pile);
      await t.pumpAndSettle();
      await t.tap(find.text('Pausa per 24 ore'));
      await t.pumpAndSettle();
      expect(s.instantsPaused, isTrue);
      expect(s.instantPile, isEmpty);
      await t.longPress(pile);
      await t.pumpAndSettle();
      await t.tap(find.text('Riprendi istantanee'));
      await t.pumpAndSettle();
      expect(s.instantsPaused, isFalse);
      expect(s.instantPile, isNotEmpty);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'Viewer remains open beyond 15 seconds and offers reactions and replies',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final item = (await s.instantList()).rows('received').single;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('GPIX/privacy'),
            (c) async => true,
          );
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: InstantViewer(items: [item])),
        ),
      );
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 20));
      expect(find.byType(InstantViewer), findsOneWidget);
      expect(find.byTooltip('Rispondi con un’istantanea'), findsOneWidget);
      expect(find.text('15s'), findsNothing);
      expect((await s.instantList()).rows('received'), isEmpty);
      expect(t.takeException(), isNull);
      await t.tap(find.text('❤️'));
      await t.pumpAndSettle();
      expect(
        s.threads.any(
          (x) => x
              .rows('messages')
              .any((m) => m.str('text').contains('Ha reagito')),
        ),
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'Active capture blocks photo download before it consumes the view',
    (t) async {
      var opened = false;
      final s = GpixStore(
        client: MockClient((r) async {
          opened = true;
          return http.Response.bytes([], 200);
        }),
      )..token = 'session37';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('GPIX/privacy'),
            (c) async => false,
          );
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(
            home: const InstantViewer(
              items: [
                {'id': 'i37', 'username': 'friend'},
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(opened, isFalse);
      expect(find.text('Contenuto protetto'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  for (final width in [320.0, 390.0])
    for (final brightness in Brightness.values) {
      testWidgets('Archive and camera layouts $width $brightness', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        Widget wrap(Widget child) => GpixScope(
          store: s,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: child,
          ),
        );
        await t.pumpWidget(wrap(const InstantArchive()));
        await t.pumpAndSettle();
        expect(find.text('Il tuo prossimo ricordo inizia qui'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(
          wrap(const InstantCollectionPage(autoCapture: false)),
        );
        await t.pumpAndSettle();
        expect(find.text('Dai tuoi amici'), findsOneWidget);
        expect(find.byType(InstantComposer), findsNothing);
        expect(t.takeException(), isNull);
        if (width == 390)
          await t.runAsync(() async {
            final boundary = t.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('QA/instants40').create(recursive: true);
            await File(
              'QA/instants40/hub-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
}
