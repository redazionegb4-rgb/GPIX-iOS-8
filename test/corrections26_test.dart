import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/ui/kit.dart';

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('QA/corrections26').create(recursive: true);
    await File(
      'QA/corrections26/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
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
  });
  testWidgets(
    'Home at offset zero shows refresh feedback and reloads demo on every tap',
    (tester) async {
      final s = GpixStore()..startTestDemo();
      await tester.pumpWidget(GpixApp(store: s));
      await tester.pumpAndSettle();
      for (var i = 1; i <= 2; i++) {
        await tester.tap(find.byTooltip('Home'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
        expect(s.homeRefreshRevision, i);
      }
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('New post gallery editor and publishing fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = (await tester.runAsync(
        () => File('assets/media/post0.jpg').readAsBytes(),
      ))!;
      await tester.runAsync(() async {
        for (final name in ['post0', 'post1']) {
          final ready = Completer<void>();
          final stream = FileImage(
            File('assets/media/$name.jpg').absolute,
          ).resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (image, sync) {
              if (!ready.isCompleted) ready.complete();
            },
            onError: (Object e, StackTrace? stack) {
              if (!ready.isCompleted) ready.completeError(e, stack);
            },
          );
          stream.addListener(listener);
          for (var i = 0; i < 30 && !ready.isCompleted; i++) {
            await tester.pump();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await ready.future.timeout(const Duration(seconds: 2));
          stream.removeListener(listener);
        }
      });
      final copies = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('GPIX/gallery'), (
            call,
          ) async {
            if (call.method == 'recent')
              return [
                {'id': 'one', 'thumbnail': bytes},
                {'id': 'two', 'thumbnail': bytes},
              ];
            final id = (call.arguments as Map)['id'] as String;
            copies.add(id);
            return File(
              'assets/media/${id == 'one' ? 'post0' : 'post1'}.jpg',
            ).absolute.path;
          });
      final s = GpixStore()..startTestDemo();
      final key = GlobalKey();
      await tester.runAsync(() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixScope(
              store: s,
              child: const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: PostComposer(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recent-photo-grid')), findsOneWidget);
      expect(copies, ['one']);
      await tester.tap(find.text('Seleziona'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('gallery-photo-two')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(copies, ['one', 'two']);
      expect(find.text('2/2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gallery-photo-two')));
      await tester.pumpAndSettle();
      expect(find.text('Anteprima foto'), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      if (width == 390) await capture(tester, key, 'post-select');
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
      expect(find.text('Testo'), findsOneWidget);
      expect(find.text('Overlay'), findsOneWidget);
      if (width == 390) await capture(tester, key, 'post-edit');
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
      expect(find.text('Pubblica post'), findsOneWidget);
      expect(find.text('Pubblica'), findsOneWidget);
      if (width == 390) await capture(tester, key, 'post-publish');
      await tester.scrollUntilVisible(
        find.text('Pubblico'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Follower'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('GPIX/gallery'), null);
    });
  }
  test(
    'Poll selection replaces a prior vote rather than counting twice',
    () async {
      final s = GpixStore()..startTestDemo();
      s.post('p0')['style'] = <String, dynamic>{
        'aspect': 1.0,
        'poll': <String, dynamic>{
          'question': 'Dove?',
          'options': ['Roma', 'Milano'],
        },
      };
      await s.act('pollVote', {'id': 'p0', 'choice': 0});
      await s.act('pollVote', {'id': 'p0', 'choice': 1});
      expect(s.post('p0').obj('style').obj('poll')['counts'], [0, 1]);
      s.dispose();
    },
  );
  testWidgets('Profile and navigation icon variants render cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final dark in [false, true])
                    Container(
                      color: dark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 22,
                        runSpacing: 24,
                        children: [
                          for (final icon in [
                            CupertinoIcons.square_grid_2x2,
                            CupertinoIcons.play_rectangle,
                            CupertinoIcons.play_rectangle_fill,
                            CupertinoIcons.repeat,
                            CupertinoIcons.paperplane,
                            CupertinoIcons.chat_bubble_2,
                            CupertinoIcons.chat_bubble_2_fill,
                            CupertinoIcons.chat_bubble,
                          ])
                            GIcon(
                              icon,
                              size: 26,
                              color: dark ? Colors.white : Colors.black,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'icons');
    expect(tester.takeException(), isNull);
  });
}
