import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

class MusicPicker extends StatefulWidget {
  const MusicPicker({super.key});
  @override
  State<MusicPicker> createState() => _MusicPickerState();
}

class _MusicPickerState extends State<MusicPicker> with WidgetsBindingObserver {
  final audio = AudioPlayer();
  List<J> tracks = [];
  String query = '', playing = '', error = '';
  J? selected;
  bool loading = true;
  double start = 0, duration = 15;
  Timer? stop;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    try {
      final values = await GpixScope.of(context, listen: false).musicTracks();
      if (mounted) setState(() => tracks = values);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> preview(J track) async {
    await perform(context, () async {
      stop?.cancel();
      await audio.stop();
      if (playing == track.str('id')) {
        setState(() => playing = '');
        return;
      }
      final uri = GpixScope.of(context, listen: false).url(track.str('audio'));
      await audio.play(
        UrlSource(uri),
        position: Duration(milliseconds: (start * 1000).round()),
      );
      if (mounted) setState(() => playing = track.str('id'));
      stop = Timer(Duration(milliseconds: (duration * 1000).round()), () {
        audio.pause();
        if (mounted) setState(() => playing = '');
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      audio.pause();
      stop?.cancel();
      if (mounted) setState(() => playing = '');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop?.cancel();
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final values = tracks
        .where(
          (t) => '${t.str('title')} ${t.str('artist')} ${t.str('genre')}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musica'),
        actions: [
          if (selected != null)
            TextButton(
              onPressed: () => Navigator.pop(c, <String, dynamic>{
                ...selected!,
                'start': start,
                'clipDuration': duration,
              }),
              child: const Text('Fine'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca brani, artisti o generi',
                prefixIcon: const Icon(CupertinoIcons.search),
                filled: true,
                fillColor: subdued(c),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(error, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                loading = true;
                                error = '';
                              });
                              load();
                            },
                            child: const Text('Riprova'),
                          ),
                        ],
                      ),
                    ),
                  )
                : values.isEmpty
                ? const EmptyState(
                    CupertinoIcons.music_note_2,
                    'Nessun brano',
                    'Prova un altro titolo o artista.',
                  )
                : ListView.builder(
                    itemCount: values.length,
                    itemBuilder: (c, i) {
                      final t = values[i];
                      final chosen = selected?.str('id') == t.str('id');
                      return ListTile(
                        onTap: () {
                          stop?.cancel();
                          audio.stop();
                          setState(() {
                            selected = t;
                            start = 0;
                            duration = t
                                .number('duration', 30)
                                .clamp(1, 15)
                                .toDouble();
                            playing = '';
                          });
                        },
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: violet.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            chosen
                                ? CupertinoIcons.check_mark
                                : CupertinoIcons.music_note_2,
                            color: violet,
                          ),
                        ),
                        title: Text(
                          t.str('title'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${t.str('artist')} · ${t.str('genre')}',
                        ),
                        trailing: IconButton(
                          tooltip: playing == t.str('id')
                              ? 'Ferma anteprima'
                              : 'Ascolta anteprima',
                          onPressed: () {
                            if (!chosen)
                              setState(() {
                                selected = t;
                                start = 0;
                                duration = t
                                    .number('duration', 30)
                                    .clamp(1, 15)
                                    .toDouble();
                              });
                            preview(t);
                          },
                          icon: Icon(
                            playing == t.str('id')
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 21,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (selected != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: subdued(c),
                  border: Border(
                    top: BorderSide(color: Theme.of(c).dividerColor),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${selected!.str('title')} · ${start.round()}s–${(start + duration).round()}s',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: start,
                      min: 0,
                      max: (selected!.number('duration', 30) - duration).clamp(
                        0,
                        600,
                      ),
                      onChanged: (v) {
                        stop?.cancel();
                        audio.pause();
                        setState(() {
                          start = v;
                          playing = '';
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final seconds in [15.0, 30.0])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: ChoiceChip(
                              label: Text('${seconds.round()} s'),
                              selected: duration == seconds,
                              onSelected:
                                  selected!.number('duration', 30) < seconds
                                  ? null
                                  : (_) {
                                      stop?.cancel();
                                      audio.pause();
                                      setState(() {
                                        duration = seconds;
                                        start = start.clamp(
                                          0,
                                          selected!.number('duration', 30) -
                                              duration,
                                        );
                                        playing = '';
                                      });
                                    },
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
    );
  }
}
