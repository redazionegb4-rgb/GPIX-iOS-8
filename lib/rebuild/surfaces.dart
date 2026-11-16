import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../screens/community.dart';
import '../screens/notes.dart';
import '../screens/instants.dart';
import '../screens/inbox_widgets.dart';
import '../screens/profile_links.dart' show ProfileLinkChips;
import '../screens/messages.dart';
import '../screens/moments.dart';
import '../screens/people.dart';
import '../screens/post_extras.dart';
import '../screens/social.dart';
import '../screens/stories.dart';
import '../screens/video.dart' show ClipPlayer;
import '../ui/kit.dart';

double _dockSpace(BuildContext context) =>
    MediaQuery.viewPaddingOf(context).bottom + 76;

class HomeTimeline extends StatefulWidget {
  const HomeTimeline({
    super.key,
    required this.controller,
    required this.onCreate,
    required this.onActivity,
    this.active = true,
    this.refreshKey,
    this.onBoundarySwipe,
  });
  final ScrollController controller;
  final GlobalKey<RefreshIndicatorState>? refreshKey;
  final bool active;
  final VoidCallback onCreate, onActivity;
  final ValueChanged<int>? onBoundarySwipe;

  @override
  State<HomeTimeline> createState() => _HomeTimelineState();
}

class _HomeTimelineState extends State<HomeTimeline> {
  Timer? activityTimer;
  Set<String> unreadIds = {};
  bool showActivityBubble = false;

  @override
  void dispose() {
    activityTimer?.cancel();
    super.dispose();
  }

