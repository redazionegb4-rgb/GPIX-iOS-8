import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

class GiphyGallery extends StatefulWidget {
  final ValueChanged<String> onSelected;
  final VoidCallback onImport;
  const GiphyGallery({
    super.key,
    required this.onSelected,
    required this.onImport,
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
        q = search.text.trim();
    setState(() {
      busy = true;
      error = '';
      if (!next) {
        offset = 0;
        gifs = demo ? demoGifs(q) : [];
        local = demo;
      }
    });
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
  Widget build(BuildContext c) => Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
              onTap: () =>
                  widget.onSelected(images.obj('original').str('url', url)),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      TextButton(
        onPressed: widget.onImport,
        child: const Text('Importa una GIF dal dispositivo'),
      ),
      const SizedBox(height: 18),
    ],
  );
}
