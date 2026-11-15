import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/notes.dart';
import 'package:gpix/ui/kit.dart';

import 'chat105_test.dart' show tap;

GpixStore fixture({bool pending = false, int longHistory = 0}) {
  final store = GpixStore()..startTestDemo();
  final thread = store.threads.first;
  final peer = store.other(thread);
  final user = store.user(peer);
  user['name'] = 'Alessio Città';
  user['username'] = 'ale.amico';
  user['lastActive'] = now - 16 * 60;
  final time = now - 20 * 60;
  thread['requestDecision'] = pending ? '' : 'accepted';
  if (pending) thread['requestPending'] = true;
  final messages = <J>[
    <String, dynamic>{
      'id': 'target',
      'author': peer,
      'text': 'Ci vediamo vicino alla città vecchia?',
      'kind': 'text',
      'created': time,
      'readBy': pending ? <String>[] : [store.myId],
    },
    if (!pending)
      for (var index = 0; index < longHistory; index++)
        <String, dynamic>{
          'id': 'mid-$index',
          'author': peer,
          'text': 'Messaggio precedente ${index + 1}',
          'kind': 'text',
          'created': time + index + 1,
          'readBy': [store.myId],
        },
    if (!pending)
      <String, dynamic>{
        'id': 'own',
        'author': store.myId,
        'text': 'Perfetto, a dopo!',
        'kind': 'text',
        'created': now - 18 * 60,
        'readBy': [store.myId, peer],
        'readAt': {peer: now - 15 * 60 - 3},
      },
  ];
  thread['messages'] = messages;
  store.state['threads'] = [thread];
  store.state['notes'] = [
    {
      'owner': peer,
      'text': 'Verso il mare ✈️',
      'created': time,
      'expires': now + 350,
    },
  ];
  return store;
}

