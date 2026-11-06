export 'profile_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../core/drafts.dart';
import '../core/push_service.dart';
import '../ui/kit.dart';
import 'post_composer.dart';
import 'stories.dart';
import 'messages.dart' show AudioBubble;

class AccountSecurity extends StatefulWidget {
  final String mode;
  const AccountSecurity({super.key, this.mode = 'change-password'});
  @override
  State<AccountSecurity> createState() => _AccountSecurityState();
}

class _AccountSecurityState extends State<AccountSecurity> {
  final login = TextEditingController(),
      code = TextEditingController(),
      current = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool sent = false, busy = false;
  String error = '', info = '';
  @override
  void dispose() {
    for (final t in [login, code, current, password, confirm]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final s = GpixScope.of(context, listen: false);
    setState(() {
      busy = true;
      error = '';
      info = '';
    });
    try {
      if (s.demo)
        throw Exception(
          'Nella demo non esistono credenziali reali. Accedi a un account per usare questa funzione.',
        );
      if (widget.mode == 'verify') {
        if (!sent) {
          await s.accountRequest('verification-send', {});
          setState(() => sent = true);
          info = 'Ti abbiamo inviato un codice. Controlla anche lo spam.';
        } else {
          await s.verifyEmail(code.text.trim());
          if (mounted) Navigator.maybePop(context);
        }
      } else if (widget.mode == 'forgot' && !sent) {
        if (login.text.trim().isEmpty)
          throw Exception('Inserisci email o nome utente');
        final r = await s.accountRequest('forgot', {
          'login': login.text.trim(),
        });
        info = r.str('message');
        sent = true;
      } else {
        if (password.text.length < 10 || password.text.length > 256)
          throw Exception('Usa da 10 a 256 caratteri');
        if (password.text != confirm.text)
          throw Exception('Le password non coincidono');
        await s.accountRequest(
          widget.mode == 'forgot' ? 'reset' : 'change-password',
          {
            'login': login.text.trim(),
            'code': code.text.trim(),
            'current': current.text,
            'password': password.text,
          },
        );
        if (mounted) {
          notice(
            context,
            widget.mode == 'forgot'
                ? 'Password aggiornata. Ora puoi accedere.'
                : 'Password aggiornata. Le altre sessioni sono state disconnesse.',
          );
          Navigator.maybePop(context);
        }
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final verify = widget.mode == 'verify', forgot = widget.mode == 'forgot';
    Widget field(
      TextEditingController t,
      String title, {
      bool secret = false,
      TextInputType? keyboard,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: t,
        obscureText: secret,
        keyboardType: keyboard,
        autocorrect: !secret,
        enableSuggestions: !secret,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          verify
              ? 'Verifica email'
              : forgot
              ? 'Recupera password'
              : 'Cambia password',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (verify)
            const Padding(
              padding: EdgeInsets.only(bottom: 22),
              child: Text(
                'Per continuare, conferma l’indirizzo email del tuo account con il codice ricevuto.',
              ),
            ),
          if (forgot) field(login, 'Email o nome utente'),
          if (!forgot && !verify)
            field(current, 'Password attuale', secret: true),
          if (sent && (forgot || verify))
            field(code, 'Codice ricevuto', keyboard: TextInputType.number),
          if (!verify && (!forgot || sent)) ...[
            field(password, 'Nuova password', secret: true),
            field(confirm, 'Ripeti nuova password', secret: true),
          ],
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(error, style: const TextStyle(color: danger)),
            ),
          if (info.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(info),
            ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(
              busy
                  ? 'Attendi…'
                  : verify
                  ? (sent ? 'Verifica codice' : 'Invia codice')
                  : forgot && !sent
                  ? 'Invia codice'
                  : 'Salva password',
            ),
          ),
          if (sent && (forgot || verify))
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() => sent = false);
                      submit();
                    },
              child: const Text('Invia un nuovo codice'),
            ),
          if (verify)
            TextButton(
              onPressed: () => GpixScope.of(c, listen: false).logout(),
              child: const Text('Esci'),
            ),
        ],
      ),
    );
  }
}

class GridOrder extends StatefulWidget {
  const GridOrder({super.key});
  @override
  State<GridOrder> createState() => _GridOrderState();
}

