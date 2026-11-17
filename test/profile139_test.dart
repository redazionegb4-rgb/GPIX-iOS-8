import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/profile_links.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/surfaces.dart';
import 'package:gpix/screens/profile_links.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  testWidgets('The profile uses the same layout on iPhone and Android', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    addTearDown(store.dispose);
    store.me
      ..['name'] = 'Andrea Russo'
      ..['username'] = 'andrea.rossi'
      ..['bio'] = 'Fotografia e viaggi\nReggio Calabria'
      ..['private'] = true
      ..['links'] = [
        socialLink('threads', 'andrea.rossi', 'andrea.rossi'),
        socialLink('facebook', 'andrea.rossi', 'Andrea Russo'),
        socialLink('instagram', 'andrea.rossi', '@andrea.rossi'),
        socialLink('telegram', 'andrea.rossi', 'Telegram'),
      ];
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    Future<List<Rect>> layout(TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.light),
            home: ProfileHome(key: ValueKey(platform), user: store.myId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final links = find.byType(ProfileLinkChips);
      final editor = find.text('Aggiungi');
      expect(tester.getSize(links).height, 24);
      expect(editor.hitTestable(), findsOneWidget);
      expect(find.byTooltip('Apri Pulse'), findsNothing);
      return [
        tester.getRect(find.byKey(const ValueKey('profile-avatar'))),
        tester.getRect(find.text('follower')),
        tester.getRect(links),
        tester.getRect(find.text('Modifica')),
        tester.getRect(find.text('Nuova')),
        tester.getRect(find.byType(TabBar)),
      ];
    }

    final iphone = await layout(TargetPlatform.iOS);
    final android = await layout(TargetPlatform.android);
    expect(iphone, android);

    final linkScroller = find.descendant(
      of: find.byType(ProfileLinkChips),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(linkScroller).position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(linkScroller, const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(find.text('Aggiungi').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Aggiungi'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileLinks), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Profile links stay usable at a larger text size', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    addTearDown(store.dispose);
    store.me['links'] = [
      socialLink('facebook', 'andrea.rossi', 'Andrea Russo Fotografia'),
      socialLink('instagram', 'andrea.rossi', 'andrea.rossi'),
      socialLink('telegram', 'andrea.rossi', 'Telegram'),
    ];
    tester.view.physicalSize = const Size(320, 790);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      GpixScope(
        store: store,
        child: MaterialApp(
          theme: gpixTheme(
            Brightness.dark,
          ).copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.65)),
            child: child!,
          ),
          home: ProfileHome(user: store.myId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aggiungi').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
