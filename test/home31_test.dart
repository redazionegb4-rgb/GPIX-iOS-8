import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';

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
  for (final width in [320.0, 390.0, 430.0]) {
    for (final mode in ['light', 'dark']) {
      testWidgets('Home reference layout and navigation $width $mode', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = mode;
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text('GPIX'), findsNothing);
        expect(find.text('Per te'), findsOneWidget);
        expect(t.takeException(), isNull);
        if (width == 390) {
          for (var i = 0; i < 3; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await t.pump();
          }
          await t.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('QA/home31').create(recursive: true);
            await File(
              'QA/home31/home-$mode.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await t.tap(find.text('Seguiti'));
        await t.pumpAndSettle();
        expect(find.text('Seguiti'), findsOneWidget);
        await t.tap(find.text('Per te'));
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Messaggi').last);
        await t.pumpAndSettle();
        await t.pageBack();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final follow = find.text('Segui').hitTestable();
        if (follow.evaluate().isNotEmpty) {
          await t.tap(follow.first);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
}
