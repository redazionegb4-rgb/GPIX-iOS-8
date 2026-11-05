import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/instants.dart';

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
    for (final mode in ['light', 'dark'])
      testWidgets('Updated archive and chat composer $width $mode', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = mode;
        s.seedInstants();
        final row = s.state.rows('demoInstants').first;
        s.state['demoInstants'] = [
          for (var i = 0; i < 6; i++)
            {
              ...row,
              'id': 'archive44-$i',
              'owner': s.myId,
              'created': now - i * 86400,
              'openedBy': [
                {'user': s.other(s.threads.first), 'opened': now - 60},
              ],
            },
        ];
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        final nav = Navigator.of(t.element(find.byType(HomeShell)));
        for (final page in <String, Widget>{
          'archive': const InstantArchive(),
          'chat': Chat(id: s.threads.first.str('id')),
        }.entries) {
          nav.push(MaterialPageRoute(builder: (_) => page.value));
          await t.pumpAndSettle();
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await t.pump();
          expect(t.takeException(), isNull);
          if (page.key == 'chat') {
            expect(find.text('Scrivi…'), findsOneWidget);
            final field = find.byType(TextField).last;
            await t.enterText(
              field,
              'Un messaggio più lungo per provare la barra di scrittura',
            );
            await t.pump();
            expect(find.text('Invia'), findsOneWidget);
            expect(t.takeException(), isNull);
            await t.enterText(field, '');
            await t.pump();
          }
          if (width == 390)
            await t.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('QA/corrections44').create(recursive: true);
              await File(
                'QA/corrections44/${page.key}-$mode.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          nav.pop();
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
}
