import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

class CloseFriends extends StatefulWidget {
  const CloseFriends({super.key});
  @override
  State<CloseFriends> createState() => _CloseFriendsState();
}

class _CloseFriendsState extends State<CloseFriends> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), selected = s.state.ids('closeFriends');
    final users =
        s.users
            .where(
              (u) =>
                  u.str('id') != s.myId &&
                  !s.blocked(u.str('id')) &&
                  '${u.str('username')} ${u.str('name')}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => (selected.contains(b.str('id')) ? 1 : 0).compareTo(
              selected.contains(a.str('id')) ? 1 : 0,
            ),
          );
    return Scaffold(
      appBar: AppBar(title: pageTitle('Amici più stretti')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                GIcon(
                  CupertinoIcons.star_circle_fill,
                  color: Colors.green,
                  size: 55,
                ),
                SizedBox(height: 14),
                Text(
                  'Scegli con chi condividere',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
                ),
                SizedBox(height: 8),
                Text(
                  'La lista è privata. Le persone non ricevono notifiche quando le aggiungi o le rimuovi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                hintText: 'Cerca',
                prefixIcon: GIcon(CupertinoIcons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${selected.length} persone selezionate',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final u in users)
                  CheckboxListTile(
                    secondary: Avatar(u.str('id')),
                    title: Text(u.str('username')),
                    subtitle: Text(u.str('name')),
                    activeColor: Colors.green,
                    value: selected.contains(u.str('id')),
                    onChanged: (v) => perform(
                      c,
                      () =>
                          s.act('closeFriend', {'user': u['id'], 'enabled': v}),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: PrimaryButton('Fine', onTap: () => Navigator.pop(c)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> relationshipMenu(BuildContext c, String user) async {
  final s = GpixScope.of(c, listen: false);
  await sheet(
    c,
    Builder(
      builder: (menu) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Avatar(user, size: 64),
                const SizedBox(height: 10),
                Text(
                  s.user(user).str('username'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const GIcon(CupertinoIcons.star_fill, color: Colors.green),
            title: const Text('Amici più stretti'),
            subtitle: Text(
              s.state.ids('closeFriends').contains(user)
                  ? 'Nella tua lista privata'
                  : 'Condividi le storie riservate con questa persona',
            ),
            trailing: GIcon(
              s.state.ids('closeFriends').contains(user)
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: Colors.green,
            ),
            onTap: () async {
              await perform(
                menu,
                () => s.act('closeFriend', {
                  'user': user,
                  'enabled': !s.state.ids('closeFriends').contains(user),
                }),
              );
              if (menu.mounted) Navigator.pop(menu);
            },
          ),
          ActionRow(CupertinoIcons.person_badge_minus, 'Non seguire più', () {
            Navigator.pop(menu);
            perform(c, () => s.act('follow', {'user': user, 'enabled': false}));
          }),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
