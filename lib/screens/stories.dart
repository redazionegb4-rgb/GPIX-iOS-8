import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../core/drafts.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import '../ui/creation.dart';
import 'social.dart';
import 'video.dart';
import 'emoji_picker.dart';
import 'giphy.dart';
import 'music_picker.dart';
import 'story_stickers.dart';
import 'story_camera.dart';
import 'post_composer.dart';

const storyColors = [
  Colors.white,
  Colors.black,
  Color(0xffffd86f),
  Color(0xff83ccf0),
  Color(0xff8dd9e7),
];

class StoryCanvas extends StatelessWidget {
  final J story;
  final bool editing;
  final bool playing;
  final ValueChanged<Offset>? onMove;
  final ValueChanged<Duration>? onVideoDuration;
  final void Function(int, Offset)? onStickerMove;
  final ValueChanged<int>? onStickerTap;
  final ValueChanged<J>? onStickerAction;
  final ValueChanged<int>? onStickerVote;
  const StoryCanvas({
    super.key,
    required this.story,
    this.editing = false,
    this.playing = false,
    this.onMove,
    this.onVideoDuration,
    this.onStickerMove,
    this.onStickerTap,
    this.onStickerAction,
    this.onStickerVote,
  });
  @override
  Widget build(BuildContext c) {
    final style = story.obj('style');
    final x = style.number('x', .5).clamp(.12, .88),
        y = style.number('y', .68).clamp(.1, .85);
    final color = storyColors[style.number('color').toInt().clamp(0, 4)];
    return LayoutBuilder(
      builder: (c, box) => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: [
                Colors.black,
                const Color(0xff202020),
                const Color(0xff0e3556),
                const Color(0xff163c32),
              ][style.number('background').toInt() % 4],
            ),
            if (story.str('media').isNotEmpty)
              Transform.scale(
                scale: style.number('zoom', 1).clamp(1, 2),
                child:
                    (style.flag('video') ||
                        story.str('media').toLowerCase().contains('.mp4') ||
                        story.str('media').toLowerCase().contains('.mov'))
                    ? ClipPlayer(
                        reference: story.str('media'),
                        active: !editing && playing,
                        onDuration: onVideoDuration,
                        fit: BoxFit.cover,
                      )
                    : MediaView(story.str('media'), fit: BoxFit.contain),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .24),
                        Colors.transparent,
                        Colors.black.withValues(alpha: .17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (story.str('text').isNotEmpty && !style.flag('stickerOnly'))
              Positioned(
                left: 0,
                right: 0,
                top: box.maxHeight * y - 35,
                child: GestureDetector(
                  onPanUpdate: editing && onMove != null
                      ? (d) => onMove!(
                          Offset(
                            x + d.delta.dx / box.maxWidth,
                            y + d.delta.dy / box.maxHeight,
                          ),
                        )
                      : null,
                  child: Align(
                    alignment: Alignment((x - .5) * 2, 0),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * .88),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: style.number('font') == 1
                            ? Colors.black54
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        story.str('text'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: style.number('size', 29).clamp(18, 48),
                          height: 1.17,
                          fontWeight: style.number('font') == 2
                              ? FontWeight.w400
                              : FontWeight.w800,
                          fontStyle: style.number('font') == 2
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: color,
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 5,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final (index, sticker) in style.rows('stickers').indexed)
              _canvasSticker(box, story, sticker, index),
            if (style.str('caption').isNotEmpty)
              Positioned(
                bottom: 16,
                left: 18,
                right: 18,
                child: Text(
                  style.str('caption'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 5)],
                  ),
                ),
              ),
            if (style.str('sticker').isNotEmpty)
              Positioned(
                left: box.maxWidth * .13,
                bottom: box.maxHeight * .16,
                child: Transform.rotate(
                  angle: -.12,
                  child: Text(
                    style.str('sticker'),
                    style: const TextStyle(fontSize: 49),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _canvasSticker(BoxConstraints box, J story, J sticker, int index) {
    final type = sticker.str('type');
    final interactiveVote = const {'poll', 'slider', 'rating'}.contains(type);
    final size = sticker.number('size', 52).clamp(28, 94).toDouble();
    final width = (interactiveVote ? size * 4.5 : 216.0).clamp(
      0.0,
      (box.maxWidth - 16).clamp(0.0, 250.0),
    );
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _StickerPosition(
          sticker.number('x', .4),
          sticker.number('y', .5),
          width,
        ),
        child: Builder(
          builder: (target) => GestureDetector(
            onTap: editing
                ? () => onStickerTap?.call(index)
                : onStickerAction != null &&
                      interactiveStoryStickers.contains(type)
                ? () => onStickerAction!({...sticker, 'position': index})
                : null,
            onPanUpdate: editing
                ? (details) {
                    final bounds = target.size ?? Size.zero;
                    final limitX = (1 - bounds.width / box.maxWidth).clamp(
                      0.0,
                      1.0,
                    );
                    final limitY = (1 - bounds.height / box.maxHeight).clamp(
                      0.0,
                      1.0,
                    );
                    final oldX = sticker.number('x', .4);
                    final oldY = sticker.number('y', .5);
                    onStickerMove?.call(
                      index,
                      Offset(
                        (oldX.clamp(0.0, limitX) +
                                    details.delta.dx / box.maxWidth)
                                .clamp(0.0, limitX) -
                            oldX,
                        (oldY.clamp(0.0, limitY) +
                                    details.delta.dy / box.maxHeight)
                                .clamp(0.0, limitY) -
                            oldY,
                      ),
                    );
                  }
                : null,
            child: Transform.rotate(
              angle: sticker.number('angle'),
              child: StoryStickerFace(
                maxWidth: width,
                onVote: onStickerVote,
                sticker: sticker,
                post: story,
                editing: editing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerPosition extends SingleChildLayoutDelegate {
  const _StickerPosition(this.x, this.y, this.width);
  final double x, y, width;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: width, maxHeight: constraints.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (size.width * x).clamp(
      0.0,
      (size.width - childSize.width).clamp(0.0, size.width),
    ),
    (size.height * y).clamp(
      0.0,
      (size.height - childSize.height).clamp(0.0, size.height),
    ),
  );

  @override
  bool shouldRelayout(_StickerPosition old) =>
      old.x != x || old.y != y || old.width != width;
}

class StoryViewer extends StatefulWidget {
  final String user;
  final List<String>? ids;
  const StoryViewer({super.key, required this.user, this.ids});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController progress =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..addStatusListener((v) {
          if (v == AnimationStatus.completed) next(1);
        });
  final reply = TextEditingController();
  final focus = FocusNode();
  AudioPlayer? _music;
  AudioPlayer get music => _music ??= AudioPlayer();
  List<String> ids = [];
  int index = 0;
  double _verticalDrag = 0;
  double _horizontalDrag = 0;
  int _slideDirection = 0;
  bool initialized = false,
      paused = false,
      reactions = false,
      recording = false;
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  String reaction = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      final s = GpixScope.of(context, listen: false);
      ids =
          widget.ids ??
          [
            widget.user,
            ...s.storyUsers
                .map((u) => u.str('id'))
                .where((id) => id != widget.user),
          ].expand((uid) => s.stories(uid).map((p) => p.str('id'))).toList();
      if (widget.ids == null && widget.user != s.myId) {
        final first = ids.indexWhere((id) {
          final p = s.post(id);
          return p.str('author') == widget.user &&
              !p.flag('seenByMe') &&
              !p.ids('viewers').contains(s.myId);
        });
        if (first >= 0) index = first;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => begin());
      focus.addListener(() {
        if (!mounted) return;
        setState(() => reactions = focus.hasFocus);
        if (focus.hasFocus) {
          progress.stop();
          _music?.pause();
        } else if (!paused) {
          progress.forward();
          _music?.resume();
        }
      });
    }
  }

  Future<void> begin() async {
    if (!mounted || ids.isEmpty) return;
    final s = GpixScope.of(context, listen: false), p = s.post(ids[index]);
    progress.duration = const Duration(seconds: 6);
    progress.forward(from: 0);
    await _music?.stop();
    final audio = p.obj('style').str('audio');
    if (audio.isNotEmpty) {
      try {
        await music.play(
          s.url(audio).startsWith('https://')
              ? UrlSource(s.url(audio))
              : DeviceFileSource(audio),
          position: Duration(
            milliseconds: (p.obj('style').obj('music').number('start') * 1000)
                .round(),
          ),
        );
      } catch (_) {}
    }
    if (mounted && p.str('author') != s.myId)
      perform(context, () => s.act('see', {'id': p['id']}));
  }

  void next(int step, {bool slide = false}) {
    if (recording) return;
    if (index + step < 0) {
      progress.forward(from: 0);
      return;
    }
    if (index + step >= ids.length) {
      Navigator.pop(context);
      return;
    }
    focus.unfocus();
    setState(() {
      _horizontalDrag = 0;
      _slideDirection = slide ? step : 0;
      index += step;
      stickerBurst = '';
      reactions = false;
      paused = false;
    });
    begin();
  }

  Future<void> respond(String text) async {
    if (text.trim().isEmpty) return;
    final p = GpixScope.of(context, listen: false).post(ids[index]);
    await perform(context, () async {
      await GpixScope.of(context, listen: false).storyReply(p, text);
      if (!mounted) return;
      reply.clear();
      focus.unfocus();
      setState(() {
        reactions = false;
        paused = false;
        reaction = text.length < 12 ? text : '';
      });
      progress.forward();
      _music?.resume();
      notice(context, 'Risposta inviata');
    });
  }

  bool votingSticker = false;

  Future<void> voteOnSticker(J story, int choice) async {
    if (votingSticker ||
        story.obj('style').obj('poll').number('myVote', -1) >= 0)
      return;
    votingSticker = true;
    progress.stop();
    _music?.pause();
    setState(() => paused = true);
    try {
      final store = GpixScope.of(context, listen: false);
      await perform(
        context,
        () => store.act('pollVote', {'id': story.str('id'), 'choice': choice}),
      );
    } finally {
      votingSticker = false;
      if (mounted) {
        setState(() => paused = false);
        if (!focus.hasFocus && !reactions) {
          progress.forward();
          _music?.resume();
        }
      }
    }
  }

  String stickerBurst = '';
  int burstSequence = 0;

  Future<void> showStoryActivity(J story) async {
    if (paused || recording) return;
    progress.stop();
    _music?.pause();
    setState(() => paused = true);
    String? selected;
    try {
      selected = await Navigator.of(context).push(
        PageRouteBuilder<String>(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, _, _) =>
              StoryActivityPanel(storyId: story.str('id')),
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 310),
          reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          transitionsBuilder: (_, animation, _, child) => SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
        ),
      );
    } finally {
      if (mounted) {
        final store = GpixScope.of(context, listen: false);
        final target = selected != null && store.post(selected).isNotEmpty
            ? selected
            : null;
        final changed = target != null && target != ids[index];
        setState(() {
          paused = false;
          if (changed) {
            if (!ids.contains(target)) ids = [...ids, target];
            index = ids.indexOf(target);
            _slideDirection = 0;
            stickerBurst = '';
          }
        });
        if (changed) {
          begin();
        } else if (!focus.hasFocus && !reactions) {
          progress.forward();
          _music?.resume();
        }
      }
    }
  }

  void _finishVerticalDrag(J story, bool own, [double velocity = 0]) {
    if (paused || recording) return;
    final movement = _verticalDrag;
    setState(() => _verticalDrag = 0);
    if (own && (movement < -55 || velocity < -480)) {
      showStoryActivity(story);
    } else if (movement > 80 || velocity > 620) {
      Navigator.maybePop(context);
    } else if (!focus.hasFocus && !reactions) {
      progress.forward();
      _music?.resume();
    }
  }

  Future<void> openSticker(J story, J sticker) async {
    final store = GpixScope.of(context, listen: false);
    final type = sticker.str('type');
    final label = sticker.str('label');
    if (type == 'reaction') {
      if (story.str('author') == store.myId) return;
      setState(() {
        stickerBurst = sticker.str('emoji');
        burstSequence++;
      });
      final position = sticker.number('position').toInt();
      if (!story.ids('myStickerReactions').contains('$position')) {
        await perform(
          context,
          () => store.act('storyStickerResponse', {
            'id': story.str('id'),
            'position': position,
          }),
        );
      }
      return;
    }
    progress.stop();
    _music?.pause();
    setState(() => paused = true);
    try {
      switch (type) {
        case 'question':
          if (!store.canReplyStory(story) || story.str('author') == store.myId)
            return;
          final answer = await storyStickerInput(
            context,
            label,
            'Risposta privata',
            replying: true,
            limit: 500,
          );
          if (answer != null && mounted) {
            await perform(context, () async {
              await store.act('storyStickerResponse', {
                'id': story.str('id'),
                'position': sticker.number('position').toInt(),
                'text': answer,
              });
              if (mounted) notice(context, 'Risposta inviata');
            });
          }
        case 'prompt':
          final chain = sticker.str('chain', story.str('id'));
          final related = store.allPosts
              .where(
                (post) =>
                    post.str('kind') == 'story' &&
                    post.str('id') != story.str('id') &&
                    !post.flag('archived') &&
                    post.number('expires') > now &&
                    post
                        .obj('style')
                        .rows('stickers')
                        .any(
                          (item) =>
                              item.str('type') == 'prompt' &&
                              item.str('chain', post.str('id')) == chain,
                        ),
              )
              .toList();
          final selection = await sheet<String>(
            context,
            Builder(
              builder: (menu) => Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(menu).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(menu, ''),
                      child: const Text('Tocca a te'),
                    ),
                    for (final post in related)
                      ListTile(
                        leading: Avatar(post.str('author')),
                        title: Text(
                          store.user(post.str('author')).str('username'),
                        ),
                        onTap: () => Navigator.pop(menu, post.str('id')),
                      ),
                  ],
                ),
              ),
            ),
          );
          if (selection == null || !mounted) return;
          if (selection.isNotEmpty) {
            await open(
              context,
              StoryViewer(
                user: store.post(selection).str('author'),
                ids: [selection],
              ),
            );
          } else {
            await open(
              context,
              Composer(
                kind: 'story',
                initialDraft: {
                  'style': {
                    'stickers': [
                      {...sticker, 'chain': chain},
                    ],
                  },
                },
              ),
            );
          }
        case 'mention':
          final username = label.replaceFirst('@', '').toLowerCase();
          final user = [store.me, ...store.users]
              .where((user) => user.str('username').toLowerCase() == username)
              .firstOrNull;
          if (user != null) await open(context, Profile(user: user.str('id')));
        case 'hashtag':
          await open(context, Explore(initialQuery: label));
        case 'link':
        case 'donation':
        case 'place':
          final uri = storyStickerLink(sticker.str('url'));
          if (uri != null)
            await perform(context, () async {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                throw Exception('Impossibile aprire il collegamento.');
              }
            });
      }
    } finally {
      if (mounted) {
        setState(() => paused = false);
        if (!focus.hasFocus && !reactions) {
          progress.forward();
          _music?.resume();
        }
      }
    }
  }

  Future<void> voice() async {
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      if (recording) {
        final path = await recorder.stop();
        setState(() => recording = false);
        if (path != null) {
          final media = await s.upload(path, 'audio/mp4');
          final tid = await s.openThread(s.post(ids[index]).str('author'));
          await s.send(
            tid,
            'Risposta vocale alla storia',
            kind: 'audio',
            media: media,
            story: s.post(ids[index]).str('id'),
          );
          if (mounted) notice(context, 'Vocale inviato');
        }
      } else {
        if (!await recorder.hasPermission())
          throw Exception('Consenti l’accesso al microfono.');
        final root = await getTemporaryDirectory();
        await recorder.start(
          const RecordConfig(),
          path: '${root.path}/story-${newId()}.m4a',
        );
        progress.stop();
        _music?.pause();
        setState(() => recording = true);
      }
    });
  }

  @override
  void dispose() {
    progress.dispose();
    reply.dispose();
    focus.dispose();
    _music?.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    if (ids.isEmpty)
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Storia non disponibile',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    final p = s.post(ids[index]),
        uid = p.str('author'),
        own = uid == s.myId,
        u = s.user(uid),
        segments = ids.where((id) => s.post(id).str('author') == uid).toList(),
        segment = segments.indexOf(p.str('id'));
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SectionSwipe(
                onDrag: (distance) {
                  if (paused || recording || MediaQuery.disableAnimationsOf(c))
                    return;
                  final limit = MediaQuery.sizeOf(c).width * .32;
                  setState(
                    () =>
                        _horizontalDrag = (distance * .55).clamp(-limit, limit),
                  );
                },
                onStep: (step) {
                  if (!paused) next(step, slide: true);
                },
                child: GestureDetector(
                  onLongPressStart: (_) {
                    setState(() => paused = true);
                    progress.stop();
                    _music?.pause();
                  },
                  onLongPressEnd: (_) {
                    setState(() => paused = false);
                    if (!focus.hasFocus) {
                      progress.forward();
                      _music?.resume();
                    }
                  },
                  onTapUp: (d) => next(
                    d.localPosition.dx < MediaQuery.sizeOf(c).width * .3
                        ? -1
                        : 1,
                  ),
                  onVerticalDragStart: (_) {
                    _verticalDrag = 0;
                    if (!recording && !paused) {
                      progress.stop();
                      _music?.pause();
                    }
                  },
                  onVerticalDragUpdate: (details) {
                    if (recording || paused) return;
                    setState(() => _verticalDrag += details.primaryDelta!);
                  },
                  onVerticalDragCancel: () => _finishVerticalDrag(p, own),
                  onVerticalDragEnd: (details) =>
                      _finishVerticalDrag(p, own, details.primaryVelocity ?? 0),
                  child: AnimatedContainer(
                    duration:
                        _verticalDrag == 0 &&
                            _horizontalDrag == 0 &&
                            !MediaQuery.disableAnimationsOf(c)
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    curve: Curves.easeOutCubic,
                    transformAlignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        _horizontalDrag,
                        (_verticalDrag * .65).clamp(-130.0, 240.0),
                        0,
                        1,
                      )
                      ..scaleByDouble(
                        1 - (_verticalDrag.abs() / 1600).clamp(0.0, .13),
                        1 - (_verticalDrag.abs() / 1600).clamp(0.0, .13),
                        1,
                        1,
                      ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TweenAnimationBuilder<double>(
                            key: ValueKey(p['id']),
                            tween: Tween(
                              begin: MediaQuery.disableAnimationsOf(c)
                                  ? 0
                                  : _slideDirection.toDouble(),
                              end: 0,
                            ),
                            duration: const Duration(milliseconds: 230),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, child) => Transform(
                              alignment: value > 0
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .001)
                                ..translateByDouble(
                                  value * MediaQuery.sizeOf(c).width * .72,
                                  0,
                                  0,
                                  1,
                                )
                                ..rotateY(value * .32),
                              child: child,
                            ),
                            child: StoryCanvas(
                              key: ValueKey(p['id']),
                              story: p,
                              onStickerAction: (sticker) =>
                                  openSticker(p, sticker),
                              onStickerVote: (choice) =>
                                  voteOnSticker(p, choice),
                              onVideoDuration: (duration) {
                                if (!mounted || duration.inMilliseconds <= 0)
                                  return;
                                progress.duration = duration;
                                if (!paused && !focus.hasFocus && !reactions)
                                  progress.forward(from: 0);
                              },
                              playing:
                                  !paused &&
                                  !focus.hasFocus &&
                                  !reactions &&
                                  (ModalRoute.of(c)?.isCurrent ?? true),
                            ),
                          ),
                          if (stickerBurst.isNotEmpty)
                            Positioned.fill(
                              child: StoryEmojiBurst(
                                key: ValueKey(burstSequence),
                                emoji: stickerBurst,
                              ),
                            ),
                          if (reactions)
                            const ColoredBox(color: Colors.black45),
                          Positioned(
                            top: 9,
                            left: 8,
                            right: 8,
                            child: AnimatedBuilder(
                              animation: progress,
                              builder: (c, _) => Row(
                                children: [
                                  for (var i = 0; i < segments.length; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: i < segment
                                                ? 1
                                                : i == segment
                                                ? progress.value
                                                : 0,
                                            minHeight: 2.5,
                                            backgroundColor: Colors.white30,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  Colors.white,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 25,
                            left: 13,
                            right: 5,
                            child: Row(
                              children: [
                                Avatar(uid, size: 33),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: own
                                              ? 'La tua storia'
                                              : u.str('username'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '  ${relative(p['created'])}',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (p.str('audience') == 'close')
                                  const GIcon(
                                    CupertinoIcons.star_fill,
                                    color: Colors.greenAccent,
                                    size: 18,
                                  ),
                                if (!reactions && !own)
                                  IconButton(
                                    tooltip: 'Opzioni storia',
                                    onPressed: () async {
                                      progress.stop();
                                      _music?.pause();
                                      await postMenu(c, p);
                                      if (mounted) {
                                        if (s.post(ids[index]).isEmpty) {
                                          next(1);
                                        } else {
                                          progress.forward();
                                          _music?.resume();
                                        }
                                      }
                                    },
                                    icon: const GIcon(
                                      CupertinoIcons.line_horizontal_3_decrease,
                                      color: Colors.white,
                                      size: 25,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: 'Chiudi storia',
                                  onPressed: () => Navigator.pop(c),
                                  icon: const GIcon(
                                    CupertinoIcons.xmark,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (reactions && !own)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 37,
                                ),
                                child: LayoutBuilder(
                                  builder: (c, b) => GridView.count(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 18,
                                    crossAxisSpacing: 15,
                                    children: [
                                      for (final emoji in [
                                        '😂',
                                        '😮',
                                        '😍',
                                        '😢',
                                        '👏',
                                        '🔥',
                                      ])
                                        GestureDetector(
                                          onTap: () => respond(emoji),
                                          child: Center(
                                            child: Text(
                                              emoji,
                                              style: TextStyle(
                                                fontSize: (b.maxWidth / 3 * .61)
                                                    .clamp(36, 65),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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
            if (own)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => showStoryActivity(p),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.viewers(p).isEmpty)
                            const GIcon(
                              CupertinoIcons.person_2,
                              color: Colors.white,
                            )
                          else
                            SizedBox(
                              width: 52,
                              height: 25,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  for (final (i, id)
                                      in s.viewers(p).take(3).indexed)
                                    Positioned(
                                      left: i * 13.0,
                                      child: Avatar(id, size: 25),
                                    ),
                                ],
                              ),
                            ),
                          const Text(
                            'Attività',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Metti in evidenza',
                      onPressed: () async {
                        progress.stop();
                        _music?.pause();
                        await addStoryHighlight(c, p);
                        if (mounted) {
                          progress.forward();
                          _music?.resume();
                        }
                      },
                      icon: const GIcon(
                        CupertinoIcons.heart_circle,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Invia storia',
                      onPressed: () async {
                        progress.stop();
                        await sharePost(c, p);
                        if (mounted) progress.forward();
                      },
                      icon: const GIcon(
                        CupertinoIcons.paperplane,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Altro',
                      onPressed: () async {
                        progress.stop();
                        await postMenu(c, p);
                        if (mounted) {
                          if (s.post(ids[index]).isEmpty) {
                            next(1);
                          } else {
                            progress.forward();
                          }
                        }
                      },
                      icon: const GIcon(
                        CupertinoIcons.ellipsis,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else if (!s.canReplyStory(p))
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text(
                  'Le risposte a questa storia sono disattivate',
                  style: TextStyle(color: Colors.white60),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: reply,
                        focusNode: focus,
                        onChanged: (_) => setState(() {}),
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Rispondi a ${u.str('username')}…',
                          hintStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xff151515),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.white54),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    if (focus.hasFocus || recording)
                      IconButton(
                        tooltip: recording ? 'Invia vocale' : 'Registra vocale',
                        onPressed: voice,
                        icon: GIcon(
                          recording
                              ? CupertinoIcons.stop_circle_fill
                              : CupertinoIcons.mic,
                          color: recording ? danger : Colors.white,
                          size: 27,
                        ),
                      )
                    else ...[
                      IconButton(
                        tooltip: 'Mi piace alla storia',
                        onPressed: () => perform(
                          c,
                          () => s.act('like', {
                            'id': p['id'],
                            'enabled': !p.ids('likes').contains(s.myId),
                          }),
                        ),
                        icon: GIcon(
                          p.ids('likes').contains(s.myId)
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: p.ids('likes').contains(s.myId)
                              ? danger
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                    IconButton(
                      tooltip: reply.text.trim().isEmpty
                          ? 'Condividi storia'
                          : 'Invia risposta',
                      onPressed: () => reply.text.trim().isNotEmpty
                          ? respond(reply.text.trim())
                          : sharePost(c, p),
                      icon: const GIcon(
                        CupertinoIcons.paperplane,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Composer extends StatefulWidget {
  final String kind;
  final bool editStory;
  final J? initialDraft;
  final Widget? modePicker;
  const Composer({
    super.key,
    required this.kind,
    this.editStory = false,
    this.initialDraft,
    this.modePicker,
  });
  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final text = TextEditingController(), location = TextEditingController();
  List<String> files = [];
  String kind = 'post';
  String reelAudience = 'followers';
  late String draftId;
  Timer? draftTimer;
  bool savingDraft = false;
  String lastDraft = '';
  Future<void> saveDraft({bool feedback = false}) async {
    if (kind != 'reel') return;
    if (files.isEmpty) {
      if (feedback)
        notice(context, 'Aggiungi un video prima di salvare la bozza.');
      return;
    }
    if (savingDraft) {
      if (!feedback) return;
      while (savingDraft && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (mounted) await saveDraft(feedback: true);
      return;
    }
    if (busy) return;
    final data = <String, dynamic>{
      'id': draftId,
      'kind': kind,
      'files': files,
      'text': text.text,
      'location': location.text,
      'caption': caption.text,
      'style': style,
      'audience': reelAudience,
    };
    final encoded = jsonEncode(data);
    if (!feedback && lastDraft == encoded) return;
    savingDraft = true;
    try {
      final s = GpixScope.of(context, listen: false);
      await Drafts.save('${s.server}|${s.myId}', data);
      lastDraft = encoded;
      if (feedback && mounted) notice(context, 'Bozza salvata');
    } catch (e) {
      if (feedback && mounted) notice(context, 'Bozza non salvata: $e');
    } finally {
      savingDraft = false;
    }
  }

  int page = 0, font = 0, color = 0, background = 0;
  double x = .5, y = .65, size = 29, zoom = 1, aspect = 1;
  String sticker = '';
  String audio = '';
  J? storyMusic;
  final caption = TextEditingController();
  final canvasKey = GlobalKey();
  final List<J> stickers = [];
  J? stickerPoll;
  bool highlightAfterPublish = false;
  int selectedSticker = -1;
  bool busy = false, cameraStage = false, expandedTools = false;
  @override
  void initState() {
    super.initState();
    kind = widget.kind;
    final previousDraftId = widget.initialDraft?.str('id') ?? '';
    draftId = previousDraftId.isEmpty ? newId() : previousDraftId;
    if (widget.initialDraft != null) {
      final d = widget.initialDraft!;
      files = d.ids('files');
      text.text = d.str('text');
      location.text = d.str('location');
      caption.text = d.str('caption');
      reelAudience = d.str('audience') == 'close' ? 'close' : 'followers';
      final st = d.obj('style');
      audio = st.str('audio');
      if (st.obj('music').isNotEmpty) storyMusic = st.obj('music');
      aspect = st.number('aspect', 1).toDouble();
      x = st.number('x', .5).toDouble();
      y = st.number('y', .65).toDouble();
      font = st.number('font').toInt();
      color = st.number('color').toInt();
      background = st.number('background').toInt();
      size = st.number('size', 29).toDouble();
      zoom = st.number('zoom', 1).toDouble();
      sticker = st.str('sticker');
      stickers.addAll(st.rows('stickers'));
      if (st.obj('poll').isNotEmpty) stickerPoll = st.obj('poll');
    }
    draftTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) saveDraft();
    });
    cameraStage = kind == 'story' && !widget.editStory;
  }

  @override
  void dispose() {
    draftTimer?.cancel();
    text.dispose();
    caption.dispose();
    location.dispose();
    super.dispose();
  }

  J get style => {
    'caption': caption.text,
    'audio': audio,
    if (storyMusic != null) 'music': storyMusic,
    'aspect': aspect,
    'x': x,
    'y': y,
    'font': font,
    'color': color,
    'background': background,
    'size': size,
    'zoom': zoom,
    'sticker': sticker,
    'stickers': stickers,
    if (stickerPoll != null) 'poll': stickerPoll,
    'video':
        files.isNotEmpty &&
        (files.first.toLowerCase().endsWith('.mp4') ||
            files.first.toLowerCase().endsWith('.mov')),
  };
  Future<void> pick({bool camera = false, bool video = false}) async {
    await perform(context, () async {
      final picker = ImagePicker();
      if (video) {
        final f = await picker.pickVideo(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 60),
        );
        if (f != null) setState(() => files = [f.path]);
      } else if (kind == 'post' && !camera) {
        final f = await picker.pickMultiImage(
          maxWidth: 1800,
          imageQuality: 90,
          limit: 10,
        );
        if (f.isNotEmpty)
          setState(() => files = f.take(10).map((e) => e.path).toList());
      } else {
        final f = await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1800,
          imageQuality: 90,
        );
        if (f != null) setState(() => files = [f.path]);
      }
    });
  }

  Future<void> publish({String? audience}) async {
    final selectedAudience =
        audience ?? (kind == 'reel' ? reelAudience : 'all');
    await saveDraft();
    if (!mounted) return;
    if (files.isEmpty &&
        !(kind == 'story' &&
            (text.text.trim().isNotEmpty || stickers.isNotEmpty))) {
      notice(context, 'Aggiungi un contenuto prima di pubblicare.');
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      if (files.length +
              stickers.fold<int>(
                0,
                (total, item) => total + item.ids('files').length,
              ) >
          10) {
        throw Exception('Puoi usare al massimo 10 foto o GIF per storia.');
      }
      final media = <String>[];
      for (final path in files) {
        media.add(
          await s.upload(
            path,
            path.toLowerCase().endsWith('.gif')
                ? 'image/gif'
                : path.toLowerCase().endsWith('.mov')
                ? 'video/quicktime'
                : path.toLowerCase().endsWith('.mp4')
                ? 'video/mp4'
                : path.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
      }
      final track = storyMusic != null
          ? storyMusic!.str('audio')
          : audio.isEmpty
          ? ''
          : await s.upload(
              audio,
              audio.endsWith('.mp3')
                  ? 'audio/mpeg'
                  : audio.endsWith('.wav')
                  ? 'audio/wav'
                  : 'audio/mp4',
            );
      final overlayMedia = <String>[];
      final publishedStickers = <J>[];
      for (final sticker in stickers) {
        final mediaIds = <String>[];
        for (final reference in sticker.ids('files')) {
          final mime = reference.toLowerCase().endsWith('.gif')
              ? 'image/gif'
              : reference.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          if (reference.startsWith('https://')) {
            final response = await s.client
                .get(Uri.parse(reference))
                .timeout(const Duration(seconds: 20));
            if (response.statusCode != 200 ||
                response.bodyBytes.length > 25 * 1024 * 1024) {
              throw Exception('GIF non disponibile. Scegline un’altra.');
            }
            final folder = await getTemporaryDirectory();
            final file = await File(
              '${folder.path}/story-${newId()}.gif',
            ).writeAsBytes(response.bodyBytes);
            try {
              mediaIds.add(await s.upload(file.path, mime));
            } finally {
              await file.delete();
            }
          } else if (File(reference).isAbsolute) {
            mediaIds.add(await s.upload(reference, mime));
          } else {
            mediaIds.add(await s.uploadAsset(reference, mime));
          }
        }
        overlayMedia.addAll(mediaIds);
        publishedStickers.add(
          {...sticker}
            ..remove('files')
            ..['mediaIds'] = mediaIds,
        );
      }
      final stickerOnly =
          kind == 'story' && text.text.trim().isEmpty && stickers.isNotEmpty;
      final previous = highlightAfterPublish
          ? s
                .stories(s.myId, archive: true)
                .map((story) => story.str('id'))
                .toSet()
          : const <String>{};
      await s.act('post', {
        'kind': kind,
        'idempotencyKey': draftId,
        'text': stickerOnly ? 'Storia con sticker' : text.text.trim(),
        'location': location.text.trim(),
        'media': media.isEmpty ? '' : media.first,
        'mediaItems': kind == 'story' ? [...media, ...overlayMedia] : const [],
        'style': {
          ...style,
          'audio': track,
          'stickers': publishedStickers,
          'stickerOnly': stickerOnly,
        },
        'audience': selectedAudience,
      });
      if (mounted && highlightAfterPublish) {
        final created = s
            .stories(s.myId)
            .where((story) => !previous.contains(story.str('id')))
            .firstOrNull;
        if (created != null) await addStoryHighlight(context, created);
      }
      if (mounted) {
        unawaited(Drafts.delete('${s.server}|${s.myId}', draftId));
        Navigator.pop(context);
        notice(
          context,
          kind == 'story' ? 'Storia pubblicata' : 'Contenuto pubblicato',
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    if (kind == 'post') return PostComposer(initialFiles: files);
    final story = kind == 'story';
    if (story && cameraStage)
      return StoryCamera(
        modePicker: widget.modePicker,
        onMedia: (path) {
          setState(() {
            files = [path];
            cameraStage = false;
          });
        },
        onCreate: () {
          setState(() => cameraStage = false);
        },
        onMode: (mode) => setState(() {
          kind = mode;
          cameraStage = false;
        }),
      );
    if (!story) return reelComposer(c);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Theme(
        data: gpixTheme(Brightness.dark),
        child: Builder(builder: (c) => storyEditor(c)),
      ),
    );
  }

  Widget reelComposer(BuildContext c) => Scaffold(
    backgroundColor: Theme.of(c).canvasColor,
    appBar: AppBar(
      centerTitle: true,
      leading: IconButton(
        tooltip: 'Annulla',
        onPressed: busy ? null : () => Navigator.pop(c),
        icon: GIcon(CupertinoIcons.xmark, color: foreground(c)),
      ),
      title: const Text('Nuovo reel'),
      actions: [
        IconButton(
          key: const ValueKey('save-reel-draft'),
          tooltip: 'Salva bozza',
          onPressed: busy ? null : () => saveDraft(feedback: true),
          icon: GIcon(CupertinoIcons.doc_text, color: foreground(c)),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: FilledButton(
        onPressed: busy || files.isEmpty ? null : publish,
        child: Text(busy ? 'Pubblicazione…' : 'Condividi reel'),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (busy)
          ValueListenableBuilder<double>(
            valueListenable: GpixScope.of(c).uploadProgress,
            builder: (c, value, _) => LinearProgressIndicator(
              value: value > 0 && value < 1 ? value : null,
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          height: (MediaQuery.sizeOf(c).height * .48).clamp(220.0, 430.0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(c).colorScheme.surfaceContainerLow,
          ),
          child: files.isEmpty
              ? CreationEmpty(
                  icon: CupertinoIcons.play_rectangle,
                  title: 'Crea il tuo reel',
                  description: 'Scegli un video oppure registralo adesso.',
                  action: 'Scegli video',
                  onPressed: busy ? null : () => pick(video: true),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: Colors.black,
                      child: ClipPlayer(
                        reference: files.first,
                        fit: BoxFit.contain,
                        active:
                            TickerMode.of(c) &&
                            (ModalRoute.of(c)?.isCurrent ?? true),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: MediaToolButton(
                        icon: CupertinoIcons.photo,
                        label: 'Cambia video',
                        onPressed: busy ? null : () => pick(video: true),
                      ),
                    ),
                  ],
                ),
        ),
        if (files.isEmpty)
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : () => pick(camera: true, video: true),
              icon: GIcon(CupertinoIcons.videocam, color: foreground(c)),
              label: Text(
                'Registra video',
                style: TextStyle(color: foreground(c)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: text,
            minLines: 2,
            maxLines: 5,
            style: TextStyle(color: foreground(c)),
            decoration: const InputDecoration(
              hintText: 'Scrivi una didascalia…',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: GIcon(CupertinoIcons.person_2, color: foreground(c)),
          title: const Text('Pubblico'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reelAudience == 'close' ? 'Amici più stretti' : 'Follower'),
              const SizedBox(width: 6),
              const GIcon(CupertinoIcons.chevron_down, size: 14),
            ],
          ),
          onTap: () => sheet(
            c,
            Builder(
              builder: (menu) => Column(
                children: [
                  for (final item in const [
                    ('followers', 'Follower'),
                    ('close', 'Amici più stretti'),
                  ])
                    ListTile(
                      title: Text(item.$2),
                      trailing: reelAudience == item.$1
                          ? const GIcon(
                              CupertinoIcons.check_mark,
                              color: auraBlue,
                            )
                          : null,
                      onTap: () {
                        setState(() => reelAudience = item.$1);
                        Navigator.pop(menu);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: TextField(
            controller: location,
            style: TextStyle(color: foreground(c)),
            decoration: InputDecoration(
              hintText: 'Aggiungi luogo',
              prefixIcon: GIcon(
                CupertinoIcons.placemark,
                color: foreground(c),
                size: 20,
              ),
              filled: false,
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> editStoryText() async {
    final result = await textDialog(context, 'Testo della storia', text.text);
    if (result != null && mounted) setState(() => text.text = result);
  }

  void addStorySticker(StoryStickerTool tool, [J data = const {}]) {
    setState(() {
      if (['poll', 'slider', 'rating'].contains(tool.name)) {
        stickers.removeWhere(
          (item) => ['poll', 'slider', 'rating'].contains(item.str('type')),
        );
      }
      if (tool == StoryStickerTool.music) {
        stickers.removeWhere((item) => item.str('type') == 'music');
      }
      stickers.add({
        'type': tool.name,
        'x': .18 + (stickers.length % 2) * .13,
        'y': .31 + (stickers.length % 4) * .11,
        'size': 52.0,
        'angle': 0.0,
        ...data,
      });
      selectedSticker = stickers.length - 1;
    });
  }

  Future<void> chooseSticker() async {
    final tool = await pickStorySticker(context);
    if (tool == null || !mounted) return;
    switch (tool) {
      case StoryStickerTool.highlight:
        setState(() => highlightAfterPublish = !highlightAfterPublish);
        notice(
          context,
          highlightAfterPublish
              ? 'Sceglierai la raccolta dopo la pubblicazione.'
              : 'Aggiunta alle raccolte annullata.',
        );
      case StoryStickerTool.music:
        final track = await open<J>(context, const MusicPicker());
        if (track != null && mounted) {
          storyMusic = track;
          audio = '';
          addStorySticker(tool, {
            'label': "${track.str('title')} · ${track.str('artist')}",
          });
        }
      case StoryStickerTool.emoji:
      case StoryStickerTool.reaction:
        final emoji = await sheet<String>(
          context,
          Builder(
            builder: (context) => EmojiPicker(
              onSelected: (emoji) => Navigator.pop(context, emoji),
            ),
          ),
          scroll: false,
        );
        if (emoji != null && mounted) addStorySticker(tool, {'emoji': emoji});
      case StoryStickerTool.gif:
        final ref = await sheet<String>(
          context,
          Builder(
            builder: (context) => GiphyGallery(
              onSelected: (ref) => Navigator.pop(context, ref),
              onImport: () => Navigator.pop(context, ''),
            ),
          ),
          scroll: false,
        );
        if (ref == null || !mounted) return;
        final path = ref.isNotEmpty
            ? ref
            : (await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['gif'],
              ))?.files.single.path;
        if (path != null && mounted)
          addStorySticker(tool, {
            'files': [path],
          });
      case StoryStickerTool.photo:
      case StoryStickerTool.frame:
      case StoryStickerTool.strip:
      case StoryStickerTool.cutout:
        final picker = ImagePicker();
        final images = tool == StoryStickerTool.strip
            ? await picker.pickMultiImage(limit: 4, maxWidth: 1200)
            : [
                await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                ),
              ].whereType<XFile>().toList();
        if (images.isEmpty || !mounted) return;
        if (tool == StoryStickerTool.strip && images.length < 2) {
          notice(context, 'Scegli almeno due foto.');
          return;
        }
        addStorySticker(tool, {
          'files': images.take(4).map((image) => image.path).toList(),
        });
      case StoryStickerTool.avatar:
        addStorySticker(tool);
      case StoryStickerTool.time:
        addStorySticker(tool, {'label': TimeOfDay.now().format(context)});
      case StoryStickerTool.poll:
      case StoryStickerTool.slider:
      case StoryStickerTool.rating:
        final result = await editStoryVote(context, tool);
        if (result == null || !mounted) return;
        stickerPoll = {
          'question': result.str('question'),
          'options': result.ids('options'),
        };
        addStorySticker(tool, {
          'label': result.str('question'),
          'palette': result.number('palette'),
          'emoji': result.str('emoji'),
        });
      case StoryStickerTool.countdown:
        final label = await storyStickerInput(
          context,
          tool.label,
          'Nome evento',
        );
        if (label == null || !mounted) return;
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          firstDate: now,
          lastDate: now.add(const Duration(days: 365)),
          initialDate: now,
        );
        if (date == null || !mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time == null || !mounted) return;
        final end = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!end.isAfter(DateTime.now())) {
          notice(context, 'Scegli una data e un’ora future.');
          return;
        }
        addStorySticker(tool, {
          'label': label,
          'end': end.millisecondsSinceEpoch,
        });
      case StoryStickerTool.link:
      case StoryStickerTool.donation:
        final url = await storyStickerInput(
          context,
          tool.label,
          'Indirizzo HTTPS',
          limit: 2048,
          validate: (value) => storyStickerLink(value) == null
              ? 'Inserisci un indirizzo HTTPS valido.'
              : null,
        );
        if (url != null && mounted) {
          addStorySticker(tool, {
            'label': storyStickerLink(url)!.host,
            'url': url,
          });
        }
      case StoryStickerTool.place:
      case StoryStickerTool.mention:
      case StoryStickerTool.hashtag:
      case StoryStickerTool.question:
      case StoryStickerTool.prompt:
        final store = GpixScope.of(context, listen: false);
        final value = await storyStickerInput(
          context,
          tool.label,
          switch (tool) {
            StoryStickerTool.place => 'Nome del luogo',
            StoryStickerTool.mention => 'Nome utente',
            StoryStickerTool.hashtag => 'Parola chiave',
            _ => 'Scrivi qui',
          },
          validate: (value) {
            if (tool == StoryStickerTool.mention &&
                ![store.me, ...store.users].any(
                  (user) =>
                      user.str('username').toLowerCase() ==
                      value.replaceFirst('@', '').toLowerCase(),
                ))
              return 'Profilo non trovato.';
            if (tool == StoryStickerTool.hashtag &&
                !RegExp(r'^#?[a-zA-Z0-9_À-ÿ]+$').hasMatch(value))
              return 'Usa una parola senza spazi.';
            return null;
          },
        );
        if (value == null || !mounted) return;
        addStorySticker(tool, {
          'label': switch (tool) {
            StoryStickerTool.mention => '@${value.replaceFirst('@', '')}',
            StoryStickerTool.hashtag => '#${value.replaceFirst('#', '')}',
            _ => value,
          },
          if (tool == StoryStickerTool.prompt) 'chain': newId(),
          if (tool == StoryStickerTool.place)
            'url': Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': value,
            }).toString(),
        });
    }
  }

  Future<void> chooseMusic() async {
    await perform(context, () async {
      final f = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav'],
      );
      if (f?.files.single.path != null)
        setState(() {
          audio = f!.files.single.path!;
          storyMusic = null;
          stickers.removeWhere((item) => item.str('type') == 'music');
          selectedSticker = -1;
        });
    });
  }

  Future<void> exportStory() async {
    await perform(context, () async {
      final boundary =
          canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final root = await getTemporaryDirectory();
      final file = File('${root.path}/GPIX-${newId()}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      if (mounted)
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            sharePositionOrigin: Rect.fromLTWH(
              0,
              0,
              MediaQuery.sizeOf(context).width,
              70,
            ),
          ),
        );
    });
  }

  Future<void> friends() async {
    final s = GpixScope.of(context, listen: false);
    await sheet(
      context,
      StatefulBuilder(
        builder: (c, update) => Column(
          children: [
            const Text(
              'Amici più stretti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Solo gli account selezionati possono vedere queste storie.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
            for (final u in s.users.where(
              (u) => u.str('id') != s.myId && !s.blocked(u.str('id')),
            ))
              CheckboxListTile(
                secondary: Avatar(u.str('id'), size: 35),
                title: Text(
                  u.str('username'),
                  style: const TextStyle(fontSize: 14),
                ),
                value: s.state.ids('closeFriends').contains(u.str('id')),
                onChanged: (v) => perform(c, () async {
                  await s.act('closeFriend', {'user': u['id'], 'enabled': v});
                  update(() {});
                }),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: PrimaryButton('Fine', onTap: () => Navigator.pop(c)),
            ),
          ],
        ),
      ),
    );
  }

  Widget storyEditor(BuildContext c) => Stack(
    fit: StackFit.expand,
    children: [
      RepaintBoundary(
        key: canvasKey,
        child: StoryCanvas(
          story: {
            'text': text.text,
            'author': GpixScope.of(c, listen: false).myId,
            'media': files.isEmpty ? '' : files.first,
            'style': style,
          },
          editing: true,
          onStickerTap: (i) => setState(() => selectedSticker = i),
          onStickerMove: (i, d) => setState(() {
            stickers[i]['x'] = (stickers[i].number('x') + d.dx).clamp(0, 1);
            stickers[i]['y'] = (stickers[i].number('y') + d.dy).clamp(0, 1);
            selectedSticker = i;
          }),
          onMove: (p) => setState(() {
            x = p.dx.clamp(.12, .88);
            y = p.dy.clamp(.1, .85);
          }),
        ),
      ),
      if (files.isEmpty && text.text.isEmpty && stickers.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 90, 72, 100),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GIcon(
                  CupertinoIcons.textformat,
                  color: Colors.white,
                  size: 38,
                ),
                const SizedBox(height: 12),
                const Text(
                  'La tua storia inizia qui',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: editStoryText,
                  child: const Text('Scrivi un pensiero'),
                ),
                TextButton(
                  onPressed: () => pick(),
                  child: const Text(
                    'Scegli una foto',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      Positioned(
        top: MediaQuery.paddingOf(c).top + 10,
        left: 12,
        child: tool(CupertinoIcons.xmark, 'Annulla', () async {
          if (await gpixAlert(
                c,
                'Scartare la storia?',
                'Il contenuto non verrà pubblicato.',
                confirm: 'Scarta',
                cancel: true,
                destructive: true,
              ) &&
              mounted)
            Navigator.pop(c);
        }),
      ),
      if (audio.isNotEmpty)
        Positioned(
          top: 13,
          left: 72,
          right: 72,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const GIcon(
                  CupertinoIcons.music_note_2,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    audio.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => audio = ''),
                  child: const GIcon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      Positioned(
        top: MediaQuery.paddingOf(c).top + 10,
        right: 12,
        child: Column(
          children: [
            tool(CupertinoIcons.textformat, 'Testo', editStoryText),
            const SizedBox(height: 10),
            tool(
              CupertinoIcons.smiley,
              'Sticker',
              () => perform(c, chooseSticker),
            ),
            const SizedBox(height: 10),
            tool(CupertinoIcons.music_note_2, 'Musica da file', chooseMusic),
            const SizedBox(height: 10),
            tool(
              CupertinoIcons.arrow_down_to_line,
              'Esporta immagine',
              exportStory,
            ),
            const SizedBox(height: 10),
            tool(
              CupertinoIcons.circle_lefthalf_fill,
              'Sfondo',
              () => setState(() => background = (background + 1) % 4),
            ),
            const SizedBox(height: 10),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expandedTools
                  ? Column(
                      children: [
                        tool(CupertinoIcons.photo, 'Foto', () => pick()),
                        const SizedBox(height: 10),
                        tool(
                          CupertinoIcons.videocam,
                          'Video',
                          () => pick(video: true),
                        ),
                        const SizedBox(height: 10),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            tool(
              expandedTools
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              expandedTools ? 'Riduci strumenti' : 'Altri strumenti',
              () => setState(() => expandedTools = !expandedTools),
            ),
          ],
        ),
      ),
      Positioned(
        left: 18,
        right: 18,
        bottom:
            110 +
            MediaQuery.paddingOf(c).bottom +
            (text.text.isNotEmpty ? 70 : 0) +
            (selectedSticker >= 0 ? 48 : 0),
        child: TextField(
          controller: caption,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
          minLines: 1,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Aggiungi una didascalia…',
            hintStyle: const TextStyle(color: Colors.white70),
            fillColor: const Color(0xcc111111),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white38),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(c).bottom),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xe6000000)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedSticker >= 0 && selectedSticker < stickers.length)
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Elimina sticker',
                      onPressed: () => setState(() {
                        final removed = stickers.removeAt(selectedSticker);
                        if (removed.str('type') == 'music') storyMusic = null;
                        if ([
                          'poll',
                          'slider',
                          'rating',
                        ].contains(removed.str('type'))) {
                          stickerPoll = null;
                        }
                        selectedSticker = -1;
                      }),
                      icon: GIcon(
                        CupertinoIcons.trash,
                        color: foreground(c),
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: stickers[selectedSticker].number('size', 52),
                        min: 24,
                        max: 100,
                        onChanged: (v) => setState(
                          () => stickers[selectedSticker]['size'] = v,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ruota sticker',
                      onPressed: () => setState(
                        () => stickers[selectedSticker]['angle'] =
                            stickers[selectedSticker].number('angle') + .2,
                      ),
                      icon: GIcon(
                        CupertinoIcons.rotate_right,
                        color: foreground(c),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              if (text.text.isNotEmpty) ...[
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                            label: Text(
                              ['Classico', 'Moderno', 'Elegante'][i],
                              style: const TextStyle(fontSize: 10),
                            ),
                            selected: font == i,
                            onSelected: (_) => setState(() => font = i),
                          ),
                        ),
                      for (var i = 0; i < storyColors.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => color = i),
                          child: Container(
                            width: 25,
                            height: 25,
                            margin: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: storyColors[i],
                              border: Border.all(
                                color: color == i ? auraBlue : Colors.white38,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Slider(
                    value: size,
                    min: 18,
                    max: 48,
                    onChanged: (v) => setState(() => size = v),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => publish(),
                        style: FilledButton.styleFrom(
                          backgroundColor: subdued(c),
                          foregroundColor: foreground(c),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 16,
                          ),
                        ),
                        icon: Avatar(GpixScope.of(c).myId, size: 25),
                        label: const Text(
                          'La tua storia',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onLongPress: friends,
                        child: FilledButton.icon(
                          onPressed: busy
                              ? null
                              : () async {
                                  if (GpixScope.of(
                                    c,
                                    listen: false,
                                  ).state.ids('closeFriends').isEmpty)
                                    await friends();
                                  if (mounted &&
                                      GpixScope.of(
                                        c,
                                        listen: false,
                                      ).state.ids('closeFriends').isNotEmpty)
                                    publish(audience: 'close');
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: subdued(c),
                            foregroundColor: foreground(c),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 16,
                            ),
                          ),
                          icon: const GIcon(
                            CupertinoIcons.star_fill,
                            color: Colors.greenAccent,
                            size: 22,
                          ),
                          label: const Text(
                            'Amici più stretti',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Condividi',
                      onPressed: busy ? null : () => publish(),
                      style: IconButton.styleFrom(
                        backgroundColor: auraBlue,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const GIcon(
                              CupertinoIcons.arrow_right,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget tool(IconData icon, String label, VoidCallback tap) =>
      MediaToolButton(icon: icon, label: label, onPressed: busy ? null : tap);
}
