import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/data.dart';
import '../core/drafts.dart';
import '../core/reel_editing.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'music_picker.dart';
import 'social.dart' show textDialog;
import 'video.dart';

class ReelEditor extends StatefulWidget {
  const ReelEditor({super.key, this.draft, this.story});

  final J? draft, story;

  @override
  State<ReelEditor> createState() => _ReelEditorState();
}

class _ReelEditorState extends State<ReelEditor> {
  late final id = widget.draft?.str('id', newId()) ?? newId();
  late final description = TextEditingController(
    text: widget.draft?.str('text'),
  );
  late final location = TextEditingController(
    text: widget.draft?.str('location'),
  );
  late final store = GpixScope.of(context, listen: false);
  final clips = <ReelClip>[];
  final picker = ImagePicker();
  final work = <Directory>[];
  late ReelText overlay = ReelText.fromJson(widget.draft?.obj('overlay') ?? {});
  late J music = widget.draft?.obj('music') ?? {};
  late bool originalAudio = widget.draft?['originalAudio'] != false;
  late bool inFeed = widget.draft?['inFeed'] != false;
  late String audience =
      widget.draft?.str('audience', 'all') ??
      widget.story?.str('audience', 'all') ??
      'all';
  String video = '', cover = '';
  String? source;
  int selected = 0;
  bool busy = false, publishing = false;

  int get duration => clips.fold(0, (sum, clip) => sum + clip.durationMs);
  String get account => '${store.server}|${store.myId}';

