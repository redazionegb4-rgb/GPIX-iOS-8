import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:gpix/main.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/photo_effects.dart';

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  for (var i = 0; i < 4; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.runAsync(() async {
    final img =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory('QA/corrections27').create(recursive: true);
    await File(
      'QA/corrections27/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    img.dispose();
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
  test(
    'Every photo adjustment changes exported pixels and all filters are distinct',
    () async {
      final args = <String, dynamic>{
        'path': File('assets/media/post0.jpg').absolute.path,
        'aspect': .8,
        'limit': 100,
        'filter': 'Originale',
      };
      final baseline = await processPhoto(args);
      for (final adjustment in photoAdjustments) {
        final image = await processPhoto({
          ...args,
          'adjustments': {adjustment: 60},
        });
        expect(image, isNot(orderedEquals(baseline)), reason: adjustment);
      }
      final signatures = <String>{};
      for (final filter in photoFilters.keys) {
        final image = await processPhoto({...args, 'filter': filter});
        signatures.add(image.toString());
      }
      expect(signatures.length, photoFilters.length);
    },
  );
  test('Text PNG is composited at requested position', () async {
    final temp = await Directory.systemTemp.createTemp('gpix27-caption');
    try {
      final stamp = im.Image(width: 100, height: 30, numChannels: 4);
      im.fill(stamp, color: im.ColorRgba8(255, 0, 0, 255));
      // A known stamp tests actual export composition, independent of fonts.
      final png = im.encodePng(stamp);
      final args = <String, dynamic>{
        'path': File('assets/media/post0.jpg').absolute.path,
        'aspect': 1,
        'filter': 'Originale',
        'output': '${temp.path}/photo.jpg',
        'captionPng': const Base64Codec().encode(png),
        'textWidth': .3,
        'textX': 1.0,
        'textY': 0.0,
      };
      final path = await renderPostPhoto(args);
      final output = im.decodeJpg(await File(path).readAsBytes())!;
      final pixel = output.getPixel((output.width * .85).round(), 10);
      expect(pixel.r, greaterThan(220));
      expect(pixel.g, lessThan(30));
    } finally {
      await temp.delete(recursive: true);
    }
  });
  testWidgets(
    'Dark chat composer and profile tabs fit actual stretched constraints',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      store.appearance = 'dark';
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GpixApp(store: store),
        ),
      );
      await t.pumpAndSettle();
      for (final entry in <String, Widget>{
        'chat-dark': Chat(id: store.threads.first.str('id')),
        'inbox-dark': const Inbox(),
        'profile-dark': Profile(user: store.myId),
      }.entries) {
        gpixNavigator.currentState!.push(
          MaterialPageRoute(builder: (_) => entry.value),
        );
        await t.pumpAndSettle();
        if (entry.key == 'chat-dark') {
          final field = find.widgetWithText(TextField, 'Scrivi…');
          expect(field, findsOneWidget);
          final containers = t.widgetList<Container>(
            find.ancestor(of: field, matching: find.byType(Container)),
          );
          expect(
            containers.any(
              (w) =>
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).gradient is LinearGradient,
            ),
            isTrue,
          );
        }
        await capture(t, key, entry.key);
        expect(t.takeException(), isNull);
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
      }
      await t.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets('Text drags on image and adjustment sheet cancels changes', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    final key = GlobalKey();
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
    await t.enterText(find.byType(TextField), 'Una nuova storia');
    await t.tap(find.text('Fine'));
    await t.pumpAndSettle();
    final text = find.byKey(const ValueKey('post-draggable-text'));
    final before = t.getCenter(text);
    await t.drag(text, const Offset(0, -90));
    await t.pumpAndSettle();
    expect(t.getCenter(text).dy, lessThan(before.dy - 50));
    await capture(t, key, 'editor-text');
    await t.tap(find.text('Modifica'));
    await t.pumpAndSettle();
    await capture(t, key, 'editor-adjustments');
    await t.drag(find.byType(Slider).last, const Offset(70, 0));
    await t.pump();
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text('Filtri'));
    await t.pumpAndSettle();
    await capture(t, key, 'editor-filters');
    await t.tap(find.text('Fine'));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
