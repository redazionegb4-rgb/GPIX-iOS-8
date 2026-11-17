import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

class GiphyGallery extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final VoidCallback? onImport;
  final bool forNote;
  const GiphyGallery({
    super.key,
    required this.onSelected,
    this.onImport,
    this.forNote = false,
  });
  @override
  State<GiphyGallery> createState() => _GiphyGalleryState();
}

class _GiphyGalleryState extends State<GiphyGallery> {
  final search = TextEditingController();
  Timer? debounce;
  List<J> gifs = [];
  String error = '';
  bool busy = false, initialized = false, local = false, more = false;
  int generation = 0, offset = 0;
  int category = 2;
  static const noteCategories = [
    ('Recenti', CupertinoIcons.clock, ''),
    ('Preferite', CupertinoIcons.star, ''),
    ('Di tendenza', Icons.trending_up_rounded, ''),
    ('Risate', CupertinoIcons.smiley, 'funny'),
    ('Amore', CupertinoIcons.heart, 'love'),
    ('Tristezza', CupertinoIcons.cloud_rain, 'sad'),
    ('Festa', CupertinoIcons.sparkles, 'celebrate'),
    ('Mi piace', CupertinoIcons.hand_thumbsup, 'thumbs up'),
  ];
  static const tags = [
    'ciao saluto hello hi wave',
    'amore love cuore heart kiss bacio',
    'ridere risata laugh funny lol divertente',
    'festa party dance ballo happy felice',
    'abbraccio hug grazie thanks thank you',
    'wow sorpresa surprise rainbow arcobaleno',
  ];
  List<J> demoGifs(String query) => [
    for (var i = 0; i < tags.length; i++)
      if (query.isEmpty ||
          query
              .toLowerCase()
              .split(RegExp(r'\s+'))
              .every((word) => tags[i].contains(word)))
        {
          'id': 'demo-$i',
          'title': tags[i],
          'images': {
            'fixed_height': {'url': 'gif$i.gif'},
            'original': {'url': 'gif$i.gif'},
          },
        },
  ];

  String _historyKey(GpixStore store, String name) =>
      'gpix.noteGifs.${store.myId}.$name';

  List<J> _remembered(GpixStore store, String name) {
    final data = store.prefs?.getString(_historyKey(store, name));
    if (data == null) return [];
    try {
      return objects(jsonDecode(data));
    } on FormatException {
      return [];
    }
  }

  void _remember(J gif, String name, {bool toggle = false}) {
    final store = GpixScope.of(context, listen: false);
    final previous = _remembered(store, name);
    final id = gif.str('id');
    final images = gif.obj('images');
    final thumbnail = images.obj('fixed_height');
    final record = {
      'id': id,
      'title': gif.str('title'),
      'images': {
        'fixed_height': {
          for (final key in const ['url', 'width', 'height'])
            key: thumbnail.str(key),
        },
        'original': {
          'url': images.obj('original').str('url', thumbnail.str('url')),
        },
      },
    };
    final list = [
      if (!toggle || !previous.any((item) => item.str('id') == id)) record,
      ...previous.where((item) => item.str('id') != id),
    ].take(30).toList();
    store.prefs?.setString(_historyKey(store, name), jsonEncode(list));
    if (toggle) {
      notice(
        context,
        list.any((item) => item.str('id') == id)
            ? 'GIF aggiunta alle preferite'
            : 'GIF rimossa dalle preferite',
      );
      if (category == 1) load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      load();
    }
  }