  @override
  void initState() {
    super.initState();
    if (widget.draft != null || widget.story != null) {
      busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) run(restore);
      });
    }
  }

  @override
  void dispose() {
    description.dispose();
    location.dispose();
    for (final folder in work) {
      if (folder.existsSync()) folder.delete(recursive: true).ignore();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await perform(context, action);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<Directory> folder() async {
    final dir = await reelWorkingDirectory();
    if (!mounted) {
      await dir.delete(recursive: true);
      throw StateError('Editor chiuso');
    }
    work.add(dir);
    return dir;
  }

  Future<void> restore() async {
    final story = widget.story;
    if (story != null) {
      final reference = story.str('media');
      final path = await reelImport(
        store,
        reference,
        extension:
            Uri.tryParse(reference)?.path.toLowerCase().endsWith('.mov') == true
            ? 'mov'
            : 'mp4',
        folder: await folder(),
        name: 'storia',
      );
      final clip = await ReelMedia.prepare(path);
      if (mounted) {
        description.text = story.obj('style').str('caption');
        setState(() => clips.add(clip));
      }
      return;
    }
    final saved = widget.draft!;
    final entries = saved.rows('clips');
    final restored = <ReelClip>[];
    if (entries.isEmpty) {
      for (final path in saved.ids('files')) {
        restored.add(await ReelMedia.prepare(path));
      }
    } else {
      for (final entry in entries) {
        final path = entry.str('path');
        if (await File(path).exists()) {
          restored.add(await ReelMedia.prepare(path, saved: entry));
        }
      }
    }
    if (mounted) setState(() => clips.addAll(restored));
  }

  Future<void> add({required bool camera}) async {
    await run(() async {
      final available = 12 - clips.length;
      if (available <= 0) throw Exception('Puoi aggiungere fino a 12 clip.');
      final files = camera
          ? [
              await picker.pickVideo(
                source: ImageSource.camera,
                maxDuration: const Duration(seconds: 90),
              ),
            ].nonNulls
          : await picker.pickMultipleMedia(limit: available);
      final prepared = <ReelClip>[];
      for (final file in files.take(available)) {
        prepared.add(await ReelMedia.prepare(file.path));
      }
      if (mounted && prepared.isNotEmpty) {
        setState(() {
          selected = clips.length;
          clips.addAll(prepared);
        });
      }
    });
  }

  Future<void> save() async {
    await run(() async {
      await Drafts.save(account, {
        'id': id,
        'kind': 'reel',
        'files': [for (final clip in clips) clip.path],
        'clips': [for (final clip in clips) clip.toJson()],
        'text': description.text,
        'location': location.text,
        'overlay': overlay.toJson(),
        'music': music,
        'originalAudio': originalAudio,
        'inFeed': inFeed,
        'audience': audience,
      });
      if (mounted) notice(context, 'Bozza salvata');
    });
  }

  Future<void> editText() async {
    final value = await textDialog(context, 'Testo sul video', overlay.text);
    if (value != null && mounted) {
      setState(
        () => overlay = ReelText(
          text: value,
          x: overlay.x,
          y: overlay.y,
          color: overlay.color,
          background: overlay.background,
        ),
      );
    }
  }

  Future<void> render() async {
    if (duration > reelMaxDurationMs) {
      notice(context, 'Accorcia le clip per rientrare in 90 secondi.');
      return;
    }
    await run(() async {
      final direction = Directionality.of(context);
      final dir = await folder();
      final art = overlay.text.trim().isEmpty
          ? null
          : await overlay.rasterize(dir, direction);
      final reference = music.str('audio');
      final track = reference.isEmpty
          ? null
          : await reelImport(
              store,
              reference,
              extension: 'mp3',
              folder: dir,
              name: 'musica',
            );
      final output = await ReelMedia.export(
        clips: clips,
        originalAudio: originalAudio,
        folder: dir,
        overlay: art,
        music: track,
        musicStartMs: (music.number('start') * 1000).round(),
        musicLengthMs: (music.number('clipDuration', 15) * 1000).round(),
      );
      final thumbnail = await ReelMedia.cover(
        path: output,
        photo: false,
        positionMs: 0,
        folder: dir,
      );
      if (mounted)
        setState(() {
          video = output;
          cover = thumbnail;
        });
    });
  }

  Future<void> chooseCover() async {
    await run(() async {
      final positions = List.generate(8, (i) => (duration - 1) * i ~/ 8);
      final rendered = ReelClip(
        id: id,
        path: video,
        photo: false,
        originalMs: duration,
        startMs: 0,
        endMs: duration,
      );
      final frames = await ReelMedia.frames(rendered, positions);
      if (!mounted) return;
      final chosen = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Scegli la copertina'),
              const SizedBox(height: 12),
              SizedBox(
                height: 105,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: frames.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (c, i) => InkWell(
                    onTap: () => Navigator.pop(c, positions[i]),
                    child: Image.memory(
                      frames[i],
                      width: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, -1),
                child: const Text('Scegli dalla galleria'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || chosen == null) return;
      final photo = chosen == -1
          ? await picker.pickImage(source: ImageSource.gallery)
          : null;
      if (chosen == -1 && photo == null) return;
      final next = await ReelMedia.cover(
        path: photo?.path ?? video,
        photo: photo != null,
        positionMs: chosen < 0 ? 0 : chosen,
        folder: await folder(),
      );
      if (mounted) setState(() => cover = next);
    });
  }

  Future<void> publish() async {
    await run(() async {
      setState(() => publishing = true);
      try {
        final media = source ??= await store.upload(video, 'video/mp4');
        final coverId = await store.upload(cover, 'image/jpeg');
        await store.act('post', {
          'kind': 'reel',
          'idempotencyKey': id,
          'text': description.text.trim(),
          'location': location.text.trim(),
          'media': media,
          'mediaItems': [media, coverId],
          'audience': audience,
          'style': {
            'coverId': coverId,
            'showInFeed': inFeed,
            if (music.isNotEmpty) 'music': music,
            'audioEmbedded': true,
          },
        });
        try {
          await Drafts.delete(account, id);
        } on FileSystemException {
          // The server has already accepted this reel.
        }
        if (mounted) {
          notice(context, 'Reel pubblicato');
          Navigator.pop(context);
        }
      } finally {
        if (mounted) setState(() => publishing = false);
      }
    });
  }

  void back() {
    if (video.isNotEmpty) {
      setState(() {
        video = '';
        cover = '';
        source = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext c) {
    final preview = video.isNotEmpty;
    final clip = clips.isEmpty ? null : clips[selected];
    return PopScope(
      canPop: !busy || publishing,
      child: Scaffold(
        backgroundColor: preview ? null : const Color(0xff101012),
        appBar: AppBar(
          backgroundColor: preview ? null : const Color(0xff101012),
          foregroundColor: preview ? null : Colors.white,
          centerTitle: true,
          leading: IconButton(
            tooltip: preview ? 'Torna al montaggio' : 'Chiudi',
            onPressed: busy ? null : back,
            icon: Icon(preview ? CupertinoIcons.back : CupertinoIcons.xmark),
          ),
          title: const Text('Nuovo reel'),
          actions: [
            IconButton(
              tooltip: 'Salva bozza',
              onPressed: busy || clips.isEmpty ? null : save,
              icon: const Icon(CupertinoIcons.doc_text),
            ),
          ],
        ),
        bottomNavigationBar: clip == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : preview
                      ? publish
                      : render,
                  child: Text(
                    busy
                        ? 'Attendi…'
                        : preview
                        ? 'Condividi'
                        : 'Avanti',
                  ),
                ),
              ),
        body: preview
            ? publishPage(c)
            : Column(
                children: [
                  if (busy) const LinearProgressIndicator(),
                  Expanded(
                    child: clip == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.play_rectangle,
                                  color: Colors.white,
                                  size: 46,
                                ),
                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => add(camera: false),
                                  icon: const Icon(
                                    CupertinoIcons.photo_on_rectangle,
                                  ),
                                  label: const Text('Galleria'),
                                ),
                                TextButton.icon(
                                  onPressed: busy
                                      ? null
                                      : () => add(camera: true),
                                  icon: const Icon(
                                    CupertinoIcons.videocam,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Registra',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: LayoutBuilder(
                                builder: (c, box) => Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (clip.photo)
                                      Image.file(
                                        File(clip.path),
                                        fit: BoxFit.cover,
                                      )
                                    else
                                      ClipPlayer(
                                        key: ValueKey(clip.id),
                                        reference: clip.path,
                                        fit: BoxFit.cover,
                                        muted: !originalAudio,
                                        active:
                                            TickerMode.of(c) &&
                                            (ModalRoute.of(c)?.isCurrent ??
                                                true),
                                      ),
                                    GestureDetector(
                                      onPanUpdate: busy || overlay.text.isEmpty
                                          ? null
                                          : (event) => setState(() {
                                              overlay = overlay.move(
                                                overlay.x +
                                                    event.delta.dx /
                                                        box.maxWidth,
                                                overlay.y +
                                                    event.delta.dy /
                                                        box.maxHeight,
                                              );
                                            }),
                                      child: CustomPaint(
                                        painter: _ReelTextPainter(
                                          overlay,
                                          Directionality.of(c),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (clip != null) timeline(c, clip),
                ],
              ),
      ),
    );
  }

  Widget timeline(BuildContext c, ReelClip clip) => SafeArea(
    top: false,
    bottom: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 58,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            buildDefaultDragHandles: false,
            itemCount: clips.length,
            onReorder: (from, to) {
              if (busy) return;
              final active = clips[selected];
              setState(() {
                clips.insert(to > from ? to - 1 : to, clips.removeAt(from));
                selected = clips.indexOf(active);
              });
            },
            itemBuilder: (c, i) => ReorderableDelayedDragStartListener(
              key: ValueKey(clips[i].id),
              index: i,
              enabled: !busy,
              child: GestureDetector(
                onTap: busy ? null : () => setState(() => selected = i),
                child: Container(
                  width: 67,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected == i ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _Thumbnail(bytes: clips[i].thumbnail),
                ),
              ),
            ),
          ),
        ),
        RangeSlider(
          min: 0,
          max: clip.originalMs.toDouble(),
          values: RangeValues(clip.startMs.toDouble(), clip.endMs.toDouble()),
          labels: RangeLabels(seconds(clip.startMs), seconds(clip.endMs)),
          onChanged: busy
              ? null
              : (range) => setState(
                  () => clips[selected] = clip.trim(
                    range.start.round(),
                    range.end.round(),
                  ),
                ),
        ),
        Text(
          '${seconds(clip.startMs)} – ${seconds(clip.endMs)}  ·  Totale ${seconds(duration)}',
          style: TextStyle(
            color: duration > reelMaxDurationMs
                ? Colors.redAccent
                : Colors.white70,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              action(
                'Galleria',
                CupertinoIcons.photo,
                () => add(camera: false),
              ),
              action(
                'Registra',
                CupertinoIcons.videocam,
                () => add(camera: true),
              ),
              action('Testo', CupertinoIcons.textformat, editText),
              action('Musica', CupertinoIcons.music_note, () async {
                final result = await open<J>(context, const MusicPicker());
                if (result != null && mounted) setState(() => music = result);
              }),
              if (music.isNotEmpty)
                action(
                  'Rimuovi brano',
                  CupertinoIcons.xmark,
                  () => setState(() => music = {}),
                ),
              action(
                originalAudio
                    ? 'Disattiva audio originale'
                    : 'Attiva audio originale',
                originalAudio
                    ? CupertinoIcons.speaker_2
                    : CupertinoIcons.speaker_slash,
                () => setState(() => originalAudio = !originalAudio),
              ),
              action(
                'Rimuovi clip',
                CupertinoIcons.trash,
                () => setState(() {
                  clips.removeAt(selected);
                  selected = selected.clamp(
                    0,
                    clips.isEmpty ? 0 : clips.length - 1,
                  );
                }),
              ),
            ],
          ),
        ),
        if (music.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              music.str('title'),
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    ),
  );

  String seconds(int ms) => '${(ms / 1000).toStringAsFixed(1)} s';

  Widget action(String label, IconData icon, VoidCallback callback) =>
      IconButton(
        tooltip: label,
        onPressed: busy ? null : callback,
        icon: Icon(icon, color: Colors.white),
      );

  Widget publishPage(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (busy) const LinearProgressIndicator(),
      Center(
        child: SizedBox(
          width: 145,
          height: 248,
          child: ClipPlayer(
            key: ValueKey(video),
            reference: video,
            fit: BoxFit.cover,
            active: !busy && (ModalRoute.of(c)?.isCurrent ?? true),
          ),
        ),
      ),
      ListTile(
        leading: Image.file(
          File(cover),
          width: 38,
          height: 50,
          fit: BoxFit.cover,
        ),
        title: const Text('Modifica copertina'),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: busy ? null : chooseCover,
      ),
      TextField(
        controller: description,
        enabled: !busy,
        maxLines: 3,
        maxLength: 2200,
        decoration: const InputDecoration(hintText: 'Scrivi una didascalia…'),
      ),
      TextField(
        controller: location,
        enabled: !busy,
        maxLength: 100,
        decoration: const InputDecoration(hintText: 'Aggiungi luogo'),
      ),
      ListTile(
        title: const Text('Pubblico'),
        trailing: DropdownButton<String>(
          value: audience,
          onChanged: busy ? null : (value) => setState(() => audience = value!),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Tutti')),
            DropdownMenuItem(value: 'followers', child: Text('Follower')),
            DropdownMenuItem(value: 'close', child: Text('Amici più stretti')),
          ],
        ),
      ),
      SwitchListTile(
        title: const Text('Mostra l’anteprima nel feed'),
        value: inFeed,
        onChanged: busy ? null : (value) => setState(() => inFeed = value),
      ),
    ],
  );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => bytes == null
      ? const ColoredBox(
          color: Colors.black,
          child: Icon(CupertinoIcons.play_rectangle, color: Colors.white70),
        )
      : Image.memory(bytes!, fit: BoxFit.cover);
}

class _ReelTextPainter extends CustomPainter {
  const _ReelTextPainter(this.text, this.direction);

  final ReelText text;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) =>
      text.draw(canvas, size, direction: direction);

  @override
  bool shouldRepaint(_ReelTextPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.direction != direction;
}
