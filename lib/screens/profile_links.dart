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

  Future<void> choosePlatform() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (menu) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .4,
        maxChildSize: .93,
        builder: (menu, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Scegli la piattaforma',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final entry in socialNames.entries)
              ListTile(
                leading: FaIcon(socialIcon(entry.key), size: 20),
                title: Text(entry.value),
                selected: entry.key == type,
                trailing: entry.key == type ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(menu, entry.key),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null || picked == type) return;
    setState(() {
      type = picked;
      error = '';
    });
  }

  void submit() {
    try {
      Navigator.pop(context, socialLink(type, value.text, title.text));
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  J? get preview {
    if (value.text.trim().isEmpty) return null;
    try {
      return socialLink(type, value.text, title.text);
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    final link = preview;
    final editing = widget.initial != null;
    final field = switch (type) {
      'website' => 'Indirizzo del sito web',
      'whatsapp' => 'Numero WhatsApp',
      _ => 'Nome utente o ID',
    };
    final hint = switch (type) {
      'website' => 'https://esempio.it',
      'whatsapp' => '+39 333 1234567',
      _ => 'nomeutente',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Modifica collegamento' : 'Aggiungi collegamento',
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Piattaforma', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Material(
            color: subdued(c),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('social-platform-picker'),
              leading: FaIcon(socialIcon(type), size: 21),
              title: Text(
                socialNames[type]!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: const GIcon(CupertinoIcons.chevron_down, size: 17),
              onTap: choosePlatform,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            key: const ValueKey('social-handle'),
            controller: value,
            keyboardType: type == 'website'
                ? TextInputType.url
                : type == 'whatsapp'
                ? TextInputType.phone
                : TextInputType.text,
            autocorrect: false,
            onChanged: (_) => setState(() => error = ''),
            decoration: InputDecoration(
              labelText: field,
              hintText: hint,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              helperText: type == 'whatsapp'
                  ? 'Usa il prefisso internazionale, ad esempio +39.'
                  : null,
              errorText: error.isEmpty ? null : error,
              errorMaxLines: 3,
              filled: false,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome da mostrare',
              hintText: 'Facoltativo',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              filled: false,
            ),
          ),
          if (link != null) ...[
            const SizedBox(height: 16),
            Text('Anteprima sul profilo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(
                avatar: FaIcon(socialIcon(type), size: 16),
                label: Text(
                  link.str('title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                backgroundColor: surface(c),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: value.text.trim().isEmpty ? null : submit,
            child: Text(editing ? 'Salva modifiche' : 'Aggiungi collegamento'),
          ),
        ),
      ),
    );
  }
}
