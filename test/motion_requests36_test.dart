import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/ui/entrance.dart';

void main() {
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
  for (final width in [320.0, 390.0])
    for (final brightness in Brightness.values) {
      testWidgets(
        'Requests match empty reference and hidden requests $width $brightness',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final s = GpixStore()..startTestDemo();
          s.state['threads'] = [];
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: GpixScope(
                store: s,
                child: MaterialApp(
                  theme: ThemeData(
                    brightness: brightness,
                    fontFamily: 'Roboto',
                  ),
                  home: const MessageRequests(),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.text('Richieste nascoste'), findsOneWidget);
          expect(
            find.text('Nessuna richiesta di messaggi recente'),
            findsOneWidget,
          );
          final center = t.getCenter(
            find.text('Nessuna richiesta di messaggi recente'),
          );
          expect((center.dx - width / 2).abs(), lessThan(1));
          expect(t.takeException(), isNull);
          if (width == 390) {
            await t.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('QA/requests36').create(recursive: true);
              await File(
                'QA/requests36/requests-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await t.tap(find.text('Richieste nascoste'));
          await t.pumpAndSettle();
          expect(find.text('Nessuna richiesta nascosta'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pageBack();
          await t.pumpAndSettle();
          await t.tap(find.text('Mostra tutto'));
          await t.pumpAndSettle();
          expect(find.text('Nessuna richiesta di messaggi'), findsOneWidget);
          await t.pumpWidget(const SizedBox());
          s.dispose();
        },
      );
    }
  testWidgets(
    'Old requests are recoverable and hidden requests can be accepted',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final peer = s.users.firstWhere((u) => u.str('id') != s.myId).str('id');
      s.state['following'] = [];
      s.state['threads'] = [
        {
          'id': 'old',
          'members': [s.myId, peer],
          'messages': [
            {
              'id': 'oldmsg',
              'author': peer,
              'text': 'Old request',
              'created': now - 31 * 86400,
            },
          ],
        },
        {
          'id': 'hidden',
          'requestDecision': 'hidden',
          'members': [s.myId, peer],
          'messages': [
            {
              'id': 'hiddenmsg',
              'author': peer,
              'text': 'Hidden request',
              'created': now,
            },
          ],
        },
      ];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: const MessageRequests()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Old request'), findsNothing);
      await t.tap(find.text('Mostra tutto'));
      await t.pumpAndSettle();
      expect(find.textContaining('Old request'), findsOneWidget);
      await t.tap(find.text('Richieste nascoste'));
      await t.pumpAndSettle();
      expect(find.textContaining('Hidden request'), findsOneWidget);
      await t.tap(find.text('Accetta'));
      await t.pumpAndSettle();
      expect(s.hiddenRequests, isEmpty);
      expect(s.inboxThreads.any((v) => v.str('id') == 'hidden'), isTrue);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('Bottom navigation compacts down and expands on reverse scroll', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(GpixApp(store: s));
    await t.pumpAndSettle();
    final bar = find.byKey(const ValueKey('floating-navigation'));
    final full = t.getSize(bar);
    await t.dragFrom(const Offset(190, 650), const Offset(0, -350));
    await t.pumpAndSettle();
    final small = t.getSize(bar);
    expect(small.width, lessThan(full.width));
    expect(small.height, 64);
    await t.dragFrom(const Offset(190, 350), const Offset(0, 130));
    await t.pumpAndSettle();
    expect(t.getSize(bar), full);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Form motion restarts on stage change and reduced motion is immediate',
    (t) async {
      Widget screen(Object stage, {bool reduced = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: EntranceMotion(stage: stage, child: const Text('Form')),
        ),
      );
      await t.pumpWidget(screen('login'));
      await t.pumpAndSettle();
      await t.pumpWidget(screen('register'));
      await t.pump();
      expect(
        t
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('Form'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        lessThan(1),
      );
      await t.pumpAndSettle();
      await t.pumpWidget(screen('login', reduced: true));
      await t.pump();
      expect(
        t
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('Form'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
    },
  );
}