class _GridOrderState extends State<GridOrder> {
  List<String>? ids;
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    ids ??= [
      ...s.me.ids('gridOrder'),
      ...s.allPosts
          .where(
            (p) =>
                p.str('author') == s.myId &&
                p.str('kind') != 'story' &&
                !p.flag('archived'),
          )
          .map((p) => p.str('id')),
    ].toSet().where((id) => s.post(id).isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riordina griglia'),
        actions: [
          TextButton(
            onPressed: () => perform(c, () async {
              await s.act('gridOrder', {'ids': ids});
              if (c.mounted) Navigator.pop(c);
            }),
            child: const Text('Fine'),
          ),
        ],
      ),
      body: ids!.isEmpty
          ? const Center(
              child: Text('Pubblica un post per riordinare la griglia.'),
            )
          : ReorderableListView.builder(
              itemCount: ids!.length,
              onReorder: (old, next) => setState(() {
                if (next > old) next--;
                final id = ids!.removeAt(old);
                ids!.insert(next, id);
              }),
              itemBuilder: (c, i) {
                final p = s.post(ids![i]);
                return ListTile(
                  key: ValueKey(ids![i]),
                  leading: SizedBox(
                    width: 48,
                    height: 60,
                    child: MediaView(p.str('media')),
                  ),
                  title: Text(
                    p.str('text', 'Post'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Tieni premuto e trascina'),
                  trailing: const GIcon(CupertinoIcons.line_horizontal_3),
                );
              },
            ),
    );
  }
}

