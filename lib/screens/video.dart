import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import '../core/store.dart';
import '../ui/kit.dart';

export 'reels.dart' show Reels, reelDockBottom, reelDockHeight;

typedef ClipProgress = ({Duration position, Duration duration});

class ClipControls {
  final progress = ValueNotifier<ClipProgress>((
    position: Duration.zero,
    duration: Duration.zero,
  ));
  final hasSubtitles = ValueNotifier<bool>(false);
  _ClipPlayerState? _player;

  void togglePlayback() => _player?._toggle();
  void seek(double fraction) => _player?._seek(fraction);

  void dispose() {
    _player = null;
    progress.dispose();
    hasSubtitles.dispose();
  }
}

class ClipPlayer extends StatefulWidget {
  const ClipPlayer({
    super.key,
    required this.reference,
    this.active = true,
    this.fit = BoxFit.contain,
    this.onDuration,
    this.controls,
    this.placeholder,
    this.suspended = false,
    this.loop = true,
    this.showSubtitles = true,
    this.muted,
    this.subtitleBottom = 24,
    this.onCompleted,
    this.onViewed,
  });

  final String reference;
  final bool active, suspended, loop, showSubtitles;
  final BoxFit fit;
  final bool? muted;
  final double subtitleBottom;
  final ClipControls? controls;
  final Widget? placeholder;
  final ValueChanged<Duration>? onDuration;
  final VoidCallback? onCompleted, onViewed;

