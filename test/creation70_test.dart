import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/live.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/ui/creation.dart';

Future<void> capture70(WidgetTester t, GlobalKey boundary, String name) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 70)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('QA/build70').create(recursive: true);
    await File('QA/build70/$name.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

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

  for (final width in [320.0, 390.0, 430.0]) {
    for (final mode in ['light', 'dark']) {
      testWidgets('Creation routes and feed are readable at $width in $mode', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('GPIX/gallery'),
              (_) async => [],
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('GPIX/gallery'),
                null,
              ),
        );
        final store = GpixStore()..startTestDemo();
        store.appearance = mode;
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: GpixApp(store: store),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (width == 390) await capture70(t, boundary, 'home-$mode');
        await t.tap(find.byTooltip('Crea').first);
        await t.pumpAndSettle();
        if (width == 390) await capture70(t, boundary, 'create-$mode');
        await t.tap(find.text('Post').hitTestable().first);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pumpAndSettle();
        expect(find.text('Nuovo post'), findsOneWidget);
        expect(find.byType(CreationEmpty), findsOneWidget);
        if (width == 390) await capture70(t, boundary, 'post-empty-$mode');
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();

        final path = File('assets/media/post0.jpg').absolute.path;
        await t.runAsync(
          () => precacheImage(
            FileImage(File(path)),
            t.element(find.byType(HomeShell)),
          ),
        );
        for (final page in <String, Widget>{
          'post-select': PostComposer(initialFiles: [path]),
          'story-edit': Composer(
            kind: 'story',
            editStory: true,
            initialDraft: {
              'id': 'visual-story',
              'kind': 'story',
              'files': [path],
              'text': 'Una giornata da ricordare.',
              'style': {'background': 0},
            },
          ),
          'story-camera': const Composer(kind: 'story'),
          'reel': const Composer(kind: 'reel'),
          'live': const LiveSetup(),
        }.entries) {
          gpixNavigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => page.value),
          );
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: page.key);
          for (final overlay in t.widgetList<MediaToolButton>(
            find.byType(MediaToolButton),
          )) {
            final button = find.descendant(
              of: find.byWidget(overlay),
              matching: find.byType(IconButton),
            );
            expect(
              t.widget<IconButton>(button).style!.backgroundColor!.resolve({}),
              const Color(0xcc111111),
            );
          }
          if (width == 390) await capture70(t, boundary, '${page.key}-$mode');

          if (page.key == 'post-select') {
            await t.tap(find.text('Avanti').hitTestable());
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            if (width == 390) await capture70(t, boundary, 'post-edit-$mode');
            await t.tap(find.text('Avanti').hitTestable());
            await t.pumpAndSettle();
            expect(find.text('Follower'), findsOneWidget);
            expect(find.text('Condividi'), findsOneWidget);
            if (width == 390)
              await capture70(t, boundary, 'post-publish-$mode');
          }
          gpixNavigator.currentState!.pop();
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  }
}
