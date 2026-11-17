import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'giphy.dart';

const noteAccent = Color(0xff4b55ed);

Color noteControls(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? const Color(0xffeef0f3)
    : Theme.of(context).colorScheme.surfaceContainerHighest;

Future<T?> noteSheet<T>(
  BuildContext context,
  Widget child, {
  double? height,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  barrierColor: const Color(0xb2141a1e),
  backgroundColor: surface(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  ),
  clipBehavior: Clip.antiAlias,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(
          duration: Duration(milliseconds: 300),
          reverseDuration: Duration(milliseconds: 220),
        ),
  builder: (context) => AnimatedPadding(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 140),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: height == null
            ? null
            : MediaQuery.sizeOf(context).height * height,
        child: Column(
          mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 34,
              height: 2,
              margin: const EdgeInsets.only(top: 14, bottom: 16),
              decoration: BoxDecoration(
                color: secondaryText(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  ),
);

InputDecoration noteSearchDecoration(BuildContext context, String hint) {
  const border = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(26)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: secondaryText(context), fontSize: 15),
    prefixIcon: GIcon(
      CupertinoIcons.search,
      size: 19,
      color: secondaryText(context),
    ),
    filled: true,
    fillColor: noteControls(context),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
    constraints: const BoxConstraints(minHeight: 44),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

Future<String?> pickNoteGif(BuildContext context) => noteSheet<String>(
  context,
  Builder(
    builder: (sheet) => GiphyGallery(
      onSelected: (gif) => Navigator.pop(sheet, gif),
      forNote: true,
    ),
  ),
  height: .665,
);

Future<String?> pickNotePlace(BuildContext context, String current) =>
    noteSheet<String>(context, _NotePlacePicker(current: current), height: .70);

class _NotePlacePicker extends StatefulWidget {
  const _NotePlacePicker({required this.current});

  final String current;

  @override
  State<_NotePlacePicker> createState() => _NotePlacePickerState();
}

class _NotePlacePickerState extends State<_NotePlacePicker> {
  late final input = TextEditingController(text: widget.current);

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final value = input.text.trim();
    final recent = {
      for (final post in store.posts)
        if (post.str('location').trim().isNotEmpty) post.str('location').trim(),
    };
    final places = recent
        .where((place) => place.toLowerCase().contains(value.toLowerCase()))
        .take(16);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: input,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: noteSearchDecoration(
              context,
              'Cerca o aggiungi un luogo',
            ).copyWith(counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (value.isNotEmpty && !recent.contains(value))
                ListTile(
                  leading: const GIcon(
                    CupertinoIcons.placemark,
                    color: noteAccent,
                  ),
                  title: Text(value),
                  subtitle: const Text('Usa questo luogo'),
                  onTap: () => Navigator.pop(context, value),
                ),
              for (final place in places)
                ListTile(
                  leading: const GIcon(CupertinoIcons.placemark),
                  title: Text(place),
                  onTap: () => Navigator.pop(context, place),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<J?> pickNoteMusic(BuildContext context) =>
    noteSheet<J>(context, const _NoteMusicPicker(), height: .865);

class _NoteMusicPicker extends StatefulWidget {
  const _NoteMusicPicker();

  @override
  State<_NoteMusicPicker> createState() => _NoteMusicPickerState();
}

class _NoteMusicPickerState extends State<_NoteMusicPicker> {
  List<J> tracks = [];
  int tab = 0;
  String query = '', error = '';
  bool loading = true;
  late Set<String> saved;
  String get saveKey =>
      'gpix.noteMusic.${GpixScope.of(context, listen: false).myId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) load();
    });
  }

  Future<void> load() async {
    final store = GpixScope.of(context, listen: false);
    try {
      final values = await store.musicTracks();
      if (mounted) setState(() => tracks = values);
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void toggleSaved(String id) {
    final store = GpixScope.of(context, listen: false);
    setState(() {
      if (!saved.add(id)) saved.remove(id);
    });
    store.prefs?.setStringList(saveKey, saved.toList());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    saved =
        GpixScope.of(
          context,
          listen: false,
        ).prefs?.getStringList(saveKey)?.toSet() ??
        {};
  }

  @override
  Widget build(BuildContext context) {
    final matches = tracks.where(
      (track) =>
          '${track.str('title')} ${track.str('artist')} ${track.str('genre')}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
    );
    final visible = switch (tab) {
      1 =>
        matches.toList()
          ..sort((a, b) => b.number('reels').compareTo(a.number('reels'))),
      2 => matches.where((track) => saved.contains(track.str('id'))).toList(),
      3 => matches.where((track) => track.flag('original')).toList(),
      _ => matches.toList(),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => query = value),
            textInputAction: TextInputAction.search,
            decoration: noteSearchDecoration(context, 'Cerca…'),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 15),
          child: Row(
            children: [
              for (final (index, label) in const [
                'Per te',
                'Popolari',
                'Salvato',
                'Audio originale',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: index == tab
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? accent(context)
                                : noteAccent)
                          : foreground(context),
                      backgroundColor: index == tab
                          ? noteAccent.withValues(alpha: .10)
                          : noteControls(context),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: () => setState(() => tab = index),
                    child: Text(label),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount:
                visible.length + (tab == 0 && query.trim().isEmpty ? 2 : 1),
            itemBuilder: (context, index) {
              final spotify = tab == 0 && query.trim().isEmpty;
              if (spotify && index == 0) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 8,
                  horizontalTitleGap: 13,
                  leading: _Cover(
                    icon: FaIcon(
                      FontAwesomeIcons.spotify,
                      size: 23,
                      color: foreground(context),
                    ),
                  ),
                  title: const Text(
                    'Condividi da Spotify',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aggiungi il link di un brano.',
                        style: TextStyle(fontSize: 12),
                      ),
                      InkWell(
                        onTap: () => gpixAlert(
                          context,
                          'Condividi da Spotify',
                          'Apri un brano in Spotify, scegli Condividi e copia il link. Incollalo in GPIX per aggiungerlo alla nota.',
                        ),
                        child: Text(
                          'Come funziona',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                ? noteAccent
                                : accent(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: CircleAvatar(
                    backgroundColor: foreground(context),
                    radius: 12,
                    child: GIcon(
                      CupertinoIcons.arrow_right,
                      size: 15,
                      color: surface(context),
                    ),
                  ),
                  onTap: () async {
                    final track = await noteSheet<J>(
                      context,
                      const _SpotifyTrackForm(),
                    );
                    if (context.mounted && track != null)
                      Navigator.pop(context, track);
                  },
                );
              }
              final row = index - (spotify ? 1 : 0);
              if (row == visible.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error.isNotEmpty
                      ? Column(
                          children: [
                            Text(error, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  error = '';
                                  loading = true;
                                });
                                load();
                              },
                              child: const Text('Riprova'),
                            ),
                          ],
                        )
                      : visible.isEmpty
                      ? Center(
                          child: Text(
                            tab == 2
                                ? 'Nessun brano salvato'
                                : 'Nessun brano trovato',
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              }
              final track = visible[row];
              final id = track.str('id');
              final duration = track.number('duration').round();
              final time =
                  '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                minVerticalPadding: 7,
                horizontalTitleGap: 13,
                leading: _Cover(
                  cover: track.str('cover'),
                  icon: const GIcon(
                    CupertinoIcons.music_note_2,
                    size: 23,
                    color: noteAccent,
                  ),
                ),
                title: Text(
                  track.str('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  "${track.str('artist')}${track['reels'] == null ? '' : " · Reel: ${track['reels']}"} · $time",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondaryText(context)),
                ),
                trailing: IconButton(
                  tooltip: saved.contains(id)
                      ? 'Rimuovi dai salvati'
                      : 'Salva brano',
                  onPressed: () => toggleSaved(id),
                  icon: GIcon(
                    saved.contains(id)
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    size: 21,
                  ),
                ),
                onTap: () => Navigator.pop(context, track),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.cover = '', required this.icon});

  final String cover;
  final Widget icon;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: SizedBox.square(
      dimension: 44,
      child: ColoredBox(
        color: noteControls(context),
        child: cover.isEmpty
            ? Center(child: icon)
            : MediaView(cover, fallback: icon),
      ),
    ),
  );
}

class _SpotifyTrackForm extends StatefulWidget {
  const _SpotifyTrackForm();

  @override
  State<_SpotifyTrackForm> createState() => _SpotifyTrackFormState();
}

class _SpotifyTrackFormState extends State<_SpotifyTrackForm> {
  String link = '', title = '';

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(link.trim());
    final valid =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'open.spotify.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        RegExp(
          r'^/(?:intl-[a-z]{2}/)?track/[a-zA-Z0-9]{22}/?$',
        ).hasMatch(uri.path);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Condividi da Spotify',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 15),
          TextField(
            keyboardType: TextInputType.url,
            onChanged: (value) => setState(() => link = value),
            decoration: const InputDecoration(hintText: 'Link del brano'),
          ),
          const SizedBox(height: 8),
          TextField(
            maxLength: 100,
            onChanged: (value) => setState(() => title = value),
            decoration: const InputDecoration(
              hintText: 'Titolo del brano (facoltativo)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: valid
                ? () => Navigator.pop(context, <String, dynamic>{
                    'spotify':
                        'https://open.spotify.com/track/${uri.pathSegments.lastWhere((part) => part.isNotEmpty)}',
                    'title': title.trim().isEmpty ? 'Spotify' : title.trim(),
                  })
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: noteAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }
}

class NotePlayback extends StatefulWidget {
  const NotePlayback({super.key, required this.track});

  final J track;

  @override
  State<NotePlayback> createState() => _NotePlaybackState();
}

class _NotePlaybackState extends State<NotePlayback>
    with WidgetsBindingObserver {
  AudioPlayer? player;
  Timer? stop;
  bool playing = false, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> toggle() => perform(context, () async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (playing) {
        await halt();
      } else {
        final url = GpixScope.of(
          context,
          listen: false,
        ).url(widget.track.str('audio'));
        final audio = player ??= AudioPlayer();
        await audio.play(UrlSource(url));
        if (!mounted) return;
        setState(() => playing = true);
        stop = Timer(const Duration(seconds: 15), () => unawaited(halt()));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  });

  Future<void> halt() async {
    stop?.cancel();
    if (mounted) setState(() => playing = false);
    await player?.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && player != null) unawaited(halt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stop?.cancel();
    player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: playing ? 'Ferma anteprima' : 'Ascolta anteprima',
    onPressed: busy ? null : toggle,
    icon: GIcon(
      playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
      size: 16,
    ),
  );
}
