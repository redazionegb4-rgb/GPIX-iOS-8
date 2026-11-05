import 'dart:io';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart';

class ClipPlayer extends StatefulWidget {
  final String reference;
  final bool active;
  final BoxFit fit;
  final ValueChanged<Duration>? onDuration;
  const ClipPlayer({
    super.key,
    required this.reference,
    this.active = true,
    this.fit = BoxFit.contain,
    this.onDuration,
  });
  @override
  State<ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<ClipPlayer> with WidgetsBindingObserver {
  mk.Player? player;
  VideoController? controller;
  final subscriptions = <StreamSubscription<dynamic>>[];
  String? error;
  bool mutedVideo = false, playing = false, buffering = true, software = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && player == null && error == null) initialize();
  }

  Future<void> initialize({bool softwareDecoder = false}) async {
    final current = ++generation;
    software = softwareDecoder;
    error = null;
    buffering = true;
    try {
      final reference = GpixScope.of(
        context,
        listen: false,
      ).url(widget.reference);
      if (reference.startsWith('/') &&
          (!await File(reference).exists() ||
              await File(reference).length() == 0)) {
        throw const FileSystemException(
          'Il file video non è più disponibile. Selezionalo nuovamente.',
        );
      }
      if (!mounted || current != generation || !widget.active) return;
      mk.MediaKit.ensureInitialized();
      final next = mk.Player(
        configuration: const mk.PlayerConfiguration(
          bufferSize: 16 * 1024 * 1024,
        ),
      );
      player = next;
      controller = VideoController(
        next,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: !softwareDecoder,
          hwdec: softwareDecoder ? 'no' : 'auto-safe',
        ),
      );
      subscriptions.add(
        next.stream.error.listen((message) {
          if (!mounted || current != generation) return;
          if (!softwareDecoder) {
            release();
            initialize(softwareDecoder: true);
          } else {
            setState(
              () => error = 'Questo video non è riproducibile. $message',
            );
          }
        }),
      );
      subscriptions.add(
        next.stream.playing.listen((value) {
          if (mounted && current == generation) setState(() => playing = value);
        }),
      );
      subscriptions.add(
        next.stream.buffering.listen((value) {
          if (mounted && current == generation)
            setState(() => buffering = value);
        }),
      );
      subscriptions.add(
        next.stream.duration.listen((value) {
          if (mounted && current == generation && value > Duration.zero)
            widget.onDuration?.call(value);
        }),
      );
      await next.setPlaylistMode(mk.PlaylistMode.single);
      await next.setVolume(mutedVideo ? 0 : 100);
      final uri = reference.startsWith('/')
          ? Uri.file(reference).toString()
          : reference.contains('://')
          ? reference
          : 'asset:///assets/media/$reference';
      await next.open(mk.Media(uri), play: widget.active);
      if (mounted && current == generation) setState(() {});
    } catch (e) {
      if (mounted && current == generation)
        setState(
          () => error = e is FileSystemException
              ? e.message
              : 'Impossibile aprire il video. ${e.toString()}',
        );
    }
  }

  void release() {
    generation++;
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
    final old = player;
    player = null;
    controller = null;
    if (old != null) unawaited(old.dispose().catchError((Object _) {}));
  }

  @override
  void didUpdateWidget(ClipPlayer old) {
    super.didUpdateWidget(old);
    if (old.reference != widget.reference || old.active != widget.active) {
      release();
      error = null;
      if (widget.active) initialize();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      player?.play();
    } else {
      player?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    if (!widget.active) return const ColoredBox(color: Colors.black);
    if (error != null)
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GIcon(
                  CupertinoIcons.exclamationmark_circle,
                  color: Colors.white70,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                TextButton(
                  onPressed: () {
                    release();
                    setState(() => error = null);
                    initialize(softwareDecoder: true);
                  },
                  child: const Text('Riprova con decoder compatibile'),
                ),
              ],
            ),
          ),
        ),
      );
    if (controller == null)
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    return GestureDetector(
      onTap: () => player?.playOrPause(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: controller!,
            controls: NoVideoControls,
            fit: widget.fit,
            pauseUponEnteringBackgroundMode: false,
          ),
          if (buffering)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          if (!playing && !buffering)
            const Center(
              child: GIcon(
                CupertinoIcons.play_fill,
                color: Colors.white,
                size: 48,
              ),
            ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton(
              tooltip: mutedVideo ? 'Attiva audio' : 'Disattiva audio',
              onPressed: () {
                setState(() => mutedVideo = !mutedVideo);
                player?.setVolume(mutedVideo ? 0 : 100);
              },
              icon: GIcon(
                mutedVideo
                    ? CupertinoIcons.speaker_slash_fill
                    : CupertinoIcons.speaker_2_fill,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Reels extends StatefulWidget {
  final bool active;
  final String? initial;
  const Reels({super.key, this.active = true, this.initial});
  @override
  State<Reels> createState() => _ReelsState();
}

class _ReelsState extends State<Reels> {
  int page = 0;
  PageController? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller == null) {
      final reels = GpixScope.of(context, listen: false).reels;
      page = widget.initial == null
          ? 0
          : reels
                .indexWhere((r) => r.str('id') == widget.initial)
                .clamp(0, reels.length);
      controller = PageController(initialPage: page);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), reels = s.reels;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (reels.isEmpty)
              const Center(
                child: Text(
                  'I nuovi reel appariranno qui.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            else
              PageView.builder(
                controller: controller,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (c, i) {
                  final p = reels[i], uid = p.str('author');
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipPlayer(
                        key: ValueKey(p['id']),
                        reference: p.str('media'),
                        active:
                            widget.active &&
                            i == page &&
                            (ModalRoute.of(c)?.isCurrent ?? true),
                        fit: BoxFit.cover,
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.center,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 17,
                        right: 75,
                        bottom: 29,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => open(c, Profile(user: uid)),
                              child: Row(
                                children: [
                                  Avatar(uid, size: 33),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      s.user(uid).str('username'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 13),
                            Text(
                              p.str('text'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Row(
                              children: [
                                GIcon(
                                  CupertinoIcons.music_note_2,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Audio originale',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 60,
                        child: Column(
                          children: [
                            action(
                              p.ids('likes').contains(s.myId)
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              '${p.ids('likes').length}',
                              () => perform(
                                c,
                                () => s.act('like', {
                                  'id': p['id'],
                                  'enabled': !p.ids('likes').contains(s.myId),
                                }),
                              ),
                              color: p.ids('likes').contains(s.myId)
                                  ? danger
                                  : Colors.white,
                            ),
                            const SizedBox(height: 18),
                            action(
                              CupertinoIcons.chat_bubble,
                              '${p.rows('comments').length}',
                              () => comments(c, p.str('id')),
                            ),
                            const SizedBox(height: 18),
                            action(
                              CupertinoIcons.paperplane,
                              'Invia',
                              () => sharePost(c, p),
                            ),
                            const SizedBox(height: 15),
                            action(
                              p.flag('saved')
                                  ? CupertinoIcons.bookmark_fill
                                  : CupertinoIcons.bookmark,
                              'Salva',
                              () => perform(
                                c,
                                () => s.act('save', {
                                  'id': p['id'],
                                  'enabled': !p.flag('saved'),
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              tooltip: 'Opzioni reel',
                              onPressed: () => postMenu(c, p),
                              icon: const GIcon(
                                CupertinoIcons.ellipsis,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            Positioned(
              top: 8,
              left: widget.initial == null ? 18 : 53,
              child: const Text(
                'Reel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 25,
                ),
              ),
            ),
            if (widget.initial != null)
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(c),
                  icon: const GIcon(CupertinoIcons.back, color: Colors.white),
                ),
              ),
            Positioned(
              top: 0,
              right: 8,
              child: IconButton(
                tooltip: 'Crea reel',
                onPressed: () => createMenu(c),
                icon: const GIcon(
                  CupertinoIcons.camera,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget action(
    IconData icon,
    String count,
    VoidCallback tap, {
    Color color = Colors.white,
  }) => InkWell(
    onTap: tap,
    child: SizedBox(
      width: 46,
      child: Column(
        children: [
          GIcon(icon, size: 29, color: color),
          const SizedBox(height: 5),
          Text(
            count,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
