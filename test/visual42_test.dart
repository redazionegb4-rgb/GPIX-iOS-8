import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/profile_links.dart';

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
    for (final brightness in Brightness.values)
      testWidgets(
        'Updated requests, instant bubble and chips fit $width $brightness',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final s = GpixStore()..startTestDemo();
          s.seedInstants();
          s.state['requests'] = s.users
              .where((u) => u.str('id') != s.myId)
              .take(5)
              .map((u) => u.str('id'))
              .toList();
          for (final page in <String, Widget>{
            'requests': const Requests(),
            'inbox': const Inbox(),
            'links': const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(18),
                child: ProfileLinkChips(links: [], own: true),
              ),
            ),
          }.entries) {
            final key = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: key,
                child: GpixScope(
                  store: s,
                  child: MaterialApp(
                    theme: ThemeData(
                      brightness: brightness,
                      fontFamily: 'Roboto',
                      useMaterial3: true,
                    ),
                    home: page.value,
                  ),
                ),
              ),
            );
            await t.pump();
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 150)),
            );
            await t.pump(const Duration(milliseconds: 300));
            expect(t.takeException(), isNull);
            if (width == 390)
              await t.runAsync(() async {
                final image =
                    await (key.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 2);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory('QA/corrections42').create(recursive: true);
                await File(
                  'QA/corrections42/${page.key}-${brightness.name}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
          }
          await t.pumpWidget(const SizedBox());
          s.dispose();
        },
      );
}
