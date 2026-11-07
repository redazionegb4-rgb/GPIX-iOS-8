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
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import '../ui/creation.dart';
import 'social.dart';
import 'video.dart';
import 'emoji_picker.dart';
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
  const StoryCanvas({
    super.key,
    required this.story,
    this.editing = false,
    this.playing = false,
    this.onMove,
    this.onVideoDuration,
    this.onStickerMove,
    this.onStickerTap,
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
            if (story.str('text').isNotEmpty)
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
            for (var i = 0; i < style.rows('stickers').length; i++)
              Positioned(
                left: box.maxWidth * style.rows('stickers')[i].number('x', .4),
                top: box.maxHeight * style.rows('stickers')[i].number('y', .5),
                child: GestureDetector(
                  onTap: editing ? () => onStickerTap?.call(i) : null,
                  onPanUpdate: editing
                      ? (d) => onStickerMove?.call(
                          i,
                          Offset(
                            d.delta.dx / box.maxWidth,
                            d.delta.dy / box.maxHeight,
                          ),
                        )
                      : null,
                  child: Transform.rotate(
                    angle: style.rows('stickers')[i].number('angle'),
                    child: Text(
                      style.rows('stickers')[i].str('emoji'),
                      style: TextStyle(
                        fontSize: style.rows('stickers')[i].number('size', 52),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
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
        );
      } catch (_) {}
    }
    if (mounted && p.str('author') != s.myId)
      perform(context, () => s.act('see', {'id': p['id']}));
  }

  void next(int step) {
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
      index += step;
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
                  d.localPosition.dx < MediaQuery.sizeOf(c).width * .3 ? -1 : 1,
                ),
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0).abs() > 150)
                    next((d.primaryVelocity ?? 0) < 0 ? 1 : -1);
                },
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 200) Navigator.pop(c);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      StoryCanvas(
                        key: ValueKey(p['id']),
                        story: p,
                        onVideoDuration: (duration) {
                          if (!mounted || duration.inMilliseconds <= 0) return;
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
                      if (reactions) const ColoredBox(color: Colors.black45),
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
                                      borderRadius: BorderRadius.circular(2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 37),
                            child: LayoutBuilder(
                              builder: (c, b) => GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
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
            if (own)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        progress.stop();
                        await people(c, s.viewers(p), 'Visualizzazioni');
                        if (mounted) progress.forward();
                      },
                      icon: const GIcon(
                        CupertinoIcons.eye,
                        color: Colors.white,
                      ),
                      label: Text(
                        '${s.viewers(p).length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Spacer(),
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
  final bool editStory, studio;
  final J? initialDraft;
  final VoidCallback? onEditorOpened;
  const Composer({
    super.key,
    required this.kind,
    this.editStory = false,
    this.studio = false,
    this.initialDraft,
    this.onEditorOpened,
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
  final caption = TextEditingController();
  final canvasKey = GlobalKey();
  final List<J> stickers = [];
  int selectedSticker = -1;
  bool busy = false, cameraStage = false;
  @override
  void initState() {
    super.initState();
    kind = widget.kind;
    draftId = widget.initialDraft?.str('id') ?? newId();
    if (widget.initialDraft != null) {
      final d = widget.initialDraft!;
      files = d.ids('files');
      text.text = d.str('text');
      location.text = d.str('location');
      caption.text = d.str('caption');
      reelAudience = d.str('audience') == 'close' ? 'close' : 'followers';
      final st = d.obj('style');
      audio = st.str('audio');
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

  Future<void> chooseMedia({bool camera = false}) async {
    if (kind != 'story') {
      await pick(camera: camera, video: kind == 'reel');
      return;
    }
    await sheet(
      context,
      Column(
        children: [
          ActionRow(CupertinoIcons.photo, 'Foto', () {
            Navigator.pop(context);
            pick(camera: camera);
          }),
          ActionRow(CupertinoIcons.videocam, 'Video', () {
            Navigator.pop(context);
            pick(camera: camera, video: true);
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> publish({String? audience}) async {
    final selectedAudience =
        audience ?? (kind == 'reel' ? reelAudience : 'all');
    await saveDraft();
    if (!mounted) return;
    if (files.isEmpty && !(kind == 'story' && text.text.trim().isNotEmpty)) {
      notice(context, 'Aggiungi un contenuto prima di pubblicare.');
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
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
      final track = audio.isEmpty
          ? ''
          : await s.upload(
              audio,
              audio.endsWith('.mp3')
                  ? 'audio/mpeg'
                  : audio.endsWith('.wav')
                  ? 'audio/wav'
                  : 'audio/mp4',
            );
      await s.act('post', {
        'kind': kind,
        'idempotencyKey': draftId,
        'text': text.text.trim(),
        'location': location.text.trim(),
        'media': media.isEmpty ? '' : media.first,
        'mediaItems': kind == 'post' ? media : [],
        'style': {...style, 'audio': track},
        'audience': selectedAudience,
      });
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
        showModes: !widget.studio,
        onMedia: (path) {
          setState(() {
            files = [path];
            cameraStage = false;
          });
          widget.onEditorOpened?.call();
        },
        onCreate: () {
          setState(() => cameraStage = false);
          widget.onEditorOpened?.call();
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
                        active: TickerMode.of(c),
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

  Future<void> chooseMusic() async {
    await perform(context, () async {
      final f = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav'],
      );
      if (f?.files.single.path != null)
        setState(() => audio = f!.files.single.path!);
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
            'media': files.isEmpty ? '' : files.first,
            'style': style,
          },
          editing: true,
          onStickerTap: (i) => setState(() => selectedSticker = i),
          onStickerMove: (i, d) => setState(() {
            stickers[i]['x'] = (stickers[i].number('x') + d.dx).clamp(0, .8);
            stickers[i]['y'] = (stickers[i].number('y') + d.dy).clamp(.05, .85);
            selectedSticker = i;
          }),
          onMove: (p) => setState(() {
            x = p.dx.clamp(.12, .88);
            y = p.dy.clamp(.1, .85);
          }),
        ),
      ),
      if (files.isEmpty && text.text.isEmpty)
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
                  onPressed: chooseMedia,
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
              () => sheet(
                c,
                EmojiPicker(
                  onSelected: (emoji) {
                    setState(() {
                      stickers.add({
                        'emoji': emoji,
                        'x': .18 + (stickers.length % 3) * .2,
                        'y': .35 + (stickers.length ~/ 3 % 3) * .15,
                        'size': 52.0,
                        'angle': 0.0,
                      });
                      selectedSticker = stickers.length - 1;
                    });
                    Navigator.pop(c);
                  },
                ),
                scroll: false,
              ),
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
            tool(CupertinoIcons.chevron_down, 'Galleria', chooseMedia),
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
                        stickers.removeAt(selectedSticker);
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
