import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart';

class Connections extends StatefulWidget {
  final String user;
  final int initial;
  const Connections({super.key, required this.user, this.initial = 0});

  @override
  State<Connections> createState() => _ConnectionsState();
}

class _ConnectionsState extends State<Connections>
    with SingleTickerProviderStateMixin {
  late final tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initial,
  );
  final searches = List.generate(2, (_) => TextEditingController());
  final orders = [false, false];
  final busy = <String>{};

  @override
  void dispose() {
    tabs.dispose();
    for (final search in searches) {
      search.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final person = store.user(widget.user);
    final own = widget.user == store.myId;
    final private =
        person.flag('private') && !own && !store.follows(widget.user);
    final suggestions = store.users
        .map((person) => person.str('id'))
        .where(
          (id) =>
              id.isNotEmpty &&
              id != store.myId &&
              !store.follows(id) &&
              !store.blocked(id),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(7),
          child: IconButton.outlined(
            tooltip: 'Indietro',
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            icon: const GIcon(CupertinoIcons.chevron_back, size: 22),
          ),
        ),
        title: pageTitle(person.str('username')),
        actions: [
          if (own)
            IconButton(
              tooltip: 'Persone suggerite',
              icon: const GIcon(CupertinoIcons.person_badge_plus),
              onPressed: () => _openPeople(
                'Persone suggerite',
                suggestions,
                allowFollow: true,
              ),
            ),
        ],
        bottom: TabBar(
          controller: tabs,
          labelColor: foreground(context),
          unselectedLabelColor: secondaryText(context),
          indicatorColor: foreground(context),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Theme.of(context).dividerColor,
          tabs: [
            Tab(text: '${person.str('followers', '0')} follower'),
            Tab(text: '${person.str('following', '0')} seguiti'),
          ],
        ),
      ),
      body: private
          ? const EmptyState(
              CupertinoIcons.lock,
              'Lista privata',
              'Segui questo account per visualizzare le persone.',
            )
          : TabBarView(
              controller: tabs,
              children: [
                _list(store, 0, own, person.ids('followersList'), suggestions),
                _list(
                  store,
                  1,
                  own,
                  own
                      ? store.state.ids('following')
                      : person.ids('followingList'),
                  suggestions,
                ),
              ],
            ),
    );
  }

  void _openPeople(String title, List<String> ids, {bool allowFollow = false}) {
    FocusScope.of(context).unfocus();
    open(
      context,
      PeopleDirectory(title: title, ids: ids, allowFollow: allowFollow),
    );
  }

  Widget _list(
    GpixStore store,
    int tab,
    bool own,
    List<String> all,
    List<String> suggestions,
  ) {
    final controller = searches[tab];
    final query = controller.text.trim().toLowerCase();
    final ids = all.where((id) {
      if (store.blocked(id)) return false;
      final person = store.user(id);
      return '${person.str('username')} ${person.str('name')}'
          .toLowerCase()
          .contains(query);
    }).toList();
    if (orders[tab]) {
      ids.sort(
        (a, b) => store
            .user(a)
            .str('username')
            .toLowerCase()
            .compareTo(store.user(b).str('username').toLowerCase()),
      );
    }
    final requests = store.state
        .ids('requests')
        .where((id) => !store.blocked(id))
        .toList();
    final notFollowed = ids
        .where((id) => id != store.myId && !store.follows(id))
        .toList();
    final interacted = <String>{
      if (own && query.isEmpty)
        for (final post in store.allPosts)
          if (post.ids('likes').contains(store.myId) ||
              post
                  .rows('comments')
                  .any((comment) => comment.str('author') == store.myId))
            post.str('author'),
    };
    final withoutInteractions = ids
        .where((id) => id != store.myId && !interacted.contains(id))
        .toList();
    final muted = ids.where(store.preferences.ids('muted').contains).toList();
    return CustomScrollView(
      key: PageStorageKey(('connections', widget.user, tab)),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              key: ValueKey(('connection-search', tab)),
              controller: controller,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cerca nome utente o nome visualizzato',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: GIcon(
                  CupertinoIcons.search,
                  size: 17,
                  color: secondaryText(context),
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Cancella ricerca',
                        onPressed: () => setState(controller.clear),
                        icon: const GIcon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 17,
                        ),
                      ),
                filled: true,
                fillColor: subdued(context),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                constraints: const BoxConstraints(minHeight: 42),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                suffixIconConstraints: const BoxConstraints(minHeight: 38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        if (query.isEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (own && tab == 0)
                  ListTile(
                    leading: requests.isEmpty
                        ? const GIcon(CupertinoIcons.person_2)
                        : Avatar(requests.first, size: 40),
                    title: const Text('Richieste di seguirti'),
                    subtitle: requests.isEmpty
                        ? null
                        : Text(
                            requests.length == 1
                                ? store.user(requests.first).str('username')
                                : '${store.user(requests.first).str('username')} + altri ${requests.length - 1}',
                          ),
                    trailing: const GIcon(
                      CupertinoIcons.chevron_forward,
                      size: 17,
                    ),
                    onTap: () => open(context, const Requests()),
                  ),
                if (own && tab == 1 && suggestions.isNotEmpty)
                  ListTile(
                    leading: const GIcon(CupertinoIcons.person_badge_plus),
                    title: const Text('Persone suggerite'),
                    trailing: const GIcon(
                      CupertinoIcons.chevron_forward,
                      size: 17,
                    ),
                    onTap: () => _openPeople(
                      'Persone suggerite',
                      suggestions,
                      allowFollow: true,
                    ),
                  ),
                if (own) ...[
                  const _ConnectionHeading('Categorie'),
                  if (tab == 0)
                    _category(
                      'Persone che non segui a tua volta',
                      notFollowed,
                      CupertinoIcons.person_2,
                    ),
                  _category(
                    'Account con cui non hai interagito',
                    withoutInteractions,
                    CupertinoIcons.heart,
                  ),
                  if (tab == 1)
                    _category(
                      'Account silenziati',
                      muted,
                      CupertinoIcons.speaker_slash,
                    ),
                ],
                if (ids.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: _ConnectionHeading(
                          orders[tab]
                              ? 'Ordina per Nome utente'
                              : 'Ordina per Predefinito',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ordina elenco',
                        onPressed: () => _chooseOrder(tab),
                        icon: const GIcon(
                          CupertinoIcons.arrow_up_arrow_down,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ],
                  ),
              ],
            ),
          ),
        if (ids.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              CupertinoIcons.person_2,
              query.isNotEmpty
                  ? 'Nessun risultato'
                  : (tab == 0 ? 'Nessun follower' : 'Nessun account seguito'),
              query.isNotEmpty
                  ? 'Prova un altro nome.'
                  : 'Le persone appariranno qui.',
            ),
          ),
        SliverList.builder(
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            final following = store.follows(id);
            final pending = store.state.ids('pending').contains(id);
            return _ConnectionPerson(
              key: ValueKey(id),
              id: id,
              trailing: id == store.myId
                  ? null
                  : Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (own && tab == 0)
                          _ConnectionButton(
                            'Rimuovi',
                            onPressed: busy.contains(id)
                                ? null
                                : () => _remove(store, id),
                          ),
                        _ConnectionButton(
                          pending
                              ? 'In attesa'
                              : following
                              ? 'Segui già'
                              : 'Segui',
                          primary: !pending && !following && !(own && tab == 0),
                          onPressed: busy.contains(id)
                              ? null
                              : () => _follow(store, id),
                        ),
                      ],
                    ),
            );
          },
          findChildIndexCallback: (key) {
            final index = ids.indexOf((key as ValueKey<String>).value);
            return index < 0 ? null : index;
          },
        ),
        const SliverToBoxAdapter(
          child: SafeArea(top: false, child: SizedBox(height: 12)),
        ),
      ],
    );
  }

  Widget _category(String title, List<String> ids, IconData icon) => ListTile(
    leading: ids.isEmpty ? GIcon(icon) : Avatar(ids.first, size: 40),
    title: Text(title),
    subtitle: Text(ids.length == 1 ? '1 account' : '${ids.length} account'),
    onTap: () => _openPeople(title, ids),
  );

  Future<void> _chooseOrder(int tab) async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ConnectionHeading('Ordina per'),
            for (final (alphabetical, title) in [
              (false, 'Predefinito'),
              (true, 'Nome utente'),
            ])
              ListTile(
                title: Text(title),
                trailing: orders[tab] == alphabetical
                    ? const GIcon(CupertinoIcons.check_mark)
                    : null,
                onTap: () => Navigator.pop(context, alphabetical),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => orders[tab] = selected);
  }

  Future<void> _remove(GpixStore store, String id) async {
    final name = store.user(id).str('username');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(id, size: 57),
              const SizedBox(height: 10),
              Text(
                'Vuoi rimuovere il follower?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Text(
                '$name non riceverà una notifica della rimozione.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: danger),
                child: const Text('Rimuovi'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(id, () async {
      await store.act('removeFollower', {'user': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Follower rimosso'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _follow(GpixStore store, String id) async {
    final following = store.follows(id);
    final pending = store.state.ids('pending').contains(id);
    if (following &&
        !await gpixAlert(
          context,
          'Vuoi smettere di seguire ${store.user(id).str('username')}?',
          'Puoi iniziare a seguire di nuovo questo account dal profilo.',
          confirm: 'Non seguire più',
          destructive: true,
          cancel: true,
        ))
      return;
    if (!mounted) return;
    await _run(
      id,
      () =>
          store.act('follow', {'user': id, 'enabled': !following && !pending}),
    );
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      await perform(context, action);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }
}

class _ConnectionHeading extends StatelessWidget {
  const _ConnectionHeading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 9),
    child: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
  );
}

class _ConnectionPerson extends StatelessWidget {
  const _ConnectionPerson({super.key, required this.id, this.trailing});
  final String id;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final person = store.user(id);
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        open(context, Profile(user: id));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Avatar(id, size: 43, ring: store.stories(id).isNotEmpty),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.str('username'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (person.str('name').isNotEmpty)
                    Text(
                      person.str('name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText(context),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton(this.label, {this.primary = false, this.onPressed});
  final String label;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: primary ? const Color(0xff4656f6) : subdued(context),
      foregroundColor: primary ? Colors.white : foreground(context),
      minimumSize: const Size(66, 32),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
    child: Text(label),
  );
}

class PeopleDirectory extends StatelessWidget {
  const PeopleDirectory({
    super.key,
    required this.title,
    required this.ids,
    required this.allowFollow,
  });
  final String title;
  final List<String> ids;
  final bool allowFollow;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final visible = ids.where((id) => !store.blocked(id)).toList();
    return Scaffold(
      appBar: AppBar(title: pageTitle(title), centerTitle: true),
      body: visible.isEmpty
          ? const EmptyState(
              CupertinoIcons.person_2,
              'Nessun account',
              'Gli account appariranno qui.',
            )
          : SafeArea(
              top: false,
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final id = visible[index];
                  final following = store.follows(id);
                  final pending = store.state.ids('pending').contains(id);
                  return _ConnectionPerson(
                    id: id,
                    trailing: allowFollow
                        ? _ConnectionButton(
                            following
                                ? 'Segui già'
                                : pending
                                ? 'In attesa'
                                : 'Segui',
                            primary: !following && !pending,
                            onPressed: following || pending
                                ? null
                                : () => perform(
                                    context,
                                    () => store.act('follow', {
                                      'user': id,
                                      'enabled': true,
                                    }),
                                  ),
                          )
                        : null,
                  );
                },
              ),
            ),
    );
  }
}