  @override
  State<ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<ClipPlayer> with WidgetsBindingObserver {
  mk.Player? _player;
  VideoController? _video;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  String? _error;
  bool _muted = false, _playing = false, _buffering = true;
  bool _starting = false, _ready = false, _userPaused = false;
  bool _foreground = true, _viewed = false;
  int _generation = 0;

  bool get _shouldPlay =>
      widget.active && !widget.suspended && _foreground && !_userPaused;
  bool get _isMuted => widget.muted ?? _muted;
  double get _volume => _isMuted ? 0 : 100;
  bool _current(int generation) => mounted && generation == _generation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.controls?._player = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_start());
  }

  Future<void> _start({bool software = false}) async {
    if (!widget.active ||
        widget.reference.isEmpty ||
        _starting ||
        _player != null ||
        _error != null)
      return;

    final generation = ++_generation;
    _starting = true;
    _buffering = true;
    try {
      final source = GpixScope.of(context, listen: false).url(widget.reference);
      if (source.startsWith('/') && !await File(source).exists()) {
        throw const FileSystemException('Il file video non è più disponibile.');
      }
      if (!_current(generation)) return;
      mk.MediaKit.ensureInitialized();
      final player = mk.Player(
        configuration: const mk.PlayerConfiguration(
          bufferSize: 16 * 1024 * 1024,
        ),
      );
      _player = player;
      _video = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: !software,
          hwdec: software ? 'no' : 'auto-safe',
        ),
      );
      _subscriptions.addAll([
        player.stream.error.listen((_) {
          if (_current(generation)) _fail(software);
        }),
        player.stream.playing.listen((playing) {
          if (_current(generation) && playing != _playing) {
            setState(() => _playing = playing);
          }
        }),
        player.stream.buffering.listen((buffering) {
          if (_current(generation) && buffering != _buffering) {
            setState(() => _buffering = buffering);
          }
        }),
        player.stream.duration.listen((duration) {
          if (!_current(generation)) return;
          if (duration > Duration.zero) widget.onDuration?.call(duration);
          _publishProgress(player);
        }),
        if (widget.controls != null || widget.onViewed != null)
          player.stream.position.listen((position) {
            if (!_current(generation)) return;
            if (widget.controls != null) _publishProgress(player);
            final duration = player.state.duration;
            final threshold =
                duration > Duration.zero &&
                    duration < const Duration(seconds: 1)
                ? duration * .75
                : const Duration(seconds: 1);
            final onViewed = widget.onViewed;
            if (!_viewed &&
                _shouldPlay &&
                _playing &&
                onViewed != null &&
                position >= threshold) {
              _viewed = true;
              onViewed();
            }
          }),
        if (widget.controls != null) ...[
          player.stream.tracks.listen((tracks) {
            if (_current(generation)) {
              widget.controls?.hasSubtitles.value = tracks.subtitle.any(
                (track) => track.id != 'auto' && track.id != 'no',
              );
            }
          }),
        ],
        player.stream.completed.listen((complete) {
          if (complete &&
              _current(generation) &&
              _ready &&
              !widget.loop &&
              _shouldPlay) {
            widget.onCompleted?.call();
          }
        }),
      ]);
      final uri = source.startsWith('/')
          ? Uri.file(source).toString()
          : source.contains('://')
          ? source
          : 'asset:///assets/media/$source';
      await player.open(mk.Media(uri), play: false);
      if (!_current(generation)) return;
      await player.setPlaylistMode(
        widget.loop ? mk.PlaylistMode.single : mk.PlaylistMode.none,
      );
      if (!_current(generation)) return;
      await player.setVolume(_volume);
      if (!_current(generation)) return;
      setState(() {
        _ready = true;
        _starting = false;
      });
      _publishProgress(player);
      _applyPlayback();
    } catch (error) {
      if (!_current(generation)) return;
      if (_player == null || error is FileSystemException) {
        _release();
        setState(
          () => _error = error is FileSystemException
              ? error.message
              : 'Impossibile aprire il video.',
        );
      } else {
        _fail(software);
      }
    }
  }

  void _publishProgress(mk.Player player) {
    widget.controls?.progress.value = (
      position: player.state.position,
      duration: player.state.duration,
    );
  }

  void _fail(bool software) {
    _release();
    if (software) {
      setState(() => _error = 'Questo video non è riproducibile.');
    } else {
      unawaited(_start(software: true));
    }
  }

  void _release() {
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    _video = null;
    _starting = false;
    _ready = false;
    _playing = false;
    if (player != null) unawaited(player.dispose().catchError((Object _) {}));
  }

  void _applyPlayback() {
    final player = _player;
    if (!_ready || player == null) return;
    final operation = _shouldPlay ? player.play() : player.pause();
    unawaited(operation.catchError((Object _) {}));
  }

  void _toggle() {
    final player = _player;
    if (!_ready || player == null || widget.suspended) return;
    _userPaused = !_userPaused && player.state.playing;
    if (!_userPaused && player.state.completed) {
      unawaited(
        player
            .seek(Duration.zero)
            .then((_) {
              if (mounted && _player == player) _applyPlayback();
            })
            .catchError((Object _) {}),
      );
    } else {
      _applyPlayback();
    }
  }

  void _seek(double fraction) {
    final player = _player;
    if (!_ready || player == null || !fraction.isFinite) return;
    final micros =
        player.state.duration.inMicroseconds * fraction.clamp(0.0, 1.0);
    unawaited(
      player
          .seek(Duration(microseconds: micros.round()))
          .catchError((Object _) {}),
    );
  }

  @override
  void didUpdateWidget(ClipPlayer old) {
    super.didUpdateWidget(old);
    if (old.controls != widget.controls) {
      if (old.controls?._player == this) old.controls?._player = null;
      widget.controls?._player = this;
    }
    if (old.reference != widget.reference) _viewed = false;
    if (old.reference != widget.reference || old.active != widget.active) {
      _release();
      _error = null;
      _userPaused = false;
      final controls = widget.controls;
      if (controls != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.controls == controls && !_ready) {
            controls.progress.value = (
              position: Duration.zero,
              duration: Duration.zero,
            );
            controls.hasSubtitles.value = false;
          }
        });
      }
      unawaited(_start());
      return;
    }
    final player = _player;
    if (!_ready || player == null) return;
    if (old.loop != widget.loop) {
      unawaited(
        player
            .setPlaylistMode(
              widget.loop ? mk.PlaylistMode.single : mk.PlaylistMode.none,
            )
            .catchError((Object _) {}),
      );
    }
    if (old.muted != widget.muted) {
      unawaited(player.setVolume(_volume).catchError((Object _) {}));
    }
    if (old.suspended != widget.suspended) _applyPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _applyPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.controls?._player == this) widget.controls?._player = null;
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final background =
        widget.placeholder ?? const ColoredBox(color: Colors.black);
    if (!widget.active || widget.reference.isEmpty) return background;
    if (_error != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          background,
          const ColoredBox(color: Colors.black54),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _error = null);
                      unawaited(_start(software: true));
                    },
                    child: const Text(
                      'Riprova',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.controls == null ? _toggle : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          background,
          if (_video != null)
            Video(
              controller: _video!,
              controls: NoVideoControls,
              fit: widget.fit,
              pauseUponEnteringBackgroundMode: false,
              subtitleViewConfiguration: widget.controls == null
                  ? const SubtitleViewConfiguration()
                  : SubtitleViewConfiguration(
                      visible: widget.showSubtitles,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        widget.subtitleBottom,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        backgroundColor: Colors.black87,
                      ),
                    ),
            ),
          if (_buffering || !_ready)
            const Center(
              child: SizedBox.square(
                dimension: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          if (!_playing && !_buffering && _ready && !widget.suspended)
            const IgnorePointer(
              child: Center(
                child: GIcon(
                  CupertinoIcons.play_fill,
                  color: Colors.white,
                  size: 45,
                ),
              ),
            ),
          if (widget.controls == null)
            Positioned(
              right: 12,
              bottom: 12,
              child: IconButton(
                tooltip: _isMuted ? 'Attiva audio' : 'Disattiva audio',
                onPressed: () {
                  setState(() => _muted = !_muted);
                  final player = _player;
                  if (player != null)
                    unawaited(
                      player.setVolume(_volume).catchError((Object _) {}),
                    );
                },
                icon: GIcon(
                  _isMuted
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
