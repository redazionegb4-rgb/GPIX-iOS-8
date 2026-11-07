import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart';

class CommunityTabs extends StatelessWidget {
  const CommunityTabs(this.labels, this.selected, this.onSelected, {super.key});
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Semantics(
                selected: selected == label,
                child: InkWell(
                  onTap: () => onSelected(label),
                  child: Container(
                    alignment: Alignment.center,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected == label
                              ? accent(context)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected == label
                            ? accent(context)
                            : secondaryText(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const Divider(height: 1),
    ],
  );
}

class CommunityDirectory extends StatefulWidget {
  const CommunityDirectory({super.key, this.query = ''});
  final String query;
  @override
  State<CommunityDirectory> createState() => _CommunityDirectoryState();
}

class _CommunityDirectoryState extends State<CommunityDirectory> {
  String search = '', selected = 'Scopri';
  @override
  Widget build(BuildContext c) {
    final store = GpixScope.of(c);
    final term = (widget.query.isEmpty ? search : widget.query)
        .trim()
        .toLowerCase();
    final groups = store.state
        .rows('socialGroups')
        .where(
          (g) =>
              '${g.str('title')} ${g.str('description')}'
                  .toLowerCase()
                  .contains(term) &&
              (selected != 'I tuoi' ||
                  g.flag('joined') ||
                  g.str('owner') == store.myId),
        )
        .toList();
    final moments = store.state
        .rows('socialItems')
        .where(
          (m) =>
              m.str('kind') == 'moment' &&
              m.str('group_id').isEmpty &&
              '${m.str('title')} ${m.str('text')}'.toLowerCase().contains(term),
        );
    if (store.state.number('communityVersion') < 1)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GIcon(CupertinoIcons.person_3, size: 44),
              const SizedBox(height: 16),
              const Text(
                'Gruppi e Momenti richiedono il server GPIX aggiornato.',
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => perform(c, store.refreshHome),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    return RefreshIndicator(
      onRefresh: () => perform(c, store.refreshHome),
      child: ListView(
        key: const PageStorageKey('community-directory'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: subdued(c),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: auraBlue.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: GIcon(
                        CupertinoIcons.person_3,
                        color: accent(c),
                        size: 25,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Crea gruppo',
                      onPressed: () => composeCommunity(c, 'communityGroup'),
                      icon: const GIcon(
                        CupertinoIcons.plus_circle_fill,
                        color: auraBlue,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Trova il tuo giro.',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Persone, passioni e Momenti da condividere.',
                  style: TextStyle(color: secondaryText(c), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (widget.query.isEmpty)
            TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                hintText: 'Cerca un gruppo',
                prefixIcon: GIcon(CupertinoIcons.search, size: 20),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final label in ['Scopri', 'I tuoi'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected == label,
                    onSelected: (_) => setState(() => selected = label),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            selected == 'I tuoi' ? 'I tuoi gruppi' : 'Gruppi da scoprire',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const GIcon(CupertinoIcons.person_2, color: muted, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    term.isNotEmpty
                        ? 'Nessun gruppo trovato'
                        : 'Il prossimo gruppo può essere il tuo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => composeCommunity(c, 'communityGroup'),
                    icon: const GIcon(CupertinoIcons.plus, size: 18),
                    label: const Text('Crea gruppo'),
                  ),
                ],
              ),
            ),
          for (final group in groups) CommunityGroupCard(group: group),
          if (moments.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'I tuoi Momenti',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final item in moments) CommunityItem(item: item),
          ],
        ],
      ),
    );
  }
}

class CommunityGroupCard extends StatelessWidget {
  const CommunityGroupCard({super.key, required this.group});
  final J group;
  @override
  Widget build(BuildContext c) {
    final cover = group.str('cover');
    final store = GpixScope.of(c);
    final joined = group.flag('joined') || group.str('owner') == store.myId;
    return Container(
      key: ValueKey('group-card-${group.str('id')}'),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface(c),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(c).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => open(c, CommunityGroup(id: group.str('id'))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 126,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover.isNotEmpty)
                    MediaView(cover, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: Theme.of(c).brightness == Brightness.dark
                              ? [
                                  const Color(0xff152738),
                                  const Color(0xff254b62),
                                ]
                              : [
                                  const Color(0xffdbe9f5),
                                  const Color(0xffeef5f7),
                                ],
                        ),
                      ),
                      child: Center(
                        child: GIcon(
                          CupertinoIcons.person_3_fill,
                          size: 47,
                          color: accent(c),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xc9111720),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        joined ? 'Sei nel gruppo' : 'Gruppo pubblico',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.str('title'),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (group.str('description').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      group.str('description'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryText(c), height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Avatar(group.str('owner'), size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${group.number('members').toInt()} membri',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText(c),
                          ),
                        ),
                      ),
                      Text(
                        joined ? 'Apri gruppo' : 'Scopri',
                        style: TextStyle(
                          color: accent(c),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 7),
                      GIcon(
                        CupertinoIcons.arrow_right,
                        color: accent(c),
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityGroup extends StatefulWidget {
  const CommunityGroup({super.key, required this.id});
  final String id;

  @override
  State<CommunityGroup> createState() => _CommunityGroupState();
}

class _CommunityGroupState extends State<CommunityGroup> {
  static const categories = {
    'Discussioni': 'discussion',
    'Momenti': 'moment',
    'Eventi': 'event',
  };
  String selected = 'Discussioni';

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final group = s.state
        .rows('socialGroups')
        .firstWhere(
          (g) => g.str('id') == widget.id,
          orElse: () => <String, dynamic>{},
        );
    if (group.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppo')),
        body: const Center(child: Text('Gruppo non disponibile')),
      );
    }
    final items = s.state
        .rows('socialItems')
        .where((m) => m.str('group_id') == widget.id);
    final events = items.where((m) => m.str('kind') == 'event');
    final visible = items.where((m) => m.str('kind') == categories[selected]);
    final owner = group.str('owner') == s.myId;
    final joined = group.flag('joined');
    final cover = group.str('cover');
    return Scaffold(
      appBar: AppBar(title: Text(group.str('title')), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () => perform(c, s.refreshHome),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
              ),
              child: AspectRatio(
                aspectRatio: 2.1,
                child: cover.isNotEmpty
                    ? MediaView(cover, fit: BoxFit.cover)
                    : ColoredBox(
                        color: subdued(c),
                        child: GIcon(
                          CupertinoIcons.person_3_fill,
                          color: accent(c),
                          size: 62,
                        ),
                      ),
              ),
            ),
            ListTile(
              title: Text(
                group.str('title'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Gruppo pubblico · ${group.number('members').toInt()} membri',
              ),
              trailing: OutlinedButton(
                onPressed: owner
                    ? null
                    : () => perform(
                        c,
                        () => s.act('communityJoin', {
                          'id': widget.id,
                          'group': widget.id,
                          'enabled': !joined,
                        }),
                      ),
                child: Text(joined ? 'Membro' : 'Iscriviti'),
              ),
            ),
            if (group.str('description').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(group.str('description')),
              ),
            CommunityTabs(
              categories.keys.toList(),
              selected,
              (label) => setState(() => selected = label),
            ),
            if (selected == 'Discussioni' && events.isNotEmpty)
              ListTile(
                leading: GIcon(CupertinoIcons.calendar, color: accent(c)),
                title: const Text('Evento fissato'),
                subtitle: Text(events.first.str('title')),
                onTap: () =>
                    open(c, CommunityDetail(id: events.first.str('id'))),
              ),
            if (joined && (selected != 'Eventi' || owner))
              ListTile(
                leading: const GIcon(CupertinoIcons.plus_circle),
                title: Text(switch (selected) {
                  'Momenti' => 'Crea Momento',
                  'Eventi' => 'Fissa evento',
                  _ => 'Scrivi nel gruppo',
                }),
                onTap: () => composeCommunity(c, switch (selected) {
                  'Momenti' => 'communityMoment',
                  'Eventi' => 'communityEvent',
                  _ => 'communityDiscuss',
                }, group: widget.id),
              ),
            for (final item in visible) CommunityItem(item: item),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Ancora nessun contenuto.'),
              ),
          ],
        ),
      ),
    );
  }
}

class CommunityItem extends StatelessWidget {
  const CommunityItem({super.key, required this.item});
  final J item;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final kind = item.str('kind');
    final contributions = item.rows('contributions');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: subdued(c),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Avatar(item.str('author'), size: 40),
            title: Text(
              item.str('title').isEmpty ? item.str('text') : item.str('title'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${s.user(item.str('author')).str('username')} · ${relative(item['created'])}',
            ),
            trailing: Text(
              kind == 'moment'
                  ? '${contributions.length} scatti'
                  : '${contributions.length} risposte',
            ),
            onTap: () => open(c, CommunityDetail(id: item.str('id'))),
          ),
        ],
      ),
    );
  }
}

