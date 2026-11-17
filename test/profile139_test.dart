import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/profile_links.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/profile_links.dart';
import 'package:gpix/screens/reel_editor.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  test('The shared theme keeps the common Roboto typography and colors', () {
    final savedPlatform = debugDefaultTargetPlatformOverride;
    try {
      for (final brightness in Brightness.values) {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final android = gpixTheme(brightness);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final iphone = gpixTheme(brightness);

        expect(iphone.platform, android.platform);
        expect(iphone.colorScheme, android.colorScheme);
        expect(iphone.visualDensity, android.visualDensity);
        expect(iphone.textTheme.bodyMedium?.fontFamily, 'GpixRoboto');
        expect(iphone.textTheme.apply(fontFamily: 'Roboto'), android.textTheme);
        expect(
          iphone.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
          android.appBarTheme.titleTextStyle,
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = savedPlatform;
    }
  });

  testWidgets(
    'An iPhone uses the measured Home and Profile typography',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 14 / 17;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final manifest = await rootBundle.loadString('FontManifest.json');
      final fonts = (jsonDecode(manifest) as List).whereType<Map>();
      final roboto = fonts.singleWhere(
        (entry) => entry['family'] == 'GpixRoboto',
      );
      final faces = (roboto['fonts'] as List).whereType<Map>();
      expect(faces.map((entry) => entry['weight']), [
        100,
        300,
        400,
        500,
        700,
        900,
      ]);
      await tester.runAsync(() async {
        final loader = FontLoader('GpixRoboto');
        for (final face in faces) {
          loader.addFont(rootBundle.load(face['asset'] as String));
        }
        await loader.load();
      });

      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      const bio =
          'Un pensiero di oggi\n'
          'Las intenciones y las atenciones no se dicen, se demuestran';
      store.me
        ..['name'] = 'Andrea Russo'
        ..['username'] = 'andrea.rossi'
        ..['bio'] = bio
        ..['followers'] = 822
        ..['links'] = [
          socialLink('threads', 'andrea.rossi', 'andrea.rossi'),
          socialLink('facebook', 'andrea.rossi', 'Andrea Russo'),
          socialLink('instagram', 'andrea.rossi', 'andrea.rossi'),
        ];
      await tester.pumpWidget(GpixApp(store: store));
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('floating-dock'));
      expect(tester.getRect(dock).bottom, 874 - (34 - 12));
      final home = find.text('Per te').last;
      expect(
        MediaQuery.textScalerOf(tester.element(home)).scale(22),
        closeTo(23.03, .1),
      );
      expect(tester.getSize(home).width, inInclusiveRange(56, 61));
      expect(tester.getCenter(home).dx, closeTo(201, 1));
      expect(tester.widget<Text>(home).style?.fontWeight, FontWeight.w700);
      expect(
        Theme.of(tester.element(home)).textTheme.bodyMedium?.fontFamily,
        'GpixRoboto',
      );
      await tester.tap(find.byTooltip('Messaggi').last);
      await tester.pumpAndSettle();
      final messages = find.text('Messaggi').first;
      expect(
        Theme.of(tester.element(messages)).textTheme.bodyMedium?.fontFamily,
        'GpixRoboto',
      );
      await tester.tap(find.byTooltip('Profilo').last);
      await tester.pumpAndSettle();

      final name = tester.widget<Text>(find.text('Andrea Russo').first);
      final count = tester.widget<Text>(find.text('822'));
      final handle = tester.widget<Text>(
        find.descendant(
          of: find.byTooltip('Cambia account'),
          matching: find.text('andrea.rossi'),
        ),
      );
      expect(name.style?.fontSize, 12.5);
      expect(name.style?.fontWeight, FontWeight.w500);
      expect(count.style?.fontSize, 15.6);
      expect(count.style?.fontWeight, FontWeight.w600);
      expect(handle.style?.fontSize, 23);
      expect(handle.style?.fontWeight, FontWeight.w700);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(bio));
      final lines = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: bio.length),
          )
          .map((box) => box.top)
          .toSet();
      expect(lines, hasLength(2));
      final links = find.byType(ProfileLinkChips);
      final add = find.descendant(of: links, matching: find.text('Aggiungi'));
      expect(add.hitTestable(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileLinkChips),
          matching: find.byType(Wrap),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Apri Pulse'), findsNothing);

      final tabs = tester.element(find.byType(TabBar));
      expect(
        ScrollConfiguration.of(tabs).getPlatform(tabs),
        TargetPlatform.iOS,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      await tester.pumpAndSettle();
      expect(MediaQuery.textScalerOf(tabs).scale(14), closeTo(19.6, .01));
      await tester.tap(find.byTooltip('Impostazioni e attività'));
      await tester.pumpAndSettle();
      final settings = tester.element(find.byType(Settings));
      expect(ModalRoute.of(settings), isA<CupertinoPageRoute<dynamic>>());
      expect(Theme.of(settings).textTheme.bodyMedium?.fontFamily, 'GpixRoboto');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'The iPhone reel starts with the same source picker',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.light),
            home: const Composer(kind: 'reel'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final picker = find.byType(ReelSourcePicker);
      expect(picker, findsOneWidget);
      expect(
        find.descendant(of: picker, matching: find.text('Galleria')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: picker, matching: find.text('Registra')),
        findsOneWidget,
      );
      expect(find.text('Nuovo reel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
