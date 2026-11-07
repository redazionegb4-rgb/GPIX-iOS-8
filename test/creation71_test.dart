import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/live.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/screens/moments.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/ui/creation.dart';
import 'package:gpix/ui/kit.dart';

Future<void> capture71(WidgetTester t, GlobalKey boundary, String name) async {
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
    await Directory('QA/build71').create(recursive: true);
    await File('QA/build71/$name.png').writeAsBytes(data!.buffer.asUint8List());
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
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('GPIX/privacy'),
              (_) async => false,
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('GPIX/privacy'),
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
        if (width == 390) await capture71(t, boundary, 'home-$mode');
        await t.tap(find.byTooltip('Crea').first);
        await t.pumpAndSettle();
        if (width == 390) await capture71(t, boundary, 'create-$mode');
        await t.tap(find.text('Post').hitTestable().first);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await t.pumpAndSettle();
        expect(find.text('Nuovo post'), findsOneWidget);
        expect(find.byType(CreationEmpty), findsOneWidget);
        if (width == 390) await capture71(t, boundary, 'post-empty-$mode');
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
          'inbox': const Inbox(),
          'activity': const Activity(),
          'instants': const InstantsPage(),
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
          if (width == 390) await capture71(t, boundary, '${page.key}-$mode');

          if (page.key == 'story-edit') {
            expect(t.getSize(find.byType(StoryCanvas)), Size(width, 844));
            final caption = find.widgetWithText(
              TextField,
              'Aggiungi una didascalia…',
            );
            expect(caption.hitTestable(), findsOneWidget);
            expect(
              t.getRect(caption).bottom,
              lessThan(t.getRect(find.text('La tua storia')).top),
            );
          }
          if (page.key == 'story-camera' || page.key == 'live') {
            expect(t.getSize(find.byType(CreationEmpty)), Size(width, 844));
          }
          if (page.key == 'post-select') {
            await t.tap(find.text('Avanti').hitTestable());
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            if (width == 390) await capture71(t, boundary, 'post-edit-$mode');
            await t.tap(find.text('Avanti').hitTestable());
            await t.pumpAndSettle();
            expect(find.text('Follower'), findsOneWidget);
            expect(find.text('Condividi'), findsOneWidget);
            if (width == 390)
              await capture71(t, boundary, 'post-publish-$mode');
          }
          gpixNavigator.currentState!.pop();
          await t.pumpAndSettle();
        }
        await t.pumpWidget(const SizedBox());
        store.dispose();
      });
    }
  }
  testWidgets(
    'Authorized Moments and social groups appear on Home and open real pages',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      store.state['posts'] = <J>[];
      store.state['communityVersion'] = 1;
      store.state['socialGroups'] = <J>[
        {
          'id': 'g71',
          'title': 'Roma da scoprire',
          'description': 'Le nostre passeggiate e i posti del cuore.',
          'owner': store.myId,
          'created': now + 5,
          'members': 3,
          'joined': true,
        },
      ];
      store.state['socialItems'] = <J>[
        {
          'id': 'm71',
          'kind': 'moment',
          'title': 'Una sera insieme',
          'text': 'Gli scatti di una serata speciale.',
          'author': store.myId,
          'created': now,
          'contributions': [
            {'author': store.myId, 'media': 'post0.jpg'},
          ],
        },
      ];
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GpixApp(store: store),
        ),
      );
      await t.pumpAndSettle();
      final group = find.byKey(const ValueKey('community-feed-group-g71'));
      expect(group, findsOneWidget);
      expect(find.text('Nuovo gruppo'), findsOneWidget);
      await capture71(t, key, 'feed-group-light');
      await t.tap(find.text('Scopri gruppo'));
      await t.pumpAndSettle();
      expect(find.byType(CommunityGroup), findsOneWidget);
      gpixNavigator.currentState!.pop();
      await t.pumpAndSettle();
      final moment = find.byKey(const ValueKey('community-feed-moment-m71'));
      await t.scrollUntilVisible(
        moment,
        350,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('feed')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await capture71(t, key, 'feed-moment-light');
      await t.ensureVisible(find.text('Apri Momento'));
      await t.tap(find.text('Apri Momento'));
      await t.pumpAndSettle();
      expect(find.byType(CommunityDetail), findsOneWidget);
      gpixNavigator.currentState!.pop();
      await t.pumpAndSettle();
      // All private chat threads are separate from socialGroups and never become feed cards.
      expect(
        find
            .byType(CommunityFeedCard)
            .evaluate()
            .every(
              (e) =>
                  (e.widget as CommunityFeedCard).item.str('id') == 'g71' ||
                  (e.widget as CommunityFeedCard).item.str('id') == 'm71',
            ),
        isTrue,
      );
      textDialog(t.element(find.byType(HomeShell)), 'Scrivi una risposta', '');
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Un testo leggibile');
      await capture71(t, key, 'input-light');
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pumpAndSettle();
      expect(find.text('Salva').hitTestable(), findsOneWidget);
      expect(t.getRect(find.text('Salva')).bottom, lessThan(544));
      t.view.resetViewInsets();
      await store.setAppearance('dark');
      await t.pumpAndSettle();
      await capture71(t, key, 'input-dark');
      await t.tap(find.text('Annulla'));
      await t.pumpAndSettle();
      expect(find.text('Scrivi una risposta'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
  testWidgets(
    'Poll sheet validates missing text and returns question and both answers',
    (t) async {
      final s = GpixStore()..startTestDemo();
      J? result;
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await sheet<J>(c, const PollEditor());
                  },
                  child: const Text('Apri sondaggio'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Apri sondaggio'));
      await t.pumpAndSettle();
      await t.tap(find.text('Aggiungi'));
      await t.pumpAndSettle();
      expect(
        find.text('Completa la domanda e le due opzioni.'),
        findsOneWidget,
      );
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'Dove andiamo?');
      await t.enterText(fields.at(1), 'Mare');
      await t.enterText(fields.at(2), 'Montagna');
      await t.tap(find.text('Aggiungi'));
      await t.pumpAndSettle();
      expect(result?.str('question'), 'Dove andiamo?');
      expect(result?.ids('options'), ['Mare', 'Montagna']);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