  void updateActivityBubble(GpixStore store) {
    final ids = store.socialNotifications
        .where((item) => !item.flag('seen'))
        .map((item) => item.str('id'))
        .toSet();
    if (ids.difference(unreadIds).isNotEmpty) {
      showActivityBubble = true;
      activityTimer?.cancel();
      activityTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => showActivityBubble = false);
      });
    }
    unreadIds = ids;
    if (ids.isEmpty) showActivityBubble = false;
  }

  void openActivity() {
    setState(() => showActivityBubble = false);
    widget.onActivity();
  }

  static const feeds = {
    'all': 'Per te',
    'following': 'Seguiti',
    'favorites': 'Preferiti',
    'groups': 'Gruppi',
  };
  String feed = 'all';

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
    final posts =
        [
          ...store.posts,
          ...store.reels.where((post) => post.obj('style').flag('showInFeed')),
        ].where((post) {
          final author = post.str('author');
          return !post.flag('collaborationPending') &&
              !mutedUsers.contains(author) &&
              switch (feed) {
                'following' => author == store.myId || store.follows(author),
                'favorites' => store.feedFavorites.contains(author),
                _ => true,
              };
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
      if (feed == 'all') ...[
        for (final group in groups) ('group', group),
        for (final moment in moments) ('moment', moment),
      ],
    ]..sort((a, b) => b.$2.number('created').compareTo(a.$2.number('created')));
    updateActivityBubble(store);
    return SectionSwipe(
      section: feeds.keys.toList().indexOf(feed),
      onStep: swipeFeed,
      child: RefreshIndicator(
        key: widget.refreshKey,
        onRefresh: () => perform(context, store.refreshHome),
        child: CustomScrollView(
          key: PageStorageKey('rebuilt-feed-${store.myId}'),
          controller: widget.controller,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 52,
              leadingWidth: 72,
              backgroundColor: surface(context),
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,

              leading: IconButton(
                tooltip: 'Crea',
                onPressed: widget.onCreate,
                icon: const GIcon(CupertinoIcons.plus, size: 27),
              ),
              centerTitle: true,
              title: _FeedSelector(feed: feed, onSelected: selectFeed),
              actions: [
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: _HomeActivityBadge.width,
                    height: 52,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: 'Attività',
                  onPressed: openActivity,
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
              if (feed == 'all')
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const StoryTray(),
                      if (showActivityBubble && unreadIds.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: _HomeActivityBadge(
                            key: const ValueKey('activity-bubble'),
                            count: unreadIds.length,
                            onTap: openActivity,
                          ),
                        ),
                    ],
                  ),
                ),
              if (entries.isEmpty)
                SliverToBoxAdapter(
                  child: feed == 'favorites'
                      ? const EmptyState(
                          CupertinoIcons.star,
                          'Nessun post dei preferiti',
                          'Aggiungi un profilo dai tre puntini di un suo post.',
                        )
                      : const EmptyState(
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
                      ? TimelinePost(
                          key: key,
                          post: item,
                          playReels: widget.active,
                        )
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

class _HomeActivityBadge extends StatelessWidget {
  const _HomeActivityBadge({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  static const color = Color(0xffff0035);
  static const double width = 72;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count attività non lette',
    button: true,
    child: SizedBox(
      width: width,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: color,
              borderRadius: BorderRadius.circular(24),
              elevation: 4,
              shadowColor: const Color(0x50000000),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 60, minHeight: 38),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GIcon(
                          CupertinoIcons.heart_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 3,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: .7853981633974483,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
    'favorites': CupertinoIcons.star,
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
          if (entry.key != widget.feed)
            dropdownRow(
              context,
              entry.key,
              entry.value,
              icons[entry.key]!,
              roomy: true,
            ),
      ],
      width: 144,
      label: 'Sezioni del feed',
      translucent: true,
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
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: duration,
                      child: Text(
                        _HomeTimelineState.feeds[widget.feed]!,
                        key: ValueKey(widget.feed),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.75,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  AnimatedRotation(
                    duration: duration,
                    turns: expanded ? .5 : 0,
                    child: GIcon(
                      CupertinoIcons.chevron_down,
                      size: 11,
                      color: foreground(context),
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
  const TimelinePost({
    super.key,
    required this.post,
    this.detail = false,
    this.playReels = false,
    this.taggedUser,
  });

  final J post;
  final bool detail, playReels;
  final String? taggedUser;

  @override
  State<TimelinePost> createState() => _TimelinePostState();
}

class _TimelinePostState extends State<TimelinePost> {
  late int slide;
  late final PageController carousel;
  bool initialized = false;
  int burst = 0;
  bool expanded = false, showPhotoTags = false;

  Object get slideKey => ('post-slide', widget.post.str('id'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final store = GpixScope.of(context);
    final count = store.media(widget.post).length;
    final taggedSlide = widget.taggedUser == null
        ? null
        : store.postTagSlide(widget.post, widget.taggedUser!);
    showPhotoTags = taggedSlide != null;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: slideKey);
    slide = saved is int && saved >= 0 && saved < count
        ? saved
        : taggedSlide ?? 0;
    carousel = PageController(initialPage: slide, keepPage: false);
  }

  @override
  void dispose() {
    carousel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final post = widget.post;
    final id = post.str('id');
    final author = post.str('author');
    final user = store.user(author);
    final username = user.str('username');
    final collaborators = post
        .ids('collaborators')
        .where((id) => id != author && !store.blocked(id))
        .toList();
    final coauthors = [author, ...collaborators];
    final byline = coauthors
        .map((id) => store.user(id).str('username'))
        .join(' e ');
    final pendingCollaborators = post.ids('pendingCollaborators');
    final likes = post.ids('likes');
    final liked = likes.contains(store.myId);
    final reposts = post.ids('reposts');
    final reposted = reposts.contains(store.myId);
    final saved = post.flag('saved');
    final reel = post.str('kind') == 'reel';
    final media = reel ? <String>[] : store.media(post);
    final replies = post.rows('comments');
    final caption = post.str('text');
    final style = post.obj('style');
    final tags = style
        .rows('photoTags')
        .where(
          (tag) =>
              tag.str('user').isNotEmpty && !store.blocked(tag.str('user')),
        )
        .toList();
    Iterable<J> tagsOn(int page) =>
        tags.where((tag) => tag.number('slide', -1) == page);
    final track = style.obj('music');
    final trackLabel = [
      track.str('artist'),
      track.str('title'),
    ].where((part) => part.isNotEmpty).join(' · ');
    final audio = style.str('audio');
    final hasAudio = !reel && audio.isNotEmpty;
    final favorite = store.feedFavorites.contains(author);
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
        if (widget.detail && post.flag('collaborationPending'))
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$username ti ha invitato a collaborare.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => perform(
                        context,
                        () => store.act('postCollaboration', {
                          'id': id,
                          'decision': 'accept',
                        }),
                      ),
                      child: const Text('Accetta'),
                    ),
                    TextButton(
                      onPressed: () => perform(
                        context,
                        () => store.act('postCollaboration', {
                          'id': id,
                          'decision': 'decline',
                        }),
                      ),
                      child: const Text('Rifiuta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (widget.detail && pendingCollaborators.isNotEmpty)
          ListTile(
            dense: true,
            leading: const GIcon(CupertinoIcons.person_2, size: 20),
            title: const Text('Inviti in attesa'),
            subtitle: Text(
              pendingCollaborators
                  .map((id) => store.user(id).str('username'))
                  .join(', '),
            ),
          ),
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
          padding: const EdgeInsets.fromLTRB(7, 1, 6, 1),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => collaborators.isEmpty
                      ? open(context, ProfileHome(user: author, detail: true))
                      : people(context, coauthors, 'Collaboratori'),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
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
                                byline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (hasAudio)
                                PostAudio(
                                  reference: audio,
                                  title: trackLabel.isEmpty
                                      ? style.str(
                                          'audioName',
                                          'Audio originale',
                                        )
                                      : trackLabel,
                                  start: track.number('start'),
                                  duration: track.number('clipDuration'),
                                  compact: true,
                                )
                              else if (detail.isNotEmpty)
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
              if (favorite)
                IconButton(
                  tooltip: 'Gestisci preferito',
                  color: const Color(0xff11a553),
                  onPressed: () => postMenu(context, post),
                  icon: const GIcon(CupertinoIcons.star_fill, size: 19),
                ),
              IconButton(
                tooltip: 'Opzioni del post',
                onPressed: () => postMenu(context, post, detail: widget.detail),
                icon: const _PostOptionsIcon(),
              ),
            ],
          ),
        ),
        if (reel)
          AspectRatio(
            aspectRatio: 4 / 5,
            child: _InlinePostVideo(
              reference: post.str('media'),
              cover: store.reelCover(post),
              enabled: widget.playReels,
              onTap: () => open(context, PostPage(id: id)),
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
              bool video(int index) =>
                  store.isVideoMedia(media[index]) ||
                  (media.length == 1 && store.isVideoPost(post));
              Widget photoFrame(int page, Widget child) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: video(page)
                    ? null
                    : () {
                        final photos = media.indexed
                            .where((entry) => !video(entry.$1))
                            .map((entry) => entry.$1)
                            .toList();
                        openPhotoGallery(
                          context,
                          photos.map((index) => media[index]).toList(),
                          initial: photos.indexOf(page),
                        );
                      },
                onDoubleTap: () => like(force: true),
                child: child,
              );

              Widget attachment(int index) {
                if (video(index)) {
                  return photoFrame(
                    index,
                    _InlinePostVideo(
                      reference: media[index],
                      cover: media.length == 1 ? store.reelCover(post) : '',
                      enabled:
                          index == current &&
                          (widget.detail || widget.playReels),
                    ),
                  );
                }
                final image = photoFrame(
                  index,
                  MediaView(
                    media[index],
                    width: width,
                    fit: BoxFit.contain,
                    placeholderHeight: width / aspect,
                  ),
                );
                if (!showPhotoTags || index != current) return image;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    for (final tag in tagsOn(index))
                      Align(
                        alignment: postTagAlignment(tag),
                        child: GestureDetector(
                          onTap: () =>
                              open(context, Profile(user: tag.str('user'))),
                          child: PostTagLabel(
                            store.user(tag.str('user')).str('username'),
                          ),
                        ),
                      ),
                  ],
                );
              }

              return ColoredBox(
                color: subdued(context),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (media.length == 1 && (video(0) || tagsOn(0).isNotEmpty))
                      AspectRatio(aspectRatio: aspect, child: attachment(0))
                    else if (media.length == 1)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: width / 2.5,
                          maxHeight: width * 2.5,
                        ),
                        child: attachment(0),
                      )
                    else
                      AspectRatio(
                        aspectRatio: aspect,
                        child: PageView.builder(
                          controller: carousel,
                          onPageChanged: (index) {
                            PageStorage.maybeOf(
                              context,
                            )?.writeState(context, index, identifier: slideKey);
                            setState(() => slide = index);
                          },
                          itemCount: media.length,
                          itemBuilder: (_, index) => attachment(index),
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
                    if (!video(current) && tagsOn(current).isNotEmpty)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: IconButton.filled(
                          tooltip: showPhotoTags
                              ? 'Nascondi tag sulla foto'
                              : 'Mostra tag sulla foto',
                          onPressed: () =>
                              setState(() => showPhotoTags = !showPhotoTags),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                          ),
                          icon: const GIcon(
                            CupertinoIcons.person_crop_circle,
                            size: 19,
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
                                    (value < .6 ? value * 5 : (1 - value) / .4)
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
                                  Shadow(color: Colors.black54, blurRadius: 14),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        if (media.length > 1)
          _CarouselDots(
            length: media.length,
            current: slide.clamp(0, media.length - 1),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 2, 3, 1),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  spacing: 14,
                  children: [
                    Flexible(
                      child: PostAction(
                        feed: true,
                        label: liked ? 'Rimuovi Mi piace' : 'Mi piace',
                        icon: liked
                            ? CupertinoIcons.heart_fill
                            : CupertinoIcons.heart,
                        color: liked ? const Color(0xffff0038) : null,
                        count: post.flag('hideLikes') ? null : likes.length,
                        onTap: () => like(),
                      ),
                    ),
                    Flexible(
                      child: PostAction(
                        feed: true,
                        label: 'Commenti',
                        icon: CupertinoIcons.chat_bubble,
                        count: replies.length,
                        onTap: () => comments(context, id),
                      ),
                    ),
                    if (canRepost)
                      Flexible(
                        child: PostAction(
                          feed: true,
                          label: reposted
                              ? 'Annulla ripubblicazione'
                              : 'Ripubblica',
                          icon: CupertinoIcons.repeat,
                          color: foreground(context),
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
                        feed: true,
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
                onPressed: () => toggleSavedPost(context, id),
                icon: GIcon(
                  saved
                      ? CupertinoIcons.bookmark_fill
                      : CupertinoIcons.bookmark,
                  size: 25,
                  postAction: true,
                ),
              ),
            ],
          ),
        ),
        PostExtras(post: post, showAudio: false, showTaggedUsers: tags.isEmpty),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!post.flag('hideLikes') && likes.isNotEmpty)
                InkWell(
                  onTap: () => people(context, likes, 'Mi piace'),
                  child: Row(
                    children: [
                      SizedBox(
                        width: likes.length > 1 ? 36 : 22,
                        height: 22,
                        child: Stack(
                          children: [
                            for (final (index, liker)
                                in likes.take(2).indexed.toList().reversed)
                              Positioned(
                                left: index * 14,
                                child: Avatar(liker, size: 21),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
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
                                const TextSpan(
                                  text: ' e altri',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
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
                          TextSpan(
                            text:
                                !widget.detail &&
                                    !expanded &&
                                    caption.characters.length > 65
                                ? '${caption.characters.take(65)}… '
                                : caption,
                          ),
                          if (!widget.detail &&
                              !expanded &&
                              caption.characters.length > 65)
                            TextSpan(
                              text: 'altro',
                              style: TextStyle(color: secondaryText(context)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.detail && !post.flag('commentsOff'))
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

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.length, required this.current});

  final int length, current;

  @override
  Widget build(BuildContext context) {
    final visible = length.clamp(0, 7);
    final first = (current - 3).clamp(0, length - visible);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = first; index < first + visible; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: CircleAvatar(
                radius: index == current
                    ? 3
                    : (index - current).abs() > 2
                    ? 1.7
                    : 2.5,
                backgroundColor: index == current
                    ? const Color(0xff4656f6)
                    : secondaryText(context).withValues(alpha: .28),
              ),
            ),
        ],
      ),
    );
  }
}

class _InlinePostVideo extends StatefulWidget {
  const _InlinePostVideo({
    required this.reference,
    required this.cover,
    required this.enabled,
    this.onTap,
  });

  final String reference;
  final VoidCallback? onTap;
  final String cover;
  final bool enabled;

  @override
  State<_InlinePostVideo> createState() => _InlinePostVideoState();
}

class _InlinePostVideoState extends State<_InlinePostVideo> {
  ScrollPosition? scroll;
  bool centered = false, muted = true;
  bool measurementScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != scroll) {
      scroll?.removeListener(scheduleMeasurement);
      scroll = position;
      scroll?.addListener(scheduleMeasurement);
    }
    scheduleMeasurement();
  }

  void scheduleMeasurement() {
    if (measurementScheduled) return;
    measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measurementScheduled = false;
      if (!mounted || scroll?.hasContentDimensions != true) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final offset = viewport
          .getOffsetToReveal(box, .5, axis: Axis.vertical)
          .offset;
      final next = (scroll!.pixels - offset).abs() <= box.size.height * .41;
      if (next != centered) {
        setState(() {
          centered = next;
          if (!next) muted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    scroll?.removeListener(scheduleMeasurement);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active =
        centered &&
        widget.enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final thumbnail = widget.cover.isEmpty
        ? null
        : MediaView(widget.cover, fit: BoxFit.cover);
    return InkWell(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: subdued(context)),
          if (active)
            ClipPlayer(
              reference: widget.reference,
              fit: BoxFit.cover,
              muted: muted,
              placeholder: thumbnail,
              showSubtitles: false,
            )
          else ...[
            if (thumbnail != null) thumbnail,
            const Center(
              child: Icon(
                CupertinoIcons.play_circle_fill,
                size: 48,
                color: Colors.white,
              ),
            ),
          ],
          if (active)
            Positioned(
              bottom: 9,
              right: 9,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.square(34),
                  padding: const EdgeInsets.all(8),
                ),
                tooltip: muted ? 'Attiva audio' : 'Disattiva audio',
                onPressed: () => setState(() => muted = !muted),
                icon: Icon(
                  muted
                      ? CupertinoIcons.speaker_slash_fill
                      : CupertinoIcons.speaker_2_fill,
                  size: 17,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostOptionsIcon extends StatelessWidget {
  const _PostOptionsIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final width in [20.0, 14.0]) ...[
          if (width < 20) const SizedBox(height: 5),
          Container(
            width: width,
            height: 2,
            decoration: BoxDecoration(
              color: foreground(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    ),
  );
}

class DirectHome extends StatefulWidget {
  const DirectHome({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<DirectHome> createState() => _DirectHomeState();
}

class _DirectHomeState extends State<DirectHome> {
  final search = TextEditingController();
  final searchFocus = FocusNode();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final page = context;
    final padding = MediaQuery.paddingOf(context);
    final edgeInset = Directionality.of(context) == TextDirection.ltr
        ? padding.right
        : padding.left;
    final term = directSearchTerm(query);
    final searching = term.isNotEmpty;
    final hideInstant = store.preferences.flag('hideInstantBubble');
    final requests = store.requestedThreads.length;
    final all = store.inboxThreads;
    final threads = !searching
        ? all
        : all.where((thread) {
            final user = store.user(store.other(thread));
            return directSearchTerm(
              '${store.threadName(thread)} ${user.str('name')} ${user.str('username')}',
            ).contains(term);
          }).toList();
    final hits = <({J thread, J message})>[];
    if (searching && store.preferences['messagePreviews'] != false) {
      for (final thread in all) {
        for (final message in thread.rows('messages')) {
          if (matchesDirectMessage(store, message, term)) {
            hits.add((thread: thread, message: message));
          }
        }
      }
      hits.sort(
        (a, b) =>
            b.message.number('created').compareTo(a.message.number('created')),
      );
      if (hits.length > 40) hits.removeRange(40, hits.length);
    }
    final bottomSpace = widget.embedded ? _dockSpace(context) : padding.bottom;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: !widget.embedded,
        toolbarHeight: 55,
        title: _AccountTitle(store: store, direct: true),
        actions: [
          if (hideInstant)
            IconButton(
              tooltip: 'Istantanee',
              icon: const GIcon(CupertinoIcons.photo_on_rectangle, size: 20),
              onPressed: () => openInstants(context),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Nuovo messaggio',
              icon: const GIcon(CupertinoIcons.square_pencil, size: 25),
              onPressed: () {
                searchFocus.unfocus();
                newConversation(context);
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: store.refreshHome,
            child: CustomScrollView(
              key: PageStorageKey('rebuilt-inbox-${store.myId}'),
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 5),
                    child: DirectSearchField(
                      key: const ValueKey('inbox-search'),
                      hint: 'Cerca nei messaggi',
                      controller: search,
                      focusNode: searchFocus,
                      onChanged: (value) => setState(() => query = value),
                    ),
                  ),
                ),
                if (!searching) const SliverToBoxAdapter(child: NotesTray()),
                if (!searching || threads.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _sectionTitle(
                      context,
                      searching ? 'Conversazioni' : 'Messaggi',
                      trailing: searching
                          ? null
                          : TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: secondaryText(context),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              onPressed: () {
                                searchFocus.unfocus();
                                open(context, const MessageRequests());
                              },
                              child: Text(
                                requests == 0
                                    ? 'Richieste'
                                    : 'Richieste ($requests)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),
                  ),
                if (threads.isEmpty && hits.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      searching
                          ? CupertinoIcons.search
                          : CupertinoIcons.paperplane,
                      searching ? 'Nessun risultato' : 'Nessun messaggio',
                      searching
                          ? ''
                          : 'Tocca la matita per iniziare una conversazione.',
                    ),
                  ),
                SliverList.builder(
                  itemCount: threads.length,
                  itemBuilder: (context, index) {
                    final t = threads[index];
                    final id = t.str('id');
                    final contact = store.other(t);
                    final group = t.str('owner').isNotEmpty;
                    final latest = t.rows('messages').lastOrNull;
                    final settings = t.obj('chatSettings');
                    final summary = inboxSummary(store, t);
                    void menu() {
                      searchFocus.unfocus();
                      inboxThreadOptions(page, store, t);
                    }

                    return SectionSwipe(
                      key: ValueKey(id),
                      animateDrag: true,
                      onStep: (step) {
                        if (step > 0) menu();
                      },
                      child: DirectThreadRow(
                        key: ValueKey('inbox-thread-$id'),
                        name: store.threadName(t),
                        portrait: group
                            ? groupAvatar()
                            : ChatPresenceAvatar(
                                contact,
                                size: 61,
                                ring: store.stories(contact).isNotEmpty,
                              ),
                        onPortrait: group
                            ? null
                            : () => open(
                                context,
                                store.stories(contact).isNotEmpty
                                    ? StoryViewer(user: contact)
                                    : ProfileHome(user: contact, detail: true),
                              ),
                        preview: store.typingPeers(id).isNotEmpty
                            ? ConversationActivity(thread: t)
                            : Text(summary.caption),
                        time: summary.time,
                        unread: store.chatHasUnread(t),
                        pinned: settings.flag('pinned'),
                        silenced: settings.flag('muted'),
                        temporary:
                            latest != null &&
                            (latest.flag('viewOnce') ||
                                latest.flag('afterRead')),
                        onTap: () {
                          searchFocus.unfocus();
                          open(context, Chat(id: id));
                        },
                        onLongPress: menu,
                      ),
                    );
                  },
                ),
                if (hits.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _sectionTitle(context, 'Risultati nei messaggi'),
                  ),
                  SliverList.builder(
                    itemCount: hits.length,
                    itemBuilder: (context, index) {
                      final hit = hits[index];
                      final m = hit.message;
                      return DirectThreadRow(
                        key: ValueKey('inbox-result-${m.str('id')}'),
                        name: store.threadName(hit.thread),
                        portrait: Avatar(m.str('author'), size: 46),
                        preview: Text(m.str('text')),
                        time: directTimeAgo(m.number('created'), compact: true),
                        onTap: () {
                          searchFocus.unfocus();
                          open(
                            context,
                            Chat(
                              id: hit.thread.str('id'),
                              initialMessage: m.str('id'),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        bottomSpace + (!hideInstant && !searching ? 122 : 12),
                  ),
                ),
              ],
            ),
          ),
          if (!hideInstant &&
              !searching &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            PositionedDirectional(
              end: edgeInset,
              bottom: widget.embedded ? bottomSpace + 5 : padding.bottom + 12,
              child: const InstantPile(docked: true),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 43),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
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
  static const categories = [
    'Per te',
    'Profili',
    'Non personalizzati',
    'Audio',
    'Tag',
    'Gruppi',
  ];
  late final search = TextEditingController(text: widget.initialQuery);
  late String query = widget.initialQuery;
  late bool results = widget.initialQuery.trim().isNotEmpty;
  final focus = FocusNode();
  bool searching = false, personalized = true;
  int category = 0;

  void submit(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    search.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    focus.unfocus();
    setState(() {
      query = term;
      searching = false;
      results = true;
      category = 0;
    });
    GpixScope.of(context, listen: false).rememberSearch(term);
  }

  void closeSearch() {
    focus.unfocus();
    search.clear();
    setState(() {
      query = '';
      searching = false;
      results = false;
      category = 0;
    });
  }

  void openProfile(J user) {
    final username = user.str('username');
    GpixScope.of(context, listen: false).rememberSearch('@$username');
    focus.unfocus();
    open(context, ProfileHome(user: user.str('id'), detail: true));
  }

  @override
  void dispose() {
    focus.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final term = query.trim().toLowerCase().replaceFirst(RegExp(r'^[@#]'), '');
    final users =
        store.users
            .where(
              (user) =>
                  user.str('id') != store.myId &&
                  !store.blocked(user.str('id')) &&
                  '${user.str('username')} ${user.str('name')}'
                      .toLowerCase()
                      .contains(term),
            )
            .toList()
          ..sort((a, b) {
            int rank(J user) {
              final label = user.str('username').toLowerCase();
              return label == term
                  ? 0
                  : label.startsWith(term)
                  ? 1
                  : 2;
            }

            return rank(a).compareTo(rank(b));
          });
    final muted = store.preferences.ids('muted').toSet();
    final favorites = store.feedFavorites.toSet();
    final content =
        [
            ...store.posts,
            ...store.reels,
          ].where((item) => !muted.contains(item.str('author'))).toList()
          ..sort((a, b) => b.number('created').compareTo(a.number('created')));
    final filtered = content
        .where(
          (item) =>
              '${item.str('text')} ${item.str('location')} ${store.user(item.str('author')).str('username')}'
                  .toLowerCase()
                  .contains(term),
        )
        .toList();
    int priority(J item) {
      final author = item.str('author');
      return favorites.contains(author)
          ? 2
          : store.follows(author)
          ? 1
          : 0;
    }

    final items = results || searching ? filtered : content;
    if (!searching && (results ? category == 0 : personalized)) {
      items.sort((a, b) {
        final rank = priority(b).compareTo(priority(a));
        return rank != 0
            ? rank
            : b.number('created').compareTo(a.number('created'));
      });
    }
    final tags = <String, int>{};
    final audio = <String, (J, int)>{};
    if (results && (category == 3 || category == 4)) {
      for (final post in content) {
        if (category == 4) {
          for (final tag
              in RegExp(r'#[\p{L}\p{N}_]+', unicode: true)
                  .allMatches(post.str('text'))
                  .map((match) => match[0]!.toLowerCase())
                  .toSet()) {
            if (tag.contains(term))
              tags.update(tag, (count) => count + 1, ifAbsent: () => 1);
          }
        } else {
          final track = post.obj('style').obj('music');
          final label = '${track.str('title')} ${track.str('artist')}';
          if (track.isNotEmpty && label.toLowerCase().contains(term)) {
            final key = track.str('id', label);
            audio.update(
              key,
              (entry) => (entry.$1, entry.$2 + 1),
              ifAbsent: () => (post, 1),
            );
          }
        }
      }
    }
    final padding = widget.detail ? 20.0 : _dockSpace(context);
    final groups = results && category == 5 && !searching;
    final profileResults = results && (category == 0 || category == 1);
    final showPosts =
        !searching && (!results || category == 0 || category == 2);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: surface(context),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: Row(
          children: [
            if (results || widget.detail)
              IconButton(
                tooltip: 'Indietro',
                onPressed: results
                    ? closeSearch
                    : () => Navigator.maybePop(context),
                icon: const GIcon(CupertinoIcons.chevron_back, size: 22),
              )
            else
              const SizedBox(width: 15),
            Expanded(
              child: TextField(
                key: const ValueKey('explore-search'),
                controller: search,
                focusNode: focus,
                textInputAction: TextInputAction.search,
                onTap: () => setState(() => searching = true),
                onChanged: (value) => setState(() {
                  searching = true;
                  query = value;
                }),
                onSubmitted: submit,
                decoration: InputDecoration(
                  hintText: 'Cerca',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 18),
                  suffixIcon: searching && search.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Svuota ricerca',
                          icon: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 16,
                          ),
                          onPressed: () {
                            search.clear();
                            setState(() => query = '');
                            focus.requestFocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: subdued(context),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (searching)
              TextButton(onPressed: closeSearch, child: const Text('Annulla'))
            else if (!results) ...[
              IconButton(
                tooltip: 'Salvati',
                icon: const GIcon(CupertinoIcons.bookmark, size: 24),
                onPressed: () =>
                    open(context, const CollectionPage(kind: 'saved')),
              ),
              Builder(
                builder: (anchor) => IconButton(
                  tooltip: 'Opzioni di Esplora',
                  icon: const GIcon(CupertinoIcons.ellipsis, size: 23),
                  onPressed: () async {
                    final choice = await anchoredMenu<String>(
                      anchor,
                      [
                        dropdownRow(
                          anchor,
                          'personalized',
                          'Per te',
                          CupertinoIcons.person_crop_circle,
                          selected: personalized,
                        ),
                        dropdownRow(
                          anchor,
                          'standard',
                          'Non personalizzati',
                          CupertinoIcons.globe,
                          selected: !personalized,
                        ),
                        dropdownRow(
                          anchor,
                          'places',
                          'Cerca un luogo',
                          CupertinoIcons.placemark,
                        ),
                      ],
                      width: 210,
                      alignRight: true,
                      label: 'Opzioni di Esplora',
                      translucent: true,
                    );
                    if (!mounted || choice == null) return;
                    if (choice == 'places') {
                      final place = await chooseGpixPlace(
                        context,
                        allowRemove: false,
                      );
                      if (mounted && place != null && place.isNotEmpty)
                        submit(place);
                    } else {
                      setState(() => personalized = choice == 'personalized');
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
            ] else
              const SizedBox(width: 12),
          ],
        ),
        bottom: results && !searching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Row(
                    children: [
                      for (final (index, label) in categories.indexed)
                        Semantics(
                          selected: index == category,
                          child: InkWell(
                            onTap: () => setState(() => category = index),
                            child: Container(
                              height: 46,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: index == category
                                        ? foreground(context)
                                        : Theme.of(context).dividerColor,
                                    width: index == category ? 2 : 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: index == category
                                      ? foreground(context)
                                      : secondaryText(context),
                                  fontWeight: index == category
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: groups
          ? CommunityDirectory(query: query, bottomPadding: padding)
          : SectionSwipe(
              section: category,
              onStep: (step) {
                final next = category + step;
                if (results &&
                    !searching &&
                    next >= 0 &&
                    next < categories.length) {
                  setState(() => category = next);
                } else if (!searching) {
                  widget.onBoundarySwipe?.call(step);
                }
              },
              child: CustomScrollView(
                key: PageStorageKey((
                  'explore',
                  store.myId,
                  searching,
                  results,
                  category,
                )),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (searching && term.isEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            title: const Text(
                              'Recenti',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            trailing: store.searchHistory.isEmpty
                                ? null
                                : TextButton(
                                    onPressed: store.clearSearchHistory,
                                    child: const Text('Cancella tutto'),
                                  ),
                          ),
                          for (final item in store.searchHistory)
                            ListTile(
                              leading: const GIcon(
                                CupertinoIcons.clock,
                                size: 21,
                              ),
                              title: Text(
                                item,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => submit(item),
                              trailing: IconButton(
                                tooltip: 'Rimuovi ricerca',
                                onPressed: () => store.removeSearch(item),
                                icon: const GIcon(
                                  CupertinoIcons.xmark,
                                  size: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (searching && term.isNotEmpty)
                    SliverToBoxAdapter(
                      child: ListTile(
                        leading: const GIcon(CupertinoIcons.search, size: 21),
                        title: Text(
                          query,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => submit(query),
                      ),
                    ),
                  if (profileResults &&
                      category == 0 &&
                      !searching &&
                      users.isNotEmpty)
                    const SliverToBoxAdapter(child: _ExploreLabel('Account')),
                  if ((searching && term.isNotEmpty) ||
                      (!searching && profileResults))
                    SliverList.builder(
                      itemCount: profileResults && !searching && category == 1
                          ? users.length
                          : users.take(5).length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final id = user.str('id');
                        final pending = store.state.ids('pending').contains(id);
                        final followed = store.follows(id);
                        return ListTile(
                          leading: Avatar(
                            id,
                            size: 39,
                            ring: store.hasUnseenStories(id),
                          ),
                          title: Text(
                            user.str('username'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            user.str('name'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: searching || followed
                              ? null
                              : FilledButton(
                                  onPressed: () => perform(
                                    context,
                                    () => store.act('follow', {
                                      'user': id,
                                      'enabled': !pending,
                                    }),
                                  ),
                                  child: Text(pending ? 'In attesa' : 'Segui'),
                                ),
                          onTap: () => openProfile(user),
                        );
                      },
                    ),
                  if (showPosts && results && category == 0 && items.isNotEmpty)
                    const SliverToBoxAdapter(child: _ExploreLabel('Post')),
                  if (showPosts)
                    _postGrid(
                      context,
                      items,
                      explore: true,
                      onOpen: () => store.rememberSearch(query),
                    ),
                  if (results && !searching && category == 3)
                    SliverList.list(
                      children: [
                        for (final (post, count) in audio.values)
                          ListTile(
                            leading: const GIcon(CupertinoIcons.music_note),
                            title: Text(
                              post.obj('style').obj('music').str('title'),
                            ),
                            subtitle: Text(
                              '${post.obj('style').obj('music').str('artist')} · $count contenuti',
                            ),
                            onTap: () =>
                                open(context, PostPage(id: post.str('id'))),
                          ),
                      ],
                    ),
                  if (results && !searching && category == 4)
                    SliverList.list(
                      children: [
                        for (final entry in tags.entries)
                          ListTile(
                            leading: const GIcon(CupertinoIcons.number),
                            title: Text(entry.key),
                            subtitle: Text('${entry.value} contenuti'),
                            onTap: () => submit(entry.key),
                          ),
                      ],
                    ),
                  if (!searching &&
                      switch (category) {
                        1 => users.isEmpty,
                        2 => items.isEmpty,
                        3 => audio.isEmpty,
                        4 => tags.isEmpty,
                        _ => items.isEmpty && (!results || users.isEmpty),
                      })
                    const SliverToBoxAdapter(
                      child: EmptyState(
                        CupertinoIcons.search,
                        'Nessun risultato',
                        'Prova un’altra ricerca.',
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: padding)),
                ],
              ),
            ),
    );
  }
}

class _ExploreLabel extends StatelessWidget {
  const _ExploreLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(15, 10, 15, 4),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
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
  bool showSuggestions = true;
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
          (post) =>
              (post.str('author') == widget.user ||
                  post.ids('collaborators').contains(widget.user)) &&
              !post.flag('archived') &&
              !post.flag('collaborationPending'),
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
      3 => store.taggedPosts(widget.user),
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
    final hasNote = own || note != null;
    final activeStories = store.stories(widget.user).isNotEmpty;
    final portraitSize = (MediaQuery.sizeOf(context).width * .246).clamp(
      78.0,
      99.0,
    );
    final noteOffset = hasNote
        ? 16.0 +
              (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(
                    0.0,
                    40.0,
                  ) *
                  1.8
        : 0.0;
    final connections = person.rows('links');
    final page = Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 60,
        leadingWidth: 72,
        title: own
            ? _AccountTitle(
                store: store,
                locked: person.flag('private'),
                profile: true,
              )
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
                icon: const GIcon(CupertinoIcons.plus, size: 26),
                onPressed: () => createMenu(context),
              )
            : null,
        actions: [
          if (own) ...[
            IconButton(
              tooltip: 'Impostazioni e attività',
              icon: const GIcon(CupertinoIcons.line_horizontal_3, size: 27),
              onPressed: () => open(context, const Settings()),
            ),
            const SizedBox(width: 14),
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
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: portraitSize,
                          height: portraitSize + noteOffset,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: [
                              Positioned(
                                left: -5,
                                bottom: 0,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: activeStories
                                      ? () => open(
                                          context,
                                          StoryViewer(user: widget.user),
                                        )
                                      : own
                                      ? () => open(context, const EditProfile())
                                      : null,
                                  child: Avatar(
                                    widget.user,
                                    key: const ValueKey('profile-avatar'),
                                    size:
                                        portraitSize -
                                        (activeStories ? 10.2 : 0),
                                    ring: activeStories,
                                    viewed:
                                        !own &&
                                        !store.hasUnseenStories(widget.user),
                                  ),
                                ),
                              ),
                              if (hasNote)
                                Positioned(
                                  top: 0,
                                  left: 1,
                                  right: 11,
                                  child: Tooltip(
                                    message: own
                                        ? 'La tua nota'
                                        : 'Rispondi alla nota',
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(17),
                                      onTap: own
                                          ? () => manageOwnNote(context)
                                          : () => replyNote(context, note!),
                                      child: NoteBubble(
                                        text:
                                            note?.str('text') ??
                                            'Lascia una nota…',
                                        details:
                                            note?.obj('details') ?? const {},
                                        placeholder: note == null,
                                      ),
                                    ),
                                  ),
                                ),
                              if (own)
                                Positioned(
                                  right: -1,
                                  bottom: 4,
                                  child: Tooltip(
                                    message: 'Aggiungi alla storia',
                                    child: InkWell(
                                      onTap: () => open(
                                        context,
                                        const Composer(kind: 'story'),
                                      ),
                                      customBorder: const CircleBorder(),
                                      child: Container(
                                        width: 29,
                                        height: 29,
                                        decoration: BoxDecoration(
                                          color: foreground(context),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: surface(context),
                                            width: 2.6,
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
                        const SizedBox(width: 9),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 34),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.str('name', person.str('username')),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 9),
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
                      ],
                    ),
                    if (person.str('pronouns').isNotEmpty ||
                        person.str('bio').isNotEmpty)
                      const SizedBox(height: 6),
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
                      Text(
                        person.str('bio').replaceAll(r'\n', '\n'),
                        style: const TextStyle(fontSize: 13, height: 1.26),
                      ),
                    ],
                    if (person.rows('links').isNotEmpty || own) ...[
                      const SizedBox(height: 12),
                      ProfileLinkChips(
                        links: connections,
                        own: own,
                        compact: true,
                      ),
                    ],
                    const SizedBox(height: 9),
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
                                  ? 'Modifica'
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
                        const SizedBox(width: 5),
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
                              backgroundColor: _profileControl(context),
                              minimumSize: const Size.square(32),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (own && showSuggestions)
              SliverToBoxAdapter(child: _suggestions(context, store)),
            if (!restricted && (own || highlights.isNotEmpty))
              SliverToBoxAdapter(
                child: _highlights(context, store, highlights, own: own),
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
                      CupertinoIcons.square_grid_3x2_fill,
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
                                'Tag',
                              ][index],
                              onPressed: () => setState(() => section = index),
                              icon: index == 0
                                  ? _profileGridGlyph(context, section == 0)
                                  : Icon(
                                      icon,
                                      size: 25,
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
              if (section == 3 && own && store.supportsPostTagManagement)
                SliverToBoxAdapter(
                  child: ListTile(
                    title: const Text('Post con tag'),
                    trailing: TextButton(
                      onPressed: () => open(context, const TaggedPostsPage()),
                      child: const Text('Gestisci'),
                    ),
                  ),
                ),
              if (posts.isEmpty)
                SliverToBoxAdapter(
                  child: section == 3
                      ? const EmptyState(
                          CupertinoIcons.person_crop_rectangle,
                          'Nessun post con tag',
                          'Qui vedrai i post in cui sei taggato.',
                        )
                      : const EmptyState(
                          CupertinoIcons.photo,
                          'Nessun contenuto',
                          'I contenuti appariranno qui.',
                        ),
                ),
              _postGrid(
                context,
                posts,
                pinned: pinned,
                taggedUser: section == 3 ? widget.user : null,
              ),
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

  Color _profileControl(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
      ? const Color(0xffeef0f3)
      : subdued(context);

  ButtonStyle _profileButton(BuildContext context, {bool primary = false}) =>
      FilledButton.styleFrom(
        backgroundColor: primary
            ? const Color(0xff4656f6)
            : _profileControl(context),
        foregroundColor: primary ? Colors.white : foreground(context),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      );

  Widget _profileGridGlyph(BuildContext context, bool active) => SizedBox(
    width: 19,
    height: 22,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var row = 0; row < 4; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var col = 0; col < 3; col++)
                Container(
                  width: 4.5,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? foreground(context)
                        : secondaryText(context),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _highlights(
    BuildContext context,
    GpixStore store,
    List<J> highlights, {
    required bool own,
  }) {
    final textSize = MediaQuery.textScalerOf(context).scale(11);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: SizedBox(
        height: 72 + textSize * 1.45,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: highlights.length + (own ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(width: 18),
          itemBuilder: (context, index) {
            final add = own && index == 0;
            final highlight = add
                ? const <String, dynamic>{}
                : highlights[index - (own ? 1 : 0)];
            final ids = highlight
                .ids('posts')
                .where((id) => store.post(id).isNotEmpty)
                .toList();
            return SizedBox(
              width: 65,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: add
                    ? () => createHighlight(context)
                    : ids.isEmpty
                    ? null
                    : () => open(
                        context,
                        StoryViewer(user: widget.user, ids: ids),
                      ),
                onLongPress: !add && own
                    ? () async {
                        final remove = await gpixAlert(
                          context,
                          'Eliminare la raccolta?',
                          highlight.str('title'),
                          confirm: 'Elimina',
                          cancel: true,
                          destructive: true,
                        );
                        if (remove && context.mounted) {
                          await perform(
                            context,
                            () => store.act('deleteHighlight', {
                              'id': highlight['id'],
                            }),
                          );
                        }
                      }
                    : null,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: add ? 2.0 : 2.7,
                        ),
                      ),
                      child: add
                          ? const GIcon(CupertinoIcons.plus, size: 30)
                          : Avatar(
                              widget.user,
                              size: 54,
                              image: highlight.str(
                                'cover',
                                ids.isEmpty
                                    ? ''
                                    : store.post(ids.first).str('media'),
                              ),
                            ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      add ? 'Nuova' : highlight.str('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, height: 1.2),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _suggestions(BuildContext context, GpixStore store) {
    final followingIds = store.state.ids('following').toSet();
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
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Persone suggerite',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => open(context, const Explore()),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.light
                        ? const Color(0xff4656f6)
                        : accent(context),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 35),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Mostra tutti'),
                ),
              ],
            ),
          ),
          SizedBox(
            height:
                188 +
                (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(
                      0.0,
                      45.0,
                    ) *
                    4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final person = people[index];
                final id = person.str('id');
                final pending = store.state.ids('pending').contains(id);
                final inCommon = person
                    .ids('followersList')
                    .where(followingIds.contains)
                    .length;
                return SizedBox(
                  width: (MediaQuery.sizeOf(context).width * .38).clamp(
                    132.0,
                    153.0,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: InkWell(
                                  onTap: () => open(
                                    context,
                                    ProfileHome(user: id, detail: true),
                                  ),
                                  child: Avatar(id, size: 87),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                person.str('name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                inCommon == 0
                                    ? 'Suggerimento per te'
                                    : '$inCommon in comune',
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
                          right: 2,
                          top: 2,
                          child: IconButton(
                            tooltip: 'Nascondi suggerimento',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                setState(() => dismissedSuggestions.add(id)),
                            icon: const GIcon(CupertinoIcons.xmark, size: 13),
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
            style: const TextStyle(
              fontSize: 15,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.16),
          ),
        ],
      ),
    ),
  );
}

class TaggedPostsPage extends StatefulWidget {
  const TaggedPostsPage({super.key});
  @override
  State<TaggedPostsPage> createState() => _TaggedPostsPageState();
}

class _TaggedPostsPageState extends State<TaggedPostsPage> {
  bool hidden = false;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final posts = store.taggedPosts(store.myId, hidden: hidden);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Con tag'), centerTitle: true),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Visibili sul profilo'),
                  ),
                  ButtonSegment(value: true, label: Text('Nascosti')),
                ],
                selected: {hidden},
                onSelectionChanged: (value) =>
                    setState(() => hidden = value.single),
              ),
            ),
          ),
          if (posts.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                CupertinoIcons.person_crop_rectangle,
                hidden ? 'Nessun post nascosto' : 'Nessun post con tag',
                '',
              ),
            )
          else
            _postGrid(context, posts, taggedUser: store.myId),
        ],
      ),
    );
  }
}

Widget _postGrid(
  BuildContext context,
  List<J> posts, {
  List<String> pinned = const [],
  VoidCallback? onOpen,
  bool explore = false,
  String? taggedUser,
}) => SliverGrid.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: explore ? 1 : 2,
    mainAxisSpacing: explore ? 1 : 2,
    childAspectRatio: .75,
  ),
  itemCount: posts.length,
  itemBuilder: (context, index) {
    final post = posts[index];
    final reel = post.str('kind') == 'reel';
    final store = GpixScope.of(context, listen: false);
    final cover = reel
        ? store.reelCover(post)
        : (store.media(post).firstOrNull ?? '');
    return InkWell(
      onTap: () {
        onOpen?.call();
        open(
          context,
          PostPage(
            id: post.str('id'),
            postIds: posts.map((post) => post.str('id')).toList(),
            taggedUser: taggedUser,
          ),
        );
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
  const _AccountTitle({
    required this.store,
    this.locked = false,
    this.profile = false,
    this.direct = false,
  });
  final GpixStore store;
  final bool locked, profile, direct;

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
              GIcon(CupertinoIcons.lock, size: profile ? 16 : 14),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                store.me.str('username'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: profile || direct
                    ? const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(CupertinoIcons.chevron_down, size: 13),
            if (profile && store.hasActivity) ...[
              const SizedBox(width: 5),
              const CircleAvatar(radius: 4, backgroundColor: Color(0xffff003c)),
            ],
          ],
        ),
      ),
    ),
  );
}
