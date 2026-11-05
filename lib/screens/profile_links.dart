import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/data.dart';
import '../core/profile_links.dart';
import '../core/store.dart';
import '../ui/kit.dart';

IconData socialIcon(String type) => switch (type) {
  'instagram' => FontAwesomeIcons.instagram,
  'facebook' => FontAwesomeIcons.facebook,
  'threads' => FontAwesomeIcons.threads,
  'whatsapp' => FontAwesomeIcons.whatsapp,
  'telegram' => FontAwesomeIcons.telegram,
  'tiktok' => FontAwesomeIcons.tiktok,
  'youtube' => FontAwesomeIcons.youtube,
  'x' => FontAwesomeIcons.xTwitter,
  'website' => FontAwesomeIcons.globe,
  _ => FontAwesomeIcons.link,
};
Future<void> openProfileLink(BuildContext c, J link) async {
  try {
    final uri = profileAppUri(link);
    final ok = await launchUrl(
      uri,
      mode: link.str('type') == 'website'
          ? LaunchMode.externalApplication
          : uri.scheme == 'https'
          ? LaunchMode.externalNonBrowserApplication
          : LaunchMode.externalApplication,
    );
    if (!ok && c.mounted)
      notice(
        c,
        link.str('type') == 'website'
            ? 'Non è stato possibile aprire il sito web.'
            : 'Installa ${socialNames[link.str('type')] ?? 'l’app del profilo'} per aprire questo collegamento.',
      );
  } catch (_) {
    if (c.mounted)
      notice(
        c,
        link.str('type') == 'website'
            ? 'Non è stato possibile aprire il sito web.'
            : 'Non è stato possibile aprire l’app del profilo. Verifica che sia installata.',
      );
  }
}

class ProfileLinkChips extends StatelessWidget {
  final List<J> links;
  final bool own;
  const ProfileLinkChips({super.key, required this.links, required this.own});
  @override
  Widget build(BuildContext c) {
    final visibleLinks = links.map(resolveSocialLink).toList();
    Widget chip(Widget icon, String text, VoidCallback tap) => ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 18, height: 18, child: Center(child: icon)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground(c),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      labelPadding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: surface(c),
      side: BorderSide(color: Theme.of(c).dividerColor),
      shape: const StadiumBorder(),
      onPressed: tap,
    );
    return Wrap(
      spacing: 7,
      runSpacing: 3,
      children: [
        for (final link in visibleLinks)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(c).width - 50,
            ),
            child: chip(
              FaIcon(
                socialIcon(link.str('type')),
                size: 16,
                color: foreground(c),
              ),
              link.str('title', link.str('value', link.str('url'))),
              () => openProfileLink(c, link),
            ),
          ),
        if (own && links.length < 5)
          chip(
            const GIcon(CupertinoIcons.plus, size: 18),
            'Aggiungi',
            () => open(c, const ProfileLinks()),
          ),
      ],
    );
  }
}

class ProfileLinks extends StatefulWidget {
  const ProfileLinks({super.key});
  @override
  State<ProfileLinks> createState() => _ProfileLinksState();
}

class _ProfileLinksState extends State<ProfileLinks> {
  List<J>? links;
  bool busy = false;
  Future<void> edit({int? index}) async {
    final result = await open<J>(
      context,
      SocialLinkEditor(initial: index == null ? null : links![index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null)
        links!.add(result);
      else
        links![index] = result;
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    links ??= s.me
        .rows('links')
        .map((e) => Map<String, dynamic>.from(resolveSocialLink(e)))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link del profilo'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => perform(c, () async {
                    setState(() => busy = true);
                    try {
                      await s.act('profileLinks', {'links': links});
                      if (c.mounted) Navigator.pop(c);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }),
            child: Text(busy ? 'Salvo…' : 'Fine'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Aggiungi fino a 5 collegamenti: profili social e siti web. I social si aprono nelle rispettive app; i siti nel browser.',
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (links!.isNotEmpty) ProfileLinkChips(links: links!, own: false),
          const SizedBox(height: 12),
          for (var i = 0; i < links!.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(socialIcon(links![i].str('type')), size: 24),
              title: Text(links![i].str('title')),
              subtitle: Text(
                socialNames[links![i].str('type')] ?? 'Collegamento esistente',
              ),
              onTap: () => edit(index: i),
              trailing: IconButton(
                tooltip: 'Rimuovi collegamento',
                icon: const GIcon(CupertinoIcons.trash, size: 20),
                onPressed: () => setState(() => links!.removeAt(i)),
              ),
            ),
          if (links!.length < 5)
            OutlinedButton.icon(
              onPressed: busy ? null : () => edit(),
              icon: const GIcon(CupertinoIcons.plus, size: 20),
              label: const Text('Aggiungi collegamento'),
            ),
        ],
      ),
    );
  }
}

class SocialLinkEditor extends StatefulWidget {
  final J? initial;
  const SocialLinkEditor({super.key, this.initial});
  @override
  State<SocialLinkEditor> createState() => _SocialLinkEditorState();
}

class _SocialLinkEditorState extends State<SocialLinkEditor> {
  late String type;
  final value = TextEditingController(), title = TextEditingController();
  String error = '';
  @override
  void initState() {
    super.initState();
    type = widget.initial?.str('type', 'instagram') ?? 'instagram';
    if (!socialNames.containsKey(type)) type = 'instagram';
    value.text = widget.initial?.str('value') ?? '';
    title.text = widget.initial?.str('title') ?? '';
  }

  @override
  void dispose() {
    value.dispose();
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: const Text('Aggiungi collegamento'),
      actions: [
        TextButton(
          onPressed: () {
            try {
              final link = socialLink(type, value.text, title.text);
              Navigator.pop(c, link);
            } on FormatException catch (e) {
              setState(() => error = e.message);
            }
          },
          child: const Text('Aggiungi'),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Scegli il social',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in socialNames.entries)
              ChoiceChip(
                showCheckmark: false,
                avatar: FaIcon(socialIcon(e.key), size: 16),
                label: Text(e.value),
                selected: type == e.key,
                onSelected: (_) => setState(() {
                  type = e.key;
                  error = '';
                }),
              ),
          ],
        ),
        const SizedBox(height: 26),
        TextField(
          key: const ValueKey('social-handle'),
          controller: value,
          keyboardType: type == 'website'
              ? TextInputType.url
              : type == 'whatsapp'
              ? TextInputType.phone
              : TextInputType.text,
          autocorrect: false,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(14),
              child: FaIcon(socialIcon(type), size: 20),
            ),
            labelText: type == 'website'
                ? 'Indirizzo del sito web'
                : type == 'whatsapp'
                ? 'Numero WhatsApp'
                : 'Username o ID profilo',
            helperText: type == 'whatsapp'
                ? 'Con prefisso internazionale, ad esempio +39.'
                : null,
            hintText: type == 'website'
                ? 'https://esempio.it'
                : type == 'whatsapp'
                ? '+39 333 1234567'
                : 'demix.87',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: title,
          maxLength: 60,
          decoration: const InputDecoration(
            prefixIcon: GIcon(CupertinoIcons.tag),
            labelText: 'Nome da mostrare (facoltativo)',
            border: OutlineInputBorder(),
          ),
        ),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: danger)),
        const SizedBox(height: 14),
        Text(
          type == 'website'
              ? 'Il sito si aprirà nel browser.'
              : 'Inserisci il profilo o il numero: non serve incollare una pagina web.',
          style: TextStyle(color: muted),
        ),
      ],
    ),
  );
}
