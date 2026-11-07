import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/people.dart';
import 'package:gpix/screens/moments.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/screens/calls.dart';

Future<void> capture72(WidgetTester t, GlobalKey boundary, String name) async {
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
    await Directory('QA/build72').create(recursive: true);
    await File('QA/build72/$name.png').writeAsBytes(data!.buffer.asUint8List());
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
      testWidgets('Profile settings activity and groups fit $width in $mode', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = mode;
        s.state['communityVersion'] = 1;
        s.state['socialGroups'] = <J>[
          {
            'id': 'g72',
            'title': 'Un giro a Roma',
            'description': 'Posti del cuore, fotografie e nuove prospettive.',
            'owner': s.myId,
            'created': now,
            'members': 3,
            'joined': true,
            'cover': 'post4.jpg',
          },
        ];
        s.state['socialItems'] = <J>[];
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        if (width == 390) await capture72(t, key, 'home-$mode');
        for (final page in <String, Widget>{
          'profile': Profile(user: s.myId),
          'settings': const Settings(),
          'activity': const Activity(),
          'groups': const Scaffold(body: SafeArea(child: CommunityDirectory())),
          'group-detail': const CommunityGroup(id: 'g72'),
        }.entries) {
          gpixNavigator.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => page.value),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: page.key);
          if (width == 390) await capture72(t, key, '${page.key}-$mode');
          if (page.key == 'profile') {
            expect(find.byKey(const ValueKey('profile-stats')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('profile-identity')),
              findsOneWidget,
            );
            await t.tap(find.text('follower').first);
            await t.pumpAndSettle();
            expect(find.byType(Connections), findsOneWidget);
            gpixNavigator.currentState!.pop();
            await t.pumpAndSettle();
          }
          if (page.key == 'settings') {
            await t.scrollUntilVisible(
              find.text('Account'),
              180,
              scrollable: find.byType(Scrollable).last,
            );
            await t.tap(find.text('Account'));
            await t.pumpAndSettle();
            expect(find.text('Password e sicurezza'), findsOneWidget);
            gpixNavigator.currentState!.pop();
            await t.pumpAndSettle();
          }
          if (page.key == 'groups') {
            await t.enterText(find.byType(TextField), 'inesistente');
            await t.pumpAndSettle();
            expect(find.text('Nessun gruppo trovato'), findsOneWidget);
            await t.enterText(find.byType(TextField), '');
            await t.pumpAndSettle();
            await t.tap(find.text('I tuoi'));
            await t.pumpAndSettle();
            expect(find.byType(CommunityGroupCard), findsOneWidget);
          }
          gpixNavigator.currentState!.pop();
          await t.pumpAndSettle();
        }
        final sections = find.byKey(const ValueKey('home-sections'));
        await t.drag(
          find.byKey(const PageStorageKey('feed')),
          const Offset(0, -180),
        );
        await t.pumpAndSettle();
        final before = t
            .widget<ListView>(find.byKey(const PageStorageKey('feed')))
            .controller!
            .offset;
        await t.drag(sections, Offset(-width * .8, 0));
        await t.pumpAndSettle();
        expect(t.widget<PageView>(sections).controller!.page, closeTo(1, .01));
        expect(
          find.byKey(const PageStorageKey('feed-following')),
          findsOneWidget,
        );
        await t.drag(sections, Offset(-width * .8, 0));
        await t.pumpAndSettle();
        expect(t.widget<PageView>(sections).controller!.page, closeTo(2, .01));
        expect(find.text('Trova il tuo giro.'), findsOneWidget);
        if (width == 390) await capture72(t, key, 'groups-home-$mode');
        await t.tap(find.text('Per te').first);
        await t.pumpAndSettle();
        expect(t.widget<PageView>(sections).controller!.page, closeTo(0, .01));
        expect(
          t
              .widget<ListView>(find.byKey(const PageStorageKey('feed')))
              .controller!
              .offset,
          closeTo(before, 1),
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
  testWidgets(
    'Bottom instant icon shows friends first and last swipe opens camera',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('GPIX/privacy'),
        (_) async => true,
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('GPIX/privacy'),
          null,
        ),
      );
      final s = GpixStore()..startTestDemo();
      final key = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: GpixApp(store: s),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Messaggi'));
      await t.pumpAndSettle();
      await t.tap(find.byType(InstantPile));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
      }
      expect(find.byType(InstantViewer), findsOneWidget);
      expect(find.byType(InstantComposer), findsNothing);
      expect(find.byKey(const ValueKey('instant-deck')), findsOneWidget);
      await capture72(t, key, 'instant-friends');
      await t.drag(
        find.byKey(const ValueKey('instant-deck')),
        const Offset(0, -250),
      );
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 150));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      expect(find.byType(InstantComposer), findsOneWidget);
      expect((await s.instantList()).rows('received'), isEmpty);
      await capture72(t, key, 'instant-camera');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'No friend cards goes directly to capture without opening a dashboard',
    (t) async {
      final s = GpixStore()..startTestDemo();
      s.state['demoInstants'] = [];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: const MaterialApp(home: InstantsPage()),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 100));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      expect(find.byType(InstantComposer), findsOneWidget);
      expect(find.byType(InstantCollectionPage), findsNothing);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