  Future<void> load({bool next = false}) async {
    final seq = ++generation,
        s = GpixScope.of(context, listen: false),
        demo = s.demo,
        entered = search.text.trim();
    if (widget.forNote && category < 2 && entered.isEmpty) {
      setState(() {
        gifs = _remembered(s, category == 0 ? 'recent' : 'favorites');
        busy = false;
        error = '';
        local = true;
        more = false;
      });
      return;
    }
    final q = entered.isEmpty && widget.forNote
        ? noteCategories[category].$3
        : entered;
    setState(() {
      busy = true;
      error = '';
      if (!next) {
        offset = 0;
        gifs = demo ? demoGifs(q) : [];
        local = demo;
      }
    });
    if (demo && widget.forNote) {
      setState(() => busy = false);
      return;
    }
    try {
      final base = s.server.isEmpty ? 'https://gpix.cc' : s.server;
      final uri = Uri.parse(
        '$base/giphy${demo ? '/demo' : ''}',
      ).replace(queryParameters: {'q': q, 'offset': '$offset'});
      final response = await s.client
          .get(
            uri,
            headers: demo
                ? <String, String>{}
                : {'Authorization': 'Bearer ${s.token}'},
          )
          .timeout(const Duration(seconds: 10));
      final data = object(jsonDecode(response.body));
      if (response.statusCode != 200)
        throw Exception(
          data.str(
            'detail',
            response.statusCode == 401
                ? 'Sessione scaduta: accedi di nuovo.'
                : 'GIPHY non disponibile (${response.statusCode}).',
          ),
        );
      if (!mounted || generation != seq) return;
      final items = data.rows('data');
      setState(() {
        gifs = [if (next && !local) ...gifs, ...items];
        local = false;
        offset += items.length;
        more = offset < data.obj('pagination').number('total_count');
      });
    } catch (e) {
      if (mounted && generation == seq)
        setState(() {
          if (demo) {
            gifs = demoGifs(q);
            local = true;
            more = false;
            error =
                'GIPHY online non disponibile. Puoi usare le GIF demo animate.';
          } else {
            error = e.toString().replaceFirst('Exception: ', '');
          }
        });
    } finally {
      if (mounted && generation == seq) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    generation++;
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => widget.forNote
      ? _noteGallery(c)
      : Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'GIF',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: TextField(
                controller: search,
                onChanged: (_) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), load);
                },
                decoration: InputDecoration(
                  hintText: 'Cerca su GIPHY',
                  prefixIcon: const GIcon(CupertinoIcons.search, size: 20),
                  filled: true,
                  fillColor: subdued(c),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: load, child: const Text('Riprova')),
                  ],
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.3,
              ),
              itemCount: gifs.length,
              itemBuilder: (c, i) {
                final gif = gifs[i],
                    images = gif.obj('images'),
                    url = images.obj('fixed_height').str('url');
                return Semantics(
                  label: 'GIF ${gif.str('id')}',
                  button: true,
                  child: InkWell(
                    key: ValueKey('gif-${gif.str('id')}'),
                    onTap: () => widget.onSelected(
                      images.obj('original').str('url', url),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MediaView(url),
                    ),
                  ),
                );
              },
            ),
            if (busy && !local)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            if (!busy && gifs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nessuna GIF trovata. Prova un’altra parola.'),
              ),
            if (!busy && more && !local)
              TextButton(
                onPressed: () => load(next: true),
                child: const Text('Carica altre GIF'),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                local ? 'GIF demo animate' : 'Powered By GIPHY',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            if (widget.onImport != null)
              TextButton(
                onPressed: widget.onImport,
                child: const Text('Importa una GIF dal dispositivo'),
              ),
            const SizedBox(height: 18),
          ],
        );

  Widget _noteGallery(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final tinted = light ? const Color(0xffeef0f3) : subdued(context);
    const border = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.all(Radius.circular(26)),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), load);
            },
            decoration: InputDecoration(
              hintText: 'Cerca GIPHY',
              prefixIcon: GIcon(
                CupertinoIcons.search,
                size: 18,
                color: secondaryText(context),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 14,
              ),
              filled: true,
              fillColor: tinted,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
        ),
        Row(
          children: [
            for (final (index, (label, icon, _)) in noteCategories.indexed)
              Expanded(
                child: IconButton(
                  tooltip: label,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: index == category ? tinted : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    debounce?.cancel();
                    search.clear();
                    setState(() => category = index);
                    load();
                  },
                  icon: GIcon(
                    icon,
                    size: 18,
                    color: index == category
                        ? foreground(context)
                        : secondaryText(context),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 6, 13, 14),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (gifs.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < 2; column++) ...[
                      if (column != 0) const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            for (
                              var index = column;
                              index < gifs.length;
                              index += 2
                            )
                              _noteGif(gifs[index]),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error.isNotEmpty)
                Column(
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    TextButton(onPressed: load, child: const Text('Riprova')),
                  ],
                )
              else if (gifs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    category == 0
                        ? 'Nessuna GIF recente'
                        : category == 1
                        ? 'Tieni premuta una GIF per salvarla'
                        : 'Nessuna GIF trovata',
                    textAlign: TextAlign.center,
                  ),
                )
              else if (more)
                TextButton(
                  onPressed: () => load(next: true),
                  child: const Text('Carica altre GIF'),
                ),
              if (!local && gifs.isNotEmpty)
                Text(
                  'Powered By GIPHY',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: secondaryText(context)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noteGif(J gif) {
    final images = gif.obj('images');
    final frame = images.obj('fixed_height');
    final url = frame.str('url');
    final width = double.tryParse(frame.str('width')) ?? 180;
    final height = double.tryParse(frame.str('height')) ?? 165;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label: gif.str('title', 'GIF'),
        button: true,
        child: InkWell(
          key: ValueKey('gif-${gif.str('id')}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            _remember(gif, 'recent');
            widget.onSelected(images.obj('original').str('url', url));
          },
          onLongPress: () => _remember(gif, 'favorites', toggle: true),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: height > 0 ? (width / height).clamp(.82, 1.75) : 1,
              child: MediaView(url),
            ),
          ),
        ),
      ),
    );
  }
}
