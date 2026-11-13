import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../screens/community.dart';
import '../screens/instants.dart';
import '../screens/features13.dart' show ProfileLinkChips;
import '../screens/messages.dart';
import '../screens/moments.dart';
import '../screens/people.dart';
import '../screens/post_extras.dart';
import '../screens/social.dart';
import '../screens/stories.dart';
import '../ui/kit.dart';

double _dockSpace(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom + 76;

class HomeTimeline extends StatefulWidget {
  const HomeTimeline({
    super.key,
    required this.controller,
    required this.onCreate,
    required this.onActivity,
    this.onBoundarySwipe,
  });
  final ScrollController controller;
  final VoidCallback onCreate, onActivity;
  final ValueChanged<int>? onBoundarySwipe;

  @override
  State<HomeTimeline> createState() => _HomeTimelineState();
}

class _HomeTimelineState extends State<HomeTimeline> {
  static const feeds = {
    'all': 'Per te',
    'following': 'Seguiti',
    'groups': 'Gruppi',
  };
  String feed = 'all';
  bool get following => feed == 'following';

  void selectFeed(String choice) {
    if (feed == choice) return;
    setState(() => feed = choice);
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
  }

  void swipeFeed(int step) {
    final sections = feeds.keys.toList();
    final next = sections.indexOf(feed) + step;
    if (next >= 0 && next < sections.length) {
      selectFeed(sections[next]);
    } else {
      widget.onBoundarySwipe?.call(step);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final mutedUsers = store.preferences.ids('muted').toSet();
    final posts = store.posts.where((post) {
      final author = post.str('author');
      return !mutedUsers.contains(author) &&
          (!following || author == store.myId || store.follows(author));
    }).toList();
    final postIds = posts.map((p) => p.str('id')).toSet();
    final groups = store.state
        .rows('socialGroups')
        .where(
          (group) =>
              !store.blocked(group.str('owner')) &&
              !mutedUsers.contains(group.str('owner')),
        );
    final moments = store.state
        .rows('socialItems')
        .where(
          (item) =>
              item.str('kind') == 'moment' &&
              !postIds.contains(item.str('post')) &&
              !store.blocked(item.str('author')) &&
              !mutedUsers.contains(item.str('author')),
        );
    final entries = <(String, J)>[
      for (final post in posts) ('post', post),
      if (!following) ...[
        for (final group in groups) ('group', group),
        for (final moment in moments) ('moment', moment),
      ],
    ]..sort((a, b) => b.$2.number('created').compareTo(a.$2.number('created')));
    return SectionSwipe(
      section: feeds.keys.toList().indexOf(feed),
      onStep: swipeFeed,
      child: RefreshIndicator(
        onRefresh: () => perform(context, store.refreshHome),
        child: CustomScrollView(
          key: PageStorageKey('rebuilt-feed-${store.myId}'),
          controller: widget.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              leading: IconButton(
                tooltip: 'Crea',
                onPressed: widget.onCreate,
                icon: const GIcon(CupertinoIcons.plus, size: 27),
              ),
              centerTitle: true,
              title: _FeedSelector(feed: feed, onSelected: selectFeed),
              actions: [
                IconButton(
                  tooltip: 'Attività',
                  onPressed: widget.onActivity,
                  icon: Badge(
                    isLabelVisible: store.hasActivity,
                    backgroundColor: danger,
                    child: const GIcon(CupertinoIcons.heart, size: 25),
                  ),
                ),
              ],
            ),
            if (feed == 'groups')
              SliverFillRemaining(
                child: CommunityDirectory(bottomPadding: _dockSpace(context)),
              )
            else ...[
              const SliverToBoxAdapter(child: StoryTray()),
              if (entries.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    CupertinoIcons.photo,
                    'Nessun post',
                    'I nuovi contenuti appariranno qui.',
                  ),
                ),
              SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final (kind, item) = entries[index];
                  final key = ValueKey((kind, item.str('id')));
                  return kind == 'post'
                      ? TimelinePost(key: key, post: item)
                      : KeyedSubtree(
                          key: key,
                          child: CommunityFeedCard(
                            item: item,
                            group: kind == 'group',
                          ),
                        );
                },
                findChildIndexCallback: (key) {
                  final index = entries.indexWhere(
                    (entry) => ValueKey((entry.$1, entry.$2.str('id'))) == key,
                  );
                  return index < 0 ? null : index;
                },
              ),
              SliverToBoxAdapter(child: SizedBox(height: _dockSpace(context))),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeedSelector extends StatefulWidget {
  const _FeedSelector({required this.feed, required this.onSelected});

  final String feed;
  final ValueChanged<String> onSelected;

  @override
  State<_FeedSelector> createState() => _FeedSelectorState();
}

class _FeedSelectorState extends State<_FeedSelector> {
  static const icons = {
    'all': CupertinoIcons.sparkles,
    'following': CupertinoIcons.person_2,
    'groups': CupertinoIcons.person_3,
  };
  bool expanded = false;

  Future<void> show() async {
    if (expanded) return;
    setState(() => expanded = true);
    final choice = await anchoredMenu<String>(
      context,
      [
        for (final entry in _HomeTimelineState.feeds.entries)
          dropdownRow(
            context,
            entry.key,
            entry.value,
            icons[entry.key]!,
            selected: widget.feed == entry.key,
          ),
      ],
      width: 199,
      label: 'Sezioni del feed',
    );
    if (!mounted) return;
    setState(() => expanded = false);
    if (choice != null) widget.onSelected(choice);
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 190);
    return Tooltip(
      message: 'Sezioni del feed',
      child: Semantics(
        button: true,
        expanded: expanded,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: show,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    child: Text(
                      _HomeTimelineState.feeds[widget.feed]!,
                      key: ValueKey(widget.feed),
                    ),
                  ),
                  const SizedBox(width: 7),
                  AnimatedRotation(
                    duration: duration,
                    turns: expanded ? .5 : 0,
                    child: GIcon(
                      CupertinoIcons.chevron_down,
                      size: 12,
                      color: secondaryText(context),
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

class TimelinePost extends StatefulWidget {
  const TimelinePost({super.key, required this.post, this.detail = false});

  final J post;
  final bool detail;

  @override
  State<TimelinePost> createState() => _TimelinePostState();
}

class _TimelinePostState extends State<TimelinePost> {
  int slide = 0;
  int burst = 0;
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final post = widget.post;
    final id = post.str('id');
    final author = post.str('author');
    final user = store.user(author);
    final username = user.str('username');
    final likes = post.ids('likes');
    final liked = likes.contains(store.myId);
    final reposts = post.ids('reposts');
    final reposted = reposts.contains(store.myId);
    final saved = post.flag('saved');
    final media = store.media(post);
    final replies = post.rows('comments');
    final caption = post.str('text');
    final location = post.str('location');
    final pending = store.state.ids('pending').contains(author);
    final moment = store.state
        .rows('socialItems')
        .firstWhere(
          (item) => item.str('kind') == 'moment' && item.str('post') == id,
          orElse: () => {},
        );
    final participants = <String>{
      if (moment.isNotEmpty) moment.str('author'),
      ...moment.rows('contributions').map((item) => item.str('author')),
    }..remove('');
    final canRepost =
        !user.flag('private') &&
        !const ['close', 'followers'].contains(post.str('audience'));
    final audience = switch (post.str('audience')) {
      'close' => 'Amici più stretti',
      'followers' when author == store.myId => 'Follower',
      _ => '',
    };
    final detail = [
      if (location.isNotEmpty) location,
      if (audience.isNotEmpty) audience,
    ].join(' · ');

    void like({bool force = false}) {
      if (force && !MediaQuery.disableAnimationsOf(context)) {
        setState(() => burst++);
      }
      if (force && liked) return;
      perform(context, () => store.act('like', {'id': id, 'enabled': !liked}));
    }

    return Column(
      key: ValueKey('feed-post-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reposts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              'Ripubblicato da ${reposts.take(3).map((id) => id == store.myId ? 'te' : store.user(id).str('username')).join(', ')}',
              style: TextStyle(color: secondaryText(context), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 3, 5, 3),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      open(context, ProfileHome(user: author, detail: true)),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Avatar(
                          author,
                          size: 34,
                          ring: store.hasUnseenStories(author),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryText(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (author != store.myId && !store.follows(author))
                TextButton(
                  onPressed: () => perform(
                    context,
                    () => store.act('follow', {
                      'user': author,
                      'enabled': !pending,
                    }),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: subdued(context),
                    foregroundColor: foreground(context),
                    minimumSize: const Size(64, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                  ),
                  child: Text(pending ? 'In attesa' : 'Segui'),
                ),
              IconButton(
                tooltip: 'Opzioni del post',
                onPressed: () => postMenu(context, post),
                icon: const GIcon(CupertinoIcons.ellipsis, size: 23),
              ),
            ],
          ),
        ),
        if (media.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final aspect = post
                  .obj('style')
                  .number('aspect', 1)
                  .clamp(.4, 2.5)
                  .toDouble();
              final current = slide.clamp(0, media.length - 1);
              Widget photo(int index) => MediaView(
                media[index],
                width: width,
                fit: BoxFit.contain,
                placeholderHeight: width / aspect,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openPhotoGallery(context, media, initial: current),
                onDoubleTap: () => like(force: true),
                child: ColoredBox(
                  color: subdued(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (media.length == 1)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: width / 2.5,
                            maxHeight: width * 2.5,
                          ),
                          child: photo(0),
                        )
                      else
                        AspectRatio(
                          aspectRatio: aspect,
                          child: PageView.builder(
                            key: PageStorageKey('carousel-$id'),
                            onPageChanged: (index) =>
                                setState(() => slide = index),
                            itemCount: media.length,
                            itemBuilder: (_, index) => photo(index),
                          ),
                        ),
                      if (media.length > 1)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              child: Text(
                                '${current + 1}/${media.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (burst > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(burst),
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 620),
                                builder: (_, value, child) => Opacity(
                                  opacity:
                                      (value < .6
                                              ? value * 5
                                              : (1 - value) / .4)
                                          .clamp(0, 1)
                                          .toDouble(),
                                  child: Transform.scale(
                                    scale: .6 + value * .65,
                                    child: child,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.heart_fill,
                                  color: Colors.white,
                                  size: 84,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        if (media.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < media.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: CircleAvatar(
                      radius: index == slide ? 3.4 : 2.7,
                      backgroundColor: index == slide
                          ? accent(context)
                          : secondaryText(context).withValues(alpha: .28),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: PostAction(
                        label: liked ? 'Rimuovi Mi piace' : 'Mi piace',
                        icon: liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: liked ? danger : null,
                        count: post.flag('hideLikes') ? null : likes.length,
                        onTap: () => like(),
                      ),
                    ),
                    Flexible(
                      child: PostAction(
                        label: 'Commenti',
                        icon: CupertinoIcons.chat_bubble,
                        count: replies.length,
                        onTap: () => comments(context, id),
                      ),
                    ),
                    if (canRepost)
                      Flexible(
                        child: PostAction(
                          label: reposted
                              ? 'Annulla ripubblicazione'
                              : 'Ripubblica',
                          icon: CupertinoIcons.repeat,
                          color: reposted ? accent(context) : null,
                          count: reposts.length,
                          onTap: () => perform(
                            context,
                            () => store.act('repost', {
                              'id': id,
                              'enabled': !reposted,
                            }),
                          ),
                        ),
                      ),
                    Flexible(
                      child: PostAction(
                        label: 'Condividi',
                        icon: CupertinoIcons.paperplane,
                        count: post.number('shareCount').toInt(),
                        onTap: () => sharePost(context, post),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: saved ? 'Rimuovi dai salvati' : 'Salva',
                onPressed: () => perform(
                  context,
                  () => store.act('save', {'id': id, 'enabled': !saved}),
                ),
                icon: GIcon(
                  saved
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
        PostExtras(post: post),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!post.flag('hideLikes') && likes.isNotEmpty)
                InkWell(
                  onTap: () => people(context, likes, 'Mi piace'),
                  child: Row(
                    children: [
                      for (final liker in likes.take(3))
                        Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Avatar(liker, size: 17),
                        ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'Piace a ',
                            children: [
                              TextSpan(
                                text: likes.first == store.myId
                                    ? 'te'
                                    : store.user(likes.first).str('username'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (likes.length > 1)
                                const TextSpan(text: ' e altri'),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: widget.detail
                        ? null
                        : () => setState(() => expanded = !expanded),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$username ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: caption),
                        ],
                      ),
                      maxLines: expanded || widget.detail ? null : 3,
                      overflow: expanded || widget.detail
                          ? null
                          : TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (replies.isNotEmpty ||
                  (widget.detail && !post.flag('commentsOff')))
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryText(context),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => comments(context, id),
                  child: Text(
                    replies.isEmpty
                        ? 'Aggiungi un commento'
                        : 'Visualizza i commenti (${replies.length})',
                  ),
                ),
              if (post.number('created') > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    relative(post['created']),
                    style: TextStyle(
                      color: secondaryText(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              if (moment.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const GIcon(CupertinoIcons.person_2),
                  title: Text(moment.str('title', 'Momento')),
                  subtitle: Text('${participants.length} partecipanti'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
                  onTap: () =>
                      open(context, CommunityDetail(id: moment.str('id'))),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class DirectHome extends StatefulWidget {
  const DirectHome({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<DirectHome> createState() => _DirectHomeState();
}

class _DirectHomeState extends State<DirectHome> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final padding = MediaQuery.paddingOf(context);
    final edgeInset = Directionality.of(context) == TextDirection.ltr
        ? padding.right
        : padding.left;
    final threads = store.inboxThreads
        .where(
          (thread) =>
              '${store.threadName(thread)} ${inboxPreview(store, thread)}'
                  .toLowerCase()
                  .contains(query.trim().toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
        title: _AccountTitle(store: store),
        actions: [
          if (store.preferences.flag('hideInstantBubble'))
            IconButton(
              tooltip: 'Istantanee',
              icon: const GIcon(CupertinoIcons.photo_on_rectangle),
              onPressed: () => openInstants(context),
            ),
          IconButton(
            tooltip: 'Nuovo messaggio',
            icon: const GIcon(CupertinoIcons.square_pencil, size: 25),
            onPressed: () => newConversation(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            key: PageStorageKey('rebuilt-inbox-${store.myId}'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _SearchBox(
                  hint: 'Cerca nei messaggi',
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              if (query.isEmpty) const SliverToBoxAdapter(child: NotesTray()),
              SliverToBoxAdapter(
                child: ListTile(
                  title: const Text(
                    'Messaggi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: TextButton(
                    onPressed: () => open(context, const MessageRequests()),
                    child: Text(
                      store.requestedThreads.isEmpty
                          ? 'Richieste'
                          : 'Richieste (${store.requestedThreads.length})',
                    ),
                  ),
                ),
              ),
              if (threads.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    CupertinoIcons.paperplane,
                    query.isEmpty ? 'Nessun messaggio' : 'Nessun risultato',
                    query.isEmpty
                        ? 'Tocca l’icona di composizione per iniziare.'
                        : 'Prova un altro nome.',
                  ),
                ),
              SliverList.builder(
                itemCount: threads.length,
                itemBuilder: (context, index) {
                  final thread = threads[index];
                  final unread = store.chatHasUnread(thread);
                  final settings = thread.obj('chatSettings');
                  final contact = store.other(thread);
                  return SectionSwipe(
                    key: ValueKey(thread.str('id')),
                    animateDrag: true,
                    onStep: (step) {
                      if (step > 0) inboxThreadOptions(context, store, thread);
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 7,
                      ),
                      minLeadingWidth: 56,
                      leading: thread.str('owner').isNotEmpty
                          ? groupAvatar()
                          : InkWell(
                              borderRadius: BorderRadius.circular(40),
                              onTap: () => open(
                                context,
                                store.stories(contact).isNotEmpty
                                    ? StoryViewer(user: contact)
                                    : ProfileHome(user: contact, detail: true),
                              ),
                              child: ChatPresenceAvatar(
                                contact,
                                size: 53,
                                ring: store.hasUnseenStories(contact),
                              ),
                            ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              store.threadName(thread),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (settings.flag('pinned'))
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: GIcon(CupertinoIcons.pin_fill, size: 12),
                            ),
                          if (settings.flag('muted'))
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: GIcon(CupertinoIcons.bell_slash, size: 13),
                            ),
                        ],
                      ),
                      subtitle: store.typingPeers(thread.str('id')).isNotEmpty
                          ? ConversationActivity(thread: thread)
                          : Text(
                              inboxPreview(store, thread),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread
                                    ? foreground(context)
                                    : secondaryText(context),
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                      trailing: unread
                          ? CircleAvatar(
                              radius: 4,
                              backgroundColor: accent(context),
                            )
                          : null,
                      onTap: () => open(context, Chat(id: thread.str('id'))),
                      onLongPress: () =>
                          inboxThreadOptions(context, store, thread),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      (widget.embedded
                          ? _dockSpace(context)
                          : MediaQuery.paddingOf(context).bottom) +
                      (store.preferences.flag('hideInstantBubble') ? 14 : 138),
                ),
              ),
            ],
          ),
          if (!store.preferences.flag('hideInstantBubble') &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            PositionedDirectional(
              end: edgeInset,
              bottom: widget.embedded
                  ? _dockSpace(context) + 5
                  : MediaQuery.paddingOf(context).bottom + 12,
              child: const InstantPile(docked: true),
            ),
        ],
      ),
    );
  }
}

class DiscoverHome extends StatefulWidget {
  const DiscoverHome({
    super.key,
    this.initialQuery = '',
    this.detail = false,
    this.onBoundarySwipe,
  });

  final String initialQuery;
  final bool detail;
  final ValueChanged<int>? onBoundarySwipe;

  @override
  State<DiscoverHome> createState() => _DiscoverHomeState();
}

class _DiscoverHomeState extends State<DiscoverHome> {
  static const categories = ['Tutti', 'Persone', 'Post', 'Reel', 'Gruppi'];
  late String query = widget.initialQuery;
  late final search = TextEditingController(text: widget.initialQuery);
  int category = 0;

  void submit(String value) {
    FocusScope.of(context).unfocus();
    search.text = value;
    setState(() => query = value);
    GpixScope.of(context, listen: false).rememberSearch(value);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final term = query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    final users = store.users
        .where(
          (user) =>
              user.str('id') != store.myId &&
              !store.blocked(user.str('id')) &&
              '${user.str('username')} ${user.str('name')}'
                  .toLowerCase()
                  .contains(term),
        )
        .toList();
    final muted = store.preferences.ids('muted').toSet();
    final posts =
        (switch (category) {
              2 => store.posts,
              3 => store.reels,
              _ => [...store.posts, ...store.reels],
            })
            .where(
              (post) =>
                  !muted.contains(post.str('author')) &&
                  '${post.str('text')} ${post.str('location')} ${store.user(post.str('author')).str('username')}'
                      .toLowerCase()
                      .contains(term),
            )
            .toList()
          ..sort((a, b) => b.number('created').compareTo(a.number('created')));
    final accounts = category == 1;
    final groups = category == 4;
    final showAccounts = accounts || (category == 0 && term.isNotEmpty);
    final padding = widget.detail ? 20.0 : _dockSpace(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Esplora'), centerTitle: true),
      body: SectionSwipe(
        section: category,
        onStep: (step) {
          final next = category + step;
          if (next >= 0 && next < categories.length) {
            setState(() => category = next);
          } else {
            widget.onBoundarySwipe?.call(step);
          }
        },
        child: CustomScrollView(
          key: PageStorageKey('rebuilt-discover-${store.myId}'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _SearchBox(
                hint: 'Cerca',
                controller: search,
                onSubmitted: submit,
                onClear: query.isEmpty ? null : () => submit(''),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            SliverToBoxAdapter(
              child: CommunityTabs(
                categories,
                categories[category],
                (label) => setState(() => category = categories.indexOf(label)),
              ),
            ),
            if (groups)
              SliverFillRemaining(
                child: CommunityDirectory(query: query, bottomPadding: padding),
              )
            else ...[
              if (term.isEmpty &&
                  category == 0 &&
                  store.searchHistory.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Ricerche recenti',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: TextButton(
                          onPressed: store.clearSearchHistory,
                          child: const Text('Cancella'),
                        ),
                      ),
                      for (final item in store.searchHistory.take(5))
                        ListTile(
                          leading: const GIcon(CupertinoIcons.clock),
                          title: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => submit(item),
                          trailing: IconButton(
                            tooltip: 'Rimuovi ricerca',
                            onPressed: () => store.removeSearch(item),
                            icon: const GIcon(CupertinoIcons.xmark, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              if (showAccounts)
                SliverList.builder(
                  itemCount: accounts ? users.length : users.length.clamp(0, 4),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final id = user.str('id');
                    return ListTile(
                      leading: Avatar(id, size: 44),
                      title: Text(user.str('username')),
                      subtitle: Text(user.str('name')),
                      onTap: () {
                        store.rememberSearch(query);
                        open(context, ProfileHome(user: id, detail: true));
                      },
                    );
                  },
                ),
              if (!accounts)
                _postGrid(
                  context,
                  posts,
                  onOpen: () => store.rememberSearch(query),
                ),
              if ((accounts && users.isEmpty) ||
                  (!accounts &&
                      posts.isEmpty &&
                      (term.isEmpty || users.isEmpty)))
                const SliverToBoxAdapter(
                  child: EmptyState(
                    CupertinoIcons.search,
                    'Nessun risultato',
                    'Prova un’altra ricerca.',
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: padding)),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileHome extends StatefulWidget {
  const ProfileHome({
    super.key,
    required this.user,
    this.detail = false,
    this.onBoundarySwipe,
  });
  final String user;
  final bool detail;
  final ValueChanged<int>? onBoundarySwipe;

  @override
  State<ProfileHome> createState() => _ProfileHomeState();
}

class _ProfileHomeState extends State<ProfileHome> {
  int section = 0;
  bool showSuggestions = false;
  final dismissedSuggestions = <String>{};

  Future<void> profileOptions(GpixStore store, J person) async {
    final id = widget.user;
    final close = store.state.ids('closeFriends').contains(id);
    final blocked = store.blocked(id);
    final selected = await sheet<String>(
      context,
      Builder(
        builder: (menu) => Column(
          children: [
            ActionRow(
              CupertinoIcons.star,
              close
                  ? 'Rimuovi dagli amici più stretti'
                  : 'Aggiungi agli amici più stretti',
              () => Navigator.pop(menu, 'close'),
            ),
            ActionRow(
              CupertinoIcons.flag,
              'Segnala',
              () => Navigator.pop(menu, 'report'),
            ),
            ActionRow(
              CupertinoIcons.nosign,
              blocked ? 'Sblocca' : 'Blocca',
              () => Navigator.pop(menu, 'block'),
              destructive: !blocked,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (selected) {
      case 'close':
        await perform(
          context,
          () => store.act('closeFriend', {'user': id, 'enabled': !close}),
        );
      case 'report':
        await report(context, id);
      case 'block':
        if (!blocked &&
            !await gpixAlert(
              context,
              'Bloccare ${person.str('username')}?',
              'Non vedrai più i contenuti e le conversazioni con questo account.',
              confirm: 'Blocca',
              cancel: true,
              destructive: true,
            ))
          return;
        if (mounted)
          await perform(
            context,
            () => store.act('block', {'user': id, 'enabled': !blocked}),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final person = store.user(widget.user);
    final own = widget.user == store.myId;
    final following = store.follows(widget.user);
    final pending = store.state.ids('pending').contains(widget.user);
    final restricted =
        store.blocked(widget.user) ||
        (person.flag('private') && !own && !following);
    final personal = store.allPosts
        .where(
          (post) => post.str('author') == widget.user && !post.flag('archived'),
        )
        .toList();
    final posts = switch (section) {
      1 => personal.where((post) => post.str('kind') == 'reel').toList(),
      2 =>
        store.allPosts
            .where(
              (post) =>
                  !store.blocked(post.str('author')) &&
                  !post.flag('archived') &&
                  post.str('kind') != 'story' &&
                  post.ids('reposts').contains(widget.user),
            )
            .toList(),
      3 =>
        store.allPosts
            .where(
              (post) =>
                  !store.blocked(post.str('author')) &&
                  !post.flag('archived') &&
                  post.str('kind') != 'story' &&
                  (post.obj('style').ids('taggedUsers').contains(widget.user) ||
                      post
                          .str('text')
                          .toLowerCase()
                          .contains(
                            '@${person.str('username').toLowerCase()}',
                          )),
            )
            .toList(),
      _ => personal.where((post) => post.str('kind') == 'post').toList(),
    };
    final pinned = person.ids('pinnedPosts');
    final gridOrder = person.ids('gridOrder');
    if (section == 0 && (pinned.isNotEmpty || gridOrder.isNotEmpty)) {
      final ids = <String>{
        ...pinned,
        ...gridOrder,
        ...posts.map((post) => post.str('id')),
      };
      final rank = {for (final (i, id) in ids.indexed) id: i};
      posts.sort((a, b) => rank[a.str('id')]!.compareTo(rank[b.str('id')]!));
    }
    final highlights = store.highlights(widget.user);
    final note = store.notes
        .where((entry) => entry.str('owner') == widget.user)
        .firstOrNull;
    final page = Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: own
            ? _AccountTitle(store: store, locked: person.flag('private'))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (person.flag('private')) ...[
                    const GIcon(CupertinoIcons.lock, size: 14),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      person.str('username'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        leading: own && !widget.detail
            ? IconButton(
                tooltip: 'Crea',
                icon: const Icon(CupertinoIcons.plus),
                onPressed: () => createMenu(context),
              )
            : null,
        actions: [
          if (own) ...[
            IconButton(
              tooltip: 'Richieste di seguirti',
              icon: const GIcon(CupertinoIcons.person_2, size: 23),
              onPressed: () => open(context, const Requests()),
            ),
            IconButton(
              tooltip: 'Impostazioni e attività',
              icon: const Icon(CupertinoIcons.line_horizontal_3),
              onPressed: () => open(context, const Settings()),
            ),
          ],
          if (!own)
            IconButton(
              tooltip: 'Opzioni profilo',
              icon: const Icon(CupertinoIcons.ellipsis),
              onPressed: () => profileOptions(store, person),
            ),
        ],
      ),
      body: SectionSwipe(
        section: section,
        enabled: !restricted,
        onStep: (step) {
          final target = section + step;
          if (target >= 0 && target < 4) {
            setState(() => section = target);
          } else {
            widget.onBoundarySwipe?.call(step);
          }
        },
        child: CustomScrollView(
          key: PageStorageKey('rebuilt-profile-${widget.user}'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 94,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (own || note != null) ...[
                                const SizedBox(height: 4),
                                Tooltip(
                                  message: own
                                      ? 'La tua nota'
                                      : 'Rispondi alla nota',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(15),
                                    onTap: own
                                        ? () => manageOwnNote(context)
                                        : () => replyNote(context, note!),
                                    child: NoteBubble(
                                      text:
                                          note?.str('text') ??
                                          'Lascia una nota…',
                                      placeholder: note == null,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox.square(
                                dimension: 90,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap:
                                          store.stories(widget.user).isNotEmpty
                                          ? () => open(
                                              context,
                                              StoryViewer(user: widget.user),
                                            )
                                          : own
                                          ? () => open(
                                              context,
                                              const EditProfile(),
                                            )
                                          : null,
                                      child: Avatar(
                                        widget.user,
                                        key: const ValueKey('profile-avatar'),
                                        size: 78,
                                        ring: store.hasUnseenStories(
                                          widget.user,
                                        ),
                                      ),
                                    ),
                                    if (own)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Tooltip(
                                          message: 'Aggiungi alla storia',
                                          child: InkWell(
                                            onTap: () => open(
                                              context,
                                              const Composer(kind: 'story'),
                                            ),
                                            customBorder: const CircleBorder(),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: foreground(context),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: surface(context),
                                                  width: 2.5,
                                                ),
                                              ),
                                              child: GIcon(
                                                CupertinoIcons.plus,
                                                size: 17,
                                                color: surface(context),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 17),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 86),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person.str('name', person.str('username')),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _stat(
                                        person.str(
                                          'postCount',
                                          '${personal.where((p) => p.str('kind') != 'story').length}',
                                        ),
                                        'post',
                                      ),
                                      _stat(
                                        person.str('followers', '0'),
                                        'follower',
                                        () => open(
                                          context,
                                          Connections(user: widget.user),
                                        ),
                                      ),
                                      _stat(
                                        person.str('following', '0'),
                                        'seguiti',
                                        () => open(
                                          context,
                                          Connections(
                                            user: widget.user,
                                            initial: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (person.str('pronouns').isNotEmpty ||
                        person.str('bio').isNotEmpty)
                      const SizedBox(height: 13),
                    if (person.str('pronouns').isNotEmpty) ...[
                      Text(
                        person.str('pronouns'),
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText(context),
                        ),
                      ),
                    ],
                    if (person.str('bio').isNotEmpty) ...[
                      if (person.str('pronouns').isNotEmpty)
                        const SizedBox(height: 4),
                      Text(person.str('bio').replaceAll(r'\n', '\n')),
                    ],
                    if (person.rows('links').isNotEmpty || own) ...[
                      const SizedBox(height: 13),
                      ProfileLinkChips(links: person.rows('links'), own: own),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: _profileButton(
                              context,
                              primary: !own && !following && !pending,
                            ),
                            onPressed: own
                                ? () => open(context, const EditProfile())
                                : following
                                ? () => relationshipMenu(context, widget.user)
                                : () => perform(
                                    context,
                                    () => store.act('follow', {
                                      'user': widget.user,
                                      'enabled': !pending,
                                    }),
                                  ),
                            child: Text(
                              own
                                  ? 'Modifica profilo'
                                  : following
                                  ? store.state
                                            .ids('closeFriends')
                                            .contains(widget.user)
                                        ? 'Amici più stretti'
                                        : 'Segui già'
                                  : pending
                                  ? 'Richiesta inviata'
                                  : 'Segui',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: _profileButton(context),
                            onPressed: own
                                ? () => perform(context, () async {
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    await SharePlus.instance.share(
                                      ShareParams(
                                        text:
                                            'Seguimi su GPIX: @${person.str('username')}',
                                        sharePositionOrigin: box == null
                                            ? null
                                            : box.localToGlobal(Offset.zero) &
                                                  box.size,
                                      ),
                                    );
                                  })
                                : () => perform(context, () async {
                                    final thread = await store.openThread(
                                      widget.user,
                                    );
                                    if (context.mounted)
                                      open(context, Chat(id: thread));
                                  }),
                            child: Text(
                              own ? 'Condividi profilo' : 'Messaggio',
                            ),
                          ),
                        ),
                        if (own) ...[
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Persone suggerite',
                            isSelected: showSuggestions,
                            onPressed: () => setState(
                              () => showSuggestions = !showSuggestions,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: subdued(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const GIcon(
                              CupertinoIcons.person_add,
                              size: 21,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (own && showSuggestions) _suggestions(context, store),
                    if (!restricted && (own || highlights.isNotEmpty)) ...[
                      const SizedBox(height: 17),
                      SizedBox(
                        height:
                            86 +
                            (MediaQuery.textScalerOf(context).scale(12) - 12)
                                .clamp(0.0, 32.0),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: highlights.length + (own ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            if (own && index == 0) {
                              return SizedBox(
                                width: 68,
                                child: InkWell(
                                  onTap: () => createHighlight(context),
                                  child: const Column(
                                    children: [
                                      SizedBox(
                                        height: 56,
                                        child: GIcon(
                                          CupertinoIcons.plus_circle,
                                          size: 46,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        'Nuova',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final highlight = highlights[index - (own ? 1 : 0)];
                            final ids = highlight
                                .ids('posts')
                                .where((id) => store.post(id).isNotEmpty)
                                .toList();
                            return SizedBox(
                              width: 68,
                              child: InkWell(
                                onTap: ids.isEmpty
                                    ? null
                                    : () => open(
                                        context,
                                        StoryViewer(
                                          user: widget.user,
                                          ids: ids,
                                        ),
                                      ),
                                onLongPress: own
                                    ? () async {
                                        final remove = await gpixAlert(
                                          context,
                                          'Eliminare la raccolta?',
                                          highlight.str('title'),
                                          confirm: 'Elimina',
                                          cancel: true,
                                          destructive: true,
                                        );
                                        if (remove && context.mounted)
                                          await perform(
                                            context,
                                            () => store.act('deleteHighlight', {
                                              'id': highlight['id'],
                                            }),
                                          );
                                      }
                                    : null,
                                child: Column(
                                  children: [
                                    Avatar(
                                      widget.user,
                                      size: 56,
                                      image: highlight.str(
                                        'cover',
                                        ids.isEmpty
                                            ? ''
                                            : store
                                                  .post(ids.first)
                                                  .str('media'),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      highlight.str('title'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            if (restricted)
              SliverToBoxAdapter(
                child: EmptyState(
                  CupertinoIcons.lock,
                  store.blocked(widget.user)
                      ? 'Account bloccato'
                      : 'Account privato',
                  'I contenuti non sono visibili.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Row(
                  children: [
                    for (final (index, icon) in const [
                      CupertinoIcons.square_grid_2x2,
                      CupertinoIcons.play_rectangle,
                      CupertinoIcons.repeat,
                      CupertinoIcons.person_crop_rectangle,
                    ].indexed)
                      Expanded(
                        child: Semantics(
                          selected: section == index,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: section == index ? 2 : 1,
                                  color: section == index
                                      ? foreground(context)
                                      : Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            child: IconButton(
                              tooltip: const [
                                'Post',
                                'Reel',
                                'Ripubblicazioni',
                                'Menzioni',
                              ][index],
                              onPressed: () => setState(() => section = index),
                              icon: Icon(
                                icon,
                                color: section == index
                                    ? foreground(context)
                                    : secondaryText(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (posts.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    CupertinoIcons.photo,
                    'Nessun contenuto',
                    'I contenuti appariranno qui.',
                  ),
                ),
              _postGrid(context, posts, pinned: pinned),
            ],
            SliverToBoxAdapter(
              child: SizedBox(height: widget.detail ? 24 : _dockSpace(context)),
            ),
          ],
        ),
      ),
    );
    return widget.detail ? AccountSheetBackdrop(child: page) : page;
  }

  ButtonStyle _profileButton(BuildContext context, {bool primary = false}) =>
      FilledButton.styleFrom(
        backgroundColor: primary ? auraBlue : subdued(context),
        foregroundColor: primary ? Colors.white : foreground(context),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      );

  Widget _suggestions(BuildContext context, GpixStore store) {
    final people = store.users
        .where((person) {
          final id = person.str('id');
          return id != store.myId &&
              !store.follows(id) &&
              !store.blocked(id) &&
              !dismissedSuggestions.contains(id);
        })
        .take(12)
        .toList();
    if (people.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Persone suggerite',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => open(context, const Explore()),
                child: const Text('Mostra tutti'),
              ),
            ],
          ),
          SizedBox(
            height: 166 + (MediaQuery.textScalerOf(context).scale(16) - 16) * 3,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final person = people[index];
                final id = person.str('id');
                final pending = store.state.ids('pending').contains(id);
                return SizedBox(
                  width: 132,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 11, 8, 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: InkWell(
                                  onTap: () => open(
                                    context,
                                    ProfileHome(user: id, detail: true),
                                  ),
                                  child: Avatar(id, size: 60),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                person.str('name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '@${person.str('username')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryText(context),
                                ),
                              ),
                              const Spacer(),
                              FilledButton(
                                onPressed: () => perform(
                                  context,
                                  () => store.act('follow', {
                                    'user': id,
                                    'enabled': !pending,
                                  }),
                                ),
                                style: _profileButton(
                                  context,
                                  primary: !pending,
                                ),
                                child: Text(
                                  pending ? 'In attesa' : 'Segui',
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: IconButton(
                            tooltip: 'Nascondi suggerimento',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => dismissedSuggestions.add(id)),
                            icon: const GIcon(CupertinoIcons.xmark, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String count, String label, [VoidCallback? onTap]) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

Widget _postGrid(
  BuildContext context,
  List<J> posts, {
  List<String> pinned = const [],
  VoidCallback? onOpen,
}) => SliverGrid.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 2,
    mainAxisSpacing: 2,
    childAspectRatio: .75,
  ),
  itemCount: posts.length,
  itemBuilder: (context, index) {
    final post = posts[index];
    final reel = post.str('kind') == 'reel';
    final store = GpixScope.of(context, listen: false);
    final cover = reel
        ? post.obj('style').str('cover')
        : (store.media(post).firstOrNull ?? '');
    return InkWell(
      onTap: () {
        onOpen?.call();
        open(context, PostPage(id: post.str('id')));
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cover.isNotEmpty)
            LayoutBuilder(
              builder: (context, box) =>
                  MediaView(cover, width: box.maxWidth, thumbnail: true),
            )
          else
            ColoredBox(
              color: subdued(context),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    post.str('text'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (reel ||
              pinned.contains(post.str('id')) ||
              store.media(post).length > 1)
            Positioned(
              top: 7,
              right: 7,
              child: Icon(
                pinned.contains(post.str('id'))
                    ? CupertinoIcons.pin_fill
                    : reel
                    ? CupertinoIcons.play_rectangle_fill
                    : CupertinoIcons.square_stack_fill,
                color: Colors.white,
                size: 18,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
              ),
            ),
        ],
      ),
    );
  },
);

class _AccountTitle extends StatelessWidget {
  const _AccountTitle({required this.store, this.locked = false});
  final GpixStore store;
  final bool locked;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Cambia account',
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => inboxAccounts(context, store),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              const GIcon(CupertinoIcons.lock, size: 14),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                store.me.str('username'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_down, size: 13),
          ],
        ),
      ),
    ),
  );
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.onSubmitted,
    this.onClear,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(15, 8, 15, 10),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(CupertinoIcons.search, size: 19),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: 'Svuota ricerca',
                onPressed: onClear,
                icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 19),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
