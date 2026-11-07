import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/community.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/messages.dart';

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
  });
  test(
    'Note limit is applied before changing demo state and counts composed emoji',
    () async {
      final s = GpixStore()..startTestDemo();
      final note = List.filled(60, '👨‍👩‍👧‍👦').join();
      await s.act('note', {'text': note, 'audience': 'mutual'});
      expect(s.notes.single['text'], note);
      await expectLater(s.act('note', {'text': '${note}a'}), throwsException);
      expect(s.notes.single['text'], note);
      await s.act('note', {'delete': true});
      expect(s.notes, isEmpty);
      s.dispose();
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    for (final mode in ['light', 'dark']) {
      testWidgets('Profile edit settings and note layouts $width $mode', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = mode;
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        Future<void> capture(String name) async {
          expect(t.takeException(), isNull, reason: name);
          if (width != 390) return;
          for (var i = 0; i < 3; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 80)),
            );
            await t.pump();
          }
          await t.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('QA/profile32').create(recursive: true);
            await File(
              'QA/profile32/$name-$mode.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        for (final page in <String, Widget>{
          'profile': Profile(user: s.myId),
          'edit': const EditProfile(),
          'settings': const Settings(),
          'notes': const Inbox(),
        }.entries) {
          gpixNavigator.currentState!.push(
            MaterialPageRoute(builder: (_) => page.value),
          );
          await t.pumpAndSettle();
          await capture(page.key);
          if (page.key == 'edit') {
            await t.enterText(
              find.byKey(const ValueKey('edit-profile-bio')),
              'Biografia salvata',
            );
            await t.tap(find.text('Salva'));
            await t.pumpAndSettle();
            expect(s.me['bio'], 'Biografia salvata');
            continue;
          }
          if (page.key == 'settings') {
            await t.enterText(
              find.byKey(const ValueKey('settings-search')),
              'privacy',
            );
            await t.pumpAndSettle();
            await t.tap(find.text("Privacy dell'account"));
            await t.pumpAndSettle();
            final old = s.me['private'];
            await t.tap(find.byType(SwitchListTile).first);
            await t.pumpAndSettle();
            expect(s.me['private'], isNot(old));
            expect(
              t.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
              s.me['private'],
            );
            gpixNavigator.currentState!.pop();
            await t.pumpAndSettle();
          }
          gpixNavigator.currentState!.pop();
          await t.pumpAndSettle();
        }
        editNote(t.element(find.byType(HomeShell)));
        await t.pumpAndSettle();
        final note = find.byKey(const ValueKey('note-text'));
        await t.enterText(note, List.filled(61, 'a').join());
        await t.pumpAndSettle();
        expect(t.widget<TextField>(note).controller!.text.length, 60);
        expect(find.text('60/60'), findsOneWidget);
        await capture('note-editor');
        await t.tap(find.text('Condividi').last);
        await t.pumpAndSettle();
        expect(s.notes.single['text'], List.filled(60, 'a').join());
        manageOwnNote(t.element(find.byType(HomeShell)));
        await t.pumpAndSettle();
        await capture('note-menu');
        await t.tap(find.text('Elimina nota'));
        await t.pumpAndSettle();
        expect(s.notes, isEmpty);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
}