class CommunityDetail extends StatefulWidget {
  const CommunityDetail({super.key, required this.id});
  final String id;

  @override
  State<CommunityDetail> createState() => _CommunityDetailState();
}

class _CommunityDetailState extends State<CommunityDetail> {
  bool busy = false;

  Future<void> addPhoto(BuildContext c, GpixStore store) async {
    if (busy) return;
    setState(() => busy = true);
    await perform(c, () async {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (image == null || !c.mounted) return;
      final text = await textDialog(c, 'Didascalia (facoltativa)', '');
      if (text == null) return;
      final ref = await store.upload(
        image.path,
        image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      await store.act('communityContribute', {
        'id': widget.id,
        'media': ref,
        'text': text,
      });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final item = s.state
        .rows('socialItems')
        .firstWhere(
          (m) => m.str('id') == widget.id,
          orElse: () => <String, dynamic>{},
        );
    final moment = item.str('kind') == 'moment';
    final group = item.str('group_id');
    final canContribute =
        item.isNotEmpty &&
        (group.isEmpty ||
            s.state
                .rows('socialGroups')
                .any((g) => g.str('id') == group && g.flag('joined')));
    final rows = item.rows('contributions');
    final post = s.post(item.str('post'));
    final cover = post.isEmpty ? <String>[] : s.media(post);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(
              item.str('title').isEmpty
                  ? (moment ? 'Momento' : 'Discussione')
                  : item.str('title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (moment)
              Text(
                '${rows.length} contributi · ${group.isEmpty ? 'Solo invitati' : 'Solo membri'}',
                style: Theme.of(c).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => perform(c, s.refreshHome),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(14),
          children: [
            if (item.isEmpty)
              const ListTile(title: Text('Contenuto non disponibile')),
            if (item.str('text').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(item.str('text')),
              ),
            if (cover.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: InkWell(
                  onTap: () => open(c, PostPage(id: post.str('id'))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: MediaView(
                      cover.first,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            for (final contribution in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Avatar(contribution.str('author'), size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(left: 9, bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: moment
                                  ? auraBlue
                                  : Theme.of(c).dividerColor,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s
                                  .user(contribution.str('author'))
                                  .str('username'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              relative(contribution['created']),
                              style: Theme.of(c).textTheme.bodySmall,
                            ),
                            if (contribution.str('media').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => openPhotoPreview(
                                      c,
                                      contribution.str('media'),
                                    ),
                                    child: MediaView(
                                      contribution.str('media'),
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            if (contribution.str('text').isNotEmpty)
                              Text(contribution.str('text')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: canContribute
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : moment
                      ? () => addPhoto(c, s)
                      : () async {
                          final value = await textDialog(
                            c,
                            'Scrivi una risposta',
                            '',
                          );
                          if (value == null ||
                              value.trim().isEmpty ||
                              !c.mounted)
                            return;
                          await perform(
                            c,
                            () => s.act('communityReply', {
                              'id': widget.id,
                              'text': value.trim(),
                            }),
                          );
                        },
                  child: Text(
                    busy
                        ? 'Caricamento…'
                        : moment
                        ? '+ Aggiungi uno scatto'
                        : 'Rispondi',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

Future<void> composeCommunity(
  BuildContext c,
  String action, {
  String group = '',
  String post = '',
}) async {
  final s = GpixScope.of(c, listen: false);
  if (s.state.number('communityVersion') < 1) {
    notice(c, 'Gruppi e Momenti richiedono il server GPIX aggiornato.');
    return;
  }
  final moment = action == 'communityMoment';
  final needsTitle = action != 'communityDiscuss';
  final title = needsTitle
      ? await textDialog(c, switch (action) {
          'communityGroup' => 'Nome del gruppo',
          'communityEvent' => 'Nome dell’evento',
          _ => 'Titolo del Momento',
        }, '')
      : '';
  if (title == null || (needsTitle && title.trim().isEmpty) || !c.mounted)
    return;
  final body = await textDialog(
    c,
    action == 'communityDiscuss' ? 'Scrivi nel gruppo' : 'Descrizione',
    '',
  );
  if (body == null || !c.mounted) return;
  final invitees = <String>{};
  if (moment && group.isEmpty) {
    final confirmed = await sheet<bool>(
      c,
      StatefulBuilder(
        builder: (context, update) => Column(
          children: [
            const ListTile(
              title: Text('Invita persone'),
              subtitle: Text(
                'Solo tu e le persone selezionate vedrete il Momento.',
              ),
            ),
            for (final user in s.users.where(
              (u) =>
                  u.str('id') != s.myId &&
                  !s.blocked(u.str('id')) &&
                  s.follows(u.str('id')),
            ))
              CheckboxListTile(
                title: Text(user.str('username')),
                value: invitees.contains(user.str('id')),
                onChanged: (value) => update(() {
                  if (value == true && invitees.length < 30) {
                    invitees.add(user.str('id'));
                  } else if (value == false) {
                    invitees.remove(user.str('id'));
                  }
                }),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Crea Momento'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !c.mounted) return;
  }
  final previous = s.state.rows('socialItems').map((m) => m.str('id')).toSet();
  await perform(c, () async {
    String cover = '';
    if (action == 'communityGroup') {
      final withCover = await gpixAlert(
        c,
        'Copertina del gruppo',
        'Vuoi aggiungere una foto visibile a tutti?',
        confirm: 'Scegli foto',
        cancel: true,
      );
      if (!c.mounted) return;
      if (withCover) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 88,
        );
        if (image != null) {
          cover = await s.upload(
            image.path,
            image.path.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg',
          );
        }
      }
    }
    if (!c.mounted) return;
    await s.act(action, {
      'media': cover,
      'group': group,
      'post': post,
      'title': title.trim(),
      'text': body.trim(),
      'invitees': invitees.toList(),
    });
    if (!moment || !c.mounted) return;
    final created = s.state
        .rows('socialItems')
        .where(
          (m) =>
              m.str('author') == s.myId &&
              m.str('kind') == 'moment' &&
              !previous.contains(m.str('id')),
        )
        .firstOrNull;
    if (created != null) open(c, CommunityDetail(id: created.str('id')));
  });
}

/// Timeline cards consume only community records authorized by the server.
/// Private conversation groups never enter the public timeline.
class CommunityFeedCard extends StatelessWidget {
  const CommunityFeedCard({super.key, required this.item, this.group = false});
  final J item;
  final bool group;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final author = item.str(group ? 'owner' : 'author');
    final photos = <String>[
      if (item.str('cover').isNotEmpty) item.str('cover'),
      if (item.str('media').isNotEmpty) item.str('media'),
      ...item
          .rows('contributions')
          .map((row) => row.str('media'))
          .where((ref) => ref.isNotEmpty),
    ];
    final title = item.str('title').isEmpty
        ? (group ? 'Un nuovo gruppo' : 'Un nuovo Momento')
        : item.str('title');
    final people = <String>{
      author,
      ...item.rows('contributions').map((row) => row.str('author')),
    }.where((id) => id.isNotEmpty).take(4).toList();
    void view() => open(
      c,
      group
          ? CommunityGroup(id: item.str('id'))
          : CommunityDetail(id: item.str('id')),
    );
    return Container(
      key: ValueKey(
        'community-feed-${group ? 'group' : 'moment'}-${item.str('id')}',
      ),
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface(c),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(c).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .055),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: auraBlue.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: GIcon(
                    group
                        ? CupertinoIcons.person_3
                        : CupertinoIcons.photo_on_rectangle,
                    color: accent(c),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group ? 'Nuovo gruppo' : 'Momento condiviso',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${s.user(author).str('username')}${item.number('created') > 0 ? ' · ${relative(item['created'])}' : ''}',
                        style: TextStyle(fontSize: 11, color: secondaryText(c)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: group ? 'Apri gruppo' : 'Apri Momento',
                  onPressed: view,
                  icon: const GIcon(CupertinoIcons.arrow_up_right, size: 20),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: view,
            child: SizedBox(
              height: photos.isEmpty ? 120 : 210,
              width: double.infinity,
              child: photos.isNotEmpty
                  ? Row(
                      children: [
                        for (final ref in photos.take(3))
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: MediaView(
                                ref,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 210,
                              ),
                            ),
                          ),
                      ],
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: Theme.of(c).brightness == Brightness.dark
                              ? [
                                  const Color(0xff142332),
                                  const Color(0xff233e54),
                                ]
                              : [
                                  const Color(0xffe3eef7),
                                  const Color(0xfff2f7fa),
                                ],
                        ),
                      ),
                      child: Center(
                        child: GIcon(
                          group
                              ? CupertinoIcons.person_3_fill
                              : CupertinoIcons.camera_on_rectangle,
                          color: accent(c),
                          size: 46,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                if ((group ? item.str('description') : item.str('text'))
                    .isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    group ? item.str('description') : item.str('text'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryText(c), height: 1.4),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: people.length * 18.0 + 12,
                      height: 30,
                      child: Stack(
                        children: [
                          for (var i = people.length - 1; i >= 0; i--)
                            Positioned(
                              left: i * 18.0,
                              child: Avatar(people[i], size: 30),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        group
                            ? '${item.number('members').toInt()} membri'
                            : '${item.rows('contributions').length} scatti',
                        style: TextStyle(fontSize: 12, color: secondaryText(c)),
                      ),
                    ),
                    FilledButton(
                      onPressed: view,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                      child: Text(
                        group ? 'Scopri gruppo' : 'Apri Momento',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
