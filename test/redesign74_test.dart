import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/ui/kit.dart';

Future<void> shot74(WidgetTester t, GlobalKey key, String name) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 70)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final im =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    await Directory('QA/build77').create(recursive: true);
    await File('QA/build77/$name.png').writeAsBytes(data!.buffer.asUint8List());
    im.dispose();
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
  for (final theme in ['light', 'dark']) {
    testWidgets(
      'Profile note is above avatar and instant access is tucked at bottom right $theme',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = theme;
        await s.act('note', {'text': 'Ciao', 'audience': 'mutual'});
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        gpixNavigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => Profile(user: s.myId)),
        );
        await t.pumpAndSettle();
        final bubble = find.byKey(const ValueKey('profile-note'));
        final avatar = find.byWidgetPredicate(
          (w) => w is Avatar && w.size == 80,
        );
        expect(
          t
              .getBottomLeft(
                find.descendant(
                  of: bubble,
                  matching: find.byKey(const ValueKey('note-bubble-body')),
                ),
              )
              .dy,
          lessThan(t.getTopLeft(avatar.first).dy),
        );
        final body = find.descendant(
          of: bubble,
          matching: find.byKey(const ValueKey('note-bubble-body')),
        );
        expect(
          (t.getCenter(body).dy - t.getCenter(find.text('Ciao').first).dy)
              .abs(),
          lessThan(1),
        );
        await shot74(t, key, 'profile-$theme');
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        await t.tap(find.byTooltip('Messaggi'));
        await t.pumpAndSettle();
        expect(find.byType(Inbox), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.byType(InstantPile),
          ),
          findsNothing,
        );
        expect(find.byType(InstantPile), findsOneWidget);
        expect(t.widget<InstantPile>(find.byType(InstantPile)).docked, isTrue);
        final front = find.byKey(const ValueKey('instant-dock-front'));
        expect(t.getSize(front).width, 82);
        expect(t.getSize(front).height, 104);
        expect(t.getRect(front).right, greaterThan(390));
        expect(t.getCenter(find.byType(InstantPile)).dx, greaterThan(330));
        expect(t.getCenter(find.byType(InstantPile)).dy, greaterThan(650));
        await shot74(t, key, 'inbox-$theme');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
    testWidgets(
      'New auth scenes animate once and retain form on toggle $theme',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..appearance = theme;
        final key = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        await shot74(t, key, 'welcome-$theme');
        await t.tap(find.text('Accedi'));
        await t.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(2));
        await shot74(t, key, 'login-$theme');
        await t.ensureVisible(find.text('Non hai un account? Registrati'));
        await t.tap(find.text('Non hai un account? Registrati'));
        await t.pumpAndSettle();
        expect(find.byType(TextFormField), findsNWidgets(5));
        final scroll = find.byType(Scrollable).first;
        await t.drag(scroll, const Offset(0, 1000));
        await t.pumpAndSettle();
        await shot74(t, key, 'register-$theme');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }
}
