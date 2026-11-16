import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/shell.dart';
import 'package:gpix/rebuild/surfaces.dart';
import 'package:gpix/screens/creation_studio.dart';
import 'package:gpix/screens/moments.dart';
import 'package:gpix/screens/people.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:image/image.dart' as im;
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/screens/video.dart' show ClipPlayer;
import 'package:gpix/ui/kit.dart';

Future<void> mount(
  WidgetTester tester,
  GpixStore store,
  Widget screen, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    GpixScope(
      store: store,
      child: MaterialApp(theme: gpixTheme(brightness), home: screen),
    ),
  );
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  testWidgets('Feed actions stay grouped at the left and hide zero counters', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final post = Map<String, dynamic>.of(store.posts.first)
      ..['author'] = store.myId
      ..['kind'] = 'post'
      ..['audience'] = 'all'
      ..['likes'] = [store.myId]
      ..['comments'] = <J>[]
      ..['shareCount'] = 0
      ..['style'] = <String, dynamic>{};
    await mount(
      tester,
      store,
      Scaffold(
        body: ListView(children: [TimelinePost(post: post)]),
      ),
    );
    final like = find.byTooltip('Rimuovi Mi piace');
    final comments = find.byTooltip('Commenti');
    final share = find.byTooltip('Condividi');
    final save = find.byTooltip('Salva');
    expect(
      tester.getTopLeft(comments).dx - tester.getTopRight(like).dx,
      closeTo(14, .5),
    );
    expect(
      tester.getTopLeft(save).dx - tester.getTopRight(share).dx,
      greaterThan(55),
    );
    expect(
      find.descendant(of: comments, matching: find.text('0')),
      findsNothing,
    );
    expect(find.descendant(of: share, matching: find.text('0')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Home activity counts comments and likes, then expires and clears on open',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final actor = store.users.first.str('id');
      store.state['notifications'] = [
        for (final kind in ['like', 'comment'])
          {
            'id': kind,
            'actor': actor,
            'type': kind,
            'created': now,
            'seen': false,
          },
      ];
      await mount(tester, store, const SocialShell());
      final bubble = find.byKey(const ValueKey('activity-bubble'));
      expect(bubble, findsOneWidget);
      expect(
        find.descendant(of: bubble, matching: find.text('2')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(bubble, findsNothing);
      expect(store.hasActivity, isTrue);
      await tester.tap(find.byTooltip('Attività').first);
      await tester.pumpAndSettle();
      expect(store.hasActivity, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'A tag notification opens its photo and supports hiding and removal',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final author = store.users.firstWhere(
        (user) => user.str('id') != store.myId,
      );
      final post = Map<String, dynamic>.of(store.posts.first)
        ..['author'] = author.str('id')
        ..['kind'] = 'post'
        ..['mediaItems'] = ['post0.jpg', 'post1.jpg']
        ..['style'] = {
          'aspect': 1,
          'taggedUsers': [store.myId],
          'photoTags': [
            {'slide': 1, 'user': store.myId, 'x': .25, 'y': .5},
          ],
        };
      store.state['posts'] = [post];
      store.state['notifications'] = <J>[
        {
          'id': 'tag-notice',
          'actor': author.str('id'),
          'type': 'postTag',
          'ref': post.str('id'),
          'created': now,
        },
      ];
      await mount(tester, store, const Activity());
      await tester.tap(find.byKey(const ValueKey('tag-notice')));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(find.byType(PostTagLabel), findsOneWidget);

      await tester.tap(find.text('Gestisci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nascondi dal mio profilo'));
      await tester.pumpAndSettle();
      expect(store.taggedPosts(store.myId), isEmpty);
      expect(store.taggedPosts(store.myId, hidden: true), hasLength(1));
      expect(find.byType(PostTagLabel), findsOneWidget);

      await tester.tap(find.text('Gestisci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostra sul mio profilo'));
      await tester.pumpAndSettle();
      expect(store.taggedPosts(store.myId), hasLength(1));

      await tester.tap(find.text('Gestisci'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi il mio tag dal post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi'));
      await tester.pumpAndSettle();
      expect(store.taggedInPost(post, store.myId), isFalse);
      expect(find.byType(PostTagLabel), findsNothing);
      expect(store.socialNotifications, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('An accepted collaboration shows one post under both names', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final author = store.users.firstWhere(
      (user) => user.str('id') != store.myId,
    );
    final post = Map<String, dynamic>.of(store.posts.first)
      ..['author'] = author.str('id')
      ..['kind'] = 'post'
      ..['collaborationPending'] = true;
    store.state['posts'] = [post];
    await mount(tester, store, PostPage(id: post.str('id')));
    await tester.tap(find.text('Accetta'));
    await tester.pumpAndSettle();
    expect(post.ids('collaborators'), [store.myId]);
    expect(
      find.text('${author.str('username')} e ${store.me.str('username')}'),
      findsOneWidget,
    );
    expect(find.text('Accetta'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Published carousel shows positioned tags for the active photo', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final users = store.users
        .where((user) => user.str('id') != store.myId)
        .take(2)
        .toList();
    final post = Map<String, dynamic>.of(store.posts.first)
      ..['kind'] = 'post'
      ..['mediaItems'] = ['post0.jpg', 'post1.jpg']
      ..['style'] = {
        'aspect': 1,
        'taggedUsers': users.map((user) => user.str('id')).toList(),
        'photoTags': [
          for (final (index, user) in users.indexed)
            {'slide': index, 'user': user.str('id'), 'x': .25, 'y': .5},
        ],
      };
    store.state['posts'] = [post];

    await mount(tester, store, PostPage(id: post.str('id')));
    expect(find.byType(PostTagLabel), findsNothing);
    await tester.tap(find.byTooltip('Mostra tag sulla foto'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Nascondi tag sulla foto'), findsOneWidget);
    expect(
      tester.widget<PostTagLabel>(find.byType(PostTagLabel)).name,
      users.first.str('username'),
    );

    await tester.tap(find.byType(PostTagLabel));
    await tester.pumpAndSettle();
    expect(find.byType(Profile), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(270, 204), const Offset(-262, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostTagLabel>(find.byType(PostTagLabel)).name,
      users.last.str('username'),
    );
    await tester.tap(find.byTooltip('Nascondi tag sulla foto'));
    await tester.pumpAndSettle();
    expect(find.byType(PostTagLabel), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Post composer keeps carousel selection and edited caption', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final files = ['post0.jpg', 'post1.jpg', 'post2.jpg'];
    await mount(tester, store, PostComposer(initialFiles: files));
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica post'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-275, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    expect(find.text('Condividi'), findsOneWidget);
    expect(find.text('Tagga persone'), findsOneWidget);
    expect(find.text('Aggiungi luogo'), findsOneWidget);
    await tester.tap(find.text('Aggiungi una didascalia…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Una giornata a Roma');
    await tester.tap(find.byTooltip('Fine'));
    await tester.pumpAndSettle();
    expect(find.text('Una giornata a Roma'), findsOneWidget);
    await tester.tap(find.text('Tagga persone'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    final people = store.users
        .where((user) => user.str('id') != store.myId)
        .take(2)
        .toList();
    final first = people.first.str('username');
    final second = people.last.str('username');

    Future<void> tag(int slide, String username) async {
      await tester.tap(find.byKey(ValueKey('tag-photo-$slide')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), username);
      await tester.pumpAndSettle();
      await tester.tap(find.text(username).first);
      await tester.pumpAndSettle();
    }

    await tag(1, second);
    final secondTag = find.byKey(
      ValueKey(('photo-tag', 1, people.last.str('id'))),
    );
    final center = tester.getCenter(secondTag);
    await tester.drag(secondTag, const Offset(22, 44));
    await tester.pumpAndSettle();
    expect(tester.getCenter(secondTag).dy, greaterThan(center.dy));

    await tester.dragFrom(const Offset(80, 145), const Offset(270, 0));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text(second), findsNothing);
    await tag(0, first);
    await tester.tap(find.byTooltip('Rimuovi tag'));
    await tester.pumpAndSettle();
    expect(find.text(first), findsNothing);
    await tag(0, first);
    await tester.tap(find.byTooltip('Fine'));
    await tester.pumpAndSettle();
    expect(find.text('2 persone'), findsOneWidget);

    await tester.tap(find.text('Tagga persone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invita collaboratori'));
    await tester.pumpAndSettle();
    expect(find.text('Invitare i collaboratori'), findsOneWidget);
    await tester.tap(find.text('Continua'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(first).first);
    await tester.pumpAndSettle();
    expect(find.text('Invito da inviare alla pubblicazione'), findsOneWidget);
    await tester.tap(find.byTooltip('Fine'));
    await tester.pumpAndSettle();
    expect(find.text('1 collaboratore'), findsOneWidget);

    await tester.tap(find.text('Aggiungi luogo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Piazza Navona');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usa «Piazza Navona»'));
    await tester.pumpAndSettle();
    expect(find.text('Piazza Navona'), findsOneWidget);
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Post export applies the crop of each asset', () async {
    final directory = await Directory.systemTemp.createTemp('gpix-crop-');
    addTearDown(() => directory.delete(recursive: true));
    final source = im.Image(width: 100, height: 200);
    for (final pixel in source) {
      pixel.r = pixel.y < 100 ? 255 : 0;
      pixel.b = pixel.y < 100 ? 0 : 255;
    }
    final path = '${directory.path}/source.png';
    await File(path).writeAsBytes(im.encodePng(source));
    Future<im.Image> crop(double y) async {
      final output = await renderPostPhoto({
        'path': path,
        'output': '${directory.path}/$y.jpg',
        'aspect': 1,
        'crop': {'y': y},
      });
      return im.decodeJpg(await File(output).readAsBytes())!;
    }

    final top = await crop(0);
    final bottom = await crop(1);
    expect(top.width, top.height);
    expect(top.getPixel(50, 50).r, greaterThan(240));
    expect(bottom.getPixel(50, 50).b, greaterThan(240));
  });

  testWidgets('Post detail opens at the selected carousel with owner actions', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final other = store.users
        .firstWhere((user) => user.str('id') != store.myId)
        .str('id');
    final sample = Map<String, dynamic>.of(store.posts.first)
      ..['id'] = 'selected'
      ..['kind'] = 'post'
      ..['author'] = store.myId
      ..['text'] = 'Post selezionato'
      ..['mediaItems'] = ['post0.jpg', 'post1.jpg', 'post2.jpg'];
    final previous = Map<String, dynamic>.of(sample)
      ..['id'] = 'previous'
      ..['author'] = other
      ..['text'] = 'Post precedente';
    store.state['posts'] = [previous, sample];
    await mount(
      tester,
      store,
      const PostPage(id: 'selected', postIds: ['previous', 'selected']),
    );
    final carousel = find.byType(PageView).hitTestable().first;
    await tester.drag(carousel, const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Opzioni del post').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Informazioni su questo post'), findsOneWidget);
    expect(find.text('Archivia'), findsOneWidget);
    expect(find.text('Segnala'), findsNothing);
    await tester.tap(find.text('Nascondi numero di Mi piace'));
    await tester.pumpAndSettle();
    expect(store.post('selected').flag('hideLikes'), isTrue);
    expect(find.text('2/3'), findsOneWidget);

    await tester.dragFrom(const Offset(150, 230), const Offset(0, 690));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opzioni del post').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('Segnala'), findsOneWidget);
    expect(find.text('Archivia'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Connections retain each search and confirm follower removal', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final follower = store.me.ids('followersList').first;
    final username = store.user(follower).str('username');
    final followingCount = store.state.ids('following').length;
    await mount(tester, store, Connections(user: store.myId));
    expect(find.text('Richieste di seguirti'), findsOneWidget);

    final followersSearch = find.byKey(
      const ValueKey(('connection-search', 0)),
    );
    await tester.enterText(followersSearch, username);
    await tester.pumpAndSettle();
    expect(find.text('Categorie'), findsNothing);

    await tester.tap(find.text('$followingCount seguiti'));
    await tester.pumpAndSettle();
    final followingSearch = find.byKey(
      const ValueKey(('connection-search', 1)),
    );
    expect(tester.widget<TextField>(followingSearch).controller!.text, isEmpty);

    await tester.tap(find.text('${store.me.str('followers')} follower'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(followersSearch).controller!.text,
      username,
    );
    await tester.tap(find.text('Rimuovi').first);
    await tester.pumpAndSettle();
    expect(find.text('Vuoi rimuovere il follower?'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(store.me.ids('followersList'), contains(follower));

    await tester.tap(find.text('Rimuovi').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Rimuovi'));
    await tester.pumpAndSettle();
    expect(store.me.ids('followersList'), isNot(contains(follower)));
    expect(find.text('Nessun risultato'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Feed and floating dock have independent horizontal gestures', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    await mount(tester, store, const SocialShell());
    final dock = find.byKey(const ValueKey('floating-dock'));
    final normalHeight = tester.getSize(dock).height;
    await tester.dragFrom(const Offset(200, 665), const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, lessThan(normalHeight));
    await tester.dragFrom(const Offset(200, 400), const Offset(0, 680));
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, normalHeight);
    await tester.dragFrom(const Offset(190, 280), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(find.text('Seguiti'), findsOneWidget);
    await tester.dragFrom(const Offset(190, 280), const Offset(-130, 0));
    await tester.pumpAndSettle();
    expect(find.text('Preferiti'), findsOneWidget);
    await tester.drag(dock, const Offset(-132, 0));
    await tester.pumpAndSettle();
    expect(find.byType(HomeTimeline).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Photo preview opens at the visible slide and can continue swiping',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final sample = Map<String, dynamic>.of(store.posts.first)
        ..['mediaItems'] = ['post0.jpg', 'post1.jpg', 'post2.jpg'];
      await mount(
        tester,
        store,
        Scaffold(
          body: ListView(children: [TimelinePost(post: sample)]),
        ),
      );
      await tester.dragFrom(const Offset(240, 240), const Offset(-270, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
      await tester.tapAt(const Offset(180, 240));
      await tester.pump(const Duration(milliseconds: 330));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.dragFrom(const Offset(270, 385), const Offset(-205, 0));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Home filters Preferiti using profiles selected from post options',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final sample = Map<String, dynamic>.of(store.posts.first)
        ..['author'] = store.users
            .firstWhere((user) => user.str('id') != store.myId)
            .str('id')
        ..['kind'] = 'post';
      store.state['posts'] = [sample];
      await mount(tester, store, const SocialShell());
      await tester.tap(find.byTooltip('Opzioni del post').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi ai preferiti'));
      await tester.pumpAndSettle();
      expect(store.feedFavorites, [sample.str('author')]);

      await tester.tap(find.text('Per te'));
      await tester.pumpAndSettle();
      expect(find.text('Seguiti'), findsOneWidget);
      await tester.tap(find.text('Preferiti'));
      await tester.pumpAndSettle();
      expect(find.byType(TimelinePost), findsOneWidget);
      await tester.tap(find.byTooltip('Gestisci preferito'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rimuovi dai preferiti'));
      await tester.pumpAndSettle();
      expect(find.text('Nessun post dei preferiti'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Home scrolls to the top first and then refreshes on retap', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    await mount(tester, store, const SocialShell());
    final feed = tester
        .widget<HomeTimeline>(find.byType(HomeTimeline))
        .controller;
    feed.jumpTo(240);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(feed.offset, 0);
    expect(store.homeRefreshRevision, 0);
    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(store.homeRefreshRevision, 1);
  });

  testWidgets('Feed menu opens the group directory', (tester) async {
    final store = GpixStore()..startTestDemo();
    await mount(tester, store, const SocialShell());
    await tester.tap(find.text('Per te'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruppi'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityDirectory).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'The story plus opens the media gallery and cancel returns to Home',
    (tester) async {
      const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(pickerChannel, (call) async {
        calls.add(call.method);
        return <String>[];
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(pickerChannel, null),
      );

      final store = GpixStore()..startTestDemo();
      await mount(tester, store, const SocialShell());
      await tester.tap(find.byKey(const ValueKey('create-own-story')));
      await tester.pumpAndSettle();
      expect(calls, ['pickMedia']);
      expect(find.byType(HomeTimeline).hitTestable(), findsOneWidget);
      expect(find.byTooltip('Chiudi fotocamera'), findsNothing);
    },
  );

  testWidgets('Explore shows its grid, recent searches and profile results', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final account = store.users.firstWhere(
      (user) => user.str('id') != store.myId,
    );
    final username = account.str('username');
    await store.rememberSearch('ultima ricerca');
    await mount(tester, store, const DiscoverHome());
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.byTooltip('Salvati'), findsOneWidget);
    final field = find.byKey(const ValueKey('explore-search'));
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('Recenti'), findsOneWidget);
    expect(find.text('ultima ricerca'), findsOneWidget);
    await tester.enterText(field, username);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profili'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, username), findsOneWidget);
    expect(store.searchHistory.first, username);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Activity groups story likes and opens the story mentioned', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final actors = store.users
        .where((user) => user.str('id') != store.myId)
        .take(3)
        .toList();
    final timestamp = now;
    store.state['posts'] = [
      {
        'id': 'activity-own-story',
        'author': store.myId,
        'kind': 'story',
        'created': timestamp,
        'expires': timestamp + 3600,
      },
      {
        'id': 'activity-mentioned-story',
        'author': actors.first.str('id'),
        'kind': 'story',
        'created': timestamp,
        'expires': timestamp + 3600,
        'style': {
          'stickers': [
            {'type': 'mention', 'label': '@${store.me.str('username')}'},
          ],
        },
      },
    ];
    store.state['notifications'] = [
      for (final (index, actor) in actors.indexed)
        {
          'id': 'grouped-like-$index',
          'actor': actor.str('id'),
          'type': 'storyLike',
          'ref': 'activity-own-story',
          'created': timestamp - index,
          'seen': false,
        },
    ];
    await mount(tester, store, const Activity());
    expect(find.text('Storie su di te'), findsOneWidget);
    expect(find.text('In primo piano'), findsOneWidget);
    final row = find.textContaining('e altri 1', findRichText: true);
    expect(row, findsOneWidget);
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      store.socialNotifications.every((item) => item.flag('seen')),
      isTrue,
    );
    expect(tester.widget<StoryViewer>(find.byType(StoryViewer)).ids, [
      'activity-own-story',
    ]);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menzioni'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(tester.widget<StoryViewer>(find.byType(StoryViewer)).ids, [
      'activity-mentioned-story',
    ]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Follow requests can be selected and confirmed together', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    store.state['requests'] = store.users
        .where((u) => u.str('id') != store.myId)
        .take(2)
        .map((user) => user.str('id'))
        .toList();
    await mount(tester, store, const Requests());
    await tester.tap(find.text('Gestisci'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona tutti'));
    await tester.pumpAndSettle();
    expect(find.text('2 selezionate'), findsOneWidget);
    await tester.tap(find.text('Conferma (2)'));
    await tester.pumpAndSettle();
    expect(store.state.ids('requests'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Post comments collapse replies and keep the reply composer above the keyboard',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final viewer = store.users.firstWhere((u) => u.str('id') != store.myId);
      final id = viewer.str('id');
      final post = {
        ...store.posts.first,
        'id': 'test-post-comments',
        'comments': [
          {
            'id': 'root',
            'author': id,
            'text': 'Che foto!',
            'created': now,
            'likes': <String>[],
          },
          {
            'id': 'child',
            'author': store.myId,
            'text': 'Grazie!',
            'parent': 'root',
            'created': now,
          },
        ],
      };
      store.state['posts'] = [post];
      await mount(
        tester,
        store,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => comments(c, 'test-post-comments'),
              child: const Text('Apri commenti'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri commenti'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Condividi post'), findsOneWidget);
      expect(find.text('Grazie!'), findsNothing);
      await tester.tap(find.text('Visualizza 1 risposta'));
      await tester.pumpAndSettle();
      expect(find.text('Grazie!'), findsOneWidget);
      await tester.tap(find.byTooltip('Mi piace al commento').first);
      await tester.pumpAndSettle();
      expect(
        store.post('test-post-comments').rows('comments').first.ids('likes'),
        [store.myId],
      );
      await tester.tap(find.text('Rispondi').first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 390);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('post-comment-input'));
      expect(tester.getBottomLeft(field).dy, lessThanOrEqualTo(410));
      expect(
        tester.widget<TextField>(field).controller!.text,
        '@${viewer.str('username')} ',
      );
      expect(find.byTooltip('Pubblica commento'), findsNothing);
      await tester.enterText(field, '@${viewer.str('username')} grazie ancora');
      await tester.pump();
      await tester.tap(find.byTooltip('Pubblica commento'));
      await tester.pumpAndSettle();
      expect(
        store.post('test-post-comments').rows('comments').last.str('parent'),
        'root',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Share keeps selections across searches and sends the optional message',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final post = store.posts.first;
      final recipients = store.users
          .where((u) => u.str('id') != store.myId)
          .take(2)
          .toList();
      await mount(
        tester,
        store,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => sharePost(c, post),
              child: const Text('Apri condivisione'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri condivisione'));
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      for (final user in recipients) {
        await tester.enterText(search, '@${user.str('username')}');
        await tester.pumpAndSettle();
        await tester.tap(find.text(user.str('name')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField).last, 'Guarda qui');
      await tester.tap(find.text('Invia separatamente'));
      await tester.pumpAndSettle();
      for (final user in recipients) {
        final messages = store.threads
            .firstWhere(
              (thread) => thread.ids('members').contains(user.str('id')),
            )
            .rows('messages');
        expect(messages[messages.length - 2].str('post'), post.str('id'));
        expect(messages.last.str('text'), 'Guarda qui');
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Share can send once to a newly created group', (tester) async {
    final store = GpixStore()..startTestDemo();
    final post = store.posts.first;
    final recipients = store.users
        .where((user) => user.str('id') != store.myId)
        .take(2)
        .toList();
    final existing = store.threads.map((thread) => thread.str('id')).toSet();
    await mount(
      tester,
      store,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => sharePost(context, post),
            child: const Text('Condividi'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Condividi'));
    await tester.pumpAndSettle();
    final search = find.byType(TextField).first;
    for (final user in recipients) {
      await tester.enterText(search, user.str('username'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(user.str('name')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Invia a nuova chat di gruppo (2)'));
    await tester.pumpAndSettle();
    final group = store.threads.singleWhere(
      (thread) => !existing.contains(thread.str('id')),
    );
    expect(group.ids('members').toSet(), {
      store.myId,
      ...recipients.map((user) => user.str('id')),
    });
    expect(group.rows('messages').single.str('post'), post.str('id'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Share opens the story editor with a reference to the public post',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final post = store.posts.firstWhere(store.canSharePublicPost);
      await mount(
        tester,
        store,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => sharePost(c, post),
              child: const Text('Apri condivisione'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri condivisione'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aggiungi alla storia'));
      await tester.pumpAndSettle();
      final editor = tester.widget<Composer>(find.byType(Composer));
      expect(
        editor.initialDraft!.obj('style').rows('stickers').single.str('postId'),
        post.str('id'),
      );
      expect(find.text('Contenuto condiviso'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Shared reel fills the story canvas with the original video player',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      final source = store.posts.firstWhere(store.canSharePublicPost);
      final reel = {
        ...source,
        'id': 'full-story-reel',
        'kind': 'reel',
        'media': 'reel0.mp4',
      };
      store.state['posts'] = [reel, ...store.allPosts];
      await mount(
        tester,
        store,
        Scaffold(
          body: StoryCanvas(
            story: {
              'style': {
                'stickers': [
                  {'type': 'sharedPost', 'postId': reel['id']},
                ],
              },
            },
          ),
        ),
      );
      final player = find.byType(ClipPlayer);
      expect(tester.widget<ClipPlayer>(player).reference, 'reel0.mp4');
      expect(tester.widget<ClipPlayer>(player).fit, BoxFit.cover);
      expect(tester.getSize(player), tester.getSize(find.byType(StoryCanvas)));
      expect(find.text('Apri reel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Saved posts can be added to a collection in manage mode', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    final posts = store.posts.take(2).toList();
    store.state['posts'] = [
      for (final post in posts) {...post, 'saved': true},
    ];
    await store.saveCollection('test-folder', 'Viaggio', []);
    await mount(tester, store, const CollectionPage(kind: 'saved'));
    expect(find.text('Salvato'), findsOneWidget);
    await tester.tap(find.text('Gestisci'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleziona tutti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi alla raccolta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viaggio'));
    await tester.pumpAndSettle();
    expect(
      store.savedCollections.single.ids('posts').toSet(),
      posts.map((post) => post.str('id')).toSet(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Private own photo carousel can be added to a story and exported with both images',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      store.me['private'] = true;
      final post = <String, dynamic>{
        'id': 'own-photo-carousel',
        'author': store.myId,
        'kind': 'post',
        'audience': 'followers',
        'text': 'Due foto',
        'media': 'post0.jpg',
        'mediaItems': [
          for (final name in ['post0.jpg', 'post1.jpg'])
            File('assets/media/$name').absolute.path,
        ],
      };
      store.state['posts'] = [post];
      final temp = Directory.systemTemp.createTempSync('gpix-share-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      const path = MethodChannel('plugins.flutter.io/path_provider');
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      List<String>? exported;
      messenger.setMockMethodCallHandler(path, (_) async => temp.path);
      messenger.setMockMethodCallHandler(share, (call) async {
        final arguments = call.arguments as Map;
        final paths = (arguments['paths'] as List).cast<String>();
        expect(paths, hasLength(2));
        expect(
          paths.map((file) => File(file).lengthSync()),
          everyElement(greaterThan(0)),
        );
        exported = (arguments['mimeTypes'] as List).cast<String>();
        return 'success';
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(path, null);
        messenger.setMockMethodCallHandler(share, null);
      });
      await mount(
        tester,
        store,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => sharePost(c, post),
              child: const Text('Apri condivisione'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri condivisione'));
      await tester.pumpAndSettle();
      expect(find.text('Aggiungi alla storia'), findsOneWidget);
      final addToStory = find
          .ancestor(
            of: find.text('Aggiungi alla storia'),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.runAsync(() async {
        await tester.tap(find.text('Condividi in…'));
        for (var attempt = 0; attempt < 40; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          await tester.pump();
          if (exported != null &&
              tester.widget<InkWell>(addToStory).onTap != null) {
            break;
          }
        }
      });
      await tester.pumpAndSettle();
      expect(exported, ['image/jpeg', 'image/jpeg']);
      await tester.tap(find.text('Aggiungi alla storia'));
      await tester.pumpAndSettle();
      expect(find.byType(Composer), findsOneWidget);
      expect(find.text('Contenuto non disponibile'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Crea keeps the editor and exposes modes by swipe', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    await mount(
      tester,
      store,
      const SocialShell(),
      brightness: Brightness.dark,
    );
    await tester.tap(find.byTooltip('Crea').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byTooltip('Chiudi fotocamera'), findsOneWidget);
    expect(find.byType(CreationStudio), findsOneWidget);
    await tester.tap(find.text('Post'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.text('Nuovo post'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
