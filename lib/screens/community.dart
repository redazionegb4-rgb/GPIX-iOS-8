import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'messages.dart';
import 'social.dart' show textDialog;

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

/// Shared by profile and inbox, including the two thought-bubble dots.
class NoteBubble extends StatelessWidget {
  final String text;
  final bool placeholder;
  const NoteBubble({super.key, required this.text, this.placeholder = false});
  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    final fill = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xfff8f9fb);
    final border = theme.dividerColor;
    Widget dot(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        shape: BoxShape.circle,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('note-bubble-body'),
          constraints: const BoxConstraints(minHeight: 37),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.15,
              color: placeholder ? secondaryText(c) : foreground(c),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 19),
          child: Align(alignment: Alignment.centerLeft, child: dot(6)),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Align(alignment: Alignment.centerLeft, child: dot(4)),
        ),
      ],
    );
  }
}

class NotesTray extends StatefulWidget {
  const NotesTray({super.key});
  @override
  State<NotesTray> createState() => _NotesTrayState();
}

class _NotesTrayState extends State<NotesTray> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), notes = s.notes;
    final own = notes.where((n) => n.str('owner') == s.myId).firstOrNull;
    final textSize = MediaQuery.textScalerOf(
      c,
    ).scale(12).clamp(12.0, double.infinity);
    final bubbleHeight = 34 + textSize * 2.4;
    return SizedBox(
      height: bubbleHeight + 86 + textSize * 1.25,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        children: [
          tile(c, s.myId, own, bubbleHeight, own: true),
          for (final n in notes.where((n) => n.str('owner') != s.myId))
            tile(c, n.str('owner'), n, bubbleHeight),
        ],
      ),
    );
  }

  Widget tile(
    BuildContext c,
    String id,
    J? note,
    double bubbleHeight, {
    bool own = false,
  }) {
    final s = GpixScope.of(c);
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: () => own ? manageOwnNote(c) : replyNote(c, note!),
        onDoubleTap: own || note == null
            ? null
            : () => perform(
                c,
                () => s.act('noteReact', {
                  'user': id,
                  'created': note['created'],
                  'enabled': true,
                }),
              ),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SizedBox(
              width: 84,
              height: bubbleHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: NoteBubble(
                  text: note?.str('text') ?? 'Lascia una nota…',
                  placeholder: note == null,
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 74,
              height: 65,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Avatar(id, size: 64),
                  if (note?.flag('likedByMe') == true ||
                      own && (note?.number('likesCount') ?? 0) > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: surface(c),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.heart_fill,
                          color: danger,
                          size: 17,
                        ),
                      ),
                    ),
                  if (note?.str('audience') == 'close')
                    const Positioned(
                      bottom: 2,
                      right: 0,
                      child: GIcon(
                        CupertinoIcons.star_circle_fill,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              own ? 'La tua nota' : s.user(id).str('name').split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: own ? secondaryText(c) : foreground(c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> manageOwnNote(BuildContext c) async {
  final s = GpixScope.of(c, listen: false);
  final note = s.notes.where((n) => n.str('owner') == s.myId).firstOrNull;
  if (note == null) {
    await editNote(c);
    return;
  }
  final action = await sheet<String>(
    c,
    Builder(
      builder: (menu) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          children: [
            Avatar(s.myId, size: 58),
            const SizedBox(height: 18),
            Text(
              note.str('text'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 9),
            Text(
              '${note.str('audience') == 'close' ? 'Condivisa con gli amici più stretti' : 'Condivisa con gli amici'} · ${relative(note['created'])}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(menu, 'new'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Lascia una nuova nota'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(menu, 'delete'),
              child: const Text('Elimina nota'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!c.mounted) return;
  if (action == 'new') await editNote(c);
  if (action == 'delete')
    await perform(c, () => s.act('note', {'delete': true}));
}

Future<void> editNote(BuildContext c) => open(c, const _NoteEditor());

class _NoteEditor extends StatefulWidget {
  const _NoteEditor();
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final text = TextEditingController();
  String audience = 'mutual';
  bool initialized = false, busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final current = s.notes.where((n) => n.str('owner') == s.myId).firstOrNull;
    if (!initialized) {
      initialized = true;
      text.text = current?.str('text') ?? '';
      audience = current?.str('audience', 'mutual') ?? 'mutual';
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Chiudi nota',
          onPressed: () => Navigator.pop(c),
          icon: const GIcon(CupertinoIcons.xmark),
        ),
        title: const SizedBox.shrink(),
        actions: [
          if (current != null)
            IconButton(
              tooltip: 'Elimina nota',
              onPressed: () => perform(c, () async {
                await s.act('note', {'delete': true});
                if (c.mounted) Navigator.pop(c);
              }),
              icon: const GIcon(CupertinoIcons.trash),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 164,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: surface(c),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 25,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          key: const ValueKey('note-text'),
                          controller: text,
                          maxLength: 60,
                          minLines: 1,
                          maxLines: 4,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, height: 1.15),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Condividi un pensiero…',
                            counterText: '',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Avatar(s.myId, size: 100),
                      const SizedBox(height: 15),
                      Text(
                        '${text.text.characters.length}/60',
                        key: const ValueKey('note-counter'),
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Visibile per 24 ore',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => sheet(
                        c,
                        Builder(
                          builder: (menu) => Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Condividi con',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              ListTile(
                                leading: const GIcon(CupertinoIcons.person_2),
                                title: const Text('Amici'),
                                subtitle: const Text(
                                  'Follower che segui a tua volta',
                                ),
                                trailing: GIcon(
                                  audience == 'mutual'
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                ),
                                onTap: () {
                                  setState(() => audience = 'mutual');
                                  Navigator.pop(menu);
                                },
                              ),
                              ListTile(
                                leading: const GIcon(
                                  CupertinoIcons.star_fill,
                                  color: Colors.green,
                                ),
                                title: const Text('Amici più stretti'),
                                subtitle: Text(
                                  '${s.state.ids('closeFriends').length} persone',
                                ),
                                trailing: GIcon(
                                  audience == 'close'
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                ),
                                onTap: () {
                                  setState(() => audience = 'close');
                                  Navigator.pop(menu);
                                },
                              ),
                              ActionRow(
                                CupertinoIcons.person_2,
                                'Modifica amici più stretti',
                                () {
                                  Navigator.pop(menu);
                                  open(c, const CloseFriends());
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      icon: GIcon(
                        audience == 'close'
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.person_2,
                        color: audience == 'close'
                            ? Colors.green
                            : foreground(c),
                      ),
                      label: Text(
                        audience == 'close'
                            ? 'Amici più stretti'
                            : 'Condividi con gli amici',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        busy ||
                            text.text.trim().isEmpty ||
                            text.text.characters.length > 60
                        ? null
                        : () => perform(c, () async {
                            setState(() => busy = true);
                            try {
                              await s.act('note', {
                                'text': text.text.trim(),
                                'audience': audience,
                              });
                              if (c.mounted) Navigator.pop(c);
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          }),
                    child: Text(busy ? 'Invio…' : 'Condividi'),
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

Future<void> replyNote(BuildContext c, J note) async {
  final s = GpixScope.of(c, listen: false);
  final text = await textDialog(
    c,
    'Rispondi alla nota: ${note.str('text')}',
    '',
  );
  if (text == null || text.trim().isEmpty || !c.mounted) return;
  await perform(c, () async {
    final id = await s.openThread(note.str('owner'));
    await s.send(id, '↪ ${note.str('text')}\n${text.trim()}');
    if (c.mounted) open(c, Chat(id: id));
  });
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
