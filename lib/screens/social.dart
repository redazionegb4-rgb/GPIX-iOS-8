import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'stories.dart';
import 'features13.dart';
import 'sessions_instants.dart';
import 'messages.dart';
import 'video.dart';
import 'people.dart';
import 'live.dart';
import 'community.dart';
import 'giphy.dart';
import 'post_extras.dart';
import 'moments.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final feedKey = GlobalKey<_FeedState>();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      backgroundColor: Theme.of(c).canvasColor,
      body: IndexedStack(
        index: tab,
        children: [
          Feed(key: feedKey),
          const Explore(),
          Reels(active: tab == 2),
          Profile(user: s.myId, root: true),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        key: const ValueKey('home-navigation'),
        color: Theme.of(c).canvasColor,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              SizedBox(
                height: 52,
                child: Row(
                  children: [
                    nav(
                      CupertinoIcons.house,
                      CupertinoIcons.house_fill,
                      0,
                      'Home',
                    ),
                    nav(
                      CupertinoIcons.search,
                      CupertinoIcons.search,
                      1,
                      'Cerca',
                    ),
                    Expanded(
                      child: IconButton(
                        tooltip: 'Crea',
                        onPressed: () => createMenu(c),
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: auraBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.plus,
                            size: 21,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    nav(
                      CupertinoIcons.play_rectangle,
                      CupertinoIcons.play_rectangle_fill,
                      2,
                      'Reel',
                    ),
                    nav(
                      CupertinoIcons.person,
                      CupertinoIcons.person_fill,
                      3,
                      'Profilo',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget nav(IconData icon, IconData activeIcon, int index, String label) {
    final selected = tab == index;
    return Expanded(
      child: Center(
        child: Semantics(
          selected: selected,
          child: IconButton(
            tooltip: label,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              minimumSize: const Size(48, 48),
            ),
            onPressed: () {
              setState(() => tab = index);
              if (index == 0) feedKey.currentState?.toTop();
            },
            icon: index == 3
                ? Avatar(GpixScope.of(context).myId, size: 26)
                : GIcon(
                    selected ? activeIcon : icon,
                    size: 25,
                    color: selected ? accent(context) : foreground(context),
                  ),
          ),
        ),
      ),
    );
  }
}

class Feed extends StatefulWidget {
  const Feed({super.key});
  @override
  State<Feed> createState() => _FeedState();
}

class _FeedState extends State<Feed> {
  static const sections = ['Per te', 'Seguiti', 'Gruppi'];
  final pages = PageController();
  final scrolls = {for (final tab in sections.take(2)) tab: ScrollController()};
  final storyKeys = {
    for (final tab in sections.take(2)) tab: GlobalKey<_StoryTrayState>(),
  };
  final refreshKeys = {
    for (final tab in sections.take(2)) tab: GlobalKey<RefreshIndicatorState>(),
  };
  ScrollController get scroll => scrolls[filter] ?? scrolls['Per te']!;
  GlobalKey<_StoryTrayState> get storyKey =>
      storyKeys[filter] ?? storyKeys['Per te']!;
  GlobalKey<RefreshIndicatorState> get refreshKey =>
      refreshKeys[filter] ?? refreshKeys['Per te']!;
  String filter = 'Per te';
  bool refreshing = false;
  Future<void> toTop() async {
    storyKey.currentState?.reset();
    if (scroll.hasClients)
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    if (refreshKey.currentState != null) {
      await refreshKey.currentState!.show();
    } else {
      await refreshFeed();
    }
  }

  Future<void> refreshFeed() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    final started = DateTime.now();
    await perform(
      context,
      () => GpixScope.of(context, listen: false).refreshHome(),
    );
    final remaining = 600 - DateTime.now().difference(started).inMilliseconds;
    if (remaining > 0)
      await Future<void>.delayed(Duration(milliseconds: remaining));
    if (mounted) {
      setState(() => refreshing = false);
      storyKey.currentState?.reset();
    }
  }

  @override
  void dispose() {
    pages.dispose();
    for (final controller in scrolls.values) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final posts = s.posts
        .where((p) => !s.preferences.ids('muted').contains(p.str('author')))
        .toList();
    final entries = <J>[
      for (final p in posts) {...p, '_entry': 'post'},
      for (final m in s.state.rows('socialItems'))
        if (m.str('kind') == 'moment' &&
            !s.blocked(m.str('author')) &&
            !s.preferences.ids('muted').contains(m.str('author')) &&
            !posts.any((p) => p.str('id') == m.str('post')))
          {...m, '_entry': 'moment'},
      for (final g in s.state.rows('socialGroups'))
        if (!s.blocked(g.str('owner')) &&
            !s.preferences.ids('muted').contains(g.str('owner')))
          {...g, '_entry': 'group'},
    ]..sort((a, b) => b.number('created').compareTo(a.number('created')));
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        toolbarHeight: 54,
        title: const Text(
          'Home',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(refreshing ? 48 : 45),
          child: Column(
            children: [
              CommunityTabs(const ['Per te', 'Seguiti', 'Gruppi'], filter, (
                value,
              ) {
                pages.animateToPage(
                  sections.indexOf(value),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                );
              }),
              if (refreshing)
                const LinearProgressIndicator(
                  key: ValueKey('home-refresh-indicator'),
                  minHeight: 3,
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Attività',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const GIcon(CupertinoIcons.bell, size: 24),
                if (s.hasActivity)
                  const Positioned(
                    top: -2,
                    right: -3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: auraBlue,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
              ],
            ),
            onPressed: () => open(c, const Activity()),
          ),
          IconButton(
            tooltip: 'Messaggi',
            onPressed: () => open(c, const Inbox()),
            icon: Badge(
              isLabelVisible: s.threads.any(s.chatHasUnread),
              backgroundColor: auraBlue,
              child: const GIcon(CupertinoIcons.paperplane, size: 24),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
      backgroundColor: Theme.of(c).canvasColor,
      body: PageView.builder(
        key: const ValueKey('home-sections'),
        controller: pages,
        itemCount: sections.length,
        onPageChanged: (index) => setState(() => filter = sections[index]),
        itemBuilder: (context, index) {
          final section = sections[index];
          if (section == 'Gruppi') return const CommunityDirectory();
          final visible = entries.where((entry) {
            final author = entry.str('_entry') == 'group'
                ? entry.str('owner')
                : entry.str('author');
            return section != 'Seguiti' ||
                s.follows(author) ||
                author == s.myId;
          }).toList();
          return RefreshIndicator(
            key: refreshKeys[section],
            color: auraBlue,
            onRefresh: refreshFeed,
            child: ListView.builder(
              key: PageStorageKey(
                section == 'Per te' ? 'feed' : 'feed-following',
              ),
              controller: scrolls[section],
              padding: const EdgeInsets.only(bottom: 16),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: visible.length + 2,
              itemBuilder: (c, i) {
                if (i == 0) return StoryTray(key: storyKeys[section]);
                if (i == visible.length + 1)
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const GIcon(
                          CupertinoIcons.check_mark_circled,
                          size: 32,
                          color: auraBlue,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          visible.isEmpty
                              ? 'Qui iniziano le tue storie.'
                              : 'Sei al passo con le novità',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                final entry = visible[i - 1];
                if (entry.str('_entry') != 'post')
                  return CommunityFeedCard(
                    item: entry,
                    group: entry.str('_entry') == 'group',
                  );
                return PostCard(
                  key: ValueKey(entry.str('id')),
                  id: entry.str('id'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class StoryTray extends StatefulWidget {
  const StoryTray({super.key});
  @override
  State<StoryTray> createState() => _StoryTrayState();
}

class _StoryTrayState extends State<StoryTray> {
  final scroll = ScrollController();
  void reset() {
    if (scroll.hasClients)
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    setState(() {});
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final users = s.storyUsers;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.state.rows('lives').isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                for (final room in s.state.rows('lives'))
                  InkWell(
                    onTap: () => open(
                      c,
                      LiveRoom(
                        id: room.str('id'),
                        host: room.str('host'),
                        title: room.str('title'),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17),
                      child: Column(
                        children: [
                          Avatar(room.str('host'), size: 41, ring: true),
                          const SizedBox(height: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height:
              112 +
              (MediaQuery.textScalerOf(c).scale(12) - 12).clamp(0.0, 32.0),
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: ListView.separated(
            key: const ValueKey('stories-strip'),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
            scrollDirection: Axis.horizontal,
            itemCount: users.length + 1,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (c, i) {
              final uid = i == 0 ? s.myId : users[i - 1].str('id');
              final stories = s.stories(uid);
              return InkWell(
                onTap: () => i == 0 && stories.isEmpty
                    ? open(c, const Composer(kind: 'story'))
                    : open(c, StoryViewer(user: uid)),
                onLongPress: i == 0
                    ? () => open(c, const Composer(kind: 'story'))
                    : null,
                child: SizedBox(
                  width: ((MediaQuery.sizeOf(c).width - 36) / 5.2).clamp(
                    56.0,
                    88.0,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(
                            uid,
                            size: ((MediaQuery.sizeOf(c).width - 36) / 5.2 - 13)
                                .clamp(48.0, 58.0),
                            ring: stories.isNotEmpty,
                            viewed:
                                i != 0 &&
                                stories.every(
                                  (p) =>
                                      (p.flag('seenByMe') ||
                                      p.ids('viewers').contains(s.myId)),
                                ),
                          ),
                          if (i == 0)
                            Positioned(
                              right: -1,
                              bottom: 0,
                              child: GestureDetector(
                                key: const ValueKey('create-own-story'),
                                onTap: () =>
                                    open(c, const Composer(kind: 'story')),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: auraBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: surface(c),
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const GIcon(
                                    CupertinoIcons.plus,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        i == 0 ? 'La tua storia' : s.user(uid).str('username'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryText(c),
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
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = count;
    final display = value != null && value >= 10000
        ? '${(value / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ',')} mila'
        : value?.toString();
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        onTap: onTap,
        label: value == null ? label : '$label, $value',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GIcon(icon, color: color ?? foreground(context), size: 23),
                  if (display != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      display,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final String id;
  final bool detail;
  const PostCard({super.key, required this.id, this.detail = false});
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with SingleTickerProviderStateMixin {
  int page = 0;
  late final AnimationController heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  @override
  void dispose() {
    heart.dispose();
    super.dispose();
  }

  void like(BuildContext c, J p, {bool force = false}) {
    final s = GpixScope.of(c, listen: false);
    if (force) {
      heart.forward(from: 0);
      if (p.ids('likes').contains(s.myId)) return;
    }
    perform(
      c,
      () => s.act('like', {
        'id': widget.id,
        'enabled': force || !p.ids('likes').contains(s.myId),
      }),
    );
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), p = s.post(widget.id);
    if (p.isEmpty) return const SizedBox.shrink();
    final uid = p.str('author'),
        u = s.user(uid),
        media = s.media(p),
        liked = p.ids('likes').contains(s.myId);
    final moment = s.state
        .rows('socialItems')
        .where(
          (item) =>
              item.str('kind') == 'moment' && item.str('post') == widget.id,
        )
        .firstOrNull;
    final participants = <String>{
      if (moment != null) moment.str('author'),
      if (moment != null)
        ...moment.rows('contributions').map((r) => r.str('author')),
    }.take(4).toList();
    final visibleLikers = p
        .ids('likes')
        .where((id) => s.user(id).str('username').isNotEmpty)
        .take(3)
        .toList();
    final menu = IconButton(
      tooltip: 'Opzioni del post',
      icon: const GIcon(CupertinoIcons.ellipsis, size: 22),
      onPressed: () {
        if (uid == s.myId &&
            moment == null &&
            s.state.number('communityVersion') > 0 &&
            p.str('kind') == 'post') {
          sheet(
            c,
            Builder(
              builder: (menu) => Column(
                children: [
                  ListTile(
                    leading: const GIcon(CupertinoIcons.person_2),
                    title: const Text('Crea un Momento da questo post'),
                    onTap: () {
                      Navigator.pop(menu);
                      composeCommunity(c, 'communityMoment', post: widget.id);
                    },
                  ),
                  ListTile(
                    leading: const GIcon(CupertinoIcons.ellipsis),
                    title: const Text('Altre opzioni del post'),
                    onTap: () {
                      Navigator.pop(menu);
                      postMenu(c, p);
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          postMenu(c, p);
        }
      },
    );
    final location = p.str('location');
    final name = u.str('name').trim().isEmpty
        ? u.str('username')
        : u.str('name');
    final postSubtitle = [
      if (p.number('created') > 0) relative(p['created']),
      if (p.str('audience') == 'close') 'Amici più stretti',
      if (location.isNotEmpty) location,
    ].join(' · ');
    final authorInfo = InkWell(
      onTap: () => open(c, Profile(user: uid)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(uid, size: 38),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    postSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: secondaryText(c)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final author = authorInfo;
    final canFollow = uid != s.myId && !s.follows(uid);
    final followButton = TextButton(
      key: ValueKey('feed-follow-$uid-${widget.id}'),
      onPressed: () =>
          perform(c, () => s.act('follow', {'user': uid, 'enabled': true})),
      style: TextButton.styleFrom(
        backgroundColor: subdued(c),
        foregroundColor: foreground(c),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(68, 34),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: const Text(
        'Segui',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    return Container(
      key: ValueKey('feed-post-${widget.id}'),
      margin: EdgeInsets.fromLTRB(
        widget.detail ? 0 : 10,
        6,
        widget.detail ? 0 : 10,
        14,
      ),
      padding: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: surface(c),
        border: Border.all(
          color: Theme.of(c).dividerColor.withValues(alpha: .6),
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(c).brightness == Brightness.dark ? .18 : .055,
            ),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.ids('reposts').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 10, 17, 0),
              child: Row(
                children: [
                  const GIcon(CupertinoIcons.repeat, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ripubblicato da ${p.ids('reposts').map((id) => id == s.myId ? 'te' : s.user(id).str('username')).take(3).join(', ')}',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: author),
                ),
                if (canFollow) followButton,
                menu,
              ],
            ),
          ),
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GestureDetector(
                  onTap: () => openPhotoPreview(
                    c,
                    media[page.clamp(0, media.length - 1)],
                  ),
                  onDoubleTap: () => like(c, p, force: true),
                  child: LayoutBuilder(
                    builder: (c, constraints) {
                      final width = constraints.maxWidth;
                      final aspect = p
                          .obj('style')
                          .number('aspect', 1)
                          .clamp(.35, 2.5)
                          .toDouble();
                      Widget photo(String ref) => ColoredBox(
                        color: subdued(c),
                        child: MediaView(
                          ref,
                          width: width,
                          fit: BoxFit.contain,
                          placeholderHeight: width / aspect,
                        ),
                      );
                      return Stack(
                        children: [
                          if (media.length == 1)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: width / 2.5,
                              ),
                              child: photo(media.first),
                            )
                          else
                            AspectRatio(
                              aspectRatio: aspect,
                              child: PageView.builder(
                                key: PageStorageKey('media-${widget.id}'),
                                itemCount: media.length,
                                onPageChanged: (i) => setState(() => page = i),
                                itemBuilder: (c, i) => photo(media[i]),
                              ),
                            ),
                          if (media.length > 1)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${page + 1}/${media.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: heart,
                                builder: (c, _) => Opacity(
                                  opacity: heart.value == 0
                                      ? 0
                                      : (1 - heart.value).clamp(0, 1),
                                  child: Transform.scale(
                                    scale: .8 + heart.value * .45,
                                    child: const Center(
                                      child: GIcon(
                                        CupertinoIcons.heart_fill,
                                        size: 95,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 12,
                                            color: Colors.black26,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          if (media.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  media.length,
                  (i) => Container(
                    width: i == page ? 6 : 5,
                    height: i == page ? 6 : 5,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == page
                          ? accent(c)
                          : secondaryText(c).withValues(alpha: .35),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 3, 9, 3),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: _PostAction(
                          label: 'Mi piace',
                          icon: liked
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: liked ? danger : foreground(c),
                          count: p.flag('hideLikes')
                              ? null
                              : p.ids('likes').length,
                          onTap: () => like(c, p),
                        ),
                      ),
                      Flexible(
                        child: _PostAction(
                          label: 'Commenti',
                          icon: CupertinoIcons.chat_bubble,
                          count: p.rows('comments').length,
                          onTap: () => comments(c, widget.id),
                        ),
                      ),
                      if (p.str('kind') != 'story' &&
                          !s.user(p.str('author')).flag('private') &&
                          !['close', 'followers'].contains(p.str('audience')))
                        Flexible(
                          child: _PostAction(
                            label: p.ids('reposts').contains(s.myId)
                                ? 'Annulla ripubblicazione'
                                : 'Ripubblica',
                            icon: CupertinoIcons.repeat,
                            color: p.ids('reposts').contains(s.myId)
                                ? Colors.green
                                : foreground(c),
                            count: p.ids('reposts').length,
                            onTap: () => perform(
                              c,
                              () => s.act('repost', {
                                'id': p['id'],
                                'enabled': !p.ids('reposts').contains(s.myId),
                              }),
                            ),
                          ),
                        ),
                      Flexible(
                        child: _PostAction(
                          label: 'Condividi',
                          icon: CupertinoIcons.paperplane,
                          count: p.number('shareCount').toInt(),
                          onTap: () => sharePost(c, p),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Salva',
                  onPressed: () => perform(
                    c,
                    () => s.act('save', {
                      'id': widget.id,
                      'enabled': !p.flag('saved'),
                    }),
                  ),
                  icon: GIcon(
                    p.flag('saved')
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    size: 23,
                    color: p.flag('saved') ? accent(c) : foreground(c),
                  ),
                ),
              ],
            ),
          ),
          if (widget.detail && canFollow)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, right: 3),
                child: followButton,
              ),
            ),
          PostExtras(post: p),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!p.flag('hideLikes') && visibleLikers.isNotEmpty)
                  InkWell(
                    onTap: () => people(c, p.ids('likes'), 'Mi piace'),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20 + (visibleLikers.length - 1) * 14.0,
                          height: 22,
                          child: Stack(
                            children: [
                              for (
                                var i = visibleLikers.length - 1;
                                i >= 0;
                                i--
                              )
                                Positioned(
                                  left: i * 14.0,
                                  child: Avatar(visibleLikers[i], size: 20),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              text: 'Piace a ',
                              children: [
                                TextSpan(
                                  text: s
                                      .user(visibleLikers.first)
                                      .str('username'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (p.ids('likes').length > 1)
                                  const TextSpan(text: ' e altri'),
                              ],
                            ),
                            style: const TextStyle(fontSize: 12.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (p.str('text').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$name ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: p.str('text')),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ],
                if (widget.detail &&
                    !p.flag('commentsOff') &&
                    p.rows('comments').isEmpty) ...[
                  const SizedBox(height: 7),
                  InkWell(
                    onTap: () => comments(c, widget.id),
                    child: Text(
                      'Aggiungi un commento…',
                      style: TextStyle(fontSize: 12.5, color: secondaryText(c)),
                    ),
                  ),
                ],
                if (widget.detail && p.number('created') > 0) ...[
                  const SizedBox(height: 5),
                  Text(
                    relative(p['created']),
                    style: TextStyle(fontSize: 11, color: secondaryText(c)),
                  ),
                ],
                if (widget.detail && location.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    p.str('location'),
                    style: TextStyle(fontSize: 10.5, color: secondaryText(c)),
                  ),
                ],
              ],
            ),
          ),
          if (moment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 3),
              child: Material(
                color: auraBlue.withValues(alpha: .06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: auraBlue.withValues(alpha: .12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width:
                            30 + (participants.length - 1).clamp(0, 3) * 18.0,
                        height: 32,
                        child: Stack(
                          children: [
                            for (var i = participants.length - 1; i >= 0; i--)
                              Positioned(
                                left: i * 18.0,
                                child: Avatar(participants[i], size: 30),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${participants.length} persone hanno aggiunto uno scatto',
                          style: const TextStyle(fontSize: 12, height: 1.2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: const BorderSide(color: auraBlue),
                          foregroundColor: accent(c),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            open(c, CommunityDetail(id: moment.str('id'))),
                        child: const Text(
                          'Apri momento',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> people(BuildContext c, List<String> ids, String title) => sheet(
  c,
  Column(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      if (ids.isEmpty)
        const Padding(
          padding: EdgeInsets.all(30),
          child: Text('Nessun account'),
        ),
      for (final id in ids)
        PersonTile(
          id,
          onTap: () {
            Navigator.pop(c);
            open(c, Profile(user: id));
          },
        ),
      const SizedBox(height: 16),
    ],
  ),
);
Future<void> postMenu(BuildContext c, J p) async {
  final s = GpixScope.of(c, listen: false), own = p.str('author') == s.myId;
  if (own && p.str('kind') == 'story') {
    final action = await sheet<String>(
      c,
      Builder(
        builder: (menu) => Column(
          children: [
            ActionRow(
              CupertinoIcons.trash,
              'Elimina storia',
              () => Navigator.pop(menu, 'delete'),
              destructive: true,
            ),
            ActionRow(
              CupertinoIcons.star_circle,
              'Metti in evidenza',
              () => Navigator.pop(menu, 'highlight'),
            ),
            ActionRow(
              CupertinoIcons.pencil,
              'Modifica didascalia',
              () => Navigator.pop(menu, 'edit'),
            ),
            ActionRow(
              CupertinoIcons.chat_bubble,
              p.flag('commentsOff') ? 'Attiva commenti' : 'Disattiva commenti',
              () => Navigator.pop(menu, 'comments'),
            ),
            ActionRow(
              CupertinoIcons.star_fill,
              'Amici più stretti',
              () => Navigator.pop(menu, 'friends'),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (!c.mounted) return;
    if (action == 'highlight') {
      await addStoryHighlight(c, p);
    } else if (action == 'friends') {
      await open(c, const CloseFriends());
    } else if (action == 'comments') {
      await perform(
        c,
        () => s.act('postOptions', {
          'id': p['id'],
          'commentsOff': !p.flag('commentsOff'),
          'hideLikes': p.flag('hideLikes'),
        }),
      );
    } else if (action == 'edit') {
      final text = await textDialog(c, 'Modifica didascalia', p.str('text'));
      if (text != null && c.mounted)
        await perform(
          c,
          () => s.act('editPost', {
            'id': p['id'],
            'text': text,
            'location': p['location'],
          }),
        );
    } else if (action == 'delete' &&
        await gpixAlert(
          c,
          'Eliminare la storia?',
          'Questa azione non può essere annullata.',
          confirm: 'Elimina',
          cancel: true,
          destructive: true,
        ) &&
        c.mounted) {
      await perform(c, () => s.act('deletePost', {'id': p['id']}));
    }
    return;
  }
  await sheet(
    c,
    Column(
      children: [
        ActionRow(
          p.flag('saved')
              ? CupertinoIcons.bookmark_fill
              : CupertinoIcons.bookmark,
          p.flag('saved') ? 'Rimuovi dai salvati' : 'Salva',
          () {
            Navigator.pop(c);
            perform(
              c,
              () => s.act('save', {'id': p['id'], 'enabled': !p.flag('saved')}),
            );
          },
        ),
        ActionRow(CupertinoIcons.paperplane, 'Invia a…', () {
          Navigator.pop(c);
          sharePost(c, p);
        }),
        if (own) ...[
          if (p.str('kind') != 'story')
            ActionRow(
              CupertinoIcons.pin,
              s.me.ids('pinnedPosts').contains(p.str('id'))
                  ? 'Rimuovi dal profilo fissato'
                  : 'Fissa nel profilo',
              () {
                Navigator.pop(c);
                perform(
                  c,
                  () => s.act('pinPost', {
                    'id': p['id'],
                    'enabled': !s.me.ids('pinnedPosts').contains(p.str('id')),
                  }),
                );
              },
            ),
          if (p.str('kind') == 'story')
            ActionRow(CupertinoIcons.star_circle, 'Metti in evidenza', () {
              Navigator.pop(c);
              addStoryHighlight(c, p);
            }),
          const Divider(),
          ActionRow(CupertinoIcons.pencil, 'Modifica', () async {
            Navigator.pop(c);
            final text = await textDialog(
              c,
              'Modifica didascalia',
              p.str('text'),
            );
            if (text != null && c.mounted)
              perform(
                c,
                () => s.act('editPost', {
                  'id': p['id'],
                  'text': text,
                  'location': p['location'],
                }),
              );
          }),
          ActionRow(
            CupertinoIcons.archivebox,
            p.flag('archived') ? 'Mostra nel profilo' : 'Archivia',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('archivePost', {
                  'id': p['id'],
                  'enabled': !p.flag('archived'),
                }),
              );
            },
          ),
          ActionRow(
            CupertinoIcons.chat_bubble,
            p.flag('commentsOff') ? 'Attiva commenti' : 'Disattiva commenti',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('postOptions', {
                  'id': p['id'],
                  'commentsOff': !p.flag('commentsOff'),
                  'hideLikes': p.flag('hideLikes'),
                }),
              );
            },
          ),
          ActionRow(
            CupertinoIcons.eye_slash,
            p.flag('hideLikes')
                ? 'Mostra numero di Mi piace'
                : 'Nascondi numero di Mi piace',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('postOptions', {
                  'id': p['id'],
                  'commentsOff': p.flag('commentsOff'),
                  'hideLikes': !p.flag('hideLikes'),
                }),
              );
            },
          ),
          ActionRow(CupertinoIcons.trash, 'Elimina', () async {
            Navigator.pop(c);
            if (await gpixAlert(
                  c,
                  'Eliminare il contenuto?',
                  'Questa azione non può essere annullata.',
                  confirm: 'Elimina',
                  destructive: true,
                  cancel: true,
                ) &&
                c.mounted)
              perform(c, () => s.act('deletePost', {'id': p['id']}));
          }, destructive: true),
        ] else ...[
          ActionRow(
            CupertinoIcons.person,
            s.follows(p.str('author')) ? 'Non seguire più' : 'Segui',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('follow', {
                  'user': p['author'],
                  'enabled': !s.follows(p.str('author')),
                }),
              );
            },
          ),
          ActionRow(CupertinoIcons.flag, 'Segnala', () {
            Navigator.pop(c);
            report(c, p.str('id'));
          }, destructive: true),
        ],
        const SizedBox(height: 16),
      ],
    ),
  );
}

Future<String?> textDialog(
  BuildContext c,
  String title,
  String value, {
  String hint = '',
  bool obscure = false,
}) => sheet<String>(
  c,
  _TextDialog(title: title, initial: value, hint: hint, obscure: obscure),
);

class _TextDialog extends StatefulWidget {
  final String title, initial, hint;
  final bool obscure;
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.obscure,
  });
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: auraBlue.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: GIcon(
                widget.obscure
                    ? CupertinoIcons.lock
                    : CupertinoIcons.square_pencil,
                color: accent(c),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Chiudi',
              onPressed: () => Navigator.pop(c),
              icon: const GIcon(CupertinoIcons.xmark, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          autofocus: true,
          minLines: widget.obscure ? 1 : 3,
          maxLines: widget.obscure ? 1 : 6,
          obscureText: widget.obscure,
          textCapitalization: widget.obscure
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          style: const TextStyle(fontSize: 17, height: 1.5),
          decoration: InputDecoration(
            hintText: widget.hint.isEmpty
                ? (widget.obscure ? 'Password' : 'Scrivi qui…')
                : widget.hint,
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Annulla'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  c,
                  widget.obscure ? controller.text : controller.text.trim(),
                ),
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> report(BuildContext c, String id) => sheet(
  c,
  Column(
    children: [
      const Text(
        'Perché vuoi segnalarlo?',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 15),
      for (final reason in [
        'Molestie o bullismo',
        'Odio e discriminazione',
        'Spam o truffa',
        'Contenuti non appropriati',
      ])
        ActionRow(CupertinoIcons.flag, reason, () {
          Navigator.pop(c);
          perform(c, () async {
            await GpixScope.of(
              c,
              listen: false,
            ).act('report', {'id': id, 'reason': reason});
            if (c.mounted)
              await gpixAlert(
                c,
                'Segnalazione registrata',
                '${GpixScope.of(c, listen: false).demo ? 'In demo la segnalazione resta su questo dispositivo.' : 'La segnalazione è stata inviata al server.'}',
              );
          });
        }),
      const SizedBox(height: 20),
    ],
  ),
);
Future<void> sharePost(BuildContext c, J p) => sheet(c, SharePanel(post: p));

class SharePanel extends StatefulWidget {
  final J post;
  const SharePanel({super.key, required this.post});
  @override
  State<SharePanel> createState() => _SharePanelState();
}

class _SharePanelState extends State<SharePanel> {
  final selected = <String>{};
  final search = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final users = s.users
        .where(
          (u) =>
              u.str('id') != s.myId &&
              !s.blocked(u.str('id')) &&
              ('${u.str('name')} ${u.str('username')}').toLowerCase().contains(
                search.text.toLowerCase(),
              ),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          const Text(
            'Condividi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cerca persone',
              prefixIcon: const GIcon(CupertinoIcons.search),
              filled: true,
              fillColor: subdued(c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nessuna persona trovata'),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              mainAxisExtent: 105,
            ),
            itemBuilder: (c, i) {
              final u = users[i],
                  id = u.str('id'),
                  active = selected.contains(id);
              return InkWell(
                onTap: busy
                    ? null
                    : () => setState(() {
                        active ? selected.remove(id) : selected.add(id);
                      }),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Avatar(id, size: 58),
                        if (active)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: auraBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.check_mark,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      u.str('username'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          if (selected.isNotEmpty)
            PrimaryButton(
              'Invia${selected.length > 1 ? ' a ${selected.length} persone' : ''}',
              busy: busy,
              onTap: () async {
                setState(() => busy = true);
                await perform(c, () async {
                  for (final id in selected.toList()) {
                    final tid = await s.openThread(id);
                    await s.act('sharePost', {
                      'id': tid,
                      'post': widget.post.str('id'),
                    });
                    selected.remove(id);
                  }
                  if (c.mounted) {
                    Navigator.pop(c);
                    notice(c, 'Post inviato');
                  }
                });
                if (mounted) setState(() => busy = false);
              },
            ),
          const SizedBox(height: 12),
          const Divider(),
          ActionRow(
            CupertinoIcons.share,
            'Condividi in un’altra app',
            () => SharePlus.instance.share(
              ShareParams(
                text:
                    '${s.user(widget.post.str('author')).str('username')} su GPIX\n${widget.post.str('text')}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> comments(BuildContext c, String id) =>
    sheet(c, Comments(id: id), scroll: false);

class Comments extends StatefulWidget {
  final String id;
  const Comments({super.key, required this.id});
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final input = TextEditingController();
  String parent = '', replyName = '', media = '';
  Future<void> pickComment(bool gif) async {
    final s = GpixScope.of(context, listen: false);
    if (gif) {
      await sheet(
        context,
        GiphyGallery(
          onSelected: (value) {
            Navigator.pop(context);
            perform(context, () async {
              final ref = await s.uploadAsset(value, 'image/gif');
              if (mounted) setState(() => media = ref);
            });
          },
          onImport: () {
            Navigator.pop(context);
            perform(context, () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['gif'],
              );
              final path = result?.files.single.path;
              if (path == null) return;
              final ref = await s.upload(path, 'image/gif');
              if (mounted) setState(() => media = ref);
            });
          },
        ),
      );
    } else {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (photo != null && mounted)
        await perform(context, () async {
          final ref = await s.upload(photo.path, 'image/jpeg');
          if (mounted) setState(() => media = ref);
        });
    }
  }

  final focus = FocusNode();
  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        p = s.post(widget.id),
        comments = p.rows('comments').where((m) {
          final owner = p.str('author') == s.myId;
          if (m.flag('hidden') && !owner && m.str('author') != s.myId)
            return false;
          final root = p
              .rows('comments')
              .where((x) => x.str('id') == m.str('parent'))
              .firstOrNull;
          return root == null ||
              !root.flag('hidden') ||
              owner ||
              root.str('author') == s.myId;
        }).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(c).height * .78,
      child: Column(
        children: [
          const Text(
            'Commenti',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: EmptyState(
                      CupertinoIcons.chat_bubble,
                      'Ancora nessun commento',
                      'Avvia la conversazione.',
                    ),
                  )
                : ListView(
                    children: [
                      for (final comment in comments.where(
                        (e) => e.str('parent').isEmpty,
                      )) ...[
                        _comment(c, comment, false),
                        for (final child in comments.where(
                          (e) => e.str('parent') == comment.str('id'),
                        ))
                          _comment(c, child, true),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in [
                  '❤️',
                  '🙌',
                  '🔥',
                  '👏',
                  '😢',
                  '😍',
                  '😮',
                  '😂',
                ])
                  InkWell(
                    onTap: () {
                      input.text += emoji;
                      setState(() {});
                      focus.requestFocus();
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 23)),
                  ),
              ],
            ),
          ),
          if (media.isNotEmpty)
            ListTile(
              leading: SizedBox(
                width: 42,
                height: 42,
                child: MediaView(s.url(media)),
              ),
              title: const Text('Immagine allegata'),
              trailing: IconButton(
                onPressed: () => setState(() => media = ''),
                icon: const GIcon(CupertinoIcons.xmark),
              ),
            ),
          if (parent.isNotEmpty)
            Container(
              color: subdued(c),
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rispondi a $replyName',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const GIcon(Icons.close, size: 17),
                    onPressed: () => setState(() => parent = ''),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 12, 12),
            child: Row(
              children: [
                Avatar(s.myId, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: input,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Aggiungi un commento…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(color: line),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                ),
                if (input.text.trim().isEmpty && media.isEmpty) ...[
                  IconButton(
                    tooltip: 'Foto nel commento',
                    onPressed: () => pickComment(false),
                    icon: const GIcon(CupertinoIcons.photo, size: 24),
                  ),
                  IconButton(
                    tooltip: 'GIF nel commento',
                    onPressed: () => pickComment(true),
                    icon: const GIcon(Icons.gif_box_outlined, size: 26),
                  ),
                ],
                if (input.text.trim().isNotEmpty || media.isNotEmpty)
                  TextButton(
                    onPressed: input.text.trim().isEmpty && media.isEmpty
                        ? null
                        : () => perform(c, () async {
                            await s.act('comment', {
                              'id': widget.id,
                              'text': input.text.trim(),
                              'parent': parent,
                              'media': media,
                            });
                            input.clear();
                            setState(() {
                              parent = '';
                              media = '';
                            });
                          }),
                    child: const Text(
                      'Pubblica',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void commentOptions(BuildContext c, J m) {
    final s = GpixScope.of(c, listen: false),
        owner = s.post(widget.id).str('author') == s.myId;
    sheet(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (owner)
            ActionRow(
              m.flag('hidden') ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              m.flag('hidden') ? 'Mostra di nuovo' : 'Nascondi agli altri',
              () async {
                Navigator.pop(c);
                await perform(
                  c,
                  () => s.act('hideComment', {
                    'id': m.str('id'),
                    'enabled': !m.flag('hidden'),
                  }),
                );
              },
            ),
          ActionRow(CupertinoIcons.trash, 'Elimina commento', () async {
            Navigator.pop(c);
            if (!await gpixAlert(
                  c,
                  'Eliminare il commento?',
                  'Verranno eliminate anche le risposte a questo commento.',
                  confirm: 'Elimina',
                  destructive: true,
                  cancel: true,
                ) ||
                !c.mounted)
              return;
            await perform(c, () => s.act('deleteComment', {'id': m.str('id')}));
          }, destructive: true),
        ],
      ),
    );
  }

  Widget _comment(BuildContext c, J m, bool child) {
    final s = GpixScope.of(c),
        uid = m.str('author'),
        liked = m.ids('likes').contains(s.myId);
    return Padding(
      padding: EdgeInsets.fromLTRB(child ? 62 : 17, 16, 15, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(uid, size: child ? 26 : 34),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress:
                  uid == s.myId || s.post(widget.id).str('author') == s.myId
                  ? () => commentOptions(c, m)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${s.user(uid).str('username')} ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: m.str('text')),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                  if (m.flag('hidden') &&
                      s.post(widget.id).str('author') == s.myId)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Nascosto agli altri · visibile all’autore',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  if (m.str('media').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: MediaView(m.str('media')),
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        relative(m['created']),
                        style: const TextStyle(fontSize: 10.5, color: muted),
                      ),
                      const SizedBox(width: 15),
                      InkWell(
                        onTap: () {
                          setState(() {
                            parent = child ? m.str('parent') : m.str('id');
                            replyName = s.user(uid).str('username');
                          });
                          focus.requestFocus();
                        },
                        child: const Text(
                          'Rispondi',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Column(
            children: [
              if (uid == s.myId || s.post(widget.id).str('author') == s.myId)
                IconButton(
                  tooltip: 'Opzioni commento',
                  onPressed: () => commentOptions(c, m),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const GIcon(CupertinoIcons.ellipsis, size: 19),
                ),
              InkWell(
                onTap: () => perform(
                  c,
                  () =>
                      s.act('likeComment', {'id': m['id'], 'enabled': !liked}),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: GIcon(
                    liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 14,
                    color: liked ? danger : muted,
                  ),
                ),
              ),
              if (m.ids('likes').isNotEmpty)
                Text(
                  '${m.ids('likes').length}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class Explore extends StatefulWidget {
  const Explore({super.key});
  @override
  State<Explore> createState() => _ExploreState();
}

class _ExploreState extends State<Explore> {
  String query = '';
  String category = 'Tutti';
  bool showAll = false;
  String mediaFilter = 'Tutti';
  final searchInput = TextEditingController();
  @override
  void dispose() {
    searchInput.dispose();
    super.dispose();
  }

  void searchFor(String value) {
    FocusScope.of(context).unfocus();
    searchInput.text = value;
    setState(() => query = value);
    GpixScope.of(context, listen: false).rememberSearch(value);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final term = query.trim().toLowerCase();
    final accountTerm = term.startsWith('@') ? term.substring(1) : term;
    final users = s.users
        .where(
          (u) =>
              u.str('id') != s.myId &&
              !s.blocked(u.str('id')) &&
              '${u.str('name')} ${u.str('username')}'.toLowerCase().contains(
                accountTerm,
              ),
        )
        .toList();
    final source = switch (mediaFilter) {
      'Reel' => s.reels,
      'Post' => s.posts,
      _ => [...s.posts, ...s.reels],
    };
    final posts = source.where((p) {
      final author = p.str('author');
      final match =
          '${p.str('text')} ${p.str('location')} ${s.user(author).str('username')}'
              .toLowerCase();
      return !s.blocked(author) &&
          !s.preferences.ids('muted').contains(author) &&
          match.contains(accountTerm);
    }).toList();
    final featured = term.isEmpty && !showAll;
    final visiblePosts = featured ? posts.take(4).toList() : posts;
    final suggestedGroups = s.state
        .rows('socialGroups')
        .where((g) => g.str('title').toLowerCase().contains(term))
        .take(3);
    final showAccounts =
        category == 'Persone' || (category == 'Tutti' && term.isNotEmpty);
    final showPosts = category == 'Tutti';
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: CustomScrollView(
          key: const PageStorageKey('explore'),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Text(
                  'Esplora',
                  style: Theme.of(c).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: CommunityTabs(
                const ['Tutti', 'Persone', 'Gruppi'],
                category,
                (label) => setState(() => category = label),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(17, 12, 17, 16),
                child: TextField(
                  controller: searchInput,
                  textInputAction: TextInputAction.search,
                  onSubmitted: searchFor,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Cerca persone, gruppi, eventi…',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Svuota ricerca',
                            onPressed: () => searchFor(''),
                            icon: const GIcon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 19,
                            ),
                          ),
                    prefixIcon: const GIcon(
                      CupertinoIcons.search,
                      size: 19,
                      color: muted,
                    ),
                    filled: true,
                    fillColor: subdued(c),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            if (category == 'Gruppi')
              SliverFillRemaining(child: CommunityDirectory(query: query)),
            if (category == 'Tutti' && term.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final option in const ['Tutti', 'Post', 'Reel'])
                        ChoiceChip(
                          label: Text(option),
                          selected: mediaFilter == option,
                          onSelected: (_) =>
                              setState(() => mediaFilter = option),
                        ),
                    ],
                  ),
                ),
              ),
            if (category != 'Gruppi' &&
                query.isEmpty &&
                s.searchHistory.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ricerche recenti',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => s.clearSearchHistory(),
                            child: const Text('Cancella cronologia'),
                          ),
                        ],
                      ),
                    ),
                    for (final term in s.searchHistory)
                      ListTile(
                        leading: const GIcon(CupertinoIcons.clock, size: 20),
                        title: Text(
                          term,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => searchFor(term),
                        trailing: IconButton(
                          tooltip: 'Rimuovi ricerca',
                          icon: const Icon(CupertinoIcons.xmark, size: 16),
                          onPressed: () => s.removeSearch(term),
                        ),
                      ),
                  ],
                ),
              ),
            if (showAccounts && users.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Account',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              SliverList.list(
                children: users
                    .map(
                      (u) => PersonTile(
                        u.str('id'),
                        onTap: () {
                          s.rememberSearch(query);
                          open(c, Profile(user: u.str('id')));
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            if (showPosts && term.isEmpty && posts.isNotEmpty)
              SliverToBoxAdapter(
                child: ListTile(
                  title: const Text(
                    'Popolari',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: TextButton(
                    onPressed: () => setState(() => showAll = !showAll),
                    child: Text(showAll ? 'Mostra meno' : 'Vedi tutto'),
                  ),
                ),
              ),
            if (showPosts && posts.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => InkWell(
                      onTap: () {
                        s.rememberSearch(query);
                        open(c, PostPage(id: visiblePosts[i].str('id')));
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (visiblePosts[i].str('kind') == 'reel')
                              ColoredBox(
                                color: subdued(c),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      visiblePosts[i].str(
                                        'text',
                                        s
                                            .user(visiblePosts[i].str('author'))
                                            .str('username'),
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(c).textTheme.labelMedium,
                                    ),
                                  ),
                                ),
                              )
                            else
                              MediaView(visiblePosts[i].str('media')),
                            if (visiblePosts[i].str('kind') == 'reel')
                              const Positioned(
                                bottom: 8,
                                right: 8,
                                child: GIcon(
                                  CupertinoIcons.play_rectangle_fill,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            if (s.media(visiblePosts[i]).length > 1)
                              const Positioned(
                                top: 9,
                                right: 9,
                                child: GIcon(
                                  CupertinoIcons.square_stack_fill,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    childCount: visiblePosts.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: featured ? 2 : 3,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: featured ? 1.3 : .78,
                  ),
                ),
              ),
            if (category == 'Tutti' && suggestedGroups.isNotEmpty)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const ListTile(
                      title: Text(
                        'Gruppi',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final group in suggestedGroups)
                      ListTile(
                        leading: Avatar(
                          group.str('owner'),
                          image: group.str('cover').isEmpty
                              ? null
                              : group.str('cover'),
                        ),
                        title: Text(group.str('title')),
                        subtitle: Text(
                          'Gruppo pubblico · ${group.number('members').toInt()} membri',
                        ),
                        trailing: const GIcon(
                          CupertinoIcons.chevron_right,
                          size: 15,
                        ),
                        onTap: () =>
                            open(c, CommunityGroup(id: group.str('id'))),
                      ),
                  ],
                ),
              ),
            if (category != 'Gruppi' &&
                (!showPosts || posts.isEmpty) &&
                (!showAccounts || users.isEmpty))
              const SliverToBoxAdapter(
                child: EmptyState(
                  CupertinoIcons.search,
                  'Nessun risultato',
                  'Prova un nome o una parola diversa.',
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 108)),
          ],
        ),
      ),
    );
  }
}

class PostPage extends StatelessWidget {
  final String id;
  const PostPage({super.key, required this.id});
  @override
  Widget build(BuildContext c) =>
      GpixScope.of(c).post(id).str('kind') == 'story'
      ? StoryViewer(user: GpixScope.of(c).post(id).str('author'), ids: [id])
      : GpixScope.of(c).post(id).str('kind') == 'reel'
      ? Reels(initial: id)
      : Scaffold(
          appBar: AppBar(title: pageTitle('Post')),
          body: ListView(children: [PostCard(id: id, detail: true)]),
        );
}

class Profile extends StatefulWidget {
  final String user;
  final bool root;
  const Profile({super.key, required this.user, this.root = false});
  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  int selected = 0;
  bool showSuggestions = false;
  final dismissedSuggestions = <String>{};
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        u = s.user(widget.user),
        own = widget.user == s.myId;
    final posts = s.allPosts
        .where(
          (p) =>
              !p.flag('archived') &&
              (selected == 3
                  ? p.str('kind') != 'story' &&
                        p
                            .str('text')
                            .toLowerCase()
                            .contains('@${u.str('username').toLowerCase()}')
                  : selected == 2
                  ? p.ids('reposts').contains(widget.user) &&
                        p.str('kind') != 'story'
                  : p.str('author') == widget.user &&
                        p.str('kind') == (selected == 0 ? 'post' : 'reel')),
        )
        .toList();
    final pinned = u.ids('pinnedPosts'),
        ordered = u.ids('gridOrder'),
        originalOrder = posts.map((p) => p.str('id')).toList();
    if (selected == 0)
      posts.sort((a, b) {
        int rank(J p) {
          final id = p.str('id');
          final pin = pinned.indexOf(id);
          if (pin >= 0) return pin;
          final order = ordered.indexOf(id);
          return 3 +
              (order >= 0
                  ? order
                  : ordered.length + originalOrder.indexOf(p.str('id')));
        }

        return rank(a).compareTo(rank(b));
      });
    final highlights = s.highlights(widget.user);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.root,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (u.flag('private')) ...[
              const GIcon(CupertinoIcons.lock, size: 15),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                u.str('username'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: own
            ? [
                IconButton(
                  tooltip: 'Crea',
                  onPressed: () => createMenu(c),
                  icon: const GIcon(CupertinoIcons.plus, size: 25),
                ),
                IconButton(
                  tooltip: 'Richieste di seguirti',
                  onPressed: () => open(c, const Requests()),
                  icon: const GIcon(CupertinoIcons.person_2, size: 25),
                ),
                IconButton(
                  tooltip: 'Menu profilo',
                  icon: const GIcon(CupertinoIcons.line_horizontal_3, size: 26),
                  onPressed: () => open(c, const Settings()),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Opzioni profilo',
                  icon: const GIcon(CupertinoIcons.ellipsis),
                  onPressed: () => sheet(
                    c,
                    Column(
                      children: [
                        ActionRow(
                          CupertinoIcons.star_fill,
                          s.state.ids('closeFriends').contains(widget.user)
                              ? 'Rimuovi dagli amici più stretti'
                              : 'Aggiungi agli amici più stretti',
                          () {
                            Navigator.pop(c);
                            perform(
                              c,
                              () => s.act('closeFriend', {
                                'user': widget.user,
                                'enabled': !s.state
                                    .ids('closeFriends')
                                    .contains(widget.user),
                              }),
                            );
                          },
                        ),
                        ActionRow(CupertinoIcons.flag, 'Segnala', () {
                          Navigator.pop(c);
                          report(c, widget.user);
                        }),
                        ActionRow(
                          CupertinoIcons.person_crop_circle_badge_xmark,
                          s.blocked(widget.user) ? 'Sblocca' : 'Blocca',
                          () async {
                            Navigator.pop(c);
                            if (await gpixAlert(
                                  c,
                                  'Bloccare ${u.str('username')}?',
                                  'Non vedrai più i contenuti e le conversazioni con questo account.',
                                  confirm: 'Blocca',
                                  destructive: true,
                                  cancel: true,
                                ) &&
                                c.mounted)
                              perform(
                                c,
                                () => s.act('block', {
                                  'user': widget.user,
                                  'enabled': !s.blocked(widget.user),
                                }),
                              );
                          },
                          destructive: true,
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),
              ],
      ),
      body: CustomScrollView(
        key: PageStorageKey('profile-${widget.user}'),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  key: const ValueKey('profile-identity'),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 94,
                            height:
                                own ||
                                    s.notes.any(
                                      (n) => n.str('owner') == widget.user,
                                    )
                                ? 142
                                : 92,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              clipBehavior: Clip.none,
                              children: [
                                InkWell(
                                  onTap: () => s.stories(widget.user).isNotEmpty
                                      ? open(c, StoryViewer(user: widget.user))
                                      : own
                                      ? open(c, const EditProfile())
                                      : null,
                                  child: Avatar(
                                    widget.user,
                                    size: 80,
                                    ring: s.hasUnseenStories(widget.user),
                                  ),
                                ),
                                if (own ||
                                    s.notes.any(
                                      (n) => n.str('owner') == widget.user,
                                    ))
                                  Positioned(
                                    key: const ValueKey('profile-note'),
                                    top: 0,
                                    left: -4,
                                    right: -4,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => own
                                          ? manageOwnNote(c)
                                          : replyNote(
                                              c,
                                              s.notes.firstWhere(
                                                (n) =>
                                                    n.str('owner') ==
                                                    widget.user,
                                              ),
                                            ),
                                      child: NoteBubble(
                                        text:
                                            s.notes
                                                .where(
                                                  (n) =>
                                                      n.str('owner') ==
                                                      widget.user,
                                                )
                                                .firstOrNull
                                                ?.str('text') ??
                                            'Lascia una nota…',
                                        placeholder: !s.notes.any(
                                          (n) => n.str('owner') == widget.user,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (own)
                                  Positioned(
                                    right: 0,
                                    bottom: -1,
                                    child: InkWell(
                                      onTap: () => open(
                                        c,
                                        const Composer(kind: 'story'),
                                      ),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: foreground(c),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: surface(c),
                                            width: 2.5,
                                          ),
                                        ),
                                        child: GIcon(
                                          CupertinoIcons.plus,
                                          color: surface(c),
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u.str('name'),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (u.str('pronouns').isNotEmpty)
                                  Text(
                                    u.str('pronouns'),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  key: const ValueKey('profile-stats'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    stat(
                                      u.str(
                                        'postCount',
                                        '${s.allPosts.where((p) => p.str('author') == widget.user && p.str('kind') != 'story' && !p.flag('archived')).length}',
                                      ),
                                      'post',
                                      null,
                                    ),
                                    stat(
                                      u.str('followers', '0'),
                                      'follower',
                                      () => open(
                                        c,
                                        Connections(
                                          user: widget.user,
                                          initial: 0,
                                        ),
                                      ),
                                    ),
                                    stat(
                                      u.str('following', '0'),
                                      'seguiti',
                                      () => open(
                                        c,
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
                        ],
                      ),
                      if (u.str('bio').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          u.str('bio').replaceAll(r'\n', '\n'),
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ProfileLinkChips(links: u.rows('links'), own: own),
                      const SizedBox(height: 16),
                      Row(
                        children: own
                            ? [
                                Expanded(
                                  child: smallButton(
                                    'Modifica profilo',
                                    () => open(c, const EditProfile()),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Builder(
                                    builder: (buttonContext) => smallButton(
                                      'Condividi profilo',
                                      () => perform(buttonContext, () async {
                                        final box =
                                            buttonContext.findRenderObject()
                                                as RenderBox;
                                        await SharePlus.instance.share(
                                          ShareParams(
                                            text:
                                                'Seguimi su GPIX: @${u.str('username')}',
                                            sharePositionOrigin:
                                                box.localToGlobal(Offset.zero) &
                                                box.size,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                SizedBox(
                                  width: 35,
                                  height: 35,
                                  child: IconButton(
                                    tooltip: 'Persone suggerite',
                                    style: IconButton.styleFrom(
                                      backgroundColor: subdued(c),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    onPressed: () => setState(
                                      () => showSuggestions = !showSuggestions,
                                    ),
                                    icon: const GIcon(
                                      CupertinoIcons.person_add,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ]
                            : [
                                Expanded(
                                  child: smallButton(
                                    s.follows(widget.user)
                                        ? s.state
                                                  .ids('closeFriends')
                                                  .contains(widget.user)
                                              ? 'Amici più stretti ⌄'
                                              : 'Segui già ⌄'
                                        : s.state
                                              .ids('pending')
                                              .contains(widget.user)
                                        ? 'Richiesta inviata'
                                        : 'Segui',
                                    () => s.follows(widget.user)
                                        ? relationshipMenu(c, widget.user)
                                        : perform(
                                            c,
                                            () => s.act('follow', {
                                              'user': widget.user,
                                              'enabled':
                                                  !s.follows(widget.user) &&
                                                  !s.state
                                                      .ids('pending')
                                                      .contains(widget.user),
                                            }),
                                          ),
                                    primary:
                                        !s.follows(widget.user) &&
                                        !s.state
                                            .ids('pending')
                                            .contains(widget.user),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: smallButton(
                                    'Messaggio',
                                    () => perform(c, () async {
                                      final id = await s.openThread(
                                        widget.user,
                                      );
                                      if (c.mounted) open(c, Chat(id: id));
                                    }),
                                  ),
                                ),
                              ],
                      ),
                      const SizedBox(height: 23),
                    ],
                  ),
                ),
                if (own || highlights.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      'In evidenza',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (own || highlights.isNotEmpty)
                  SizedBox(
                    height:
                        86 +
                        (MediaQuery.textScalerOf(c).scale(11) - 11).clamp(
                          0.0,
                          35.0,
                        ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 19),
                      scrollDirection: Axis.horizontal,
                      itemCount: highlights.length + (own ? 1 : 0),
                      separatorBuilder: (_, i) => const SizedBox(width: 7),
                      itemBuilder: (c, i) {
                        if (own && i == 0)
                          return InkWell(
                            onTap: () => createHighlight(c),
                            child: const SizedBox(
                              width: 65,
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 27,
                                    backgroundColor: Colors.transparent,
                                    child: GIcon(
                                      CupertinoIcons.plus_circle,
                                      size: 42,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text('Nuova', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        final h = highlights[i - (own ? 1 : 0)],
                            ids = h
                                .ids('posts')
                                .where((id) => s.post(id).isNotEmpty)
                                .toList();
                        return InkWell(
                          onTap: () => ids.isEmpty
                              ? null
                              : open(
                                  c,
                                  StoryViewer(user: widget.user, ids: ids),
                                ),
                          onLongPress: own
                              ? () => sheet(
                                  c,
                                  ActionRow(
                                    CupertinoIcons.trash,
                                    'Elimina raccolta',
                                    () {
                                      Navigator.pop(c);
                                      perform(
                                        c,
                                        () => s.act('deleteHighlight', {
                                          'id': h['id'],
                                        }),
                                      );
                                    },
                                    destructive: true,
                                  ),
                                )
                              : null,
                          child: SizedBox(
                            width: 65,
                            child: Column(
                              children: [
                                ClipOval(
                                  child: SizedBox.square(
                                    dimension: 54,
                                    child: MediaView(
                                      ids.isEmpty
                                          ? ''
                                          : s.post(ids.first).str('media'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  h.str('title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (own || highlights.isNotEmpty) const SizedBox(height: 24),
                if (own && showSuggestions) _suggestions(c),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => selected = i),
                          child: Container(
                            height: 47,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: selected == i
                                      ? auraBlue
                                      : Theme.of(c).dividerColor,
                                  width: selected == i ? 1.5 : .5,
                                ),
                              ),
                            ),
                            child: GIcon(
                              i == 0
                                  ? CupertinoIcons.square_grid_2x2
                                  : i == 1
                                  ? CupertinoIcons.play_rectangle
                                  : i == 2
                                  ? CupertinoIcons.repeat
                                  : CupertinoIcons.person_crop_square,
                              size: 23,
                              color: selected == i ? auraBlue : muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (s.blocked(widget.user))
            const SliverToBoxAdapter(
              child: EmptyState(
                CupertinoIcons.person_crop_circle_badge_xmark,
                'Account bloccato',
                'Puoi sbloccarlo dal menu del profilo.',
              ),
            )
          else if (u.flag('private') && !own && !s.follows(widget.user))
            const SliverToBoxAdapter(
              child: EmptyState(
                CupertinoIcons.lock,
                'Questo account è privato',
                'Segui questo account per vedere i suoi contenuti.',
              ),
            )
          else if (posts.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                CupertinoIcons.camera,
                selected == 0
                    ? 'I tuoi momenti, qui'
                    : selected == 1
                    ? 'Nessun reel'
                    : selected == 2
                    ? 'Nessuna ripubblicazione'
                    : 'Nessuna menzione',
                '${own ? 'Condividi qualcosa che ti rappresenta.' : 'I nuovi contenuti appariranno qui.'}',
                action: own
                    ? PrimaryButton(
                        'Crea',
                        onTap: () => open(
                          c,
                          Composer(kind: selected == 0 ? 'post' : 'reel'),
                        ),
                      )
                    : null,
              ),
            )
          else
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (c, i) => InkWell(
                  onTap: () => open(
                    c,
                    posts[i].str('kind') != 'reel'
                        ? PostPage(id: posts[i].str('id'))
                        : Reels(initial: posts[i].str('id')),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      posts[i].str('kind') != 'reel'
                          ? MediaView(posts[i].str('media'))
                          : const ColoredBox(
                              color: ink,
                              child: GIcon(
                                CupertinoIcons.play_fill,
                                color: Colors.white,
                              ),
                            ),
                      if (pinned.contains(posts[i].str('id')))
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            key: ValueKey('pinned-${posts[i].str('id')}'),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const GIcon(
                              CupertinoIcons.pin_fill,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                childCount: posts.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 3 / 4,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 115)),
        ],
      ),
    );
  }

  Widget _suggestions(BuildContext c) {
    final s = GpixScope.of(c);
    final users = s.users
        .where(
          (u) =>
              u.str('id') != s.myId &&
              !s.follows(u.str('id')) &&
              !s.blocked(u.str('id')) &&
              !dismissedSuggestions.contains(u.str('id')),
        )
        .take(12)
        .toList();
    if (users.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 10, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Persone suggerite',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              TextButton(
                onPressed: () => open(c, const Explore()),
                child: const Text(
                  'Mostra tutti',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: users.length,
            separatorBuilder: (_, i) => const SizedBox(width: 10),
            itemBuilder: (c, i) {
              final u = users[i],
                  id = u.str('id'),
                  pending = s.state.ids('pending').contains(u.str('id'));
              return Container(
                width: 148,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(c).dividerColor),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () => open(c, Profile(user: id)),
                          child: Avatar(id, size: 70),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          u.str('name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '@${u.str('username')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 31,
                          child: FilledButton(
                            onPressed: () => perform(
                              c,
                              () => s.act('follow', {
                                'user': id,
                                'enabled': !pending,
                              }),
                            ),
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              pending ? 'Richiesta inviata' : 'Segui',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: IconButton(
                        tooltip: 'Nascondi suggerimento',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            setState(() => dismissedSuggestions.add(id)),
                        icon: const GIcon(CupertinoIcons.xmark, size: 15),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget stat(String value, String label, VoidCallback? tap) => Expanded(
    child: InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget smallButton(String text, VoidCallback tap, {bool primary = false}) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: FilledButton(
          onPressed: tap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: primary ? auraBlue : subdued(context),
            foregroundColor: primary ? Colors.white : foreground(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );
}

Future<void> addStoryHighlight(BuildContext c, J story) async {
  final s = GpixScope.of(c, listen: false);
  final choice = await sheet<String>(
    c,
    Builder(
      builder: (menu) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Metti in evidenza',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          for (final h in s.highlights(s.myId))
            ActionRow(
              CupertinoIcons.star_circle,
              h.str('title'),
              () => Navigator.pop(menu, h.str('id')),
            ),
          ActionRow(
            CupertinoIcons.plus_circle,
            'Nuova raccolta',
            () => Navigator.pop(menu, 'new'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (!c.mounted || choice == null) return;
  if (choice == 'new') {
    final title = await textDialog(c, 'Nome della raccolta', '');
    if (title != null && title.trim().isNotEmpty && c.mounted)
      await perform(
        c,
        () => s.act('highlight', {
          'title': title.trim(),
          'posts': [story['id']],
        }),
      );
  } else {
    await perform(
      c,
      () => s.act('addHighlight', {'id': choice, 'post': story['id']}),
    );
  }
}

Future<void> createHighlight(BuildContext c) =>
    sheet(c, const _HighlightEditor());

class _HighlightEditor extends StatefulWidget {
  const _HighlightEditor();
  @override
  State<_HighlightEditor> createState() => _HighlightEditorState();
}

class _HighlightEditorState extends State<_HighlightEditor> {
  final selected = <String>{};
  final title = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), stories = s.stories(s.myId, archive: true);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Nuova storia in evidenza',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 17),
          AppInput(title, 'Nome della raccolta'),
          const SizedBox(height: 15),
          if (stories.isEmpty)
            const Text(
              'Pubblica una storia per aggiungerla qui.',
              style: TextStyle(color: muted),
            ),
          for (final p in stories)
            CheckboxListTile(
              title: Text(p.str('text', 'Storia'), maxLines: 2),
              secondary: SizedBox(
                width: 40,
                height: 48,
                child: MediaView(p.str('media')),
              ),
              value: selected.contains(p.str('id')),
              onChanged: (v) => setState(
                () => v == true
                    ? selected.add(p.str('id'))
                    : selected.remove(p.str('id')),
              ),
            ),
          const SizedBox(height: 16),
          PrimaryButton(
            'Crea raccolta',
            onTap: selected.isEmpty
                ? null
                : () => perform(c, () async {
                    if (title.text.trim().isEmpty)
                      throw Exception('Dai un nome alla raccolta.');
                    await s.act('highlight', {
                      'title': title.text.trim(),
                      'posts': selected.toList(),
                    });
                    if (c.mounted) Navigator.pop(c);
                  }),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

void profileMenu(BuildContext c) => sheet(
  c,
  Column(
    children: [
      ActionRow(CupertinoIcons.star_fill, 'Amici più stretti', () {
        Navigator.pop(c);
        open(c, const CloseFriends());
      }),
      ActionRow(CupertinoIcons.gear, 'Impostazioni e privacy', () {
        Navigator.pop(c);
        open(c, const Settings());
      }),
      ActionRow(CupertinoIcons.bookmark, 'Salvati', () {
        Navigator.pop(c);
        open(c, const CollectionPage(kind: 'saved'));
      }),
      ActionRow(CupertinoIcons.archivebox, 'Archivio', () {
        Navigator.pop(c);
        open(c, const CollectionPage(kind: 'archive'));
      }),
      ActionRow(CupertinoIcons.person_add, 'Richieste di seguirti', () {
        Navigator.pop(c);
        open(c, const Requests());
      }),
      const SizedBox(height: 18),
    ],
  ),
);

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String avatar = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (fields.isEmpty) {
      final u = GpixScope.of(context, listen: false).me;
      for (final k in [
        'name',
        'username',
        'pronouns',
        'bio',
        'website',
        'gender',
      ]) {
        fields[k] = TextEditingController(text: u.str(k));
      }
      avatar = u.str('avatarId', u.str('avatar'));
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Modifica profilo')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: busy
              ? null
              : () => perform(c, () async {
                  if (fields['name']!.text.trim().isEmpty ||
                      fields['username']!.text.trim().isEmpty)
                    throw Exception('Nome e nome utente sono obbligatori.');
                  final site = fields['website']!.text.trim();
                  if (site.isNotEmpty && !site.startsWith('https://'))
                    throw Exception('Il sito deve iniziare con https://');
                  setState(() => busy = true);
                  try {
                    await s.act('profile', {
                      for (final e in fields.entries)
                        e.key: e.value.text.trim(),
                      'avatar': avatar,
                      'private': s.me.flag('private'),
                    });
                    if (c.mounted) Navigator.pop(c);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }),
          child: Text(busy ? 'Salvo…' : 'Salva'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const SizedBox(height: 22),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: auraBlue),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Avatar(
                  s.myId,
                  size: 88,
                  image: avatar == s.me.str('avatarId')
                      ? s.me.str('avatar')
                      : avatar,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => perform(c, () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 800,
                imageQuality: 85,
              );
              if (file == null) return;
              final ref = await s.upload(
                file.path,
                'image/${file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg'}',
              );
              if (mounted) setState(() => avatar = ref);
            }),
            child: const Text('Cambia foto'),
          ),
          const SizedBox(height: 8),
          for (final field in const [
            (key: 'name', label: 'Nome', max: 60),
            (key: 'username', label: 'Nome utente', max: 30),
            (key: 'bio', label: 'Biografia', max: 150),
            (key: 'website', label: 'Sito web', max: 200),
            (key: 'pronouns', label: 'Pronomi', max: 40),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    key: ValueKey('edit-profile-${field.key}'),
                    controller: fields[field.key],
                    maxLength: field.max,
                    minLines: field.key == 'bio' ? 2 : 1,
                    maxLines: field.key == 'bio' ? 5 : 1,
                    keyboardType: field.key == 'website'
                        ? TextInputType.url
                        : null,
                    decoration: InputDecoration(
                      hintText: field.key == 'website' ? 'https://' : null,
                      counterText: '',
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.link),
            title: const Text('Link del profilo'),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => open(c, const ProfileLinks()),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.square_grid_2x2),
            title: const Text('Riordina griglia'),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => open(c, const GridOrder()),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.person),
            title: const Text('Genere'),
            subtitle: Text(
              fields['gender']!.text.isEmpty
                  ? 'Non specificato'
                  : fields['gender']!.text,
            ),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => sheet(
              c,
              Builder(
                builder: (menu) => Column(
                  children: [
                    for (final gender in [
                      'Uomo',
                      'Donna',
                      'Non binario',
                      'Preferisco non specificarlo',
                    ])
                      ListTile(
                        title: Text(gender),
                        trailing: fields['gender']!.text == gender
                            ? const GIcon(
                                CupertinoIcons.check_mark,
                                color: auraBlue,
                              )
                            : null,
                        onTap: () {
                          setState(() => fields['gender']!.text = gender);
                          Navigator.pop(menu);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              'Il genere non viene mostrato nel profilo pubblico.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  final String kind;
  const CollectionPage({super.key, required this.kind});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final posts = s.allPosts
        .where(
          (p) => kind == 'saved'
              ? p.flag('saved')
              : p.str('author') == s.myId &&
                    (p.flag('archived') || p.str('kind') == 'story'),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: pageTitle(kind == 'saved' ? 'Salvati' : 'Archivio'),
      ),
      body: posts.isEmpty
          ? EmptyState(
              kind == 'saved'
                  ? CupertinoIcons.bookmark
                  : CupertinoIcons.archivebox,
              kind == 'saved' ? 'Tieni i tuoi preferiti' : 'Il tuo archivio',
              'I contenuti appariranno qui.',
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: .75,
              ),
              itemCount: posts.length,
              itemBuilder: (c, i) {
                final p = posts[i];
                return InkWell(
                  onTap: () => p.str('kind') == 'story'
                      ? open(c, StoryViewer(user: s.myId, ids: [p.str('id')]))
                      : open(c, PostPage(id: p.str('id'))),
                  onLongPress: () => postMenu(c, p),
                  child: MediaView(p.str('media')),
                );
              },
            ),
    );
  }
}

class Activity extends StatefulWidget {
  const Activity({super.key});
  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  bool unreadOnly = false;
  String activityFilter = 'Tutte';
  final deciding = <String>{};

  Future<void> decide(GpixStore store, String id, bool accept) async {
    if (!deciding.add(id)) return;
    setState(() {});
    await perform(
      context,
      () => store.act('accept', {'user': id, 'enabled': accept}),
    );
    if (mounted) setState(() => deciding.remove(id));
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final notifications = s.socialNotifications
      ..sort((a, b) => b.number('created').compareTo(a.number('created')));
    final unread = notifications.any((n) => !n.flag('seen'));
    final visible = notifications.where(
      (n) =>
          (!unreadOnly || !n.flag('seen')) &&
          (activityFilter == 'Tutte' ||
              (activityFilter == 'Mi piace' &&
                  ['like', 'storyLike', 'noteLike'].contains(n.str('type'))) ||
              (activityFilter == 'Commenti' && n.str('type') == 'comment') ||
              (activityFilter == 'Follower' &&
                  [
                    'follow',
                    'followRequest',
                    'followAccepted',
                  ].contains(n.str('type')))),
    );
    final requests = s.state.ids('requests');
    final date = DateTime.now();
    double midnight(int offset) =>
        DateTime(
          date.year,
          date.month,
          date.day - offset,
        ).millisecondsSinceEpoch /
        1000;
    String section(J notification) {
      if (notification.flag('highlighted') ||
          notification.str('type') == 'system') {
        return 'In evidenza';
      }
      final created = notification.number('created');
      if (created >= midnight(0)) return 'Oggi';
      if (created >= midnight(1)) return 'Ieri';
      if (created >= midnight(6)) return 'Ultimi 7 giorni';
      return 'Precedenti';
    }

    Widget dot(Color color) => CircleAvatar(radius: 4, backgroundColor: color);
    final surface = Theme.of(c).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Attività',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Opzioni attività',
            icon: const GIcon(CupertinoIcons.ellipsis),
            onSelected: (value) {
              if (value == 'read') {
                perform(c, () => s.act('notificationsRead'));
              } else {
                setState(() => unreadOnly = !unreadOnly);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'filter',
                child: Text(unreadOnly ? 'Tutte le attività' : 'Da leggere'),
              ),
              PopupMenuItem(
                value: 'read',
                enabled: unread,
                child: const Text('Segna tutto come letto'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => s.sync(silent: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'Le persone, le interazioni, le tue novità.',
                style: TextStyle(color: secondaryText(c)),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in [
                    'Tutte',
                    'Mi piace',
                    'Commenti',
                    'Follower',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value),
                        selected: activityFilter == value,
                        onSelected: (_) =>
                            setState(() => activityFilter = value),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(c).dividerColor),
              ),
              padding: const EdgeInsets.all(14),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SizedBox.square(
                  dimension: 54,
                  child: requests.isEmpty
                      ? CircleAvatar(
                          backgroundColor: subdued(c),
                          child: const GIcon(CupertinoIcons.person_add),
                        )
                      : Stack(
                          children: [
                            Avatar(
                              requests.first,
                              size: requests.length > 1 ? 40 : 54,
                            ),
                            if (requests.length > 1)
                              Align(
                                alignment: Alignment.bottomRight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: surface,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Avatar(requests[1], size: 40),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
                title: const Text(
                  'Richieste di seguirti',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  requests.isEmpty
                      ? 'Nessuna richiesta in attesa'
                      : "${s.user(requests.first).str('username')}${requests.length > 1 ? ' + altri ${requests.length - 1}' : ''}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (requests.isNotEmpty) ...[
                      dot(auraBlue),
                      const SizedBox(width: 10),
                    ],
                    const GIcon(CupertinoIcons.chevron_right, size: 18),
                  ],
                ),
                onTap: () => open(c, const Requests()),
              ),
            ),
            if (visible.isEmpty)
              EmptyState(
                CupertinoIcons.heart,
                unreadOnly ? 'Tutto letto' : 'Nessuna nuova attività',
                'Qui trovi like, commenti e nuovi follower.',
              ),
            for (final name in [
              'In evidenza',
              'Oggi',
              'Ieri',
              'Ultimi 7 giorni',
              'Precedenti',
            ])
              if (visible.any((n) => section(n) == name)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 6),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (final n in visible.where((n) => section(n) == name))
                  Builder(
                    builder: (c) {
                      final actor = n.str('actor');
                      final pending =
                          n.str('type') == 'followRequest' &&
                          requests.contains(actor);
                      final label = n.str('message').isNotEmpty
                          ? n.str('message')
                          : switch (n.str('type')) {
                              'comment' => 'ha commentato il tuo post.',
                              'like' =>
                                s.post(n.str('ref')).str('kind') == 'story'
                                    ? 'ha messo Mi piace alla tua storia.'
                                    : 'ha messo Mi piace al tuo post.',
                              'storyLike' =>
                                'ha messo Mi piace alla tua storia.',
                              'follow' => 'ha iniziato a seguirti.',
                              'followRequest' => 'ha chiesto di seguirti.',
                              'followAccepted' =>
                                'ha accettato la tua richiesta.',
                              'repost' => 'ha ripubblicato il tuo post.',
                              'message' => 'ti ha inviato un messaggio.',
                              'messageReaction' =>
                                'ha reagito a un tuo messaggio.',
                              'noteLike' => 'ha messo Mi piace alla tua nota.',
                              'call' => 'ti ha chiamato.',
                              _ => 'ha interagito con te.',
                            };
                      final actions = Wrap(
                        spacing: 5,
                        children: [
                          for (final accept in [true, false])
                            FilledButton(
                              onPressed: deciding.contains(actor)
                                  ? null
                                  : () => decide(s, actor, accept),
                              style: FilledButton.styleFrom(
                                backgroundColor: accept ? auraBlue : subdued(c),
                                foregroundColor: accept
                                    ? Colors.white
                                    : foreground(c),
                                minimumSize: const Size(44, 44),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                              child: Text(
                                accept ? 'Conferma' : 'Elimina',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      );
                      return LayoutBuilder(
                        builder: (c, constraints) {
                          final inline =
                              constraints.maxWidth >= 355 &&
                              MediaQuery.textScalerOf(c).scale(12) < 15;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: !n.flag('seen')
                                  ? auraBlue.withValues(alpha: .055)
                                  : subdued(c).withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 10,
                              horizontalTitleGap: 12,
                              leading: actor.isEmpty
                                  ? CircleAvatar(
                                      radius: 26,
                                      backgroundColor: subdued(c),
                                      child: const GIcon(CupertinoIcons.bell),
                                    )
                                  : Avatar(actor, size: 52),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        if (actor.isNotEmpty)
                                          TextSpan(
                                            text:
                                                "${s.user(actor).str('username')} ",
                                            style: TextStyle(
                                              color: foreground(c),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        TextSpan(
                                          text: label,
                                          style: TextStyle(
                                            color: foreground(c),
                                          ),
                                        ),
                                        TextSpan(
                                          text: '  ${relative(n['created'])}',
                                          style: const TextStyle(color: muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (pending && !inline) actions,
                                ],
                              ),
                              trailing: pending && inline
                                  ? actions
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (s.post(n.str('ref')).isNotEmpty &&
                                            s
                                                .media(s.post(n.str('ref')))
                                                .isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                              child: MediaView(
                                                s
                                                    .media(s.post(n.str('ref')))
                                                    .first,
                                                width: 42,
                                                height: 52,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                        if (!pending && !n.flag('seen'))
                                          dot(auraBlue),
                                      ],
                                    ),
                              onTap: () => perform(c, () async {
                                await s.act('notificationsRead', {
                                  'id': n['id'],
                                });
                                if (!c.mounted) return;
                                if (n.str('type') == 'followRequest') {
                                  open(c, const Requests());
                                } else if (n.str('type') == 'messageReaction') {
                                  final thread = s.threads
                                      .where(
                                        (t) => t
                                            .rows('messages')
                                            .any(
                                              (m) =>
                                                  m.str('id') == n.str('ref'),
                                            ),
                                      )
                                      .firstOrNull;
                                  if (thread != null) {
                                    open(c, Chat(id: thread.str('id')));
                                  } else {
                                    notice(
                                      c,
                                      'Il messaggio non è più disponibile',
                                    );
                                  }
                                } else if (n.str('type') == 'noteLike') {
                                  manageOwnNote(c);
                                } else if (n.str('type') == 'storyLike' ||
                                    (n.str('type') == 'like' &&
                                        s.post(n.str('ref')).str('kind') ==
                                            'story')) {
                                  final story = s.post(n.str('ref'));
                                  if (story.isNotEmpty &&
                                      story.number('expires') > now) {
                                    open(
                                      c,
                                      StoryViewer(
                                        user: story.str('author'),
                                        ids: [story.str('id')],
                                      ),
                                    );
                                  } else {
                                    notice(
                                      c,
                                      'Questa storia non è più disponibile',
                                    );
                                  }
                                } else if (s.post(n.str('ref')).isNotEmpty) {
                                  open(c, PostPage(id: n.str('ref')));
                                } else if (actor.isNotEmpty) {
                                  open(c, Profile(user: actor));
                                }
                              }),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class Requests extends StatefulWidget {
  const Requests({super.key});
  @override
  State<Requests> createState() => _RequestsState();
}

class _RequestsState extends State<Requests> {
  String query = '';
  bool editing = false, busy = false;
  final selected = <String>{}, accepted = <String>{};
  final order = <String>[];
  Future<void> decide(List<String> ids, bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      for (final id in ids) {
        if (s.state.ids('requests').contains(id)) {
          await s.act('accept', {'user': id, 'enabled': accept});
          if (accept && mounted) setState(() => accepted.add(id));
        }
      }
      if (mounted) setState(() => selected.removeAll(ids));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    for (final id in s.state.ids('requests')) {
      if (!order.contains(id)) order.add(id);
    }
    final width = MediaQuery.sizeOf(c).width, compact = width < 360;
    final requests = order
        .where(
          (id) => s.state.ids('requests').contains(id) || accepted.contains(id),
        )
        .where(
          (id) => '${s.user(id).str('name')} ${s.user(id).str('username')}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
        )
        .toList();
    selected.removeWhere((id) => !s.state.ids('requests').contains(id));
    Widget button(String text, bool accept, VoidCallback? action) =>
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size(
              accept ? (compact ? 70 : 84) : (compact ? 60 : 70),
              36,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: accept ? const Color(0xff4f57ff) : subdued(c),
            foregroundColor: accept ? Colors.white : foreground(c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          onPressed: action,
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.outlined(
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              side: BorderSide(
                color: Theme.of(c).dividerColor.withValues(alpha: .35),
              ),
            ),
            tooltip: 'Indietro',
            onPressed: () => Navigator.maybePop(c),
            icon: const GIcon(CupertinoIcons.chevron_left, size: 24),
          ),
        ),
        title: Text(
          'Richieste di seguirti',
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(78, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: const Color(0xff4f57ff),
                side: BorderSide(
                  color: Theme.of(c).dividerColor.withValues(alpha: .35),
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: busy
                  ? null
                  : () => setState(() {
                      editing = !editing;
                      selected.clear();
                    }),
              child: Text(
                editing ? 'Fine' : 'Gestisci',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca nome utente o nome visualizzato',
                hintStyle: TextStyle(fontSize: compact ? 12 : 14, color: muted),
                prefixIcon: const GIcon(
                  CupertinoIcons.search,
                  color: muted,
                  size: 20,
                ),
                filled: true,
                fillColor: subdued(c),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: foreground(c)),
              ),
              child: const Stack(
                children: [
                  Center(child: GIcon(CupertinoIcons.search, size: 29)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GIcon(CupertinoIcons.sparkles, size: 12),
                  ),
                ],
              ),
            ),
            title: const Text(
              'Scopri altri profili',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Vedi suggerimenti non personalizzati',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: const GIcon(
              CupertinoIcons.chevron_right,
              color: muted,
              size: 19,
            ),
            onTap: () => open(
              c,
              Scaffold(
                appBar: AppBar(title: pageTitle('Scopri altri profili')),
                body: ListView(
                  children: [
                    for (final u
                        in (s.users
                            .where(
                              (u) =>
                                  u.str('id') != s.myId &&
                                  !s.blocked(u.str('id')) &&
                                  !s.follows(u.str('id')),
                            )
                            .toList()
                          ..sort(
                            (a, b) =>
                                a.str('username').compareTo(b.str('username')),
                          )))
                      PersonTile(
                        u.str('id'),
                        onTap: () => open(c, Profile(user: u.str('id'))),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: EmptyState(
                      CupertinoIcons.person_add,
                      query.isEmpty ? 'Nessuna richiesta' : 'Nessun risultato',
                      query.isEmpty
                          ? 'Le nuove richieste appariranno qui.'
                          : 'Prova un altro nome.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: requests.length,
                    itemBuilder: (c, i) {
                      final id = requests[i],
                          u = s.user(id),
                          detail = s.state.obj('requestDetails').obj(id);
                      final common = detail.containsKey('mutualUsers')
                              ? detail.ids('mutualUsers')
                              : u
                                    .ids('followersList')
                                    .where(s.state.ids('following').contains)
                                    .take(3)
                                    .toList(),
                          count = detail
                              .number(
                                'mutualCount',
                                u
                                    .ids('followersList')
                                    .where(s.state.ids('following').contains)
                                    .length
                                    .toDouble(),
                              )
                              .toInt();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => editing
                                  ? setState(
                                      () => selected.contains(id)
                                          ? selected.remove(id)
                                          : selected.add(id),
                                    )
                                  : open(c, Profile(user: id)),
                              child: Stack(
                                children: [
                                  Avatar(id, size: compact ? 48 : 54),
                                  if (editing)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Icon(
                                        selected.contains(id)
                                            ? CupertinoIcons
                                                  .checkmark_circle_fill
                                            : CupertinoIcons.circle_fill,
                                        color: selected.contains(id)
                                            ? auraBlue
                                            : muted,
                                        size: 21,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => editing
                                    ? setState(
                                        () => selected.contains(id)
                                            ? selected.remove(id)
                                            : selected.add(id),
                                      )
                                    : open(c, Profile(user: id)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.str('name', u.str('username')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (common.isNotEmpty) ...[
                                          SizedBox(
                                            width:
                                                common.take(3).length * 12 + 8,
                                            height: 20,
                                            child: Stack(
                                              children: [
                                                for (
                                                  var j = 0;
                                                  j < common.take(3).length;
                                                  j++
                                                )
                                                  Positioned(
                                                    left: j * 12.0,
                                                    child: Avatar(
                                                      common[j],
                                                      size: 20,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            count > 0
                                                ? '$count in comune'
                                                : accepted.contains(id)
                                                ? 'Richiesta accettata'
                                                : 'Vuole seguirti',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (accepted.contains(id))
                              button(
                                s.follows(id)
                                    ? 'Segui già'
                                    : s.state.ids('pending').contains(id)
                                    ? 'Richiesta inviata'
                                    : 'Segui anche tu',
                                true,
                                busy || s.follows(id)
                                    ? null
                                    : () => perform(
                                        c,
                                        () => s.act('follow', {
                                          'user': id,
                                          'enabled': !s.state
                                              .ids('pending')
                                              .contains(id),
                                        }),
                                      ),
                              )
                            else if (!editing) ...[
                              button(
                                'Conferma',
                                true,
                                busy ? null : () => decide([id], true),
                              ),
                              const SizedBox(width: 5),
                              Tooltip(
                                message: 'Rifiuta richiesta',
                                child: button(
                                  'Elimina',
                                  false,
                                  busy ? null : () => decide([id], false),
                                ),
                              ),
                            ] else
                              IconButton(
                                tooltip: selected.contains(id)
                                    ? 'Deseleziona'
                                    : 'Seleziona',
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => selected.contains(id)
                                            ? selected.remove(id)
                                            : selected.add(id),
                                      ),
                                icon: Icon(
                                  selected.contains(id)
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  color: auraBlue,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${selected.length} selezionate',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: button(
                            'Elimina',
                            false,
                            busy || selected.isEmpty
                                ? null
                                : () => decide(selected.toList(), false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: button(
                            busy ? 'Attendi…' : 'Conferma',
                            true,
                            busy || selected.isEmpty
                                ? null
                                : () => decide(selected.toList(), true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class Settings extends StatefulWidget {
  final String? _area;
  const Settings({super.key}) : _area = null;
  const Settings._category(this._area);
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    Widget row(
      IconData icon,
      String title,
      VoidCallback tap, {
      String? value,
      String? subtitle,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
      minLeadingWidth: 30,
      leading: GIcon(icon, size: 25, color: foreground(c)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.35),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(value, style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(width: 8),
          ],
          const GIcon(CupertinoIcons.chevron_right, size: 17, color: muted),
        ],
      ),
      onTap: tap,
    );
    void controls(String title, List<Widget> children) =>
        open(c, _SettingsDetail(title: title, children: children));
    final privacy = row(
      CupertinoIcons.lock,
      "Privacy dell'account",
      () => open(c, const _AccountPrivacy()),
      value: s.me.flag('private') ? 'Privato' : 'Pubblico',
    );
    final blocked = row(
      CupertinoIcons.person_crop_circle_badge_xmark,
      'Utenti bloccati',
      () => open(c, const _BlockedAccounts()),
      value: '${s.state.ids('blocks').length}',
    );
    final groups = <(String, String, IconData, List<(String, Widget)>)>[
      (
        'Account',
        'Dati, accesso e sicurezza',
        CupertinoIcons.person_crop_circle,
        [
          (
            'Dispositivi collegati',
            row(
              CupertinoIcons.device_phone_portrait,
              'Dispositivi collegati',
              () => open(c, const DeviceSessions()),
            ),
          ),
          (
            'Modifica profilo',
            row(
              CupertinoIcons.person_crop_circle,
              'Modifica profilo',
              () => open(c, const EditProfile()),
            ),
          ),
          (
            'Password e sicurezza',
            row(
              CupertinoIcons.lock_shield,
              'Password e sicurezza',
              () => open(c, const AccountSecurity()),
            ),
          ),
          (
            'Verifica email',
            row(
              CupertinoIcons.envelope_badge,
              'Verifica email',
              () => open(c, const AccountSecurity(mode: 'verify')),
            ),
          ),
        ],
      ),
      (
        'Privacy',
        'Visibilità e interazioni',
        CupertinoIcons.shield,
        [
          ("Privacy dell'account", privacy),
          (
            'Amici più stretti',
            row(
              CupertinoIcons.star_circle,
              'Amici più stretti',
              () => open(c, const CloseFriends()),
              value: '${s.state.ids('closeFriends').length}',
            ),
          ),
          ('Utenti bloccati', blocked),
          (
            'Storie nascoste silenziati restrizioni messaggi tag menzioni',
            row(
              CupertinoIcons.shield,
              'Gestisci le interazioni',
              () => open(c, const PrivacyTools()),
              subtitle: 'Storie, messaggi, menzioni e account silenziati.',
            ),
          ),
          (
            'Messaggi e risposte alle storie attività conferme lettura anteprime protezione',
            row(
              CupertinoIcons.check_mark_circled,
              'Messaggi e risposte alle storie',
              () => open(c, const _MessagePrivacy()),
            ),
          ),
          (
            'Richieste di seguirti',
            row(
              CupertinoIcons.person_add,
              'Richieste di seguirti',
              () => open(c, const Requests()),
              value: '${s.state.ids('requests').length}',
            ),
          ),
        ],
      ),
      (
        'Notifiche',
        'Avvisi e attività',
        CupertinoIcons.bell,
        [
          (
            'Notifiche push',
            row(
              CupertinoIcons.bell,
              'Notifiche push',
              () => open(c, const PushSettings()),
            ),
          ),
          (
            'Attività ricevuta',
            row(
              CupertinoIcons.heart,
              'Attività ricevuta',
              () => open(c, const Activity()),
            ),
          ),
        ],
      ),
      (
        'I tuoi contenuti',
        'Bozze, salvati e archivio',
        CupertinoIcons.photo_on_rectangle,
        [
          (
            'Bozze',
            row(
              CupertinoIcons.doc_text,
              'Bozze',
              () => open(c, const DraftList()),
            ),
          ),
          (
            'Salvati',
            row(
              CupertinoIcons.bookmark,
              'Salvati',
              () => open(c, const CollectionPage(kind: 'saved')),
            ),
          ),
          (
            'Archivio',
            row(
              CupertinoIcons.archivebox,
              'Archivio',
              () => open(c, const CollectionPage(kind: 'archive')),
            ),
          ),
          (
            'Note',
            row(CupertinoIcons.text_bubble, 'Note', () => manageOwnNote(c)),
          ),
        ],
      ),
      (
        'Aspetto',
        'Tema e visualizzazione',
        CupertinoIcons.moon,
        [
          (
            'Istantanee bolla nascondi',
            row(
              CupertinoIcons.photo_on_rectangle,
              'Bolla delle istantanee',
              () => open(c, const InstantBubbleSetting()),
            ),
          ),
          (
            'Aspetto chiaro scuro tema',
            row(
              CupertinoIcons.moon,
              'Aspetto',
              () => open(c, const AppearancePage()),
              value: s.appearance == 'dark'
                  ? 'Scuro'
                  : s.appearance == 'light'
                  ? 'Chiaro'
                  : 'Dispositivo',
            ),
          ),
        ],
      ),
      (
        'Assistenza',
        'Aiuto e contatti',
        CupertinoIcons.question_circle,
        [
          (
            'Trova persone',
            row(
              CupertinoIcons.search,
              'Trova persone',
              () => open(c, const Explore()),
            ),
          ),
          (
            'Invita amici',
            row(
              CupertinoIcons.share,
              'Invita amici',
              () => SharePlus.instance.share(
                ShareParams(text: 'Seguimi su GPIX: @${s.me.str('username')}'),
              ),
            ),
          ),
          (
            'Aiuto',
            row(
              CupertinoIcons.question_circle,
              'Aiuto',
              () => controls('Aiuto', const [
                ListTile(
                  leading: GIcon(CupertinoIcons.person_crop_circle),
                  title: Text('Modificare il profilo'),
                  subtitle: Text(
                    'Apri Profilo → Modifica profilo e premi Fine per salvare.',
                  ),
                ),
                ListTile(
                  leading: GIcon(CupertinoIcons.doc_text),
                  title: Text('Salvare una bozza'),
                  subtitle: Text(
                    'Durante la creazione di un post o reel tocca Salva bozza. Ritrovi il contenuto in Crea → Bozze.',
                  ),
                ),
                ListTile(
                  leading: GIcon(CupertinoIcons.text_bubble),
                  title: Text('Pubblicare una nota'),
                  subtitle: Text(
                    'Nei Messaggi tocca La tua nota. Massimo 60 caratteri.',
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    ];
    final access = row(
      CupertinoIcons.square_arrow_left,
      'Gestisci accesso e account',
      () => open(c, const _AccountSettings()),
    );
    final area = widget._area;
    if (area != null) {
      final group = groups.firstWhere((group) => group.$1 == area);
      return Scaffold(
        appBar: AppBar(title: pageTitle(area)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GIcon(group.$3, size: 30, color: accent(c)),
                  const SizedBox(height: 14),
                  Text(
                    group.$2,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            for (final entry in group.$4)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: subdued(c),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: entry.$2,
              ),
            if (area == 'Account') access,
          ],
        ),
      );
    }
    final filter = query.trim().toLowerCase();
    final results = [
      for (final group in groups)
        for (final entry in group.$4)
          if ('${group.$1} ${entry.$1}'.toLowerCase().contains(filter))
            entry.$2,
      if ('gestisci accesso esci elimina account'.contains(filter)) access,
    ];
    return Scaffold(
      appBar: AppBar(
        title: pageTitle('Impostazioni e attività'),
        centerTitle: true,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: TextField(
              key: const ValueKey('settings-search'),
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca un’impostazione',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(13),
                  child: GIcon(CupertinoIcons.search, size: 21, color: muted),
                ),
                filled: true,
                fillColor: subdued(c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (filter.isEmpty) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(24),
              ),
              child: InkWell(
                onTap: () => open(c, const EditProfile()),
                child: Row(
                  children: [
                    Avatar(s.myId, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.me.str('name'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@${s.me.str('username')}',
                            style: TextStyle(
                              color: secondaryText(c),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const GIcon(CupertinoIcons.chevron_right, size: 17),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Text(
                'Il tuo spazio, le tue regole',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final group in groups)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: surface(c),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(c).dividerColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: subdued(c),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: GIcon(group.$3, size: 22),
                  ),
                  title: Text(
                    group.$1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    group.$2,
                    style: TextStyle(fontSize: 12, color: secondaryText(c)),
                  ),
                  trailing: const GIcon(CupertinoIcons.chevron_right, size: 15),
                  onTap: () => open(c, Settings._category(group.$1)),
                ),
              ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  row(
                    CupertinoIcons.bell,
                    'La tua attività',
                    () => open(c, const Activity()),
                  ),
                  row(
                    CupertinoIcons.bookmark,
                    'Elementi salvati',
                    () => open(c, const CollectionPage(kind: 'saved')),
                  ),
                  row(
                    CupertinoIcons.calendar,
                    'Eventi e momenti',
                    () => open(
                      c,
                      const Scaffold(
                        body: SafeArea(child: CommunityDirectory()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              decoration: BoxDecoration(
                color: danger.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                leading: const GIcon(
                  CupertinoIcons.square_arrow_left,
                  color: danger,
                ),
                title: const Text(
                  'Esci',
                  style: TextStyle(color: danger, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '@${s.me.str('username')}',
                  style: TextStyle(fontSize: 12, color: secondaryText(c)),
                ),
                onTap: () => _logout(c, s),
              ),
            ),
          ] else if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nessuna impostazione trovata'),
            )
          else
            ...results,
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _SettingsDetail extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsDetail({required this.title, required this.children});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: pageTitle(title), centerTitle: true),
    body: ListView(children: children),
  );
}

class _AccountPrivacy extends StatelessWidget {
  const _AccountPrivacy();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle("Privacy dell'account")),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: const GIcon(CupertinoIcons.lock),
            title: const Text('Account privato'),
            subtitle: const Text(
              'Solo i follower approvati possono vedere i tuoi contenuti.',
            ),
            value: s.me.flag('private'),
            onChanged: (v) =>
                perform(c, () => s.act('profile', {'private': v})),
          ),
        ],
      ),
    );
  }
}

class _MessagePrivacy extends StatelessWidget {
  const _MessagePrivacy();
  @override
  Widget build(BuildContext c) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Text(
        text,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
    );
    Widget link(IconData icon, String title, Widget page) => ListTile(
      leading: GIcon(icon),
      title: Text(title),
      trailing: const GIcon(CupertinoIcons.chevron_right, size: 18),
      onTap: () => open(c, page),
    );
    return Scaffold(
      appBar: AppBar(title: pageTitle('Messaggi e risposte alle storie')),
      body: ListView(
        children: [
          heading('In che modo le persone possono contattarti'),
          link(
            CupertinoIcons.paperplane,
            'Richieste di messaggi',
            const MessageAudienceSetting(),
          ),
          link(
            CupertinoIcons.chat_bubble,
            'Risposte alle storie',
            const MessageAudienceSetting(story: true),
          ),
          const Divider(thickness: 7, height: 30),
          heading('Chi può vedere che sei online'),
          link(
            CupertinoIcons.circle,
            'Mostra stato di attività',
            const MessageToggleSetting(setting: 'activityStatus'),
          ),
          link(
            CupertinoIcons.check_mark_circled,
            'Mostra conferme di lettura',
            const MessageToggleSetting(setting: 'readReceipts'),
          ),
          const Divider(thickness: 7, height: 30),
          heading('Cosa vedi nei messaggi'),
          link(
            CupertinoIcons.eye_slash,
            'Protezione delle immagini',
            const MessageToggleSetting(setting: 'imageProtection'),
          ),
          link(
            CupertinoIcons.text_bubble,
            'Anteprime',
            const MessageToggleSetting(setting: 'messagePreviews'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class MessageAudienceSetting extends StatelessWidget {
  final bool story;
  const MessageAudienceSetting({super.key, this.story = false});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        key = story ? 'storyReplies' : 'allowMessages',
        value = s.preferences.str(key, 'all');
    return Scaffold(
      appBar: AppBar(
        title: pageTitle(
          story ? 'Risposte alle storie' : 'Richieste di messaggi',
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              story
                  ? 'Scegli chi può rispondere alle tue storie.'
                  : 'Scegli chi può inviarti messaggi e richieste. Gli account che segui compaiono nella tua posta; le altre persone nelle richieste.',
            ),
          ),
          RadioGroup<String>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) perform(c, () => s.setPreference(key, v));
            },
            child: Column(
              children: [
                for (final entry in {
                  'all': 'Tutti',
                  'following': 'Persone che segui',
                  'none': story ? 'Nessuno' : 'Non ricevere messaggi',
                }.entries)
                  RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                  ),
              ],
            ),
          ),
          if (!story)
            ListTile(
              leading: const GIcon(CupertinoIcons.tray),
              title: const Text('Apri richieste ricevute'),
              trailing: const GIcon(CupertinoIcons.chevron_right),
              onTap: () => open(c, const MessageRequests()),
            ),
        ],
      ),
    );
  }
}

class MessageToggleSetting extends StatelessWidget {
  final String setting;
  const MessageToggleSetting({super.key, required this.setting});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final info = <String, (String, String, IconData, bool)>{
      'activityStatus': (
        'Mostra stato di attività',
        'Le persone che segui e con cui hai una conversazione possono vedere quando sei attivo. Se lo disattivi, non vedrai il loro stato.',
        CupertinoIcons.circle,
        true,
      ),
      'readReceipts': (
        'Mostra conferme di lettura',
        'Mostra quando leggi i messaggi e visualizza le conferme degli altri.',
        CupertinoIcons.check_mark_circled,
        true,
      ),
      'imageProtection': (
        'Protezione delle immagini',
        'Sfoca tutte le foto e GIF ricevute nelle chat finché non scegli di mostrarle. La protezione è preventiva: non analizza né identifica automaticamente immagini di nudo.',
        CupertinoIcons.eye_slash,
        false,
      ),
      'messagePreviews': (
        'Anteprime',
        'Mostra il testo dell’ultimo messaggio nell’elenco delle conversazioni. Questa scelta non modifica le anteprime delle notifiche di sistema.',
        CupertinoIcons.text_bubble,
        true,
      ),
    }[setting]!;
    final value = setting == 'readReceipts'
        ? s.readReceipts
        : s.preferences[setting] as bool? ?? info.$4;
    return Scaffold(
      appBar: AppBar(title: pageTitle(info.$1)),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: GIcon(info.$3),
            title: Text(info.$1),
            subtitle: Text(info.$2),
            value: value,
            onChanged: (v) => perform(
              c,
              () => setting == 'readReceipts'
                  ? s.act('profile', {'readReceipts': v})
                  : s.setPreference(setting, v),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedAccounts extends StatelessWidget {
  const _BlockedAccounts();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), ids = s.state.ids('blocks');
    return Scaffold(
      appBar: AppBar(title: pageTitle('Utenti bloccati')),
      body: ids.isEmpty
          ? const Center(child: Text('Nessun account bloccato.'))
          : ListView(
              children: [
                for (final id in ids)
                  PersonTile(
                    id,
                    trailing: TextButton(
                      onPressed: () => perform(
                        c,
                        () => s.act('block', {'user': id, 'enabled': false}),
                      ),
                      child: const Text('Sblocca'),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> _logout(BuildContext c, GpixStore store) async {
  if (await gpixAlert(
        c,
        'Uscire da GPIX?',
        'Puoi accedere di nuovo in qualsiasi momento.',
        confirm: 'Esci',
        cancel: true,
      ) &&
      c.mounted) {
    await store.logout();
    if (c.mounted) Navigator.popUntil(c, (route) => route.isFirst);
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Centro gestione account')),
      body: ListView(
        children: [
          PersonTile(s.myId),
          const Divider(),
          if (s.demo)
            ActionRow(
              CupertinoIcons.arrow_counterclockwise,
              'Reimposta demo',
              () async {
                if (await gpixAlert(
                      c,
                      'Reimpostare la demo?',
                      'Elimina tutte le modifiche locali e ripristina i dati di prova.',
                      confirm: 'Reimposta',
                      cancel: true,
                    ) &&
                    c.mounted)
                  perform(c, () => s.startDemo(reset: true));
              },
            ),
          ActionRow(
            CupertinoIcons.square_arrow_left,
            'Esci',
            () => _logout(c, s),
            destructive: true,
          ),
          ActionRow(CupertinoIcons.trash, 'Elimina account', () async {
            final pass = s.demo
                ? 'demo'
                : await textDialog(c, 'Conferma password', '', obscure: true);
            if (pass == null || !c.mounted) return;
            if (await gpixAlert(
                  c,
                  'Eliminare definitivamente l’account?',
                  'Post, messaggi e profilo verranno rimossi. Non puoi annullare questa azione.',
                  confirm: 'Elimina account',
                  destructive: true,
                  cancel: true,
                ) &&
                c.mounted)
              perform(c, () async {
                await s.act('deleteAccount', {'password': pass});
                if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
              });
          }, destructive: true),
          const SizedBox(height: 30),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

Future<void> createMenu(BuildContext c) async {
  final selected = await sheet<String>(
    c,
    Builder(
      builder: (menu) {
        Widget tile(String label, IconData icon) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 72),
                foregroundColor: foreground(menu),
              ),
              onPressed: () => Navigator.pop(menu, label),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [GIcon(icon), const SizedBox(height: 5), Text(label)],
              ),
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Crea',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Altre creazioni',
                  icon: const GIcon(CupertinoIcons.ellipsis),
                  onSelected: (value) => Navigator.pop(menu, value),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'Istantanee',
                      child: Text('Istantanee'),
                    ),
                    PopupMenuItem(value: 'Bozze', child: Text('Bozze')),
                  ],
                ),
              ),
              Row(
                children: [
                  tile('Post', CupertinoIcons.square_pencil),
                  tile('Storia', CupertinoIcons.camera),
                ],
              ),
              Row(
                children: [
                  tile('Reel', CupertinoIcons.play_rectangle),
                  tile('Diretta', CupertinoIcons.dot_radiowaves_left_right),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const GIcon(CupertinoIcons.person_2),
                title: const Text('Momento'),
                trailing: const GIcon(CupertinoIcons.chevron_right, size: 16),
                onTap: () => Navigator.pop(menu, 'Momento'),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (selected == null || !c.mounted) return;
  switch (selected) {
    case 'Post':
      open(c, const Composer(kind: 'post'));
    case 'Storia':
      open(c, const Composer(kind: 'story'));
    case 'Reel':
      open(c, const Composer(kind: 'reel'));
    case 'Diretta':
      open(c, const LiveSetup());
    case 'Bozze':
      open(c, const DraftList());
    case 'Momento':
      await composeCommunity(c, 'communityMoment');
    case 'Istantanee':
      open(c, const InstantComposer(autoCapture: true));
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Aspetto')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: BrandLogo(width: 210)),
          ),
          for (final item in const {
            'light': 'Chiaro',
            'dark': 'Scuro',
            'system': 'Come il dispositivo',
          }.entries)
            ListTile(
              title: Text(item.value),
              leading: GIcon(
                item.key == 'light'
                    ? CupertinoIcons.sun_max
                    : item.key == 'dark'
                    ? CupertinoIcons.moon
                    : CupertinoIcons.device_phone_portrait,
              ),
              trailing: s.appearance == item.key
                  ? const Icon(CupertinoIcons.check_mark, color: auraBlue)
                  : null,
              onTap: () => s.setAppearance(item.key),
            ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'La scelta viene salvata su questo dispositivo. Con “Come il dispositivo” GPIX segue automaticamente il tema del telefono.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class InstantBubbleSetting extends StatelessWidget {
  const InstantBubbleSetting({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Bolla delle istantanee')),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: const GIcon(CupertinoIcons.photo_on_rectangle),
            title: const Text('Mostra bolla nei messaggi'),
            subtitle: const Text(
              'Nasconde solo la bolla. Le istantanee restano accessibili dall’icona nella pagina Messaggi.',
            ),
            value: !s.preferences.flag('hideInstantBubble'),
            onChanged: (v) =>
                perform(c, () => s.setPreference('hideInstantBubble', !v)),
          ),
        ],
      ),
    );
  }
}