class PrivacyTools extends StatelessWidget {
  const PrivacyTools({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    Widget permission(String key, String title) => ListTile(
      leading: GIcon(
        key == 'allowMessages' ? CupertinoIcons.paperplane : CupertinoIcons.at,
      ),
      title: Text(title),
      trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
      subtitle: Text(
        s.preferences.str(key, 'all') == 'all'
            ? 'Tutti'
            : s.preferences.str(key) == 'following'
            ? 'Persone che segui'
            : 'Nessuno',
      ),
      onTap: () => sheet(
        c,
        Builder(
          builder: (menu) => Column(
            children: [
              for (final e in {
                'all': 'Tutti',
                'following': 'Persone che segui',
                'none': 'Nessuno',
              }.entries)
                ListTile(
                  leading: GIcon(
                    e.key == 'all'
                        ? CupertinoIcons.globe
                        : e.key == 'following'
                        ? CupertinoIcons.person_2
                        : CupertinoIcons.nosign,
                  ),
                  title: Text(e.value),
                  onTap: () => perform(menu, () async {
                    await s.act('preferences', {'key': key, 'value': e.key});
                    if (menu.mounted) Navigator.pop(menu);
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy e interazioni')),
      body: ListView(
        children: [
          permission('allowMessages', 'Chi può inviarti messaggi e chiamarti'),
          permission('allowMentions', 'Chi può taggarti e menzionarti'),
          for (final e in {
            'hiddenStories': 'Nascondi le storie a',
            'muted': 'Account silenziati',
            'restricted': 'Account con restrizioni',
          }.entries)
            ListTile(
              leading: GIcon(
                e.key == 'hiddenStories'
                    ? CupertinoIcons.eye_slash
                    : e.key == 'muted'
                    ? CupertinoIcons.bell_slash
                    : CupertinoIcons.person_crop_circle_badge_xmark,
              ),
              title: Text(e.value),
              subtitle: Text('${s.preferences.ids(e.key).length} persone'),
              trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
              onTap: () =>
                  open(c, PrivacyPeople(prefKey: e.key, title: e.value)),
            ),
        ],
      ),
    );
  }
}

class PrivacyPeople extends StatelessWidget {
  final String prefKey, title;
  const PrivacyPeople({super.key, required this.prefKey, required this.title});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), selected = s.preferences.ids(prefKey);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        children: [
          if (prefKey == 'restricted')
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'I messaggi di questi account vengono spostati nelle richieste. Non riceverai notifiche push da loro.',
              ),
            ),
          for (final u in s.users.where(
            (u) => u.str('id') != s.myId && !s.blocked(u.str('id')),
          ))
            CheckboxListTile(
              title: Text(u.str('username')),
              secondary: Avatar(u.str('id'), size: 38),
              value: selected.contains(u.str('id')),
              onChanged: (v) => perform(c, () async {
                final next = [...selected]..remove(u.str('id'));
                if (v == true) next.add(u.str('id'));
                await s.act('preferences', {'key': prefKey, 'value': next});
              }),
            ),
        ],
      ),
    );
  }
}

class SharedMedia extends StatelessWidget {
  final String thread;
  const SharedMedia({super.key, required this.thread});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final messages = s
        .thread(thread)
        .rows('messages')
        .where(
          (m) =>
              m.str('media').isNotEmpty &&
              !m.flag('viewOnce') &&
              !m.flag('afterRead') &&
              (m.number('expires') == 0 ||
                  m.number('expires') >
                      DateTime.now().millisecondsSinceEpoch / 1000),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Contenuti condivisi')),
      body: messages.isEmpty
          ? const Center(
              child: Text('Non ci sono contenuti condivisi disponibili.'),
            )
          : ListView(
              children: [
                for (final m in messages)
                  ListTile(
                    leading: SizedBox(
                      width: 56,
                      height: 56,
                      child: m.str('kind') == 'image' || m.str('kind') == 'gif'
                          ? MediaView(m.str('media'))
                          : const GIcon(CupertinoIcons.play_circle),
                    ),
                    title: Text(
                      m.str('kind') == 'audio'
                          ? 'Messaggio vocale'
                          : m.str('text').isEmpty
                          ? 'Contenuto multimediale'
                          : m.str('text'),
                    ),
                    subtitle: Text(relative(m['created'])),
                    onTap: () => open(
                      c,
                      Scaffold(
                        appBar: AppBar(
                          title: const Text('Contenuto condiviso'),
                        ),
                        body: Center(
                          child: m.str('kind') == 'audio'
                              ? AudioBubble(
                                  reference: m.str('media'),
                                  own: false,
                                )
                              : InteractiveViewer(
                                  minScale: .5,
                                  maxScale: 5,
                                  child: MediaView(
                                    m.str('media'),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class DraftList extends StatefulWidget {
  const DraftList({super.key});
  @override
  State<DraftList> createState() => _DraftListState();
}

class _DraftListState extends State<DraftList> {
  Future<List<J>>? load;
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), account = '${s.server}|${s.myId}';
    load ??= Drafts.list(account);
    return Scaffold(
      appBar: AppBar(title: const Text('Bozze')),
      body: FutureBuilder<List<J>>(
        future: load,
        builder: (c, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snap.data!.isEmpty)
            return const Center(
              child: Text('Le bozze salvate appariranno qui.'),
            );
          return ListView(
            children: [
              for (final d in snap.data!)
                ListTile(
                  leading: d.ids('files').isNotEmpty
                      ? SizedBox(
                          width: 50,
                          height: 60,
                          child: d.str('kind') == 'reel'
                              ? const GIcon(CupertinoIcons.play_rectangle)
                              : MediaView(d.ids('files').first),
                        )
                      : const GIcon(CupertinoIcons.doc_text),
                  title: Text(
                    d.str('text').isEmpty
                        ? (d.str('kind') == 'reel' ? 'Reel' : 'Post')
                        : d.str('text'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Salvata su questo dispositivo'),
                  trailing: IconButton(
                    tooltip: 'Elimina bozza',
                    icon: const GIcon(CupertinoIcons.trash),
                    onPressed: () async {
                      await Drafts.delete(account, d.str('id'));
                      if (mounted) setState(() => load = Drafts.list(account));
                    },
                  ),
                  onTap: () async {
                    await open(
                      c,
                      d.str('kind') == 'post'
                          ? PostComposer(initialDraft: d)
                          : Composer(kind: d.str('kind'), initialDraft: d),
                    );
                    if (mounted) setState(() => load = Drafts.list(account));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class PushSettings extends StatefulWidget {
  const PushSettings({super.key});
  @override
  State<PushSettings> createState() => _PushSettingsState();
}

class _PushSettingsState extends State<PushSettings> {
  String status = '';
  bool busy = false;
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifiche push')),
      body: ListView(
        children: [
          if (!PushService.nativePushAvailable)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Le notifiche push non sono disponibili in questa build. L’attività dentro GPIX resta disponibile.',
              ),
            ),
          SwitchListTile.adaptive(
            secondary: const GIcon(CupertinoIcons.bell),
            title: const Text('Ricevi notifiche'),
            subtitle: const Text(
              'Messaggi, richieste, commenti, chiamate e avvisi da GPIX.',
            ),
            value: s.preferences['pushEnabled'] != false,
            onChanged: busy
                ? null
                : (v) => perform(
                    c,
                    () => s.act('preferences', {
                      'key': 'pushEnabled',
                      'value': v,
                    }),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: FilledButton(
              onPressed:
                  busy ||
                      !PushService.nativePushAvailable ||
                      s.preferences['pushEnabled'] == false
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        status = '';
                      });
                      try {
                        status = await PushService.instance.enable(s);
                      } catch (e) {
                        status = e.toString().replaceFirst('Exception: ', '');
                      }
                      if (mounted) setState(() => busy = false);
                    },
              child: Text(
                busy
                    ? 'Registrazione in corso…'
                    : 'Attiva o verifica questo dispositivo',
              ),
            ),
          ),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Semantics(liveRegion: true, child: Text(status)),
            ),
        ],
      ),
    );
  }
}
