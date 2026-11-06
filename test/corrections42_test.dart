import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/profile_links.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'History survives a store restart, deduplicates, and isolates accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final s = GpixStore()..startTestDemo();
      s.prefs = prefs;
      await s.rememberSearch(' Mario ');
      await s.rememberSearch('Milano');
      await s.rememberSearch('mario');
      expect(s.searchHistory, ['mario', 'Milano']);
      final fresh = GpixStore()..startTestDemo();
      fresh.prefs = prefs;
      expect(fresh.searchHistory, ['mario', 'Milano']);
      fresh.state['me'] = {...fresh.me, 'id': 'altro42'};
      expect(fresh.searchHistory, isEmpty);
      await s.removeSearch('Milano');
      expect(s.searchHistory, ['mario']);
      await s.clearSearchHistory();
      expect(
        prefs.getKeys().where((k) => k.startsWith('gpix.search.')),
        isEmpty,
      );
      s.dispose();
      fresh.dispose();
    },
  );
  testWidgets('Search submits and restores terms and clears the history', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Explore()),
      ),
    );
    await t.enterText(find.byType(TextField), 'mare42');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pump();
    expect(s.searchHistory, ['mare42']);
    await t.enterText(find.byType(TextField), '');
    await t.pump();
    expect(find.text('Ricerche recenti'), findsOneWidget);
    await t.tap(find.text('mare42'));
    await t.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(
      (t.widget<TextField>(find.byType(TextField))).controller!.text,
      'mare42',
    );
    await t.enterText(find.byType(TextField), '');
    await t.pump();
    await t.tap(find.text('Cancella cronologia'));
    await t.pump();
    expect(s.searchHistory, isEmpty);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Explore can find reels separately from photo posts', (t) async {
    final s = GpixStore()..startTestDemo();
    s.reels.first['text'] = 'Ricerca reel univoca';
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Explore()),
      ),
    );
    await t.enterText(find.byType(TextField), 'univoca');
    await t.tap(find.widgetWithText(ChoiceChip, 'Reel'));
    await t.pumpAndSettle();
    expect(find.text('Ricerca reel univoca'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Post'));
    await t.pumpAndSettle();
    expect(find.text('Nessun risultato'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Story likes use story wording and reactions are absent from Activity',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final peer = s.users.firstWhere((u) => u.str('id') != s.myId).str('id');
      s.state['notifications'] = [
        {
          'id': 'story42',
          'type': 'storyLike',
          'actor': peer,
          'ref': 'expiredStory',
          'created': now,
          'seen': false,
        },
        {
          'id': 'reaction42',
          'type': 'messageReaction',
          'actor': peer,
          'ref': 'm42',
          'created': now,
          'seen': false,
        },
      ];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: const MaterialApp(home: Activity()),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('ha messo Mi piace alla tua storia'),
        findsOneWidget,
      );
      expect(find.textContaining('al tuo post'), findsNothing);
      expect(find.textContaining('ha reagito'), findsNothing);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('Follow requests offer styled accept and reject actions', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    final peer = s.users.firstWhere((u) => u.str('id') != s.myId).str('id');
    s.state['requests'] = [peer];
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Requests()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Conferma'), findsOneWidget);
    expect(find.byTooltip('Rifiuta richiesta'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Rifiuta richiesta'));
    await t.pumpAndSettle();
    expect(s.state.ids('requests'), isEmpty);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Profile add chip keeps icon and label in the same compact row', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(
          home: Scaffold(body: ProfileLinkChips(links: [], own: true)),
        ),
      ),
    );
    await t.pump();
    final chip = find.byType(ActionChip);
    expect(chip, findsOneWidget);
    expect(t.getSize(chip).width, lessThan(170));
    expect(find.text('Aggiungi'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Instant bubble animates from its pressed state into the deck', (
    t,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('GPIX/privacy'),
          (c) async => null,
        );
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Scaffold(body: InstantPile())),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(InstantPile));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(ScaleTransition), findsWidgets);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(InstantsPage), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
