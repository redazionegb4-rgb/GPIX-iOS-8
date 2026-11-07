import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/instants.dart';
import 'package:gpix/screens/social.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Presence refresh replaces stale privacy fields and sends foreground header',
    () async {
      var allowed = true;
      final requests = <http.Request>[];
      final s = GpixStore(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'users': [
                {
                  'id': 'peer',
                  if (allowed) ...{
                    'online': true,
                    'lastActive': now - 2,
                    'onlineUntil': now + 12,
                  },
                },
              ],
              'typing': allowed
                  ? [
                      {'user': 'peer', 'kind': 'typing', 'until': now + 8},
                    ]
                  : [],
            }),
            200,
          );
        }),
      );
      s.token = 'session';
      s.state = {
        'me': {'id': 'me'},
        'users': [
          {'id': 'peer'},
        ],
        'threads': [
          {
            'id': 't',
            'members': ['me', 'peer'],
            'messages': [],
          },
        ],
      };
      await s.threadPresence('t');
      expect(s.online('peer'), true);
      expect(s.typingPeers('t'), hasLength(1));
      expect(requests.single.headers['X-GPIX-Active'], '1');
      allowed = false;
      await s.threadPresence('t');
      expect(s.online('peer'), false);
      expect(s.user('peer').containsKey('lastActive'), false);
      expect(s.typingPeers('t'), isEmpty);
      s.dispose();
    },
  );
  testWidgets(
    'Real inbox/chat online dot, exact last access and animated typing',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final thread = s.threads.firstWhere((x) => x.str('owner').isEmpty);
      final peer = s.other(thread);
      s.user(peer).addAll({
        'online': true,
        'onlineUntil': now + 12,
        'lastActive': now - 3,
      });
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: Chat(id: thread.str('id'))),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(ValueKey('online-$peer')), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      thread['typing'] = [
        {'user': peer, 'kind': 'typing', 'until': now + 8},
      ];
      s.notifyListeners();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Sta scrivendo…'), findsOneWidget);
      expect(find.byType(TypingDots), findsOneWidget);
      thread['typing'] = [
        {'user': peer, 'kind': 'recording', 'until': now + 8},
      ];
      s.notifyListeners();
      await t.pump();
      expect(find.text('Sta registrando un audio…'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
      expect(find.byType(TypingDots), findsNothing);
      thread['typing'] = [];
      s.user(peer)['onlineUntil'] = now - 1;
      s.notifyListeners();
      await t.pump();
      expect(find.byKey(ValueKey('online-$peer')), findsNothing);
      expect(find.textContaining('Ultimo accesso oggi alle'), findsOneWidget);
      s.state['preferences'] = {'activityStatus': false};
      s.notifyListeners();
      await t.pump();
      expect(find.textContaining('Ultimo accesso'), findsNothing);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('Inbox activity replaces the message preview temporarily', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    final thread = s.inboxThreads.firstWhere((x) => x.str('owner').isEmpty);
    final peer = s.other(thread);
    final preview = inboxPreview(s, thread);
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Inbox()),
      ),
    );
    expect(find.text(preview), findsOneWidget);
    thread['typing'] = [
      {'user': peer, 'kind': 'typing', 'until': now + 8},
    ];
    s.notifyListeners();
    await t.pump();
    expect(find.text('Sta scrivendo…'), findsOneWidget);
    expect(find.text(preview), findsNothing);
    thread['typing'] = [
      {'user': peer, 'kind': 'recording', 'until': now + 8},
    ];
    s.notifyListeners();
    await t.pump();
    expect(find.text('Sta registrando un audio…'), findsOneWidget);
    thread['typing'] = [];
    s.notifyListeners();
    await t.pump();
    expect(find.text(preview), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Inbox instant pile opens friend cards before the private archive',
    (t) async {
      final s = GpixStore()..startTestDemo();
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
                    MaterialPageRoute(builder: (_) => const InstantsPage()),
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
      expect(find.byType(InstantViewer), findsOneWidget);
      expect(find.byType(InstantCollectionPage), findsNothing);
      expect(find.byType(InstantComposer), findsNothing);
      await t.tap(find.byTooltip('Le tue istantanee'));
      await t.pumpAndSettle();
      expect(find.byType(InstantArchive), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets(
    'Private profile displays server totals even when content lists are absent',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final peer = s.users.firstWhere((x) => x.str('id') != s.myId).str('id');
      s.user(peer).addAll({
        'private': true,
        'postCount': 123,
        'followers': 456,
        'following': 789,
        'followersList': [],
        'followingList': [],
      });
      s.state['following'] = [];
      s.state['posts'] = [];
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: Profile(user: peer)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('123'), findsOneWidget);
      expect(find.text('456'), findsOneWidget);
      expect(find.text('789'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
}
