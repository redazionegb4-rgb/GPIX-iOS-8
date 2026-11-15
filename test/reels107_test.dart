import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/shell.dart';
import 'package:gpix/screens/reels.dart';
import 'package:gpix/screens/video.dart' show ClipPlayer, ClipProgress;

import 'chat105_test.dart' show tap;
import 'inbox106_test.dart' show show;

final _dock = find.byKey(const ValueKey('floating-dock'));
final _drawer = find.byKey(const ValueKey('reel-sheet'));
final _handle = find.byKey(const ValueKey('reel-sheet-handle'));
final _input = find.byKey(const ValueKey('reel-comment-input'));
Finder _player(String id) => find.byKey(ValueKey('reel-player-$id'));

GpixStore _fixture({bool commentsOff = false}) {
  final store = GpixStore()..startTestDemo();
  final peer = store.other(store.threads.first);
  store.state['posts'] = [
    ...store.allPosts.where((p) => p.str('kind') != 'reel'),
    for (var i = 1; i <= 2; i++)
      {
        'id': 'r$i',
        'kind': 'reel',
        'author': peer,
        'text': i == 1
            ? 'Un tramonto sul porto, vicino al mare. Il cielo cambia colore ogni minuto.'
            : 'La costa al mattino',
        'media': '',
        'style': {'cover': 'post$i.jpg'},
        'created': now - i * 600,
        'audience': i == 1 ? 'all' : 'followers',
        'shareCount': i == 1 ? 10080 : 0,
        'commentsOff': commentsOff,
        'comments': i == 1
            ? <J>[
                {
                  'id': 'main',
                  'author': peer,
                  'text': 'Che luce!',
                  'created': now - 100,
                  'likes': <String>[],
                },
                {
                  'id': 'reply',
                  'parent': 'main',
                  'author': store.myId,
                  'text': 'Ci torniamo domani?',
                  'created': now - 80,
                },
              ]
            : <J>[],
      },
  ];
  return store;
}