Future<void> show(
  WidgetTester tester,
  GpixStore store,
  Widget screen, {
  double width = 402,
  double textScale = 1,
  Brightness theme = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, width < 350 ? 769 : 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 49, bottom: 31);
  tester.view.viewPadding = const FakeViewPadding(top: 49, bottom: 31);
  addTearDown(tester.view.reset);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    GpixScope(
      store: store,
      child: MaterialApp(
        theme: gpixTheme(theme),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(
            c,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String threadId(GpixStore s) => s.threads.single.str('id');
final inboxSearch = find.descendant(
  of: find.byKey(const ValueKey('inbox-search')),
  matching: find.byType(TextField),
);
final receipt = find.textContaining('Visualizzato 15 min fa');
final composer = find.byKey(const ValueKey('chat-composer-pill'));

void main() {
  testWidgets(
    'Inbox uses the reference row sizes and opens an older message directly',
    (tester) async {
      final s = fixture(longHistory: 75);
      await show(tester, s, const Inbox());
      final row = find.byKey(ValueKey('inbox-thread-${threadId(s)}'));
      final portrait = find.descendant(
        of: row,
        matching: find.byType(ChatPresenceAvatar),
      );
      expect(tester.getSize(portrait), const Size.square(61));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(71));
      expect(find.text('Messaggi'), findsOneWidget);
      expect(find.text('Richieste'), findsOneWidget);
      expect(find.text('La tua nota'), findsOneWidget);
      expect(find.text('Alessio Città'), findsWidgets);
      expect(find.byType(NotesTray), findsOneWidget);
      expect(receipt, findsOneWidget);

      await tester.enterText(inboxSearch, '@ale.amico');
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(find.byType(NotesTray), findsNothing);
      await tester.enterText(inboxSearch, 'citta vecchia');
      await tester.pumpAndSettle();
      expect(find.text('Risultati nei messaggi'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('inbox-result-target')));
      final highlight = find.byKey(const ValueKey('chat-search-highlight'));
      final target = find.byKey(const ValueKey('chat-message-target'));
      expect(highlight, findsOneWidget);
      expect(target, findsOneWidget);
      expect(tester.getCenter(target).dy, inInclusiveRange(150, 690));
      await tap(tester, find.text('Più recenti'));
      expect(find.byKey(const ValueKey('chat-message-own')), findsOneWidget);
      expect(highlight, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Conversation header shows online, last active and privacy on a narrow dark screen',
    (tester) async {
      final s = fixture();
      final id = threadId(s);
      final peer = s.other(s.threads.single);
      s.user(peer)['online'] = true;
      s.user(peer)['onlineUntil'] = now + 3600;
      await show(
        tester,
        s,
        Chat(id: id),
        width: 320,
        textScale: 1.48,
        theme: Brightness.dark,
      );
      final header = find.byKey(const ValueKey('chat-presence-label'));
      expect(tester.widget<Text>(header).data, 'Attivo/a ora');
      expect(find.byKey(ValueKey('online-$peer')), findsOneWidget);
      s.user(peer)['online'] = false;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<Text>(header).data, 'Ultimo accesso 16 min fa');
      expect(find.byKey(ValueKey('online-$peer')), findsNothing);
      await s.setPreference('activityStatus', false);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(header).data, 'ale.amico');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Opening a request does not read it before explicit acceptance', (
    tester,
  ) async {
    final s = fixture(pending: true);
    await show(
      tester,
      s,
      const MessageRequests(),
      width: 320,
      theme: Brightness.dark,
    );
    final request = find.byKey(ValueKey('message-request-${threadId(s)}'));
    await tap(tester, request);
    expect(find.text('Richiesta di messaggio'), findsOneWidget);
    expect(composer, findsNothing);
    expect(s.message('target').ids('readBy'), isEmpty);
    expect(find.byTooltip('Videochiamata'), findsNothing);
    await tap(tester, find.text('Nascondi'));
    expect(s.hiddenRequests, hasLength(1));
    await tap(tester, find.text('Richieste nascoste'));
    await tap(tester, request);
    expect(find.text('Richiesta nascosta'), findsOneWidget);
    expect(s.message('target').ids('readBy'), isEmpty);
    await tap(tester, find.text('Accetta'));
    await tester.pump(const Duration(seconds: 2));
    expect(composer, findsOneWidget);
    expect(s.requestedThreads, isEmpty);
    expect(s.hiddenRequests, isEmpty);
    expect(s.message('target').ids('readBy'), contains(s.myId));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Search from chat details returns to the matching bubble and keeps the draft',
    (tester) async {
      final s = fixture(longHistory: 49);
      await show(tester, s, Chat(id: threadId(s)));
      final input = find.byKey(const ValueKey('chat-message-input'));
      await tester.enterText(input, 'Bozza conservata');
      await tap(tester, find.byKey(const ValueKey('chat-details')));
      await tap(tester, find.text('Cerca'));
      final search = find.descendant(
        of: find.byKey(const ValueKey('thread-search')),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'vecchia');
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('thread-result-target')));
      expect(
        find.byKey(const ValueKey('chat-search-highlight')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Bozza conservata',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Traduci shares only the selected message with the chosen Android service',
    (tester) async {
      const channel = SystemChannels.processText;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'ProcessText.queryTextActions') {
          return {
            'com.example.Translator': 'Traduttore di test',
            'com.example.Note': 'Scrivi nota',
          };
        }
        return 'Testo tradotto';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final s = fixture();
      await show(tester, s, Chat(id: threadId(s)));
      await tester.longPress(find.byKey(const ValueKey('chat-message-target')));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Altro'));
      await tap(tester, find.text('Traduci'));
      expect(find.text('Traduci con'), findsOneWidget);
      expect(find.text('Scrivi nota'), findsNothing);
      expect(calls, isNotEmpty);
      expect(
        calls.every((call) => call.method == 'ProcessText.queryTextActions'),
        isTrue,
      );
      await tap(tester, find.text('Traduttore di test'));
      expect(find.text('Testo tradotto'), findsOneWidget);
      final action = calls.singleWhere(
        (call) => call.method == 'ProcessText.processTextAction',
      );
      final args = action.arguments as List<dynamic>;
      expect(args, [
        'com.example.Translator',
        s.message('target').str('text'),
        true,
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}
