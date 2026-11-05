import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart' show people;

class PostExtras extends StatelessWidget {
  final J post;
  const PostExtras({super.key, required this.post});
  @override
  Widget build(BuildContext c) {
    final style = post.obj('style'),
        poll = style.obj('poll'),
        options = poll.ids('options');
    final counts =
        (poll['counts'] as List?)?.map((v) => (v as num).toInt()).toList() ??
        List<int>.filled(options.length, 0);
    final total = counts.fold<int>(0, (a, b) => a + b),
        mine = poll.number('myVote', -1).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (style.flag('aiLabel'))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '✧ Contenuto con etichetta IA',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          if (style.str('topic').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '# ${style.str('topic')}',
                style: const TextStyle(
                  color: violet,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          if (style.str('audio').isNotEmpty)
            PostAudio(
              reference: style.str('audio'),
              title: style.str('audioName', 'Audio originale'),
              start: style.obj('music').number('start'),
              duration: style.obj('music').number('clipDuration'),
            ),
          if (style.ids('taggedUsers').isNotEmpty)
            TextButton.icon(
              onPressed: () =>
                  people(c, style.ids('taggedUsers'), 'Persone taggate'),
              icon: const GIcon(CupertinoIcons.person_crop_rectangle, size: 17),
              label: Text(
                '${style.ids('taggedUsers').length} persone taggate',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (options.isNotEmpty) ...[
            Text(
              poll.str('question'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => perform(
                    c,
                    () => GpixScope.of(
                      c,
                      listen: false,
                    ).act('pollVote', {'id': post.str('id'), 'choice': i}),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 43,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      border: Border.all(color: mine == i ? violet : line),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        if (mine >= 0)
                          FractionallySizedBox(
                            widthFactor: total == 0 ? 0 : counts[i] / total,
                            heightFactor: 1,
                            child: ColoredBox(
                              color: violet.withValues(alpha: .12),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  options[i],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (mine == i)
                                const Icon(
                                  CupertinoIcons.check_mark,
                                  color: violet,
                                  size: 16,
                                ),
                              if (mine >= 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Text(
                                    '${total == 0 ? 0 : (counts[i] * 100 / total).round()}%',
                                    style: const TextStyle(
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
                  ),
                ),
              ),
            Text(
              '$total ${total == 1 ? 'voto' : 'voti'}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class PostAudio extends StatefulWidget {
  final String reference, title;
  final double start, duration;
  const PostAudio({
    super.key,
    required this.reference,
    required this.title,
    this.start = 0,
    this.duration = 0,
  });
  @override
  State<PostAudio> createState() => _PostAudioState();
}

class _PostAudioState extends State<PostAudio> with WidgetsBindingObserver {
  AudioPlayer? audio;
  bool playing = false;
  Timer? clipStop;
  StreamSubscription<void>? completed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      clipStop?.cancel();
      audio?.pause();
      if (mounted) setState(() => playing = false);
    }
  }

  Future<void> toggle() async {
    await perform(context, () async {
      audio ??= AudioPlayer();
      completed ??= audio!.onPlayerComplete.listen((_) {
        if (mounted) setState(() => playing = false);
      });
      clipStop?.cancel();
      if (playing)
        await audio!.pause();
      else {
        final ref = GpixScope.of(context, listen: false).url(widget.reference);
        await audio!.play(
          ref.startsWith('https://')
              ? UrlSource(ref)
              : ref.startsWith('/')
              ? DeviceFileSource(ref)
              : AssetSource('media/$ref'),
          position: Duration(milliseconds: (widget.start * 1000).round()),
        );
        if (widget.duration > 0)
          clipStop = Timer(
            Duration(milliseconds: (widget.duration * 1000).round()),
            () {
              audio?.pause();
              if (mounted) setState(() => playing = false);
            },
          );
      }
      if (mounted) setState(() => playing = !playing);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clipStop?.cancel();
    completed?.cancel();
    audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: IconButton(
      tooltip: playing ? 'Pausa audio' : 'Ascolta audio',
      onPressed: toggle,
      icon: GIcon(
        playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
        size: 18,
      ),
    ),
    title: Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    subtitle: const Text(
      'Audio del post',
      style: TextStyle(color: muted, fontSize: 10),
    ),
  );
}
