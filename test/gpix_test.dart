import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/screens/people.dart';
import 'package:gpix/screens/emoji_picker.dart';
import 'package:gpix/screens/story_camera.dart';
import 'package:gpix/screens/chat_media.dart';
import 'package:gpix/screens/community.dart';
import 'package:gpix/screens/giphy.dart';
import 'package:gpix/screens/photo_send.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:image/image.dart' as image_lib;
import 'package:gpix/ui/kit.dart';

class _TestPaths extends PathProviderPlatform {
  final String root;
  _TestPaths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('GPIX/gallery'),
          (call) async => call.method == 'recent' ? [] : null,
        );
    await Directory('QA/screens').create(recursive: true);
    final roboto = FontLoader('Roboto')
      ..addFont(
        File(
          'test/fonts/Roboto-Regular.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await roboto.load();
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await cupertino.load();
  });
  test(
    'demo mutations preserve comments, message reactions, story context and groups',
    () async {
      final s = GpixStore()..startTestDemo();
      await s.act('like', {'id': 'p0', 'enabled': true});
      expect(s.post('p0').ids('likes'), contains(s.myId));
      await s.act('comment', {
        'id': 'p0',
        'text': 'Risposta di prova',
        'parent': 'c0',
      });
      expect(s.post('p0').rows('comments').last.str('parent'), 'c0');
      await s.act('likeComment', {'id': 'c0', 'enabled': true});
      expect(
        s.post('p0').rows('comments').first.ids('likes'),
        contains(s.myId),
      );
      await s.storyReply(s.post('s0'), '🔥');
      final message = s.thread('t0').rows('messages').last;
      expect(message.obj('story').str('id'), 's0');
      await s.act('react', {'id': message['id'], 'emoji': '🌈'});
      expect(
        s.thread('t0').rows('messages').last.obj('reactions').str(s.myId),
        '🌈',
      );
      await s.act('group', {
        'title': 'Pride',
        'users': ['u1', 'u2'],
      });
      final group = s.threads.firstWhere((t) => t.str('title') == 'Pride');
      await s.act('removeMember', {'id': group['id'], 'user': 'u2'});
      expect(s.thread(group.str('id')).ids('members'), isNot(contains('u2')));
      await s.act('sharePost', {'id': 't0', 'post': 'p0'});
      expect(s.thread('t0').rows('messages').last.str('post'), 'p0');
      s.dispose();
    },
  );
  test('deleting demo account removes its persisted data and media', () async {
    final old = PathProviderPlatform.instance;
    final root = await Directory.systemTemp.createTemp('gpix-delete-test-');
    PathProviderPlatform.instance = _TestPaths(root.path);
    try {
      SharedPreferences.setMockInitialValues({'gpix.demoData': 'old-account'});
      final s = GpixStore()..startTestDemo();
      s.prefs = await SharedPreferences.getInstance();
      final media = Directory('${root.path}/gpix-media');
      await media.create();
      await File('${media.path}/photo.jpg').writeAsString('local-demo-media');
      await s.act('deleteAccount', {'password': 'demo'});
      expect(s.signedIn, isFalse);
      expect(s.prefs!.containsKey('gpix.demoData'), isFalse);
      expect(await media.exists(), isFalse);
      s.dispose();
    } finally {
      PathProviderPlatform.instance = old;
      await root.delete(recursive: true);
    }
  });
  testWidgets('double tap likes without changing feed offset', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pump(const Duration(milliseconds: 500));
    final feed = find.byKey(const PageStorageKey('feed'));
    await tester.drag(feed, const Offset(0, -480));
    await tester.pumpAndSettle();
    final list = tester.widget<ListView>(feed);
    final offset = list.controller!.offset;
    final card = find.byType(PostCard).last;
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final stable = list.controller!.offset;
    final photo = find
        .descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) => widget is MediaView && widget.fit == BoxFit.contain,
          ),
        )
        .first;
    final point = tester.getCenter(photo);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 800));
    expect(list.controller!.offset, closeTo(stable, .1));
    expect(offset, greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('chat sends, quotes and opens reaction sheet', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const Chat(id: 't0'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Messaggio reale di test',
    );
    await tester.pump();
    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();
    expect(
      s.thread('t0').rows('messages').last.str('text'),
      'Messaggio reale di test',
    );
    await tester.longPress(find.text('Messaggio reale di test'));
    await tester.pumpAndSettle();
    expect(find.text('Rispondi'), findsOneWidget);
    expect(find.text('Annulla invio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final screen in [
      'feed',
      'photo-send',
      'note-editor',
      'expiry-settings',
      'post-editing',
      'close-friends',
      'own-story',
      'connections',
      'emoji-sheet',
      'profile',
      'chat',
      'story-editor',
      'story-camera',
      'story-viewer',
      'story-reactions',
      'post-editor',
      'inbox',
      'comments',
      'menu',
      'explore',
      'home',
    ]) {
      testWidgets('layout $screen ${size.width}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        if (screen == 'inbox')
          s.state['notes'] = [
            {
              'owner': 'u0',
              'text': 'Oggi ho voglia di mare',
              'expires': now + 86400,
              'audience': 'mutual',
            },
            {
              'owner': 'u1',
              'text': 'Ci vediamo stasera?',
              'expires': now + 86400,
              'audience': 'close',
            },
          ];
        if (screen == 'own-story')
          await s.act('post', {
            'kind': 'story',
            'text': 'Una nuova storia',
            'audience': 'close',
          });
        Widget page = switch (screen) {
          'photo-send' => const PhotoSend(
            path: 'post0.jpg',
            recipient: 'Andrea',
          ),
          'expiry-settings' => const MessageExpiry(seconds: 3600),
          'post-editing' => PostComposer(initialFiles: ['post0.jpg']),
          'note-editor' => const Inbox(),
          'close-friends' => const CloseFriends(),
          'own-story' => StoryViewer(
            user: s.myId,
            ids: [s.stories(s.myId).first.str('id')],
          ),
          'profile' => const Profile(user: 'me'),
          'chat' => const Chat(id: 't0'),
          'story-editor' => const Composer(kind: 'story', editStory: true),
          'story-camera' => const Composer(kind: 'story'),
          'story-viewer' ||
          'story-reactions' => const StoryViewer(user: 'u0', ids: ['s0']),
          'post-editor' => const Composer(kind: 'post'),
          'inbox' => const Inbox(),
          'connections' => Connections(user: s.myId),
          'explore' => const Explore(),
          'home' => const HomeShell(),
          _ => const Feed(),
        };
        final key = GlobalKey();
        BuildContext? pageContext;
        await tester.pumpWidget(
          GpixScope(
            store: s,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  scaffoldBackgroundColor: Colors.white,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                  ),
                ),
                home: Builder(
                  builder: (c) {
                    pageContext = c;
                    return page;
                  },
                ),
              ),
            ),
          ),
        );
        if (screen == 'story-viewer' ||
            screen == 'story-reactions' ||
            screen == 'own-story') {
          await tester.pump(const Duration(milliseconds: 350));
          if (screen == 'story-reactions') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            addTearDown(tester.view.resetViewInsets);
            await tester.tap(find.byType(TextField).last);
            await tester.pump(const Duration(milliseconds: 350));
          }
        } else {
          await tester.pumpAndSettle();
        }
        if (screen == 'note-editor') {
          editNote(pageContext!);
          await tester.pumpAndSettle();
        }
        if (screen == 'comments') {
          comments(pageContext!, 'p0');
          await tester.pumpAndSettle();
        }
        if (screen == 'menu') {
          postMenu(pageContext!, s.post('p0'));
          await tester.pumpAndSettle();
        }
        if (screen == 'emoji-sheet') {
          sheet(pageContext!, EmojiPicker(onSelected: (_) {}), scroll: false);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        // Render the entire overlay, including sheets.
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'QA/screens/$screen-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
  testWidgets('story heart and reply preserve story context', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: const StoryViewer(user: 'u0', ids: ['s0']),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Mi piace alla storia'));
    await tester.pump();
    expect(s.post('s0').ids('likes'), contains(s.myId));
    await tester.enterText(find.byType(TextField).last, 'Che bella storia!');
    await tester.pump();
    await tester.tap(find.byTooltip('Invia risposta'));
    await tester.pump(const Duration(milliseconds: 200));
    final last = s.thread('t0').rows('messages').last;
    expect(last.str('text'), 'Che bella storia!');
    expect(last.obj('story').str('id'), 's0');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('create a text story through the editor', (tester) async {
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Crea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Storia'));
    await tester.pumpAndSettle();
    if (find.byType(StoryCamera).evaluate().isNotEmpty) {
      await tester.tap(find.text('Crea'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Testo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'La mia nuova storia');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    expect(find.text('La mia nuova storia'), findsOneWidget);
    await tester.tap(find.byTooltip('Condividi'));
    await tester.pumpAndSettle();
    expect(s.stories(s.myId).first.str('text'), 'La mia nuova storia');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  for (final page in ['profile', 'chat', 'settings']) {
    testWidgets('large text $page', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = GpixStore()..startTestDemo();
      await tester.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: switch (page) {
              'profile' => const Profile(user: 'me'),
              'chat' => const Chat(id: 't0'),
              _ => const Settings(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
  testWidgets('Home always returns the feed to the top', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    final finder = find.byKey(const PageStorageKey('feed'));
    await tester.drag(finder, const Offset(0, -550));
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(finder).controller!;
    expect(scroll.offset, greaterThan(0));
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, .1));
    await tester.drag(finder, const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cerca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(0, .1));
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('own story plus opens creation even when a story exists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    expect(s.stories(s.myId), isNotEmpty);
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-own-story')));
    await tester.pumpAndSettle();
    expect(find.byType(StoryCamera), findsOneWidget);
    expect(find.byType(Composer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('connections have tabs, search and follower removal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(home: Connections(user: s.myId)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 follower'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'andrea');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PersonTile),
        matching: find.text('andrea.rossi'),
      ),
      findsOneWidget,
    );
    expect(find.text('alex.rivera'), findsNothing);
    await tester.tap(find.text('Rimuovi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimuovi').last);
    await tester.pumpAndSettle();
    expect(s.me.ids('followersList'), isNot(contains('u0')));
    expect(s.me.number('followers'), 1);
    expect(find.text('1 follower'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('multiple emoji stickers can be added, moved and published', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-own-story')));
    await tester.pumpAndSettle();
    if (find.byType(StoryCamera).evaluate().isNotEmpty) {
      await tester.tap(find.text('Crea'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Testo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Giornata speciale');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    for (final emoji in ['🔥', '💜']) {
      await tester.tap(find.byTooltip('Sticker'));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPicker), findsOneWidget);
      await tester.tap(find.text(emoji).last);
      await tester.pumpAndSettle();
    }
    final before = tester
        .widget<StoryCanvas>(find.byType(StoryCanvas).last)
        .story
        .obj('style')
        .rows('stickers')
        .last
        .number('x');
    await tester.drag(find.text('💜'), const Offset(80, -40));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Condividi'));
    await tester.pumpAndSettle();
    final p = s.stories(s.myId).first;
    expect(p.obj('style').rows('stickers').length, 2);
    expect(
      p.obj('style').rows('stickers').last.number('x'),
      greaterThan(before),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('story emoji picker sends a reaction in the original chat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: const StoryViewer(user: 'u0', ids: ['s0']),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('🔥').last);
    await tester.tap(find.text('🔥').last);
    await tester.pump(const Duration(milliseconds: 500));
    final m = s.thread('t0').rows('messages').last;
    expect(m.str('text'), '🔥');
    expect(m.obj('story').str('id'), 's0');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('private chat exposes voice and video calls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(home: const Chat(id: 't0')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chiamata vocale'), findsOneWidget);
    expect(find.byTooltip('Videochiamata'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('incoming call can be rejected from any page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late GpixStore s;
    var ended = false;
    final client = MockClient((request) async {
      final body = object(jsonDecode(request.body));
      ended = body.str('action') == 'callEnd';
      s.state.rows('calls').first['status'] = 'declined';
      return http.Response(
        jsonEncode({'state': s.state}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    s = GpixStore(client: client)..startTestDemo();
    s.demo = false;
    s.token = 'test';
    s.server = 'https://test';
    s.state['calls'] = [
      {
        'id': 'incoming',
        'caller': 'u0',
        'callee': s.myId,
        'thread': 't0',
        'status': 'ringing',
        'video': true,
        'created': now,
      },
    ];
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    expect(find.text('Videochiamata in arrivo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reject-call')));
    await tester.pumpAndSettle();
    expect(ended, isTrue);
    expect(find.text('Videochiamata in arrivo'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'long server errors remain scrollable with a visible confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => gpixAlert(
                  c,
                  'Errore del server',
                  List.filled(500, 'Messaggio di errore.').join(' '),
                ),
                child: const Text('Apri errore'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri errore'));
      await tester.pumpAndSettle();
      expect(find.text('OK').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Home resets the story strip and puts unviewed users first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await s.act('see', {'id': 's0'});
    expect(s.storyUsers.first.str('id'), 'u1');
    expect(s.storyUsers.last.str('id'), 'u0');
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    final strip = find.byKey(const ValueKey('stories-strip'));
    await tester.drag(strip, const Offset(-250, 0));
    await tester.pumpAndSettle();
    final controller = tester.widget<ListView>(strip).controller!;
    expect(controller.offset, greaterThan(0));
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, .1));
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Activity excludes private messages and calls', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    s.state['notifications'] = [
      {
        'id': 'a',
        'type': 'message',
        'actor': 'u0',
        'ref': 't0',
        'created': now,
      },
      {'id': 'b', 'type': 'call', 'actor': 'u0', 'ref': 't0', 'created': now},
      {'id': 'c', 'type': 'like', 'actor': 'u1', 'ref': 'p0', 'created': now},
    ];
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Activity()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('andrea.rossi'), findsNothing);
    expect(find.textContaining('giulia.b'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('read receipt information and privacy control are available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Chat(id: 't0')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visualizzato').last);
    await tester.pumpAndSettle();
    expect(find.text('Informazioni sul messaggio'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PersonTile),
        matching: find.text('andrea.rossi'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Settings()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('settings-search')),
      'Messaggi',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messaggi e risposte alle storie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostra conferme di lettura'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Mostra conferme di lettura',
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(s.readReceipts, isFalse);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('once-only photo is consumed and cannot be reopened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Chat(id: 't0')),
      ),
    );
    await tester.pumpAndSettle();
    final photo = find.text('Tocca per aprire · una volta');
    await tester.ensureVisible(photo);
    await tester.tap(photo);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(OncePhoto), findsOneWidget);
    expect(s.message('once-demo').ids('openedBy'), contains(s.myId));
    await tester.tap(find.byTooltip('Chiudi foto'));
    await tester.pumpAndSettle();
    expect(find.text('Foto aperta'), findsWidgets);
    await expectLater(s.openOnce('once-demo'), throwsException);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('chat sends a real animated GIF and a sticker', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Chat(id: 't0')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Allegati'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('GIF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final item = find
        .descendant(
          of: find.byType(GiphyGallery),
          matching: find.byType(MediaView),
        )
        .first;
    await tester.tap(item);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.thread('t0').rows('messages').last.str('kind'), 'gif');
    await tester.tap(find.byTooltip('Allegati'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Sticker'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('🌈').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(s.thread('t0').rows('messages').last.str('kind'), 'sticker');
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('timed message expires in the chat UI', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Chat(id: 't0')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Allegati'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messaggi a scadenza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 minuto'));
    await tester.tap(find.text('Salva durata'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Questo scade');
    await tester.pump();
    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();
    final m = s.thread('t0').rows('messages').last;
    expect(m.number('expires'), greaterThan(now));
    m['expires'] = now - 1;
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Messaggio scaduto'), findsOneWidget);
    expect(find.text('Questo scade'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('live creation is available from the creation studio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Crea'));
    await tester.pumpAndSettle();
    final modes = find.byType(PageView);
    for (var index = 0; index < 4; index++) {
      await tester.drag(modes, const Offset(-90, 0));
      await tester.pumpAndSettle();
    }
    expect(find.text('Titolo della diretta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  test('camera collage and Boomerang encode actual media', () async {
    final root = await Directory.systemTemp.createTemp('gpix-camera-test-');
    try {
      final collage = await storyComposite([
        'assets/media/post0.jpg',
        'assets/media/post1.jpg',
      ], '${root.path}/layout.jpg');
      final img = image_lib.decodeImage(await File(collage).readAsBytes())!;
      expect(img.width, 720);
      expect(img.height, 1280);
      final boom = await storyComposite(
        [
          'assets/media/post0.jpg',
          'assets/media/post1.jpg',
          'assets/media/post2.jpg',
        ],
        '${root.path}/boom.gif',
        boomerang: true,
      );
      final animation = image_lib.decodeGif(await File(boom).readAsBytes())!;
      expect(animation.numFrames, 4);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test(
    'new social state excludes self views, reads individually and toggles reposts',
    () async {
      final s = GpixStore()..startTestDemo();
      await s.act('post', {
        'kind': 'story',
        'text': 'Only us',
        'audience': 'close',
      });
      final p = s.stories(s.myId).first;
      await s.act('see', {'id': p['id']});
      expect(s.viewers(p), isEmpty);
      p['viewers'] = [s.myId, 'u0'];
      expect(s.viewers(p), ['u0']);
      s.state['notifications'] = [
        {'id': 'one', 'seen': false, 'type': 'like'},
        {'id': 'two', 'seen': false, 'type': 'comment'},
      ];
      expect(s.hasActivity, isTrue);
      await s.act('notificationsRead', {'id': 'one'});
      expect(s.hasActivity, isTrue);
      expect(s.socialNotifications.first.flag('seen'), isTrue);
      expect(s.socialNotifications.last.flag('seen'), isFalse);
      await s.act('notificationsRead', {'id': 'two'});
      expect(s.hasActivity, isFalse);
      await s.act('repost', {'id': 'p0'});
      expect(s.post('p0').ids('reposts'), contains(s.myId));
      await s.act('repost', {'id': 'p0', 'enabled': false});
      expect(s.post('p0').ids('reposts'), isEmpty);
      s.dispose();
    },
  );
  testWidgets('close friends can be edited in their page and from a profile', (
    tester,
  ) async {
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: CloseFriends()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'andrea.rossi'));
    await tester.pumpAndSettle();
    expect(s.state.ids('closeFriends'), contains('u0'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Profile(user: 'u0')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opzioni profilo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rimuovi dagli amici più stretti'));
    await tester.pumpAndSettle();
    expect(s.state.ids('closeFriends'), isNot(contains('u0')));
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('notes publish, appear in inbox, replace and delete', (
    tester,
  ) async {
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Inbox()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('La tua nota'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Un pensiero per oggi');
    await tester.pump();
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    expect(s.notes.single.str('text'), 'Un pensiero per oggi');
    expect(find.text('Un pensiero per oggi'), findsOneWidget);
    await tester.tap(find.text('La tua nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina nota'));
    await tester.pumpAndSettle();
    expect(s.notes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('own story options add the current story to highlights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await s.act('post', {'kind': 'story', 'text': 'Today'});
    final id = s.stories(s.myId).first.str('id');
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: StoryViewer(user: s.myId, ids: [id]),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Altro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('Metti in evidenza'));
    await tester.tap(find.text('Metti in evidenza'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.ensureVisible(find.text('Nuova raccolta'));
    await tester.tap(find.text('Nuova raccolta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField).last, 'Ricordi');
    await tester.pump();
    await tester.tap(find.text('Salva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(s.highlights(s.myId).last.ids('posts'), contains(id));
    expect(s.viewers(s.post(id)), isEmpty);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  test(
    'story ring follows newest audience rather than any older close story',
    () async {
      final s = GpixStore()..startTestDemo();
      await s.act('post', {
        'kind': 'story',
        'text': 'close',
        'audience': 'close',
      });
      expect(s.closeStory(s.myId), isTrue);
      await s.act('post', {
        'kind': 'story',
        'text': 'public',
        'audience': 'all',
      });
      expect(s.closeStory(s.myId), isFalse);
      await s.act('post', {
        'kind': 'story',
        'text': 'close again',
        'audience': 'close',
      });
      expect(s.closeStory(s.myId), isTrue);
      s.dispose();
    },
  );
  testWidgets('photo preview cycles keep, once, replay before returning mode', (
    tester,
  ) async {
    final s = GpixStore()..startTestDemo();
    BuildContext? page;
    int? result;
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              page = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    open<int>(
      page!,
      const PhotoSend(path: 'post0.jpg', recipient: 'Andrea'),
    ).then((v) => result = v);
    await tester.pumpAndSettle();
    expect(find.text('Conserva nella chat'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photo-mode')));
    await tester.pump();
    expect(find.text('Visualizza una volta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photo-mode')));
    await tester.pump();
    expect(find.text('Consenti di riprodurre di nuovo'), findsOneWidget);
    await tester.tap(find.text('Invia'));
    await tester.pumpAndSettle();
    expect(result, 2);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('Home requests fresh remote state on every tap', (tester) async {
    final source = GpixStore()..startTestDemo();
    final snapshot = jsonDecode(jsonEncode(source.state));
    source.dispose();
    int requests = 0;
    final s = GpixStore(
      client: MockClient((r) async {
        expect(r.url.path, '/state');
        requests++;
        return http.Response(
          jsonEncode({'state': snapshot}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    s.state = object(snapshot);
    s.ready = true;
    s.server = 'https://gpix.test';
    s.token = 'test';
    await tester.pumpWidget(GpixApp(store: s));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('GIPHY uses authenticated server proxy without exposing a key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'gpix.giphyKey': 'test-key'});
    final queries = <Uri>[];
    final s = GpixStore(
      client: MockClient((r) async {
        queries.add(r.url);
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'gif',
                'images': {
                  'fixed_height': {
                    'url': 'https://media0.giphy.com/media/test/giphy.gif',
                  },
                  'original': {
                    'url': 'https://media0.giphy.com/media/test/giphy.gif',
                  },
                },
              },
            ],
            'pagination': {'total_count': 1},
          }),
          200,
        );
      }),
    )..startTestDemo();
    s.demo = false;
    s.server = 'https://gpix.test';
    s.token = 'test-token';
    String selected = '';
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GiphyGallery(
                onSelected: (v) => selected = v,
                onImport: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(queries.single.path, '/giphy');
    expect(queries.single.queryParameters.containsKey('api_key'), isFalse);
    await tester.enterText(find.byType(TextField), 'ciao mondo');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(queries.last.path, '/giphy');
    expect(queries.last.queryParameters['q'], 'ciao mondo');
    await tester.tap(find.byType(MediaView).first);
    expect(selected, 'https://media0.giphy.com/media/test/giphy.gif');
    expect(find.text('Powered By GIPHY'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    SharedPreferences.setMockInitialValues({});
  });
  test('post export crops and applies the same monochrome matrix', () async {
    final root = await Directory.systemTemp.createTemp('gpix-post-');
    try {
      final out = await renderPostPhoto({
        'path': File('assets/media/post0.jpg').absolute.path,
        'output': '${root.path}/post.jpg',
        'aspect': .8,
        'filter': 'Mono',
        'brightness': 1.0,
      });
      final image = image_lib.decodeImage(await File(out).readAsBytes())!;
      expect(image.width / image.height, closeTo(.8, .01));
      final pixel = image.getPixel(image.width ~/ 2, image.height ~/ 2);
      expect((pixel.r - pixel.g).abs(), lessThan(3));
      expect((pixel.g - pixel.b).abs(), lessThan(3));
    } finally {
      await root.delete(recursive: true);
    }
  });
  testWidgets('post creation moves from selection to edit to share', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(home: PostComposer(initialFiles: ['post0.jpg'])),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('Testo'), findsOneWidget);
    await tester.tap(find.text('Filtri'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mono'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          )
          .last,
    );
    await tester.tap(find.text('Mono'));
    await tester.tap(find.text('Fine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Aggiungi una didascalia…'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Altre opzioni'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('Altre opzioni'));
    await tester.pumpAndSettle();
    expect(find.text('Disattiva commenti'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('inbox avatar opens the story while the row opens the chat', (
    tester,
  ) async {
    final s = GpixStore()..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Inbox()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is Avatar && w.user == 'u0').first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(StoryViewer), findsOneWidget);
    expect(find.byType(Chat), findsNothing);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('own story has one options menu and no duplicate top menu', (
    tester,
  ) async {
    final s = GpixStore()..startTestDemo();
    await s.act('post', {'kind': 'story', 'text': 'Today'});
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: StoryViewer(
            user: s.myId,
            ids: [s.stories(s.myId).first.str('id')],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byTooltip('Altro'), findsOneWidget);
    expect(find.byTooltip('Opzioni storia'), findsNothing);
    expect(find.text('In evidenza'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets('GIPHY configuration is absent from mobile app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = GpixStore(
      client: MockClient(
        (r) async =>
            http.Response('{"data":[],"pagination":{"total_count":0}}', 200),
      ),
    )..startTestDemo();
    await tester.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GiphyGallery(onSelected: (_) {}, onImport: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Collega GIPHY'), findsNothing);
    expect(find.text('Powered By GIPHY'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
    SharedPreferences.setMockInitialValues({});
  });
}
