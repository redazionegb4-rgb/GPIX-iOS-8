import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Publish with zero friends; active for 24h, archive stays private',
    () async {
      final s = GpixStore()..startTestDemo();
      s.state['following'] = [];
      s.state['closeFriends'] = [];
      s.me['followersList'] = [];
      s.state['demoInstants'] = [];
      expect(s.instantAudience('friends'), isEmpty);
      final before = now;
      final id = await s.sendInstant(
        'post0.jpg',
        [],
        'Il mio momento',
        audience: 'friends',
        requestKey: 'solo38',
      );
      final data = await s.instantList();
      expect(data.rows('active'), hasLength(1));
      expect(
        data.rows('active').single.number('expires'),
        closeTo(before + 86400, 2),
      );
      expect(data.rows('active').single.str('id'), id);
      s.state.rows('demoInstants').single['expires'] = now - 1;
      expect((await s.instantList()).rows('active'), isEmpty);
      expect(await s.instantArchive(), hasLength(1));
      s.dispose();
    },
  );
  for (final width in [320.0, 390.0])
    for (final mode in Brightness.values) {
      testWidgets(
        'Hub opens cards, never camera; own content works with no friends $width $mode',
        (t) async {
          t.view.physicalSize = Size(width, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final s = GpixStore()..startTestDemo();
          await t.pumpWidget(
            GpixScope(
              store: s,
              child: MaterialApp(
                theme: ThemeData(brightness: mode),
                home: const InstantCollectionPage(autoCapture: true),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(find.byType(InstantComposer), findsNothing);
          expect(find.byType(InstantFriendCard), findsOneWidget);
          expect(find.text('Dai tuoi amici'), findsOneWidget);
          expect(find.byKey(const ValueKey('instant-create')), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.ensureVisible(find.text('Le tue'));
          await t.pumpAndSettle();
          await t.tap(find.text('Le tue'));
          await t.pumpAndSettle();
          expect(find.byType(InstantFriendCard), findsNothing);
          expect(find.text('Le tue · 24 ore'), findsOneWidget);
          s.state['following'] = [];
          s.me['followersList'] = [];
          s.state['demoInstants'] = [];
          await s.sendInstant(
            'post0.jpg',
            [],
            'Solo',
            audience: 'friends',
            requestKey: 'own38',
          );
          await t.pump(const Duration(seconds: 31));
          await t.pumpAndSettle();
          expect(find.byType(InstantOwnCard), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          s.dispose();
        },
      );
    }
}
