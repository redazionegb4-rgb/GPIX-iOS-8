import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/chat_ui.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/ui/kit.dart';

String _threadId(GpixStore store) => store.threads.first.str('id');

Future<GpixStore> showChat(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double width = 402,
  double scale = 1,
}) async {
  final store = GpixStore()..startTestDemo();
  final thread = store.threads.first;
  final other = store.other(thread);
  final start = now - 205;
  thread['messages'] = [
    {
      'id': 'chat-one',
      'author': store.myId,
      'kind': 'text',
      'created': start,
      'text': 'Ci vediamo al parco dopo il lavoro?',
      'readBy': [store.myId, other],
    },
    {
      'id': 'chat-emoji',
      'author': other,
      'kind': 'text',
      'created': start + 23,
      'text': '🙈 🫶',
      'readBy': [store.myId],
    },
    {
      'id': 'chat-two',
      'author': other,
      'kind': 'text',
      'created': start + 65,
      'text': 'Va benissimo',
      'readBy': [store.myId],
    },
    {
      'id': 'chat-three',
      'author': other,
      'kind': 'text',
      'created': start + 75,
      'text': 'Ci sono alle sette!',
      'readBy': [store.myId],
    },
  ];
  tester.view.physicalSize = Size(width, width < 350 ? 742 : 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 49, bottom: 32);
  addTearDown(tester.view.reset);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    GpixScope(
      store: store,
      child: MaterialApp(
        theme: gpixTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Chat(id: _threadId(store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Finder _message(String id) => find.byKey(ValueKey('chat-message-chat-$id'));

final _composer = find.byKey(const ValueKey('chat-composer-pill'));
final _input = find.byKey(const ValueKey('chat-message-input'));
final _reply = find.byKey(const ValueKey('chat-reply-bar'));

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Left swipe reveals timeline clocks, right swipe quotes and keeps draft',
    (tester) async {
      final store = await showChat(tester);
      final initial = tester.getCenter(_message('three'));
      final left = await tester.startGesture(initial);
      await left.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await left.moveBy(const Offset(-43, 0));
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.getCenter(_message('three')).dx, lessThan(initial.dx - 25));
      expect(
        find.text(clock(store.message('chat-three')['created'])),
        findsWidgets,
      );
      expect(_reply, findsNothing);
      await left.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(_message('three')).dx, closeTo(initial.dx, .1));
      expect(_reply, findsNothing);

      await tester.enterText(_input, 'Una bozza');
      await tester.pumpAndSettle();
      final right = await tester.startGesture(
        tester.getCenter(_message('three')),
      );
      await right.moveBy(const Offset(28, 0));
      await tester.pump(const Duration(milliseconds: 20));
      await right.moveBy(const Offset(56, 0));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byIcon(CupertinoIcons.reply), findsOneWidget);
      await right.up();
      await tester.pumpAndSettle();
      expect(_reply, findsOneWidget);
      expect(find.text('Ci sono alle sette!'), findsNWidgets(2));
      expect(tester.widget<TextField>(_input).focusNode!.hasFocus, isTrue);
      await tap(tester, find.byTooltip('Chiudi risposta'));
      expect(tester.widget<TextField>(_input).controller!.text, 'Una bozza');
      await tester.drag(_message('three'), const Offset(120, 0));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Invia'));
      expect(
        store.thread(_threadId(store)).rows('messages').last.str('reply'),
        'chat-three',
      );
      expect(_reply, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (brightness, width, scale) in [
    (Brightness.light, 402.0, 1.0),
    (Brightness.dark, 320.0, 1.25),
  ]) {
    testWidgets(
      'Composer and contextual menu fit keyboard and theme ${brightness.name}',
      (tester) async {
        final store = await showChat(
          tester,
          brightness: brightness,
          width: width,
          scale: scale,
        );
        expect(find.byTooltip('Chiamata vocale'), findsOneWidget);
        expect(find.byTooltip('Videochiamata'), findsOneWidget);
        expect(find.byTooltip('Fotocamera chat'), findsOneWidget);
        expect(find.byTooltip('Sticker'), findsOneWidget);
        final second = tester.getRect(_message('two'));
        final third = tester.getRect(_message('three'));
        expect(second.left, closeTo(third.left, .1));
        expect(third.top - second.bottom, closeTo(2, .1));
        expect(tester.widget<Text>(find.text('🙈 🫶')).style!.fontSize, 48);

        await tap(tester, _input);
        tester.view.viewInsets = const FakeViewPadding(bottom: 315);
        tester.view.padding = const FakeViewPadding(top: 49);
        await tester.pumpAndSettle();
        final screen = tester.view.physicalSize;
        expect(
          tester.getBottomLeft(_composer).dy,
          lessThan(screen.height - 315),
        );
        expect(tester.getTopLeft(_composer).dy, greaterThan(62));
        expect(tester.takeException(), isNull);

        await tester.longPress(_message('three'));
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        tester.view.padding = const FakeViewPadding(top: 49, bottom: 32);
        await tester.pumpAndSettle();
        expect(find.text('Rispondi'), findsOneWidget);
        expect(find.text('Aggiungi adesivo'), findsOneWidget);
        expect(find.text('Elimina per te'), findsOneWidget);
        expect(find.text('😮'), findsOneWidget);
        await tap(tester, find.text('😮'));
        expect(
          store.message('chat-three').obj('reactions').str(store.myId),
          '😮',
        );
        await tester.longPress(_message('three'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Altro'));
        await tap(tester, find.text('Altro'));
        expect(find.text('Copia'), findsOneWidget);
        await tap(tester, find.text('Fissa'));
        expect(
          store.thread(_threadId(store)).obj('chatStyle').str('pinnedMessage'),
          'chat-three',
        );
        expect(find.textContaining('Messaggio fissato ·'), findsOneWidget);

        await tester.longPress(_message('three'));
        await tester.pumpAndSettle();
        await tap(tester, find.text('Elimina per te'));
        await tap(tester, find.text('Elimina per te').last);
        expect(store.message('chat-three'), isEmpty);
        expect(find.textContaining('Messaggio fissato ·'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Details open from header and appearance, mute and expiry apply to chat',
    (tester) async {
      final store = await showChat(tester);
      await tap(tester, find.byKey(const ValueKey('chat-details')));
      expect(find.byType(ThreadInfo), findsOneWidget);
      expect(find.text('Profilo'), findsOneWidget);
      expect(find.text('Cerca'), findsOneWidget);
      expect(find.text('Messaggi temporanei'), findsOneWidget);
      expect(find.text('Soprannomi'), findsOneWidget);
      expect(find.text('Privacy e sicurezza'), findsOneWidget);
      expect(find.text('Crea una chat di gruppo'), findsOneWidget);
      await tap(tester, find.text('Silenzia'));
      expect(
        store.thread(_threadId(store)).obj('chatSettings').flag('muted'),
        isTrue,
      );
      expect(find.text('Riattiva'), findsOneWidget);
      await tap(tester, find.text('Personalizza'));
      await tap(tester, find.text('Blu'));
      await tap(tester, find.text('Monospazio'));
      await tap(tester, find.text('Applica'));
      expect(
        store.thread(_threadId(store)).obj('chatStyle').str('theme'),
        'blue',
      );
      expect(
        store.thread(_threadId(store)).obj('chatStyle').str('font'),
        'mono',
      );
      await tap(tester, find.text('Messaggi temporanei'));
      expect(find.byType(MessageExpiry), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('Indietro').last);
      expect(
        tester
            .widget<ChatBubble>(
              find.descendant(
                of: _message('one'),
                matching: find.byType(ChatBubble),
              ),
            )
            .colors,
        ChatColors.blue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
