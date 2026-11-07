import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Request reference search and bulk management change only selected accounts',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final peers = s.users
          .where((u) => u.str('id') != s.myId)
          .take(2)
          .toList();
      s.state['requests'] = peers.map((u) => u.str('id')).toList();
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: const MaterialApp(home: Requests()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Scopri altri profili'), findsOneWidget);
      expect(find.text('Conferma'), findsNWidgets(2));
      expect(find.text('Elimina'), findsNWidgets(2));
      await t.enterText(find.byType(TextField), peers.first.str('username'));
      await t.pump();
      expect(find.text('Conferma'), findsOneWidget);
      await t.enterText(find.byType(TextField), '');
      await t.pump();
      await t.tap(find.text('Gestisci'));
      await t.pump();
      await t.tap(find.byTooltip('Seleziona').first);
      await t.pump();
      expect(find.text('1 selezionate'), findsOneWidget);
      await t.tap(find.text('Conferma'));
      await t.pumpAndSettle();
      expect(s.state.ids('requests'), [peers.last.str('id')]);
      expect(s.me.ids('followersList'), contains(peers.first.str('id')));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'Archive shows the per-photo view count and opens the actual viewers',
    (t) async {
      final s = GpixStore()..startTestDemo();
      s.seedInstants();
      final peer = s.users.firstWhere((u) => u.str('id') != s.myId);
      final row = {
        ...s.state.rows('demoInstants').first,
        'id': 'archive43',
        'owner': s.myId,
        'openedBy': [
          {'user': peer.str('id'), 'opened': now - 60},
        ],
      };
      s.state['demoInstants'] = [row];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: const MaterialApp(home: InstantArchive()),
        ),
      );
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await t.ensureVisible(find.text('1'));
      await t.pumpAndSettle();
      await t.tap(find.text('1'));
      await t.pumpAndSettle();
      expect(find.text('1 visualizzazione'), findsOneWidget);
      expect(find.text(peer.str('name')), findsOneWidget);
      expect(find.textContaining('Visualizzata'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  for (final cancel in [true, false])
    testWidgets(
      cancel
          ? 'Short card drag settles back without consuming the next photo'
          : 'Committed card drag promotes the next card exactly once',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('GPIX/privacy'),
              (c) async => null,
            );
        final s = GpixStore()..startTestDemo();
        s.seedInstants();
        final first = s.state.rows('demoInstants').first,
            second = {...first, 'id': 'gesture43', 'caption': 'Prossima43'};
        s.state['demoInstants'] = [first, second];
        await t.pumpWidget(
          GpixScope(
            store: s,
            child: MaterialApp(home: InstantViewer(items: [first, second])),
          ),
        );
        await t.pumpAndSettle();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await t.pumpAndSettle();
        final deck = find.byKey(const ValueKey('instant-deck'));
        final gesture = await t.startGesture(t.getCenter(deck));
        await gesture.moveBy(const Offset(0, -20));
        await t.pump();
        await gesture.moveBy(Offset(20, cancel ? -12 : -140));
        await t.pump(const Duration(milliseconds: 100));
        final moving = t.widget<Transform>(
          find.byKey(const ValueKey('instant-front-motion')),
        );
        expect(moving.transform.storage[13], lessThan(0));
        expect(second.flag('opened'), false);
        await t.pump(const Duration(milliseconds: 250));
        await gesture.up();
        await t.pumpAndSettle();
        if (cancel) {
          expect(second.flag('opened'), false);
          expect(
            t
                .widget<Transform>(
                  find.byKey(const ValueKey('instant-front-motion')),
                )
                .transform
                .storage[13]
                .abs(),
            lessThan(.01),
          );
        } else {
          expect(second.flag('opened'), true);
          expect(find.text('Prossima43'), findsOneWidget);
          expect(s.state.rows('demoInstants').last.rows('openedBy').length, 1);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
}
