import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'reel_panels.dart';
import 'social.dart';
import 'stories.dart' show Composer;
import 'video.dart' show ClipControls, ClipPlayer, ClipProgress;

enum _Drawer { comments, share }

class Reels extends StatefulWidget {
  const Reels({
    super.key,
    this.active = true,
    this.initial,
    this.bottomOverlay = 0,
    this.onCoverDock,
  });

  final bool active;
  final String? initial;
  final double bottomOverlay;
  final ValueChanged<bool>? onCoverDock;

  @override
  State<Reels> createState() => _ReelsState();
}

class _ReelsState extends State<Reels> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  PageController? _pages;
  List<String> _ids = const [];
  String? _current, _preview;
  int _index = 0;
  _Drawer? _drawer;
  bool _pulling = false, _repositioning = false, _advancing = false;
  bool _menu = false, _immersive = false, _auto = false, _muted = false;
  bool _captions = true;
  final _hidden = <String>{};
  final _preferred = <String>{};
  late String _preferences;

  bool get _cover => _drawer != null || _immersive;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _drawer != null) {
          setState(() {
            _drawer = null;
            _preview = null;
          });
          _updateDock();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pages != null) return;
    final s = GpixScope.of(context, listen: false);
    _preferences = 'gpix.reels.${s.demo ? 'demo' : s.server}.${s.myId}';
    _muted = s.prefs?.getBool('$_preferences.muted') ?? false;
    _auto = s.prefs?.getBool('$_preferences.auto') ?? false;
    _captions = s.prefs?.getBool('$_preferences.captions') ?? true;
    _hidden.addAll(s.prefs?.getStringList('$_preferences.hidden') ?? []);
    _preferred.addAll(s.prefs?.getStringList('$_preferences.preferred') ?? []);
    _ids = _visible(s).map((p) => p.str('id')).toList();
    _index = math.max(0, _ids.indexOf(widget.initial ?? ''));
    _current = _ids.elementAtOrNull(_index);
    _pages = PageController(initialPage: _index, keepPage: false);
  }

  List<J> _visible(GpixStore s) {
    final visible = s.reels.where((p) {
      final id = p.str('id');
      return !_hidden.contains(id) || id == widget.initial;
    });
    if (_preferred.isEmpty || widget.initial != null) return visible.toList();
    return [
      ...visible.where((p) => _preferred.contains(p.str('author'))),
      ...visible.where((p) => !_preferred.contains(p.str('author'))),
    ];
  }

  void _keepCurrent(List<J> posts) {
    final ids = posts.map((p) => p.str('id')).toList();
    if (listEquals(ids, _ids)) return;
    _ids = ids;
    final previous = _index;
    final current = ids.indexOf(_current ?? '');
    _index = current >= 0
        ? current
        : ids.isEmpty
        ? 0
        : _index.clamp(0, ids.length - 1);
    _current = ids.elementAtOrNull(_index);
    if (_preview != null && !ids.contains(_preview)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    if (ids.isEmpty || previous == _index || _repositioning) return;
    _repositioning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ids.isNotEmpty && _pages!.hasClients)
        _pages!.jumpToPage(_index);
      _repositioning = false;
    });
  }

  Duration _duration(int milliseconds) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);

  void _updateDock() => widget.onCoverDock?.call(widget.active && _cover);

  void _open(_Drawer drawer, String id) {
    if (_drawer != null || id != _current) return;
    setState(() {
      _drawer = drawer;
      _preview = id;
    });
    _updateDock();
    if (_duration(310) == Duration.zero) {
      _reveal.value = 1;
    } else {
      _reveal.animateTo(
        1,
        duration: _duration(310),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _close() {
    if (_drawer == null) return;
    _pulling = false;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reveal.value == 0 || _duration(235) == Duration.zero) {
      _reveal.value = 0;
      if (_drawer != null) {
        setState(() {
          _drawer = null;
          _preview = null;
        });
        _updateDock();
      }
    } else {
      _reveal.animateBack(
        0,
        duration: _duration(235),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _pull(double delta, double height) {
    if (height <= 0) return;
    _reveal.value = (_reveal.value - delta / height).clamp(.09, 1.0);
  }

  void _endPull(double velocity) {
    if (_reveal.value < .83 || velocity > 350) {
      _close();
    } else {
      _reveal.animateTo(
        1,
        duration: _duration(175),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _pullFromList(ScrollNotification event, double height) {
    if (event.depth != 0 || event.metrics.axis != Axis.vertical) return false;
    if (event is OverscrollNotification &&
        event.dragDetails != null &&
        event.overscroll < 0 &&
        event.metrics.extentBefore == 0) {
      _pulling = true;
      _pull(-event.overscroll, height);
    } else if (_pulling &&
        (event is ScrollEndNotification || event.metrics.extentBefore > 0)) {
      _pulling = false;
      _endPull(0);
    }
    return false;
  }

  Future<void> _advance(String id) async {
    final pages = _pages;
    if (!_auto ||
        _advancing ||
        _menu ||
        _drawer != null ||
        !widget.active ||
        id != _current ||
        _index >= _ids.length - 1 ||
        pages == null ||
        !pages.hasClients ||
        pages.position.isScrollingNotifier.value)
      return;
    _advancing = true;
    try {
      final duration = _duration(300);
      if (duration == Duration.zero) {
        pages.jumpToPage(_index + 1);
      } else {
        await pages.nextPage(duration: duration, curve: Curves.easeInOutCubic);
      }
    } finally {
      _advancing = false;
    }
  }

  void _persist(String field, Object value) {
    final prefs = GpixScope.of(context, listen: false).prefs;
    if (prefs == null) return;
    final key = '$_preferences.$field';
    final write = value is bool
        ? prefs.setBool(key, value)
        : prefs.setStringList(key, (value as Set<String>).toList());
    unawaited(write.catchError((Object _) => false));
  }

  void _mute() {
    setState(() => _muted = !_muted);
    _persist('muted', _muted);
  }

  void _fullscreen(bool value) {
    setState(() => _immersive = value);
    _updateDock();
  }

  Future<void> _options(J post, ClipControls controls) async {
    if (_menu) return;
    final s = GpixScope.of(context, listen: false);
    final id = post.str('id'), author = post.str('author');
    setState(() => _menu = true);
    try {
      final choice = await showReelOptions(
        context,
        post,
        own: author == s.myId,
      );
      if (!mounted || s.post(id).isEmpty) return;
      switch (choice) {
        case 'save':
          await toggleSavedPost(context, id);
        case 'playback':
          final fullscreen = await showReelPlayback(
            context,
            subtitles: controls.hasSubtitles,
            auto: _auto,
            muted: _muted,
            captions: _captions,
            onAuto: (value) {
              setState(() => _auto = value);
              _persist('auto', value);
            },
            onMute: _mute,
            onCaptions: (value) {
              setState(() => _captions = value);
              _persist('captions', value);
            },
          );
          if (mounted && fullscreen == true) _fullscreen(true);
        case 'info':
          await showReelInfo(context, post);
        case 'why':
          await showReelReason(
            context,
            s.follows(author),
            _preferred.contains(author),
          );
        case 'prefer':
          setState(() => _preferred.add(author));
          _persist('preferred', _preferred);
          notice(context, 'Reel di questo autore in priorità');
        case 'hide':
          setState(() => _hidden.add(id));
          _persist('hidden', _hidden);
          if (widget.initial == id) {
            await Navigator.maybePop(context);
          } else {
            notice(context, 'Reel rimosso dalla tua sezione Reel');
          }
        case 'report':
          await report(context, id);
        case 'manage':
          await postMenu(context, s.post(id));
        case 'create':
          setState(() => _menu = false);
          await open(context, const Composer(kind: 'reel'));
      }
    } finally {
      if (mounted) setState(() => _menu = false);
    }
  }

  @override
  void dispose() {
    _pages?.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final posts = _visible(s);
    _keepCurrent(posts);
    final indices = {for (final (i, id) in _ids.indexed) id: i};
    final padding = MediaQuery.viewPaddingOf(c);
    final keyboard = MediaQuery.viewInsetsOf(c).bottom > 0;
    final suspended = !(ModalRoute.of(c)?.isCurrent ?? true) && !_menu;
    final progressBottom = widget.bottomOverlay > 0
        ? widget.bottomOverlay + 18
        : padding.bottom + 12;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: !widget.active || !_cover,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || !widget.active) return;
          if (_drawer != null) {
            _close();
          } else if (_immersive) {
            _fullscreen(false);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (c, bounds) {
              final height = bounds.maxHeight;
              final minimumVideo = math.min(
                padding.top + (keyboard ? 60 : 100),
                height * .39,
              );
              final drawerHeight = math.min(
                height - minimumVideo,
                height * (keyboard ? .76 : .60),
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (posts.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Nessun Reel da vedere',
                            style: TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton(
                            onPressed: () =>
                                open(c, const Composer(kind: 'reel')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Crea reel'),
                          ),
                        ],
                      ),
                    )
                  else
                    PageView.builder(
                      key: const ValueKey('reel-vertical-feed'),
                      controller: _pages,
                      scrollDirection: Axis.vertical,
                      physics: _drawer != null || _menu
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      itemCount: posts.length,
                      findChildIndexCallback: (key) =>
                          indices[(key as ValueKey<String>).value],
                      onPageChanged: (i) {
                        if (_repositioning || i >= posts.length) return;
                        setState(() {
                          _index = i;
                          _current = posts[i].str('id');
                        });
                      },
                      itemBuilder: (c, i) {
                        final post = posts[i], id = post.str('id');
                        final preview = id == _preview && _drawer != null;
                        return _Reel(
                          key: ValueKey(id),
                          post: post,
                          reveal: _reveal,
                          preview: preview,
                          immersive: _immersive,
                          active: widget.active && id == _current,
                          suspended: suspended,
                          loop:
                              !_auto ||
                              preview ||
                              _menu ||
                              i == posts.length - 1,
                          captions: _captions,
                          muted: _muted,
                          top: padding.top,
                          progressBottom: progressBottom,
                          drawerHeight: drawerHeight,
                          onComplete: () => _advance(id),
                          onClose: _close,
                          onMute: _mute,
                          onComments: () => _open(_Drawer.comments, id),
                          onShare: () => _open(_Drawer.share, id),
                          onOptions: (controls) => _options(post, controls),
                        );
                      },
                    ),
                  if (_drawer == null && (_immersive || widget.initial != null))
                    Positioned(
                      top: padding.top + 7,
                      left: _immersive ? null : 9,
                      right: _immersive ? 9 : null,
                      child: _FilmButton(
                        _immersive
                            ? CupertinoIcons.fullscreen_exit
                            : CupertinoIcons.chevron_back,
                        _immersive ? 'Esci da schermo intero' : 'Indietro',
                        _immersive
                            ? () => _fullscreen(false)
                            : () => Navigator.maybePop(c),
                      ),
                    ),
                  if (_drawer != null && _preview != null)
                    AnimatedBuilder(
                      animation: _reveal,
                      child: Theme(
                        data: gpixTheme(Brightness.dark),
                        child: Material(
                          key: const ValueKey('reel-sheet'),
                          color: const Color(0xff191a1f),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                GestureDetector(
                                  key: const ValueKey('reel-sheet-handle'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _close,
                                  onVerticalDragUpdate: (event) =>
                                      _pull(event.delta.dy, drawerHeight),
                                  onVerticalDragEnd: (event) =>
                                      _endPull(event.primaryVelocity ?? 0),
                                  onVerticalDragCancel: () => _endPull(0),
                                  child: Semantics(
                                    button: true,
                                    label: 'Chiudi pannello',
                                    child: const SizedBox(
                                      height: 22,
                                      width: double.infinity,
                                      child: Center(
                                        child: DecoratedBox(
                                          decoration: ShapeDecoration(
                                            color: Colors.white38,
                                            shape: StadiumBorder(),
                                          ),
                                          child: SizedBox(width: 35, height: 3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child:
                                      NotificationListener<ScrollNotification>(
                                        onNotification: (event) =>
                                            _pullFromList(event, drawerHeight),
                                        child: _drawer == _Drawer.comments
                                            ? Comments(
                                                id: _preview!,
                                                reel: true,
                                              )
                                            : ReelSharePanel(
                                                id: _preview!,
                                                onDone: _close,
                                              ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      builder: (c, child) => Positioned(
                        top: height - drawerHeight * _reveal.value,
                        left: 0,
                        right: 0,
                        height: drawerHeight,
                        child: child!,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

const _filmShadow = [
  Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 1)),
];

class _Reel extends StatefulWidget {
  const _Reel({
    super.key,
    required this.post,
    required this.reveal,
    required this.preview,
    required this.immersive,
    required this.active,
    required this.suspended,
    required this.loop,
    required this.captions,
    required this.muted,
    required this.top,
    required this.progressBottom,
    required this.drawerHeight,
    required this.onComplete,
    required this.onClose,
    required this.onMute,
    required this.onComments,
    required this.onShare,
    required this.onOptions,
  });

  final J post;
  final Animation<double> reveal;
  final bool preview, immersive, active, suspended, loop, captions, muted;
  final double top, progressBottom, drawerHeight;
  final VoidCallback onComplete, onClose, onMute, onComments, onShare;
  final ValueChanged<ClipControls> onOptions;

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  final _clip = ClipControls();
  late final AnimationController _heart;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _heart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _heart.dispose();
    _clip.dispose();
    super.dispose();
  }

  Future<void> _like({bool doubleTap = false}) async {
    final s = GpixScope.of(context, listen: false);
    final id = widget.post.str('id');
    final liked = s.post(id).ids('likes').contains(s.myId);
    if (doubleTap && !MediaQuery.disableAnimationsOf(context))
      _heart.forward(from: 0);
    if (!liked || !doubleTap) {
      await perform(
        context,
        () => s.act('like', {'id': id, 'enabled': !liked}),
      );
    }
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), post = widget.post;
    final uid = post.str('author'), id = post.str('id');
    final cover = s.reelCover(post);
    final player = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _clip.togglePlayback,
      onDoubleTap: widget.preview || widget.immersive
          ? null
          : () => _like(doubleTap: true),
      child: ClipPlayer(
        key: ValueKey('reel-player-$id'),
        reference: post.str('media'),
        active: widget.active,
        suspended: widget.suspended,
        fit: BoxFit.cover,
        controls: _clip,
        placeholder: cover.isEmpty ? null : MediaView(cover, fit: BoxFit.cover),
        muted: widget.muted,
        loop: widget.loop,
        showSubtitles: widget.captions,
        subtitleBottom: widget.preview || widget.immersive
            ? 12
            : widget.progressBottom + 111,
        onCompleted: widget.onComplete,
        onViewed: () => unawaited(s.recordReelView(id)),
      ),
    );
    return LayoutBuilder(
      builder: (c, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final top = widget.top + 5, bottom = h - widget.drawerHeight - 7;
        final previewHeight = math.max(0.0, bottom - top);
        final previewWidth = math.min(w * .53, previewHeight * .8);
        final preview = Rect.fromLTWH(
          (w - previewWidth) / 2,
          top,
          previewWidth,
          previewHeight,
        );
        final full = Offset.zero & Size(w, h);
        return AnimatedBuilder(
          animation: widget.reveal,
          child: player,
          builder: (c, player) {
            final t = widget.preview ? widget.reveal.value : 0.0;
            final opacity = (1 - t / .62).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (widget.preview)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: const ColoredBox(color: Colors.black),
                  ),
                Positioned.fromRect(
                  key: const ValueKey('reel-video-frame'),
                  rect: Rect.lerp(full, preview, t)!,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(t * 11),
                    child: player!,
                  ),
                ),
                if (!widget.immersive && opacity > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: widget.preview,
                      child: Opacity(
                        opacity: opacity,
                        child: _controls(c, s, uid, h),
                      ),
                    ),
                  ),
                if (widget.preview && t > .56)
                  Positioned(
                    right: 12,
                    top: math.max(widget.top, h - widget.drawerHeight * t - 41),
                    child: _FilmButton(
                      widget.muted
                          ? CupertinoIcons.speaker_slash_fill
                          : CupertinoIcons.speaker_2_fill,
                      widget.muted ? 'Attiva audio' : 'Disattiva audio',
                      widget.onMute,
                      size: 29,
                    ),
                  ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _heart,
                    builder: (c, _) {
                      final t = _heart.value;
                      if (t == 0 || t == 1) return const SizedBox.shrink();
                      return Center(
                        child: Opacity(
                          opacity: ((1 - t) * 4).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale:
                                .35 +
                                .8 *
                                    Curves.easeOutBack.transform(
                                      (t * 2.8).clamp(0.0, 1.0),
                                    ),
                            child: const Icon(
                              CupertinoIcons.heart_fill,
                              color: Color(0xffff355b),
                              size: 88,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _controls(BuildContext c, GpixStore s, String uid, double height) {
    final p = widget.post, id = widget.post.str('id');
    final liked = p.ids('likes').contains(s.myId),
        reposted = p.ids('reposts').contains(s.myId);
    final canRepost =
        !s.user(uid).flag('private') &&
        !const ['close', 'followers'].contains(p.str('audience'));
    final step = (height * .078).clamp(37.0, 68.0);
    final style = p.obj('style');
    return Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x52000000),
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xa6000000),
                ],
                stops: [0, .14, .53, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 66,
          bottom: widget.progressBottom + 20,
          child: _ReelDetails(
            post: p,
            expanded: _expanded,
            onCaption: () => setState(() => _expanded = !_expanded),
          ),
        ),
        Positioned(
          right: 6,
          bottom: widget.progressBottom + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReelAction(
                liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                liked ? 'Rimuovi Mi piace' : 'Mi piace',
                _like,
                height: step,
                color: liked ? const Color(0xffff355b) : Colors.white,
                count: p.flag('hideLikes') ? null : p.ids('likes').length,
              ),
              _ReelAction(
                CupertinoIcons.chat_bubble,
                'Commenti',
                widget.onComments,
                height: step,
                count: p.rows('comments').length,
              ),
              if (canRepost)
                _ReelAction(
                  CupertinoIcons.repeat,
                  reposted ? 'Rimuovi repost' : 'Ripubblica',
                  () => perform(
                    c,
                    () => s.act('repost', {'id': id, 'enabled': !reposted}),
                  ),
                  height: step,
                  count: p.ids('reposts').length,
                  color: reposted ? const Color(0xff8ff5bd) : Colors.white,
                ),
              _ReelAction(
                CupertinoIcons.paperplane,
                'Condividi reel',
                widget.onShare,
                height: step,
                count: p.number('shareCount').toInt(),
              ),
              _ReelAction(
                CupertinoIcons.ellipsis,
                'Opzioni reel',
                () => widget.onOptions(_clip),
                height: 42,
              ),
              _AudioTile(
                user: uid,
                cover: style.obj('music').str('cover'),
                onTap: () => showReelAudio(c, p, widget.muted, widget.onMute),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: widget.progressBottom - 9,
          child: ReelProgressBar(progress: _clip.progress, onSeek: _clip.seek),
        ),
      ],
    );
  }
}

class _ReelDetails extends StatelessWidget {
  const _ReelDetails({
    required this.post,
    required this.expanded,
    required this.onCaption,
  });

  final J post;
  final bool expanded;
  final VoidCallback onCaption;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final uid = post.str('author'), profile = s.user(uid);
    final story = s.stories(uid);
    final follow = s.follows(uid),
        pending = s.state.ids('pending').contains(uid);
    final likes = post.ids('likes');
    final supporters = likes
        .where((id) => s.follows(id) && !s.blocked(id))
        .toList();
    final mutualFollowers = profile
        .ids('followersList')
        .where((id) => id != s.myId && s.follows(id) && !s.blocked(id))
        .toList();
    final showFollowers =
        mutualFollowers.isNotEmpty &&
        (supporters.isEmpty || post.flag('hideLikes'));
    final familiar = showFollowers
        ? mutualFollowers
        : post.flag('hideLikes')
        ? const <String>[]
        : supporters.isEmpty
        ? likes.where((id) => !s.blocked(id)).toList()
        : supporters;
    final text = post.str('text');
    final track = post.obj('style').obj('music');
    const title = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      shadows: _filmShadow,
    );
    const body = TextStyle(
      color: Colors.white,
      fontSize: 12,
      height: 1.28,
      shadows: _filmShadow,
    );
    final name = familiar.isEmpty ? '' : s.user(familiar.first).str('username');
    final others = (showFollowers ? mutualFollowers.length : likes.length) - 1;
    final more = others <= 0
        ? ''
        : showFollowers && others == 1
        ? ' e 1 altra persona'
        : ' e altri ${formatReelCount(others)}';
    void viewProfile() => open(c, Profile(user: uid));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: viewProfile,
              child: Avatar(uid, size: 44, ring: story.isNotEmpty),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: InkResponse(
                onTap: viewProfile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.str('username'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: title,
                    ),
                    if (track.str('title').isNotEmpty)
                      Text(
                        '♫  ${track.str('title')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body.copyWith(fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
            if (uid != s.myId && !follow) ...[
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => perform(
                  c,
                  () => s.act('follow', {'user': uid, 'enabled': !pending}),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(48, 23),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                child: Text(
                  pending ? 'Richiesta inviata' : 'Segui',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (c, bounds) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: body),
                textDirection: Directionality.of(c),
                textScaler: MediaQuery.textScalerOf(c),
                maxLines: 1,
              )..layout(maxWidth: bounds.maxWidth);
              final overflow = painter.didExceedMaxLines;
              painter.dispose();
              if (!overflow)
                return Text(
                  text,
                  key: const ValueKey('reel-caption'),
                  style: body,
                );
              if (expanded) {
                return GestureDetector(
                  onTap: onCaption,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 170),
                    child: SingleChildScrollView(
                      child: Text(
                        '$text  ·  Meno',
                        style: body,
                        key: const ValueKey('reel-caption'),
                      ),
                    ),
                  ),
                );
              }
              return GestureDetector(
                onTap: onCaption,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        text,
                        key: const ValueKey('reel-caption'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('altro', style: body),
                  ],
                ),
              );
            },
          ),
        ],
        if (familiar.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkResponse(
            onTap: () => showFollowers
                ? people(c, mutualFollowers, 'Follower in comune')
                : people(c, likes, 'Mi piace'),
            child: Row(
              children: [
                for (final person in familiar.take(2)) Avatar(person, size: 16),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    showFollowers
                        ? 'Seguito da $name$more'
                        : 'Piace a $name$more',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String formatReelCount(int count) {
  if (count < 10000) return '$count';
  final millions = count >= 1000000;
  final truncated = (count / (millions ? 1000000 : 1000)).toStringAsFixed(1);
  final number = truncated
      .replaceFirst(RegExp(r'\.0$'), '')
      .replaceAll('.', ',');
  return '$number ${millions ? 'mln' : 'mila'}';
}

class _ReelAction extends StatelessWidget {
  const _ReelAction(
    this.icon,
    this.label,
    this.onTap, {
    required this.height,
    this.count,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double height;
  final int? count;
  final Color color;

  @override
  Widget build(BuildContext c) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: count == null ? label : '$label, $count',
      child: InkResponse(
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: height,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon == CupertinoIcons.ellipsis)
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FilmLine(20),
                      SizedBox(height: 5),
                      _FilmLine(14),
                    ],
                  )
                else
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(c)
                        ? Duration.zero
                        : const Duration(milliseconds: 175),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: GIcon(
                      icon,
                      key: ValueKey(icon),
                      color: color,
                      size: 28,
                    ),
                  ),
                if (count != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    formatReelCount(count!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      shadows: _filmShadow,
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

class _FilmLine extends StatelessWidget {
  const _FilmLine(this.width);
  final double width;

  @override
  Widget build(BuildContext c) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(2),
    ),
    child: SizedBox(width: width, height: 1.7),
  );
}

class _FilmButton extends StatelessWidget {
  const _FilmButton(this.icon, this.label, this.onTap, {this.size = 42});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext c) => SizedBox.square(
    dimension: size,
    child: IconButton.filled(
      tooltip: label,
      padding: EdgeInsets.zero,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Colors.white12),
      icon: GIcon(icon, color: Colors.white, size: size * .49),
    ),
  );
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.user,
    required this.cover,
    required this.onTap,
  });
  final String user, cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) {
    final url = cover.isEmpty
        ? GpixScope.of(c).user(user).str('avatar')
        : cover;
    return Tooltip(
      message: 'Audio del reel',
      child: InkResponse(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: SizedBox.square(
                    dimension: 27,
                    child: MediaView(
                      url,
                      fit: BoxFit.cover,
                      fallback: const ColoredBox(
                        color: Color(0xff24252a),
                        child: Center(
                          child: GIcon(
                            CupertinoIcons.music_note_2,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReelProgressBar extends StatefulWidget {
  const ReelProgressBar({
    super.key,
    required this.progress,
    required this.onSeek,
  });
  final ValueListenable<ClipProgress> progress;
  final ValueChanged<double> onSeek;

  @override
  State<ReelProgressBar> createState() => _ReelProgressBarState();
}

class _ReelProgressBarState extends State<ReelProgressBar> {
  double? _drag;

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<ClipProgress>(
    valueListenable: widget.progress,
    builder: (c, progress, _) {
      final total = progress.duration.inMicroseconds;
      final value =
          _drag ??
          (total <= 0
              ? 0.0
              : (progress.position.inMicroseconds / total).clamp(0.0, 1.0));
      return SizedBox(
        height: 19,
        child: SliderTheme(
          data: SliderTheme.of(c).copyWith(
            trackHeight: _drag == null ? 2 : 3.5,
            trackShape: const RoundedRectSliderTrackShape(),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white38,
            disabledInactiveTrackColor: Colors.white38,
            thumbColor: Colors.white,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: _drag == null ? 0 : 4,
              disabledThumbRadius: 0,
            ),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            key: const ValueKey('reel-progress'),
            value: value,
            padding: EdgeInsets.zero,
            semanticFormatterCallback: (value) =>
                '${(value * 100).round()} percento',
            onChanged: total <= 0
                ? null
                : (value) => setState(() => _drag = value),
            onChangeEnd: total <= 0
                ? null
                : (value) {
                    widget.onSeek(value);
                    setState(() => _drag = null);
                  },
          ),
        ),
      );
    },
  );
}
