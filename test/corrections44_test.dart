import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final private in [false, true])
    testWidgets(
      'Accepted request stays visible and follows back private=$private',
      (t) async {
        final s = GpixStore()..startTestDemo();
        final peer = s.users.firstWhere(
              (u) => u.str('id') != s.myId && !s.follows(u.str('id')),
            ),
            id = peer.str('id');
        peer['private'] = private;
        s.state['requests'] = [id];
        await t.pumpWidget(
          GpixScope(
            store: s,
            child: const MaterialApp(home: Requests()),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Conferma'));
        await t.pumpAndSettle();
        expect(s.state.ids('requests'), isEmpty);
        expect(find.text('Segui anche tu'), findsOneWidget);
        s.notifyListeners();
        await t.pump();
        expect(find.text(peer.str('name')), findsOneWidget);
        await t.tap(find.text('Segui anche tu'));
        await t.pumpAndSettle();
        expect(
          find.text(private ? 'Richiesta inviata' : 'Segui già'),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  testWidgets('Post owner sees comment options to hide, restore and delete', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    final post = s.posts.first;
    post['author'] = s.myId;
    final peer = s.users.firstWhere((u) => u.str('id') != s.myId).str('id');
    post['comments'] = [
      {
        'id': 'comment44',
        'author': peer,
        'text': 'Test44',
        'parent': '',
        'created': now,
        'likes': <String>[],
      },
    ];
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Scaffold(body: Comments(id: post.str('id'))),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Opzioni commento'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nascondi agli altri'));
    await t.pumpAndSettle();
    expect(post.rows('comments').first.flag('hidden'), true);
    expect(find.textContaining('Nascosto agli altri'), findsOneWidget);
    await t.tap(find.byTooltip('Opzioni commento'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mostra di nuovo'));
    await t.pumpAndSettle();
    expect(post.rows('comments').first.flag('hidden'), false);
    await t.tap(find.byTooltip('Opzioni commento'));
    await t.pumpAndSettle();
    await t.tap(find.text('Elimina commento'));
    await t.pumpAndSettle();
    await t.tap(find.text('Elimina'));
    await t.pumpAndSettle();
    expect(post.rows('comments'), isEmpty);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Archive photo opens on tap; selection is explicit for recaps', (
    t,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('GPIX/privacy'),
          (c) async => null,
        );
    final s = GpixStore()..startTestDemo();
    s.seedInstants();
    s.state['demoInstants'] = [
      {
        ...s.state.rows('demoInstants').first,
        'id': 'own44',
        'owner': s.myId,
        'caption': 'Archivio44',
      },
    ];
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: InstantArchive()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Le tue istantanee'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('archive-own44')));
    await t.pumpAndSettle();
    expect(find.byType(InstantViewer), findsOneWidget);
    Navigator.of(t.element(find.byType(InstantViewer))).pop();
    await t.pumpAndSettle();
    await t.tap(find.text('Seleziona'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('archive-own44')));
    await t.pump();
    expect(find.text('Crea riepilogo · 1/9'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
