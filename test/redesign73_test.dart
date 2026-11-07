import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/people.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/screens/calls.dart';

Future<void> capture73(WidgetTester t, GlobalKey boundary, String name) async {
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
    await Directory('QA/build73').create(recursive: true);
    await File('QA/build73/$name.png').writeAsBytes(data!.buffer.asUint8List());
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
      testWidgets('Open profile and photo-first archive at $width in $mode', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = mode;
        final peer = s.users.firstWhere((u) => u.str('id') != s.myId).str('id');
        s.state['demoInstants'] = <J>[
          for (var i = 0; i < 4; i++)
            {
              'id': 'a73-$i',
              'owner': s.myId,
              'created': now - i * 90000,
              'expires': i == 0 ? now + 4000 : now - 100,
              'retainUntil': now + 300000,
              'media': 'post$i.jpg',
              'openedBy': i == 0
                  ? [
                      {'user': peer, 'opened': now - 100},
                    ]
                  : <J>[],
            },
        ];
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: GpixApp(store: s),
          ),
        );
        await t.pumpAndSettle();
        gpixNavigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => Profile(user: s.myId)),
        );
        await t.pumpAndSettle();
        final identity = find.byKey(const ValueKey('profile-identity'));
        expect(t.widget(identity), isA<Padding>());
        expect(
          t.widget(find.byKey(const ValueKey('profile-stats'))),
          isA<Row>(),
        );
        if (width == 390) await capture73(t, boundary, 'profile-$mode');
        await t.tap(find.text('follower').first);
        await t.pumpAndSettle();
        expect(find.byType(Connections), findsOneWidget);
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        gpixNavigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const InstantArchive()),
        );
        for (var i = 0; i < 4; i++) {
          await t.pump();
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 70)),
          );
        }
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('archive-tile-a73-0')),
          findsOneWidget,
        );
        if (width == 390) await capture73(t, boundary, 'archive-$mode');
        await t.tap(find.text('Ultime 24 ore'));
        await t.pumpAndSettle();
        expect(find.byType(ArchiveThumbnail), findsOneWidget);
        await t.tap(find.byTooltip('Seleziona foto'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('archive-a73-0')));
        await t.pumpAndSettle();
        expect(find.text('Crea riepilogo · 1/9'), findsOneWidget);
        if (width == 390) await capture73(t, boundary, 'archive-select-$mode');
        await t.tap(find.text('Fine'));
        await t.pumpAndSettle();
        await t.tap(find.text('1'));
        await t.pumpAndSettle();
        expect(find.text('1 visualizzazione'), findsOneWidget);
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        s.state['demoInstants'] = [];
        await t.drag(
          find.byKey(const PageStorageKey('own-instant-archive')),
          const Offset(0, 320),
        );
        for (var i = 0; i < 4; i++)
          await t.pump(const Duration(milliseconds: 250));
        await t.pumpAndSettle();
        expect(
          find.text('Nessuna istantanea nelle ultime 24 ore'),
          findsOneWidget,
        );
        if (width == 390) await capture73(t, boundary, 'archive-empty-$mode');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
}
