import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/data.dart';
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
  late final TabController tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initial)
        ..addListener(() {
          if (mounted) setState(() {});
        });
  final search = TextEditingController();
  @override
  void dispose() {
    tabs.dispose();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), u = s.user(widget.user);
    final own = widget.user == s.myId;
    final lists = [
      u.ids('followersList'),
      own ? s.state.ids('following') : u.ids('followingList'),
    ];
    final query = search.text.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(
        title: pageTitle(u.str('username')),
        bottom: TabBar(
          controller: tabs,
          labelColor: ink,
          unselectedLabelColor: muted,
          indicatorColor: ink,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: line,
          tabs: [
            Tab(text: '${u.str('followers', '0')} follower'),
            Tab(text: '${u.str('following', '0')} seguiti'),
          ],
        ),
      ),
      body: u.flag('private') && !own && !s.follows(widget.user)
          ? const EmptyState(
              CupertinoIcons.lock,
              'Lista privata',
              'Segui questo account per visualizzare le persone.',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 18, 17, 8),
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cerca',
                      prefixIcon: const GIcon(
                        CupertinoIcons.search,
                        size: 19,
                        color: muted,
                      ),
                      filled: true,
                      fillColor: soft,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(11),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabs,
                    children: [
                      for (var i = 0; i < 2; i++)
                        Builder(
                          builder: (c) {
                            final ids = lists[i]
                                .where(
                                  (id) =>
                                      !s.blocked(id) &&
                                      '${s.user(id).str('username')} ${s.user(id).str('name')}'
                                          .toLowerCase()
                                          .contains(query),
                                )
                                .toList();
                            if (ids.isEmpty)
                              return EmptyState(
                                CupertinoIcons.person_2,
                                query.isEmpty
                                    ? (i == 0
                                          ? 'Nessun follower'
                                          : 'Nessun account seguito')
                                    : 'Nessun risultato',
                                query.isEmpty
                                    ? 'Le persone appariranno qui.'
                                    : 'Prova un altro nome.',
                              );
                            return ListView.builder(
                              itemCount: ids.length,
                              itemBuilder: (c, j) {
                                final id = ids[j],
                                    following = s.follows(id),
                                    pending = s.state
                                        .ids('pending')
                                        .contains(id);
                                return PersonTile(
                                  id,
                                  onTap: () => open(c, Profile(user: id)),
                                  trailing: id == s.myId
                                      ? null
                                      : SizedBox(
                                          width: 103,
                                          height: 33,
                                          child: FilledButton(
                                            onPressed: () => perform(c, () async {
                                              if (own && i == 0) {
                                                if (!await gpixAlert(
                                                  c,
                                                  'Rimuovere ${s.user(id).str('username')}?',
                                                  'Non riceverà una notifica della rimozione.',
                                                  confirm: 'Rimuovi',
                                                  cancel: true,
                                                ))
                                                  return;
                                                await s.act('removeFollower', {
                                                  'user': id,
                                                });
                                              } else {
                                                if (following &&
                                                    !await gpixAlert(
                                                      c,
                                                      'Non seguire più ${s.user(id).str('username')}?',
                                                      'Puoi iniziare a seguirlo di nuovo dal profilo.',
                                                      confirm:
                                                          'Non seguire più',
                                                      cancel: true,
                                                    ))
                                                  return;
                                                await s.act('follow', {
                                                  'user': id,
                                                  'enabled':
                                                      !following && !pending,
                                                });
                                              }
                                            }),
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  (own && i == 0) ||
                                                      following ||
                                                      pending
                                                  ? soft
                                                  : violet,
                                              foregroundColor:
                                                  (own && i == 0) ||
                                                      following ||
                                                      pending
                                                  ? ink
                                                  : Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              own && i == 0
                                                  ? 'Rimuovi'
                                                  : pending
                                                  ? 'Richiesta inviata'
                                                  : following
                                                  ? 'Segui già'
                                                  : 'Segui',
                                              maxLines: 1,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
