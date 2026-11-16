import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/data.dart';
import '../core/reel_editing.dart' show ReelMedia;
import '../core/store.dart';
import '../ui/kit.dart';
import 'inbox_widgets.dart' show directSearchTerm;
import 'social.dart'
    show Comments, PostAction, Profile, comments, report, sharePost;
import 'video.dart' show ClipPlayer;

class PulsePage extends StatefulWidget {
  const PulsePage({super.key});

  @override
  State<PulsePage> createState() => _PulsePageState();
}

enum _PulseSection { home, search, activity, profile }

class _PulsePageState extends State<PulsePage> {
  _PulseSection section = _PulseSection.home;
  final storage = PageStorageBucket();

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final alerts = store.state.rows('notifications').where((notification) {
      return store.post(notification.str('ref')).str('kind') == 'text';
    }).toList();

    Widget destination(_PulseSection value, IconData icon, String label) {
      final selected = section == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          child: IconButton(
            tooltip: label,
            onPressed: () => setState(() => section = value),
            color: selected ? foreground(context) : secondaryText(context),
            icon: Badge(
              isLabelVisible:
                  value == _PulseSection.activity &&
                  alerts.any((notification) => !notification.flag('seen')),
              child: GIcon(icon, size: 25),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: section == _PulseSection.home
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GIcon(CupertinoIcons.waveform_path, size: 28),
                  SizedBox(width: 6),
                  Text('Pulse', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              )
            : pageTitle(switch (section) {
                _PulseSection.search => 'Cerca',
                _PulseSection.activity => 'Attività',
                _ => 'Profilo Pulse',
              }),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: PageStorage(
              bucket: storage,
              child: switch (section) {
                _PulseSection.home => const _PulseFeed(),
                _PulseSection.search => const _PulseSearch(),
                _PulseSection.activity => _PulseActivity(alerts: alerts),
                _PulseSection.profile => _PulseProfile(user: store.myId),
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: surface(context),
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              height: 57,
              width: 550,
              child: Row(
                children: [
                  destination(
                    _PulseSection.home,
                    section == _PulseSection.home
                        ? CupertinoIcons.house_fill
                        : CupertinoIcons.house,
                    'Home Pulse',
                  ),
                  destination(
                    _PulseSection.search,
                    CupertinoIcons.search,
                    'Cerca su Pulse',
                  ),
                  Expanded(
                    child: Center(
                      child: IconButton(
                        tooltip: 'Scrivi un post',
                        style: IconButton.styleFrom(
                          backgroundColor: subdued(context),
                          minimumSize: const Size(60, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: store.supportsTextPosts
                            ? () => open(context, const _PulseComposer())
                            : null,
                        icon: const GIcon(CupertinoIcons.plus, size: 23),
                      ),
                    ),
                  ),
                  destination(
                    _PulseSection.activity,
                    section == _PulseSection.activity
                        ? CupertinoIcons.heart_fill
                        : CupertinoIcons.heart,
                    'Attività Pulse',
                  ),
                  destination(
                    _PulseSection.profile,
                    section == _PulseSection.profile
                        ? CupertinoIcons.person_fill
                        : CupertinoIcons.person,
                    'Il tuo profilo Pulse',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseFeed extends StatelessWidget {
  const _PulseFeed();

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    if (!store.supportsTextPosts) {
      return const EmptyState(
        CupertinoIcons.waveform_path,
        'Pulse in arrivo',
        'Disponibile dopo l’aggiornamento del server GPIX.',
      );
    }
    double date(J post) => math.max(
      post.number('created'),
      post.obj('recentRepost').number('created'),
    );
    final feed = store.textPosts..sort((a, b) => date(b).compareTo(date(a)));
    final following = feed.where((post) {
      final author = post.str('author');
      return author == store.myId ||
          store.follows(author) ||
          post.obj('recentRepost').isNotEmpty;
    }).toList();
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const _PulseTabs(labels: ['Per te', 'Seguiti']),
          Expanded(
            child: TabBarView(
              children: [
                _PulseList(key: const PageStorageKey('pulse-all'), posts: feed),
                _PulseList(
                  key: const PageStorageKey('pulse-following'),
                  posts: following,
                  empty: 'Nessun post dai seguiti',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseTabs extends StatelessWidget {
  const _PulseTabs({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) => TabBar(
    dividerColor: Theme.of(context).dividerColor,
    indicatorColor: foreground(context),
    indicatorSize: TabBarIndicatorSize.tab,
    indicatorWeight: 2,
    labelColor: foreground(context),
    labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    unselectedLabelColor: secondaryText(context),
    tabs: [for (final label in labels) Tab(height: 43, text: label)],
  );
}

class _PulseList extends StatelessWidget {
  const _PulseList({
    super.key,
    required this.posts,
    this.empty = 'Nessun post',
  });
  final List<J> posts;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context, listen: false);
    return RefreshIndicator(
      color: foreground(context),
      onRefresh: () => perform(context, store.sync),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(CupertinoIcons.waveform_path, empty, ''),
            )
          else
            SliverList.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) => _PulseTile(
                key: ValueKey(posts[index].str('id')),
                post: posts[index],
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseSearch extends StatefulWidget {
  const _PulseSearch();

  @override
  State<_PulseSearch> createState() => _PulseSearchState();
}

class _PulseSearchState extends State<_PulseSearch> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final posts = query.isEmpty
        ? const <J>[]
        : store.textPosts
              .where(
                (post) => directSearchTerm(post.str('text')).contains(query),
              )
              .toList();
    final accounts = query.isEmpty
        ? const <J>[]
        : store.users
              .where((user) {
                return !store.blocked(user.str('id')) &&
                    directSearchTerm(
                      '${user.str('username')} ${user.str('name')}',
                    ).contains(query);
              })
              .take(12)
              .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() {
              query = directSearchTerm(
                value.trim().replaceFirst(RegExp(r'^@'), ''),
              );
            }),
            decoration: const InputDecoration(
              prefixIcon: GIcon(CupertinoIcons.search, size: 19),
              hintText: 'Cerca persone e post',
            ),
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? const SizedBox.shrink()
              : accounts.isEmpty && posts.isEmpty
              ? const EmptyState(CupertinoIcons.search, 'Nessun risultato', '')
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: accounts.length + posts.length,
                  itemBuilder: (context, index) {
                    if (index >= accounts.length) {
                      return _PulseTile(post: posts[index - accounts.length]);
                    }
                    final account = accounts[index];
                    final id = account.str('id');
                    return ListTile(
                      leading: Avatar(id),
                      title: Text(account.str('username')),
                      subtitle: Text(account.str('name')),
                      onTap: () => _openPulseProfile(context, id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PulseActivity extends StatelessWidget {
  const _PulseActivity({required this.alerts});
  final List<J> alerts;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    if (alerts.isEmpty) {
      return const EmptyState(
        CupertinoIcons.heart,
        'Nessuna attività su Pulse',
        '',
      );
    }
    return ListView.separated(
      key: const PageStorageKey('pulse-activity'),
      itemCount: alerts.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final actor = alert.str('actor');
        final username = store.user(actor).str('username');
        final action = switch (alert.str('type')) {
          'like' => 'ha messo Mi piace al tuo post',
          'comment' => 'ha risposto al tuo post',
          'repost' => 'ha ripubblicato il tuo post',
          _ => 'ha interagito con il tuo post',
        };
        return ListTile(
          leading: Avatar(actor),
          title: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: username,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' $action'),
              ],
            ),
          ),
          subtitle: Text(relative(alert['created'])),
          trailing: alert.flag('seen')
              ? null
              : const Icon(Icons.circle, size: 8, color: Color(0xffff3040)),
          onTap: () async {
            if (!alert.flag('seen')) {
              await perform(
                context,
                () => store.act('notificationsRead', {'id': alert.str('id')}),
              );
            }
            if (context.mounted)
              open(context, PulsePostPage(id: alert.str('ref')));
          },
        );
      },
    );
  }
}

void _openPulseProfile(BuildContext context, String id) {
  open(
    context,
    Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Profilo Pulse')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _PulseProfile(user: id),
          ),
        ),
      ),
    ),
  );
}

class _PulseProfile extends StatelessWidget {
  const _PulseProfile({required this.user});
  final String user;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final account = store.user(user);
    final username = account.str('username');
    final posts = store.textPosts;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.str('name', username),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@$username',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Avatar(user, size: 64),
                  ],
                ),
                if (account.str('bio').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      account.str('bio'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                TextButton(
                  onPressed: () => open(context, Profile(user: user)),
                  style: TextButton.styleFrom(
                    foregroundColor: foreground(context),
                  ),
                  child: const Text('Profilo GPIX'),
                ),
              ],
            ),
          ),
          const _PulseTabs(labels: ['Post', 'Ripubblicazioni']),
          Expanded(
            child: TabBarView(
              children: [
                _PulseList(
                  posts: posts
                      .where((post) => post.str('author') == user)
                      .toList(),
                ),
                _PulseList(
                  posts: posts
                      .where(
                        (post) =>
                            post.ids('reposts').contains(user) &&
                            store.canRepostPulse(post),
                      )
                      .toList(),
                  empty: 'Nessuna ripubblicazione',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PulsePostPage extends StatelessWidget {
  const PulsePostPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final post = GpixScope.of(context).post(id);
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Post')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: post.isEmpty
                ? const EmptyState(
                    CupertinoIcons.waveform_path,
                    'Post non disponibile',
                    '',
                  )
                : Comments(
                    id: id,
                    inlineHeader: _PulseTile(post: post, detail: true),
                  ),
          ),
        ),
      ),
    );
  }
}

class _PulseTile extends StatelessWidget {
  const _PulseTile({super.key, required this.post, this.detail = false});
  final J post;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final id = post.str('id');
    final author = post.str('author');
    final username = store.user(author).str('username');
    final own = author == store.myId;
    final likes = post.ids('likes');
    final liked = likes.contains(store.myId);
    final replies = post.rows('comments');
    final reposts = post.ids('reposts');
    final reposted = reposts.contains(store.myId);
    final canRepost = store.canRepostPulse(post);
    final recent = post.obj('recentRepost').str('user');
    final quote = post.obj('style').str('quotePostId');
    final shareCount = post.number('shareCount').toInt();
    final media = _pulseMedia(store, post);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!detail &&
                  recent.isNotEmpty &&
                  store.user(recent).str('username').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 13, bottom: 6),
                  child: Row(
                    children: [
                      GIcon(
                        CupertinoIcons.repeat,
                        size: 13,
                        color: secondaryText(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recent == store.myId
                              ? 'Hai ripubblicato'
                              : 'Ripubblicato da ${store.user(recent).str('username')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openPulseProfile(context, author),
                    customBorder: const CircleBorder(),
                    child: Avatar(author, size: 36),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: InkWell(
                                onTap: () => _openPulseProfile(context, author),
                                child: Text(
                                  username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: detail
                                  ? null
                                  : () => open(context, PulsePostPage(id: id)),
                              child: Text(
                                relative(post['created']),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryText(context),
                                ),
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              tooltip: 'Opzioni del post',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 156),
                              icon: const GIcon(
                                CupertinoIcons.ellipsis,
                                size: 20,
                              ),
                              onSelected: (value) async {
                                if (value == 'report') {
                                  await report(context, id);
                                } else if (await gpixAlert(
                                      context,
                                      'Eliminare il post?',
                                      'Il post sarà rimosso da Pulse.',
                                      confirm: 'Elimina',
                                      cancel: true,
                                    ) &&
                                    context.mounted) {
                                  await perform(
                                    context,
                                    () => store.act('deletePost', {'id': id}),
                                  );
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: own ? 'delete' : 'report',
                                  child: Text(own ? 'Elimina' : 'Segnala'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (post.str('text').isNotEmpty)
                          InkWell(
                            onTap: detail
                                ? null
                                : () => open(context, PulsePostPage(id: id)),
                            child: Text(
                              post.str('text'),
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.32,
                              ),
                            ),
                          ),
                        if (media.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _PulseMedia(items: media),
                          ),
                        if (quote.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _PulseQuote(id: quote),
                          ),
                        if (post.obj('style').obj('poll').isNotEmpty)
                          _PulsePoll(post: post),
                        if (post.obj('style').flag('aiLabel') ||
                            post.str('location').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              [
                                if (post.obj('style').flag('aiLabel'))
                                  'Info sull’IA',
                                if (post.str('location').isNotEmpty)
                                  post.str('location'),
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryText(context),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Flexible(
                              child: PostAction(
                                icon: liked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                label: liked ? 'Rimuovi Mi piace' : 'Mi piace',
                                color: liked ? const Color(0xffff3040) : null,
                                count: post.flag('hideLikes') && !own
                                    ? null
                                    : likes.length,
                                feed: true,
                                onTap: () => perform(
                                  context,
                                  () => store.act('like', {
                                    'id': id,
                                    'enabled': !liked,
                                  }),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Flexible(
                              child: PostAction(
                                icon: CupertinoIcons.chat_bubble,
                                label: 'Risposte',
                                count: replies.length,
                                feed: true,
                                onTap: () => comments(context, id),
                              ),
                            ),
                            if (store.supportsPulseMedia) ...[
                              const SizedBox(width: 14),
                              if (canRepost || reposted)
                                Flexible(
                                  child: PostAction(
                                    icon: CupertinoIcons.repeat,
                                    label: 'Ripubblica o cita',
                                    count: reposts.length,
                                    color: reposted
                                        ? const Color(0xff169553)
                                        : null,
                                    feed: true,
                                    onTap: () => sheet<void>(
                                      context,
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const GIcon(
                                              CupertinoIcons.repeat,
                                            ),
                                            title: Text(
                                              reposted
                                                  ? 'Rimuovi ripubblicazione'
                                                  : 'Ripubblica',
                                            ),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await perform(
                                                context,
                                                () => store.act('repost', {
                                                  'id': id,
                                                  'enabled': !reposted,
                                                }),
                                              );
                                            },
                                          ),
                                          if (canRepost)
                                            ListTile(
                                              leading: const GIcon(
                                                CupertinoIcons.quote_bubble,
                                              ),
                                              title: const Text('Cita'),
                                              onTap: () {
                                                Navigator.pop(context);
                                                open(
                                                  context,
                                                  _PulseComposer(quoteId: id),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Tooltip(
                                  message:
                                      'Le ripubblicazioni sono disponibili per i post pubblici',
                                  child: GIcon(
                                    CupertinoIcons.repeat,
                                    size: 24,
                                    color: secondaryText(
                                      context,
                                    ).withValues(alpha: .52),
                                  ),
                                ),
                              const SizedBox(width: 14),
                              Flexible(
                                child: PostAction(
                                  icon: CupertinoIcons.paperplane,
                                  label: 'Invia in chat',
                                  count: shareCount,
                                  feed: true,
                                  onTap: () => sharePost(context, post),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

typedef _PulseAttachment = ({String reference, bool video, String cover});

List<_PulseAttachment> _pulseMedia(GpixStore store, J post) {
  final entries = post['mediaItems'];
  if (entries is List && entries.isNotEmpty && entries.first is Map) {
    return [
      for (final entry in post.rows('mediaItems'))
        if (entry.str('url').isNotEmpty)
          (
            reference: entry.str('url'),
            video: entry.flag('video'),
            cover: entry.str('cover'),
          ),
    ];
  }
  final covers = post.obj('style').obj('videoCovers');
  return [
    for (final reference in store.media(post))
      (
        reference: reference,
        video: store.isVideoMedia(reference),
        cover: covers.str(reference),
      ),
  ];
}

class _PulseMedia extends StatelessWidget {
  const _PulseMedia({required this.items, this.onRemove});
  final List<_PulseAttachment> items;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final width = items.length == 1
            ? bounds.maxWidth
            : math.min(255.0, bounds.maxWidth * .86);
        final height = math.min(300.0, width * .82);
        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: width,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: () => open(
                          context,
                          _PulseGallery(items: items, initial: index),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (!item.video || item.cover.isNotEmpty)
                              MediaView(
                                item.video ? item.cover : item.reference,
                                thumbnail: true,
                                width: width,
                              )
                            else
                              ColoredBox(color: subdued(context)),
                            if (item.video)
                              const Center(
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    CupertinoIcons.play_fill,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (onRemove != null)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton(
                            tooltip: 'Rimuovi allegato',
                            color: Colors.white,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                            ),
                            onPressed: () => onRemove!(index),
                            icon: const Icon(CupertinoIcons.xmark, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PulseGallery extends StatefulWidget {
  const _PulseGallery({required this.items, required this.initial});
  final List<_PulseAttachment> items;
  final int initial;

  @override
  State<_PulseGallery> createState() => _PulseGalleryState();
}

class _PulseGalleryState extends State<_PulseGallery> {
  late int index = widget.initial;
  late final pages = PageController(initialPage: index);

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      centerTitle: true,
      title: widget.items.length > 1
          ? Text('${index + 1} / ${widget.items.length}')
          : null,
    ),
    body: SafeArea(
      top: false,
      child: PageView.builder(
        controller: pages,
        itemCount: widget.items.length,
        onPageChanged: (value) => setState(() => index = value),
        itemBuilder: (context, position) {
          final item = widget.items[position];
          if (item.video) {
            return ClipPlayer(
              key: ValueKey(item.reference),
              reference: item.reference,
              active: position == index,
              placeholder: item.cover.isEmpty
                  ? null
                  : MediaView(item.cover, fit: BoxFit.contain),
            );
          }
          return InteractiveViewer(
            child: Center(
              child: MediaView(item.reference, fit: BoxFit.contain),
            ),
          );
        },
      ),
    ),
  );
}

class _PulseQuote extends StatelessWidget {
  const _PulseQuote({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final post = store.post(id);
    final available = post.str('kind') == 'text' && !post.flag('archived');
    final author = post.str('author');
    final first = _pulseMedia(store, post).firstOrNull;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: available ? () => open(context, PulsePostPage(id: id)) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: !available
            ? Text(
                'Post non disponibile',
                style: TextStyle(color: secondaryText(context)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Avatar(author, size: 19),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          store.user(author).str('username'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (post.str('text').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        post.str('text'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (first != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: first.video
                          ? const GIcon(CupertinoIcons.play_rectangle, size: 25)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: MediaView(
                                first.reference,
                                width: 88,
                                height: 66,
                                thumbnail: true,
                              ),
                            ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PulsePoll extends StatelessWidget {
  const _PulsePoll({required this.post});
  final J post;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final poll = post.obj('style').obj('poll');
    final counts = poll['counts'];
    final options = poll.ids('options');
    final vote = poll.number('myVote', -1).toInt();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            poll.str('question'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final (index, option) in options.indexed)
            OutlinedButton(
              onPressed: () => perform(
                context,
                () => store.act('pollVote', {
                  'id': post.str('id'),
                  'choice': index,
                }),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground(context),
              ),
              child: Text(
                vote >= 0 && counts is List && index < counts.length
                    ? '${vote == index ? '✓ ' : ''}$option · ${counts[index]}'
                    : option,
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseComposer extends StatefulWidget {
  const _PulseComposer({this.quoteId = ''});
  final String quoteId;

  @override
  State<_PulseComposer> createState() => _PulseComposerState();
}

class _PulseComposerState extends State<_PulseComposer> {
  final draft = TextEditingController();
  final picker = ImagePicker();
  final files = <XFile>[];
  final uploaded = <String, String>{};
  final videoCovers = <String, String>{};
  final publishKey = newId();
  String audience = 'all';
  bool sending = false, picking = false;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  String mime(XFile file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.gif')) return 'image/gif';
    if (path.endsWith('.mov') || file.mimeType == 'video/quicktime')
      return 'video/quicktime';
    if (path.endsWith('.webm') || file.mimeType == 'video/webm')
      return 'video/webm';
    if (file.mimeType?.startsWith('video/') == true ||
        const ['.mp4', '.m4v', '.mkv', '.3gp'].any(path.endsWith)) {
      return 'video/mp4';
    }
    return 'image/jpeg';
  }

  bool get ready =>
      draft.text.trim().isNotEmpty ||
      files.isNotEmpty ||
      widget.quoteId.isNotEmpty;

  Future<void> attach() async {
    if (picking || sending || files.length >= 10) return;
    FocusScope.of(context).unfocus();
    setState(() => picking = true);
    await perform(context, () async {
      final remaining = 10 - files.length;
      final next = remaining == 1
          ? [
              await picker.pickMedia(
                imageQuality: 90,
                maxWidth: 2160,
                maxHeight: 2160,
              ),
            ].nonNulls
          : await picker.pickMultipleMedia(
              limit: remaining,
              imageQuality: 90,
              maxWidth: 2160,
              maxHeight: 2160,
            );
      if (mounted) {
        setState(() {
          final paths = files.map((file) => file.path).toSet();
          files.addAll(
            next.where((file) => paths.add(file.path)).take(remaining),
          );
        });
      }
    });
    if (mounted) setState(() => picking = false);
  }

  Future<void> publish() async {
    if (!ready || picking || sending) return;
    final store = GpixScope.of(context, listen: false);
    final text = draft.text.trim();
    final identity = (store.server, store.myId, store.token);
    setState(() => sending = true);
    await perform(context, () async {
      final ids = <String>[];
      final covers = <String, String>{};
      for (final file in files) {
        final type = mime(file);
        final id = uploaded[file.path] ??= await store.upload(file.path, type);
        if (!mounted || identity != (store.server, store.myId, store.token)) {
          return;
        }
        ids.add(id);
        if (type.startsWith('video/')) {
          final cover = videoCovers[id] ?? await uploadCover(store, file.path);
          if (!mounted || identity != (store.server, store.myId, store.token))
            return;
          if (cover != null) covers[id] = videoCovers[id] = cover;
        }
      }
      await store.act('post', {
        'kind': 'text',
        'text': text,
        'audience': audience,
        'idempotencyKey': publishKey,
        if (ids.isNotEmpty) 'media': ids.first,
        if (ids.isNotEmpty) 'mediaItems': ids,
        if (covers.isNotEmpty) 'videoCovers': covers,
        if (widget.quoteId.isNotEmpty) 'quotePostId': widget.quoteId,
      });
      if (mounted &&
          identity == (store.server, store.myId, store.token) &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
        notice(context, 'Pubblicato su Pulse');
      }
    });
    if (mounted) setState(() => sending = false);
  }

  Future<String?> uploadCover(GpixStore store, String path) async {
    final identity = (store.server, store.myId, store.token);
    final folder = await (await getTemporaryDirectory()).createTemp(
      'gpix-pulse-',
    );
    try {
      final jpg = await ReelMedia.cover(
        path: path,
        photo: false,
        positionMs: 0,
        folder: folder,
      );
      if (!mounted || identity != (store.server, store.myId, store.token))
        return null;
      return await store.upload(jpg, 'image/jpeg');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } finally {
      await folder.delete(recursive: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final audiences = {
      'all': store.me.flag('private') ? 'Follower approvati' : 'Tutti',
      'followers': 'Follower',
      'close': 'Amici più stretti',
    };
    return PopScope(
      canPop: !sending,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Annulla',
            onPressed: sending ? null : () => Navigator.pop(context),
            icon: const GIcon(CupertinoIcons.xmark, size: 20),
          ),
          title: pageTitle('Nuovo post'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Avatar(store.myId, size: 38),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.me.str('username'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextField(
                                    controller: draft,
                                    autofocus: true,
                                    enabled: !sending,
                                    minLines: 2,
                                    maxLines: null,
                                    maxLength: textPostLimit,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: const TextStyle(fontSize: 15),
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText: 'A cosa pensi?',
                                      filled: false,
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                    ),
                                  ),
                                  if (files.isNotEmpty)
                                    IgnorePointer(
                                      ignoring: sending,
                                      child: _PulseMedia(
                                        items: [
                                          for (final file in files)
                                            (
                                              reference: file.path,
                                              video: mime(
                                                file,
                                              ).startsWith('video/'),
                                              cover: '',
                                            ),
                                        ],
                                        onRemove: sending
                                            ? null
                                            : (index) => setState(
                                                () => files.removeAt(index),
                                              ),
                                      ),
                                    ),
                                  if (widget.quoteId.isNotEmpty)
                                    IgnorePointer(
                                      ignoring: sending,
                                      child: _PulseQuote(id: widget.quoteId),
                                    ),
                                  if (store.supportsPulseMedia)
                                    IconButton(
                                      tooltip: 'Aggiungi foto e video',
                                      onPressed:
                                          sending ||
                                              picking ||
                                              files.length >= 10
                                          ? null
                                          : attach,
                                      color: secondaryText(context),
                                      icon: const GIcon(
                                        CupertinoIcons.photo_on_rectangle,
                                        size: 23,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: PopupMenuButton<String>(
                            enabled: !sending,
                            initialValue: audience,
                            tooltip: 'Pubblico',
                            onSelected: (value) =>
                                setState(() => audience = value),
                            itemBuilder: (_) => [
                              for (final option in audiences.entries)
                                PopupMenuItem(
                                  value: option.key,
                                  child: Text(option.value),
                                ),
                            ],
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  const GIcon(CupertinoIcons.globe, size: 17),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      audiences[audience]!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: secondaryText(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: ready && !sending && !picking
                              ? publish
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: foreground(context),
                            foregroundColor: surface(context),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(sending ? 'Pubblicazione…' : 'Pubblica'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
