import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/community.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Private follow keeps pending label until cancellation', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    final peer = s.users
        .firstWhere((u) => u.str('id') != s.myId && !s.follows(u.str('id')))
        .str('id');
    s.user(peer)['private'] = true;
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(home: Profile(user: peer)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Segui').first);
    await t.pumpAndSettle();
    expect(find.text('Richiesta inviata'), findsOneWidget);
    expect(s.state.ids('pending'), contains(peer));
    await t.tap(find.text('Richiesta inviata'));
    await t.pumpAndSettle();
    expect(s.state.ids('pending'), isNot(contains(peer)));
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Hidden pile remains reachable via inbox header', (t) async {
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: InstantBubbleSetting()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(s.preferences.flag('hideInstantBubble'), true);
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Inbox()),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(InstantPile), findsNothing);
    expect(find.byTooltip('Istantanee'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Double tap on a note adds one heart without opening reply', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    s.state['notes'] = [
      {
        'owner': 'u0',
        'text': 'Cuore sulla nota41',
        'audience': 'mutual',
        'created': now,
        'expires': now + 86400,
      },
    ];
    final note = s.notes.firstWhere((x) => x.str('owner') != s.myId);
    final text = note.str('text');
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Scaffold(body: NotesTray())),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pump(const Duration(milliseconds: 70));
    await t.tap(find.text(text));
    await t.pumpAndSettle();
    expect(note.flag('likedByMe'), true);
    expect(note.number('likesCount'), 1);
    expect(find.byType(AlertDialog), findsNothing);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Read-triggered temporary message disappears after grace period',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final thread = s.threads.firstWhere((x) => x.str('owner').isEmpty),
          peer = s.other(thread),
          id = thread.str('id');
      await s.send(id, 'Scomparsa dopo lettura41', expiresIn: -1);
      final m = thread.rows('messages').last;
      m['author'] = peer;
      m['readBy'] = <String>[];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: Chat(id: id)),
        ),
      );
      await t.pumpAndSettle();
      expect(m.flag('afterRead'), true);
      expect(find.text('Scomparsa dopo lettura41'), findsOneWidget);
      expect(m.number('readExpiresAt'), greaterThan(now));
      m['readExpiresAt'] = now - 1;
      await t.pump(const Duration(seconds: 1));
      await t.pumpAndSettle();
      expect(find.text('Scomparsa dopo lettura41'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'Tap advances a deck then opens internal camera after last photo',
    (t) async {
      final s = GpixStore()..startTestDemo();
      s.seedInstants();
      final first = s.state.rows('demoInstants').first,
          second = {...first, 'id': 'tap41', 'caption': 'Seconda41'};
      s.state['demoInstants'] = [first, second];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('GPIX/privacy'),
            (c) async => null,
          );
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    c,
                    MaterialPageRoute(
                      builder: (_) => InstantViewer(items: [first, second]),
                    ),
                  ),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Apri'));
      await t.pumpAndSettle();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('instant-deck')));
      await t.pumpAndSettle();
      expect(find.text('Seconda41'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('instant-deck')));
      await t.pumpAndSettle();
      expect(find.byType(InstantComposer), findsOneWidget);
      expect(find.byType(LiveInstantCamera), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('New message reaction stays in conversations without a banner', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    final thread = s.threads.firstWhere((x) => x.str('owner').isEmpty),
        peer = s.other(thread);
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await t.pumpAndSettle();
    s.state['notifications'] = [
      ...s.state.rows('notifications'),
      {
        'id': 'react41',
        'type': 'messageReaction',
        'actor': peer,
        'ref': thread.rows('messages').first.str('id'),
        'created': now,
        'seen': false,
      },
    ];
    s.notifyListeners();
    await t.pumpAndSettle();
    expect(find.textContaining('ha reagito a un tuo messaggio'), findsNothing);
    expect(s.socialNotifications.any((n) => n.str('id') == 'react41'), false);
    expect(inboxPreview(s, thread), contains('ha reagito a un tuo messaggio'));
    expect(s.chatHasUnread(thread), true);
    await s.act('notificationsRead');
    expect(s.chatReactions(thread), isNotEmpty);
    await s.markRead(thread.str('id'));
    expect(s.chatReactions(thread), isEmpty);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