void main() {
  testWidgets(
    'Comments resize and restore the same player on a downward swipe',
    (tester) async {
      final s = _fixture();
      await show(tester, s, const SocialShell());
      await tap(tester, find.byTooltip('Reel'));
      final video = _player('r1');
      final player = tester.state(video);
      expect(tester.getSize(video), const Size(402, 874));
      expect(tester.getSize(_dock).width, closeTo(304, 1));
      expect(tester.getSize(_dock).height, 50);
      expect(find.text('10,1 mila'), findsOneWidget);

      await tester.tap(find.byTooltip('Commenti'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.getSize(video).width, inExclusiveRange(214, 402));
      expect(tester.state(video), same(player));
      await tester.pumpAndSettle();
      expect(tester.getSize(video).width, closeTo(213, 1));
      expect(tester.getTopLeft(_drawer).dy, closeTo(350, 1));
      expect(Theme.of(tester.element(_drawer)).brightness, Brightness.dark);
      expect(tester.widget<ClipPlayer>(video).suspended, isFalse);
      expect(_dock, findsNothing);

      await tap(tester, find.text('Visualizza 1 risposta'));
      expect(find.text('Ci torniamo domani?'), findsOneWidget);
      await tap(tester, find.byTooltip('Mi piace al commento').first);
      expect(s.post('r1').rows('comments').first.ids('likes'), [s.myId]);
      await tap(tester, find.text('Rispondi').first);
      await tester.enterText(_input, 'Certo, a domani!');
      await tester.pump();
      await tap(tester, find.byTooltip('Pubblica commento'));
      expect(s.post('r1').rows('comments').last.str('parent'), 'main');
      expect(find.text('Certo, a domani!'), findsOneWidget);

      await tester.drag(find.text('Che luce!'), const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(_drawer, findsNothing);
      expect(_dock, findsOneWidget);
      expect(tester.state(video), same(player));
      expect(tester.getSize(video), const Size(402, 874));

      await tester.dragFrom(const Offset(190, 610), const Offset(0, -515));
      await tester.pumpAndSettle();
      expect(tester.widget<ClipPlayer>(_player('r2')).active, isTrue);
      expect(find.text('La costa al mattino'), findsOneWidget);
      expect(find.byTooltip('Ripubblica'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sharing sends the selected reel to the recipient chat', (
    tester,
  ) async {
    final s = _fixture();
    final peer = s.other(s.threads.first);
    await show(
      tester,
      s,
      const Reels(),
      width: 320,
      theme: Brightness.dark,
      textScale: 1.35,
    );
    final video = tester.state(_player('r1'));
    await tap(tester, find.byTooltip('Condividi reel'));
    expect(tester.state(_player('r1')), same(video));
    await tap(tester, find.text(s.user(peer).str('name')));
    await tap(tester, find.text('Invia'));
    final thread = s.threads.firstWhere((t) => t.ids('members').contains(peer));
    expect(thread.rows('messages').last.str('post'), 'r1');
    expect(s.post('r1').number('shareCount'), 10081);
    expect(_drawer, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Playback options, fullscreen and auto-advance work without replacing the player',
    (tester) async {
      final s = _fixture(commentsOff: true);
      await show(tester, s, const SocialShell());
      await tap(tester, find.byTooltip('Reel'));
      final video = _player('r1'), player = tester.state(video);
      await tap(tester, find.byTooltip('Commenti'));
      expect(_input, findsNothing);
      expect(find.text('Commenti disattivati'), findsOneWidget);
      await tap(tester, _handle);
      await tap(tester, find.byTooltip('Opzioni reel'));
      await tap(tester, find.text('Salva'));
      expect(s.post('r1').flag('saved'), isTrue);
      expect(find.text('Salvato'), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Opzioni reel'));
      await tap(tester, find.text('Riproduzione'));
      await tap(tester, find.text('Scorrimento automatico'));
      await tap(tester, find.text('Disattiva audio'));
      expect(tester.widget<ClipPlayer>(video).muted, isTrue);
      await tap(tester, find.text('Visualizza a schermo intero'));
      expect(_dock, findsNothing);
      expect(tester.state(video), same(player));
      await tap(tester, find.byTooltip('Esci da schermo intero'));
      expect(_dock, findsOneWidget);
      expect(tester.widget<ClipPlayer>(video).loop, isFalse);
      tester.widget<ClipPlayer>(video).onCompleted!();
      await tester.pumpAndSettle();
      expect(tester.widget<ClipPlayer>(_player('r2')).active, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Comment composer stays above the keyboard on a small screen', (
    tester,
  ) async {
    final s = _fixture();
    await show(tester, s, const Reels(), width: 320, textScale: 1.45);
    await tap(tester, find.byTooltip('Commenti'));
    await tester.tap(_input);
    tester.view.viewInsets = const FakeViewPadding(bottom: 430);
    tester.view.padding = const FakeViewPadding(top: 49);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(_input).dy, lessThan(339));
    expect(tester.getSize(_player('r1')).height, greaterThan(40));
    await tester.enterText(_input, 'Bellissimo!');
    await tester.pump();
    await tap(tester, find.byTooltip('Pubblica commento'));
    expect(s.post('r1').rows('comments').last.str('text'), 'Bellissimo!');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Playback position updates and a scrub requests just one seek', (
    tester,
  ) async {
    final progress = ValueNotifier<ClipProgress>((
      position: const Duration(seconds: 3),
      duration: const Duration(seconds: 10),
    ));
    final seeks = <double>[];
    addTearDown(progress.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ReelProgressBar(progress: progress, onSeek: seeks.add),
            ),
          ),
        ),
      ),
    );
    final slider = find.byType(Slider);
    expect(tester.widget<Slider>(slider).value, .3);
    await tester.dragFrom(tester.getCenter(slider), const Offset(90, 0));
    expect(seeks, hasLength(1));
    expect(seeks.single, closeTo(.8, .11));
  });
}
