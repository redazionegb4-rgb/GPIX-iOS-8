import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/shell.dart';
import 'package:gpix/rebuild/surfaces.dart';
import 'package:gpix/screens/creation_studio.dart';
import 'package:gpix/ui/kit.dart';

Future<void> mount(
  WidgetTester tester,
  GpixStore store,
  Widget screen, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    GpixScope(
      store: store,
      child: MaterialApp(theme: gpixTheme(brightness), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  testWidgets('Feed and floating dock have independent horizontal gestures', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    await mount(tester, store, const SocialShell());
    final dock = find.byKey(const ValueKey('floating-dock'));
    final normalHeight = tester.getSize(dock).height;
    await tester.dragFrom(const Offset(200, 665), const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, lessThan(normalHeight));
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 680));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, normalHeight);
    await tester.dragFrom(const Offset(190, 280), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(find.text('Seguiti'), findsOneWidget);
    await tester.dragFrom(const Offset(190, 280), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(find.text('Gruppi'), findsWidgets);
    await tester.drag(dock, const Offset(-132, 0));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTimeline).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Photo preview opens at the visible slide and can continue swiping',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final sample = Map<String, dynamic>.of(store.posts.first)
        ..['mediaItems'] = ['post0.jpg', 'post1.jpg', 'post2.jpg'];
      await mount(
        tester,
        store,
        Scaffold(
          body: ListView(children: [TimelinePost(post: sample)]),
        ),
      );
      await tester.dragFrom(const Offset(240, 240), const Offset(-270, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      await tester.tapAt(const Offset(180, 240));
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.dragFrom(const Offset(270, 385), const Offset(-205, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Crea keeps the editor and exposes modes by swipe', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    await mount(
      tester,
      store,
      const SocialShell(),
      brightness: Brightness.dark,
    );
    await tester.tap(find.byTooltip('Crea').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Nuovo post'), findsOneWidget);
    await tester.dragFrom(const Offset(204, 772), const Offset(-115, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byTooltip('Chiudi fotocamera'), findsOneWidget);
    expect(find.byType(CreationStudio), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
