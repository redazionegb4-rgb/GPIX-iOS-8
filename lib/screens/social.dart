import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'stories.dart';
import 'features13.dart';
import 'sessions_instants.dart';
import 'messages.dart';
import 'video.dart';
import 'live.dart';
import 'community.dart';
import 'creation_studio.dart';
import 'giphy.dart';
import '../rebuild/surfaces.dart' show DiscoverHome, ProfileHome, TimelinePost;
import 'moments.dart';

class StoryTray extends StatefulWidget {
  const StoryTray({super.key});
  @override
  State<StoryTray> createState() => _StoryTrayState();
}

class _StoryTrayState extends State<StoryTray> {
  final scroll = ScrollController();
  void reset() {
    if (scroll.hasClients)
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    setState(() {});
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final users = s.storyUsers;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.state.rows('lives').isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                for (final room in s.state.rows('lives'))
                  InkWell(
                    onTap: () => open(
                      c,
                      LiveRoom(
                        id: room.str('id'),
                        host: room.str('host'),
                        title: room.str('title'),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 17),
                      child: Column(
                        children: [
                          Avatar(room.str('host'), size: 41, ring: true),
                          const SizedBox(height: 3),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Container(
          height:
              121 +
              (MediaQuery.textScalerOf(c).scale(12) - 12).clamp(0.0, 32.0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(c).dividerColor)),
          ),
          child: ListView.separated(
            key: const ValueKey('stories-strip'),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
            scrollDirection: Axis.horizontal,
            itemCount: users.length + 1,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (c, i) {
              final uid = i == 0 ? s.myId : users[i - 1].str('id');
              final stories = s.stories(uid);
              return InkWell(
                onTap: () => i == 0 && stories.isEmpty
                    ? open(c, const Composer(kind: 'story'))
                    : open(c, StoryViewer(user: uid)),
                onLongPress: i == 0
                    ? () => open(c, const Composer(kind: 'story'))
                    : null,
                child: SizedBox(
                  width: ((MediaQuery.sizeOf(c).width - 36) / 3.65).clamp(
                    69.0,
                    102.0,
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(
                            uid,
                            size:
                                ((MediaQuery.sizeOf(c).width - 36) / 3.65 - 15)
                                    .clamp(54.0, 68.0),
                            ring: stories.isNotEmpty,
                            viewed:
                                i != 0 &&
                                stories.every(
                                  (p) =>
                                      (p.flag('seenByMe') ||
                                      p.ids('viewers').contains(s.myId)),
                                ),
                          ),
                          if (i == 0)
                            Positioned(
                              right: -1,
                              bottom: 0,
                              child: GestureDetector(
                                key: const ValueKey('create-own-story'),
                                onTap: () =>
                                    open(c, const Composer(kind: 'story')),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: auraBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: surface(c),
                                      width: 2.5,
                                    ),
                                  ),
                                  child: const GIcon(
                                    CupertinoIcons.plus,
                                    size: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        i == 0 ? 'La tua storia' : s.user(uid).str('username'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryText(c),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PostAction extends StatelessWidget {
  const PostAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.count,
    this.color,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = count;
    final display = value != null && value >= 10000
        ? '${(value / 1000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ',')} mila'
        : value?.toString();
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        onTap: onTap,
        label: value == null ? label : '$label, $value',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation.drive(Tween(begin: .78, end: 1.0)),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: GIcon(
                      icon,
                      key: ValueKey(icon),
                      color: color ?? foreground(context),
                      size: 23,
                    ),
                  ),
                  if (display != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      display,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.id, this.detail = false});

  final String id;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final post = GpixScope.of(context).post(id);
    return post.isEmpty
        ? const EmptyState(
            CupertinoIcons.photo,
            'Contenuto non disponibile',
            '',
          )
        : TimelinePost(key: ValueKey(id), post: post, detail: detail);
  }
}

Future<void> people(BuildContext c, List<String> ids, String title) => sheet(
  c,
  Column(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      if (ids.isEmpty)
        const Padding(
          padding: EdgeInsets.all(30),
          child: Text('Nessun account'),
        ),
      for (final id in ids)
        PersonTile(
          id,
          onTap: () {
            Navigator.pop(c);
            open(c, Profile(user: id));
          },
        ),
      const SizedBox(height: 16),
    ],
  ),
);
Future<void> postMenu(BuildContext c, J p) async {
  final s = GpixScope.of(c, listen: false), own = p.str('author') == s.myId;
  if (own && p.str('kind') == 'story') {
    final action = await sheet<String>(
      c,
      Builder(
        builder: (menu) => Column(
          children: [
            ActionRow(
              CupertinoIcons.trash,
              'Elimina storia',
              () => Navigator.pop(menu, 'delete'),
              destructive: true,
            ),
            ActionRow(
              CupertinoIcons.star_circle,
              'Metti in evidenza',
              () => Navigator.pop(menu, 'highlight'),
            ),
            ActionRow(
              CupertinoIcons.pencil,
              'Modifica didascalia',
              () => Navigator.pop(menu, 'edit'),
            ),
            ActionRow(
              CupertinoIcons.chat_bubble,
              p.flag('commentsOff') ? 'Attiva commenti' : 'Disattiva commenti',
              () => Navigator.pop(menu, 'comments'),
            ),
            ActionRow(
              CupertinoIcons.star_fill,
              'Amici più stretti',
              () => Navigator.pop(menu, 'friends'),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (!c.mounted) return;
    if (action == 'highlight') {
      await addStoryHighlight(c, p);
    } else if (action == 'friends') {
      await open(c, const CloseFriends());
    } else if (action == 'comments') {
      await perform(
        c,
        () => s.act('postOptions', {
          'id': p['id'],
          'commentsOff': !p.flag('commentsOff'),
          'hideLikes': p.flag('hideLikes'),
        }),
      );
    } else if (action == 'edit') {
      final text = await textDialog(c, 'Modifica didascalia', p.str('text'));
      if (text != null && c.mounted)
        await perform(
          c,
          () => s.act('editPost', {
            'id': p['id'],
            'text': text,
            'location': p['location'],
          }),
        );
    } else if (action == 'delete' &&
        await gpixAlert(
          c,
          'Eliminare la storia?',
          'Questa azione non può essere annullata.',
          confirm: 'Elimina',
          cancel: true,
          destructive: true,
        ) &&
        c.mounted) {
      await perform(c, () => s.act('deletePost', {'id': p['id']}));
    }
    return;
  }
  await sheet(
    c,
    Column(
      children: [
        ActionRow(
          p.flag('saved')
              ? CupertinoIcons.bookmark_fill
              : CupertinoIcons.bookmark,
          p.flag('saved') ? 'Rimuovi dai salvati' : 'Salva',
          () {
            Navigator.pop(c);
            perform(
              c,
              () => s.act('save', {'id': p['id'], 'enabled': !p.flag('saved')}),
            );
          },
        ),
        ActionRow(CupertinoIcons.paperplane, 'Invia a…', () {
          Navigator.pop(c);
          sharePost(c, p);
        }),
        if (own) ...[
          if (p.str('kind') == 'post' &&
              s.state.number('communityVersion') > 0 &&
              !s.state
                  .rows('socialItems')
                  .any((item) => item.str('post') == p.str('id')))
            ActionRow(
              CupertinoIcons.person_2,
              'Crea un Momento da questo post',
              () {
                Navigator.pop(c);
                composeCommunity(c, 'communityMoment', post: p.str('id'));
              },
            ),
          if (p.str('kind') != 'story')
            ActionRow(
              CupertinoIcons.pin,
              s.me.ids('pinnedPosts').contains(p.str('id'))
                  ? 'Rimuovi dal profilo fissato'
                  : 'Fissa nel profilo',
              () {
                Navigator.pop(c);
                perform(
                  c,
                  () => s.act('pinPost', {
                    'id': p['id'],
                    'enabled': !s.me.ids('pinnedPosts').contains(p.str('id')),
                  }),
                );
              },
            ),
          if (p.str('kind') == 'story')
            ActionRow(CupertinoIcons.star_circle, 'Metti in evidenza', () {
              Navigator.pop(c);
              addStoryHighlight(c, p);
            }),
          const Divider(),
          ActionRow(CupertinoIcons.pencil, 'Modifica', () async {
            Navigator.pop(c);
            final text = await textDialog(
              c,
              'Modifica didascalia',
              p.str('text'),
            );
            if (text != null && c.mounted)
              perform(
                c,
                () => s.act('editPost', {
                  'id': p['id'],
                  'text': text,
                  'location': p['location'],
                }),
              );
          }),
          ActionRow(
            CupertinoIcons.archivebox,
            p.flag('archived') ? 'Mostra nel profilo' : 'Archivia',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('archivePost', {
                  'id': p['id'],
                  'enabled': !p.flag('archived'),
                }),
              );
            },
          ),
          ActionRow(
            CupertinoIcons.chat_bubble,
            p.flag('commentsOff') ? 'Attiva commenti' : 'Disattiva commenti',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('postOptions', {
                  'id': p['id'],
                  'commentsOff': !p.flag('commentsOff'),
                  'hideLikes': p.flag('hideLikes'),
                }),
              );
            },
          ),
          ActionRow(
            CupertinoIcons.eye_slash,
            p.flag('hideLikes')
                ? 'Mostra numero di Mi piace'
                : 'Nascondi numero di Mi piace',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('postOptions', {
                  'id': p['id'],
                  'commentsOff': p.flag('commentsOff'),
                  'hideLikes': !p.flag('hideLikes'),
                }),
              );
            },
          ),
          ActionRow(CupertinoIcons.trash, 'Elimina', () async {
            Navigator.pop(c);
            if (await gpixAlert(
                  c,
                  'Eliminare il contenuto?',
                  'Questa azione non può essere annullata.',
                  confirm: 'Elimina',
                  destructive: true,
                  cancel: true,
                ) &&
                c.mounted)
              perform(c, () => s.act('deletePost', {'id': p['id']}));
          }, destructive: true),
        ] else ...[
          ActionRow(
            CupertinoIcons.person,
            s.follows(p.str('author')) ? 'Non seguire più' : 'Segui',
            () {
              Navigator.pop(c);
              perform(
                c,
                () => s.act('follow', {
                  'user': p['author'],
                  'enabled': !s.follows(p.str('author')),
                }),
              );
            },
          ),
          ActionRow(CupertinoIcons.flag, 'Segnala', () {
            Navigator.pop(c);
            report(c, p.str('id'));
          }, destructive: true),
        ],
        const SizedBox(height: 16),
      ],
    ),
  );
}

Future<String?> textDialog(
  BuildContext c,
  String title,
  String value, {
  String hint = '',
  bool obscure = false,
}) => sheet<String>(
  c,
  _TextDialog(title: title, initial: value, hint: hint, obscure: obscure),
);

class _TextDialog extends StatefulWidget {
  final String title, initial, hint;
  final bool obscure;
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.obscure,
  });
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Chiudi',
              onPressed: () => Navigator.pop(c),
              icon: const GIcon(CupertinoIcons.xmark, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          autofocus: true,
          minLines: widget.obscure ? 1 : 3,
          maxLines: widget.obscure ? 1 : 6,
          obscureText: widget.obscure,
          textCapitalization: widget.obscure
              ? TextCapitalization.none
              : TextCapitalization.sentences,
          style: const TextStyle(fontSize: 17, height: 1.5),
          decoration: InputDecoration(
            hintText: widget.hint.isEmpty
                ? (widget.obscure ? 'Password' : 'Scrivi qui…')
                : widget.hint,
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Annulla'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  c,
                  widget.obscure ? controller.text : controller.text.trim(),
                ),
                child: const Text('Salva'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> report(BuildContext c, String id) => sheet(
  c,
  Column(
    children: [
      const Text(
        'Perché vuoi segnalarlo?',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 15),
      for (final reason in [
        'Molestie o bullismo',
        'Odio e discriminazione',
        'Spam o truffa',
        'Contenuti non appropriati',
      ])
        ActionRow(CupertinoIcons.flag, reason, () {
          Navigator.pop(c);
          perform(c, () async {
            await GpixScope.of(
              c,
              listen: false,
            ).act('report', {'id': id, 'reason': reason});
            if (c.mounted)
              await gpixAlert(
                c,
                'Segnalazione registrata',
                '${GpixScope.of(c, listen: false).demo ? 'In demo la segnalazione resta su questo dispositivo.' : 'La segnalazione è stata inviata al server.'}',
              );
          });
        }),
      const SizedBox(height: 20),
    ],
  ),
);
Future<void> sharePost(BuildContext c, J p) => sheet(c, SharePanel(post: p));

class SharePanel extends StatefulWidget {
  final J post;
  const SharePanel({super.key, required this.post});
  @override
  State<SharePanel> createState() => _SharePanelState();
}

class _SharePanelState extends State<SharePanel> {
  final selected = <String>{};
  final search = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final users = s.users
        .where(
          (u) =>
              u.str('id') != s.myId &&
              !s.blocked(u.str('id')) &&
              ('${u.str('name')} ${u.str('username')}').toLowerCase().contains(
                search.text.toLowerCase(),
              ),
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        children: [
          const Text(
            'Condividi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cerca persone',
              prefixIcon: const GIcon(CupertinoIcons.search),
              filled: true,
              fillColor: subdued(c),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nessuna persona trovata'),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              mainAxisExtent: 105,
            ),
            itemBuilder: (c, i) {
              final u = users[i],
                  id = u.str('id'),
                  active = selected.contains(id);
              return InkWell(
                onTap: busy
                    ? null
                    : () => setState(() {
                        active ? selected.remove(id) : selected.add(id);
                      }),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Avatar(id, size: 58),
                        if (active)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: auraBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.check_mark,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      u.str('username'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
          if (selected.isNotEmpty)
            PrimaryButton(
              'Invia${selected.length > 1 ? ' a ${selected.length} persone' : ''}',
              busy: busy,
              onTap: () async {
                setState(() => busy = true);
                await perform(c, () async {
                  for (final id in selected.toList()) {
                    final tid = await s.openThread(id);
                    await s.act('sharePost', {
                      'id': tid,
                      'post': widget.post.str('id'),
                    });
                    selected.remove(id);
                  }
                  if (c.mounted) {
                    Navigator.pop(c);
                    notice(c, 'Post inviato');
                  }
                });
                if (mounted) setState(() => busy = false);
              },
            ),
          const SizedBox(height: 12),
          const Divider(),
          ActionRow(
            CupertinoIcons.share,
            'Condividi in un’altra app',
            () => SharePlus.instance.share(
              ShareParams(
                text:
                    '${s.user(widget.post.str('author')).str('username')} su GPIX\n${widget.post.str('text')}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> comments(BuildContext c, String id) =>
    sheet(c, Comments(id: id), scroll: false);

class Comments extends StatefulWidget {
  final String id;
  const Comments({super.key, required this.id});
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final input = TextEditingController();
  String parent = '', replyName = '', media = '';
  Future<void> pickComment(bool gif) async {
    final s = GpixScope.of(context, listen: false);
    if (gif) {
      await sheet(
        context,
        GiphyGallery(
          onSelected: (value) {
            Navigator.pop(context);
            perform(context, () async {
              final ref = await s.uploadAsset(value, 'image/gif');
              if (mounted) setState(() => media = ref);
            });
          },
          onImport: () {
            Navigator.pop(context);
            perform(context, () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['gif'],
              );
              final path = result?.files.single.path;
              if (path == null) return;
              final ref = await s.upload(path, 'image/gif');
              if (mounted) setState(() => media = ref);
            });
          },
        ),
      );
    } else {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (photo != null && mounted)
        await perform(context, () async {
          final ref = await s.upload(photo.path, 'image/jpeg');
          if (mounted) setState(() => media = ref);
        });
    }
  }

  final focus = FocusNode();
  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        p = s.post(widget.id),
        comments = p.rows('comments').where((m) {
          final owner = p.str('author') == s.myId;
          if (m.flag('hidden') && !owner && m.str('author') != s.myId)
            return false;
          final root = p
              .rows('comments')
              .where((x) => x.str('id') == m.str('parent'))
              .firstOrNull;
          return root == null ||
              !root.flag('hidden') ||
              owner ||
              root.str('author') == s.myId;
        }).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(c).height * .78,
      child: Column(
        children: [
          const Text(
            'Commenti',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: EmptyState(
                      CupertinoIcons.chat_bubble,
                      'Ancora nessun commento',
                      'Avvia la conversazione.',
                    ),
                  )
                : ListView(
                    children: [
                      for (final comment in comments.where(
                        (e) => e.str('parent').isEmpty,
                      )) ...[
                        _comment(c, comment, false),
                        for (final child in comments.where(
                          (e) => e.str('parent') == comment.str('id'),
                        ))
                          _comment(c, child, true),
                      ],
                    ],
                  ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final emoji in [
                  '❤️',
                  '🙌',
                  '🔥',
                  '👏',
                  '😢',
                  '😍',
                  '😮',
                  '😂',
                ])
                  InkWell(
                    onTap: () {
                      input.text += emoji;
                      setState(() {});
                      focus.requestFocus();
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 23)),
                  ),
              ],
            ),
          ),
          if (media.isNotEmpty)
            ListTile(
              leading: SizedBox(
                width: 42,
                height: 42,
                child: MediaView(s.url(media)),
              ),
              title: const Text('Immagine allegata'),
              trailing: IconButton(
                onPressed: () => setState(() => media = ''),
                icon: const GIcon(CupertinoIcons.xmark),
              ),
            ),
          if (parent.isNotEmpty)
            Container(
              color: subdued(c),
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rispondi a $replyName',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const GIcon(Icons.close, size: 17),
                    onPressed: () => setState(() => parent = ''),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 12, 12),
            child: Row(
              children: [
                Avatar(s.myId, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: input,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Aggiungi un commento…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(color: line),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                ),
                if (input.text.trim().isEmpty && media.isEmpty) ...[
                  IconButton(
                    tooltip: 'Foto nel commento',
                    onPressed: () => pickComment(false),
                    icon: const GIcon(CupertinoIcons.photo, size: 24),
                  ),
                  IconButton(
                    tooltip: 'GIF nel commento',
                    onPressed: () => pickComment(true),
                    icon: const GIcon(Icons.gif_box_outlined, size: 26),
                  ),
                ],
                if (input.text.trim().isNotEmpty || media.isNotEmpty)
                  TextButton(
                    onPressed: input.text.trim().isEmpty && media.isEmpty
                        ? null
                        : () => perform(c, () async {
                            await s.act('comment', {
                              'id': widget.id,
                              'text': input.text.trim(),
                              'parent': parent,
                              'media': media,
                            });
                            input.clear();
                            setState(() {
                              parent = '';
                              media = '';
                            });
                          }),
                    child: const Text(
                      'Pubblica',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void commentOptions(BuildContext c, J m) {
    final s = GpixScope.of(c, listen: false),
        owner = s.post(widget.id).str('author') == s.myId;
    sheet(
      c,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (owner)
            ActionRow(
              m.flag('hidden') ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              m.flag('hidden') ? 'Mostra di nuovo' : 'Nascondi agli altri',
              () async {
                Navigator.pop(c);
                await perform(
                  c,
                  () => s.act('hideComment', {
                    'id': m.str('id'),
                    'enabled': !m.flag('hidden'),
                  }),
                );
              },
            ),
          ActionRow(CupertinoIcons.trash, 'Elimina commento', () async {
            Navigator.pop(c);
            if (!await gpixAlert(
                  c,
                  'Eliminare il commento?',
                  'Verranno eliminate anche le risposte a questo commento.',
                  confirm: 'Elimina',
                  destructive: true,
                  cancel: true,
                ) ||
                !c.mounted)
              return;
            await perform(c, () => s.act('deleteComment', {'id': m.str('id')}));
          }, destructive: true),
        ],
      ),
    );
  }

  Widget _comment(BuildContext c, J m, bool child) {
    final s = GpixScope.of(c),
        uid = m.str('author'),
        liked = m.ids('likes').contains(s.myId);
    return Padding(
      padding: EdgeInsets.fromLTRB(child ? 62 : 17, 16, 15, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(uid, size: child ? 26 : 34),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress:
                  uid == s.myId || s.post(widget.id).str('author') == s.myId
                  ? () => commentOptions(c, m)
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${s.user(uid).str('username')} ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: m.str('text')),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                  if (m.flag('hidden') &&
                      s.post(widget.id).str('author') == s.myId)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Nascosto agli altri · visibile all’autore',
                        style: TextStyle(color: muted, fontSize: 10),
                      ),
                    ),
                  if (m.str('media').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: MediaView(m.str('media')),
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Text(
                        relative(m['created']),
                        style: const TextStyle(fontSize: 10.5, color: muted),
                      ),
                      const SizedBox(width: 15),
                      InkWell(
                        onTap: () {
                          setState(() {
                            parent = child ? m.str('parent') : m.str('id');
                            replyName = s.user(uid).str('username');
                          });
                          focus.requestFocus();
                        },
                        child: const Text(
                          'Rispondi',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Column(
            children: [
              if (uid == s.myId || s.post(widget.id).str('author') == s.myId)
                IconButton(
                  tooltip: 'Opzioni commento',
                  onPressed: () => commentOptions(c, m),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 30,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const GIcon(CupertinoIcons.ellipsis, size: 19),
                ),
              InkWell(
                onTap: () => perform(
                  c,
                  () =>
                      s.act('likeComment', {'id': m['id'], 'enabled': !liked}),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: GIcon(
                    liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 14,
                    color: liked ? danger : muted,
                  ),
                ),
              ),
              if (m.ids('likes').isNotEmpty)
                Text(
                  '${m.ids('likes').length}',
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class Explore extends StatelessWidget {
  const Explore({super.key, this.initialQuery = ''});
  final String initialQuery;

  @override
  Widget build(BuildContext context) =>
      DiscoverHome(initialQuery: initialQuery, detail: true);
}

class PostPage extends StatelessWidget {
  final String id;
  const PostPage({super.key, required this.id});
  @override
  Widget build(BuildContext c) =>
      GpixScope.of(c).post(id).str('kind') == 'story'
      ? StoryViewer(user: GpixScope.of(c).post(id).str('author'), ids: [id])
      : GpixScope.of(c).post(id).str('kind') == 'reel'
      ? Reels(initial: id)
      : Scaffold(
          appBar: AppBar(title: pageTitle('Post')),
          body: ListView(children: [PostCard(id: id, detail: true)]),
        );
}

class Profile extends StatelessWidget {
  const Profile({super.key, required this.user});
  final String user;

  @override
  Widget build(BuildContext context) => ProfileHome(user: user, detail: true);
}

Future<void> addStoryHighlight(BuildContext c, J story) async {
  final s = GpixScope.of(c, listen: false);
  final choice = await sheet<String>(
    c,
    Builder(
      builder: (menu) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Metti in evidenza',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          for (final h in s.highlights(s.myId))
            ActionRow(
              CupertinoIcons.star_circle,
              h.str('title'),
              () => Navigator.pop(menu, h.str('id')),
            ),
          ActionRow(
            CupertinoIcons.plus_circle,
            'Nuova raccolta',
            () => Navigator.pop(menu, 'new'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
  if (!c.mounted || choice == null) return;
  if (choice == 'new') {
    final title = await textDialog(c, 'Nome della raccolta', '');
    if (title != null && title.trim().isNotEmpty && c.mounted)
      await perform(
        c,
        () => s.act('highlight', {
          'title': title.trim(),
          'posts': [story['id']],
        }),
      );
  } else {
    await perform(
      c,
      () => s.act('addHighlight', {'id': choice, 'post': story['id']}),
    );
  }
}

Future<void> createHighlight(BuildContext c) =>
    sheet(c, const _HighlightEditor());

class _HighlightEditor extends StatefulWidget {
  const _HighlightEditor();
  @override
  State<_HighlightEditor> createState() => _HighlightEditorState();
}

class _HighlightEditorState extends State<_HighlightEditor> {
  final selected = <String>{};
  final title = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), stories = s.stories(s.myId, archive: true);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'Nuova storia in evidenza',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 17),
          AppInput(title, 'Nome della raccolta'),
          const SizedBox(height: 15),
          if (stories.isEmpty)
            const Text(
              'Pubblica una storia per aggiungerla qui.',
              style: TextStyle(color: muted),
            ),
          for (final p in stories)
            CheckboxListTile(
              title: Text(p.str('text', 'Storia'), maxLines: 2),
              secondary: SizedBox(
                width: 40,
                height: 48,
                child: MediaView(p.str('media')),
              ),
              value: selected.contains(p.str('id')),
              onChanged: (v) => setState(
                () => v == true
                    ? selected.add(p.str('id'))
                    : selected.remove(p.str('id')),
              ),
            ),
          const SizedBox(height: 16),
          PrimaryButton(
            'Crea raccolta',
            onTap: selected.isEmpty
                ? null
                : () => perform(c, () async {
                    if (title.text.trim().isEmpty)
                      throw Exception('Dai un nome alla raccolta.');
                    await s.act('highlight', {
                      'title': title.text.trim(),
                      'posts': selected.toList(),
                    });
                    if (c.mounted) Navigator.pop(c);
                  }),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

void profileMenu(BuildContext c) => sheet(
  c,
  Column(
    children: [
      ActionRow(CupertinoIcons.star_fill, 'Amici più stretti', () {
        Navigator.pop(c);
        open(c, const CloseFriends());
      }),
      ActionRow(CupertinoIcons.gear, 'Impostazioni e privacy', () {
        Navigator.pop(c);
        open(c, const Settings());
      }),
      ActionRow(CupertinoIcons.bookmark, 'Salvati', () {
        Navigator.pop(c);
        open(c, const CollectionPage(kind: 'saved'));
      }),
      ActionRow(CupertinoIcons.archivebox, 'Archivio', () {
        Navigator.pop(c);
        open(c, const CollectionPage(kind: 'archive'));
      }),
      ActionRow(CupertinoIcons.person_add, 'Richieste di seguirti', () {
        Navigator.pop(c);
        open(c, const Requests());
      }),
      const SizedBox(height: 18),
    ],
  ),
);

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final fields = <String, TextEditingController>{};
  bool busy = false;
  String avatar = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (fields.isEmpty) {
      final u = GpixScope.of(context, listen: false).me;
      for (final k in [
        'name',
        'username',
        'pronouns',
        'bio',
        'website',
        'gender',
      ]) {
        fields[k] = TextEditingController(text: u.str(k));
      }
      avatar = u.str('avatarId', u.str('avatar'));
    }
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Modifica profilo')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: busy
              ? null
              : () => perform(c, () async {
                  if (fields['name']!.text.trim().isEmpty ||
                      fields['username']!.text.trim().isEmpty)
                    throw Exception('Nome e nome utente sono obbligatori.');
                  final site = fields['website']!.text.trim();
                  if (site.isNotEmpty && !site.startsWith('https://'))
                    throw Exception('Il sito deve iniziare con https://');
                  setState(() => busy = true);
                  try {
                    await s.act('profile', {
                      for (final e in fields.entries)
                        e.key: e.value.text.trim(),
                      'avatar': avatar,
                      'private': s.me.flag('private'),
                    });
                    if (c.mounted) Navigator.pop(c);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                }),
          child: Text(busy ? 'Salvo…' : 'Salva'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const SizedBox(height: 22),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: auraBlue),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Avatar(
                  s.myId,
                  size: 88,
                  image: avatar == s.me.str('avatarId')
                      ? s.me.str('avatar')
                      : avatar,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => perform(c, () async {
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 800,
                imageQuality: 85,
              );
              if (file == null) return;
              final ref = await s.upload(
                file.path,
                'image/${file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg'}',
              );
              if (mounted) setState(() => avatar = ref);
            }),
            child: const Text('Cambia foto'),
          ),
          const SizedBox(height: 8),
          for (final field in const [
            (key: 'name', label: 'Nome', max: 60),
            (key: 'username', label: 'Nome utente', max: 30),
            (key: 'bio', label: 'Biografia', max: 150),
            (key: 'website', label: 'Sito web', max: 200),
            (key: 'pronouns', label: 'Pronomi', max: 40),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                key: ValueKey('edit-profile-${field.key}'),
                controller: fields[field.key],
                maxLength: field.max,
                minLines: field.key == 'bio' ? 2 : 1,
                maxLines: field.key == 'bio' ? 5 : 1,
                keyboardType: field.key == 'website' ? TextInputType.url : null,
                decoration: InputDecoration(
                  labelText: field.label,
                  hintText: field.key == 'website' ? 'https://' : null,
                  alignLabelWithHint: field.key == 'bio',
                  counterText: '',
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.link),
            title: const Text('Link del profilo'),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => open(c, const ProfileLinks()),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.square_grid_2x2),
            title: const Text('Riordina griglia'),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => open(c, const GridOrder()),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const GIcon(CupertinoIcons.person),
            title: const Text('Genere'),
            subtitle: Text(
              fields['gender']!.text.isEmpty
                  ? 'Non specificato'
                  : fields['gender']!.text,
            ),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
            onTap: () => sheet(
              c,
              Builder(
                builder: (menu) => Column(
                  children: [
                    for (final gender in [
                      'Uomo',
                      'Donna',
                      'Non binario',
                      'Preferisco non specificarlo',
                    ])
                      ListTile(
                        title: Text(gender),
                        trailing: fields['gender']!.text == gender
                            ? const GIcon(
                                CupertinoIcons.check_mark,
                                color: auraBlue,
                              )
                            : null,
                        onTap: () {
                          setState(() => fields['gender']!.text = gender);
                          Navigator.pop(menu);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Text(
              'Il genere non viene mostrato nel profilo pubblico.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionPage extends StatelessWidget {
  final String kind;
  const CollectionPage({super.key, required this.kind});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final posts = s.allPosts
        .where(
          (p) => kind == 'saved'
              ? p.flag('saved')
              : p.str('author') == s.myId &&
                    (p.flag('archived') || p.str('kind') == 'story'),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: pageTitle(kind == 'saved' ? 'Salvati' : 'Archivio'),
      ),
      body: posts.isEmpty
          ? EmptyState(
              kind == 'saved'
                  ? CupertinoIcons.bookmark
                  : CupertinoIcons.archivebox,
              kind == 'saved' ? 'Tieni i tuoi preferiti' : 'Il tuo archivio',
              'I contenuti appariranno qui.',
            )
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: .75,
              ),
              itemCount: posts.length,
              itemBuilder: (c, i) {
                final p = posts[i];
                return InkWell(
                  onTap: () => p.str('kind') == 'story'
                      ? open(c, StoryViewer(user: s.myId, ids: [p.str('id')]))
                      : open(c, PostPage(id: p.str('id'))),
                  onLongPress: () => postMenu(c, p),
                  child: MediaView(p.str('media')),
                );
              },
            ),
    );
  }
}

class Activity extends StatefulWidget {
  const Activity({super.key});
  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  static const filters = ['Tutte', 'Mi piace', 'Commenti', 'Follower'];
  static const headings = [
    'In evidenza',
    'Oggi',
    'Ieri',
    'Ultimi 7 giorni',
    'Precedenti',
  ];

  int selected = 0;
  bool unreadOnly = false;
  bool menuOpen = false;
  final deciding = <String>{};
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void selectFilter(int filter) {
    if (selected == filter) return;
    setState(() => selected = filter);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> showOptions(BuildContext anchor, GpixStore store) async {
    if (menuOpen) return;
    menuOpen = true;
    final result = await anchoredMenu<String>(
      anchor,
      [
        dropdownRow(
          anchor,
          'settings',
          'Impostazioni notifiche',
          CupertinoIcons.gear_alt,
        ),
        dropdownRow(
          anchor,
          'unread',
          unreadOnly ? 'Mostra tutte' : 'Solo da leggere',
          CupertinoIcons.envelope_badge,
          selected: unreadOnly,
        ),
        dropdownRow(
          anchor,
          'read',
          'Segna tutte come lette',
          CupertinoIcons.check_mark_circled,
          enabled: store.hasActivity,
        ),
      ],
      alignRight: true,
      width: 236,
      label: 'Opzioni attività',
    );
    menuOpen = false;
    if (!mounted) return;
    switch (result) {
      case 'settings':
        open(context, const PushSettings());
      case 'unread':
        setState(() => unreadOnly = !unreadOnly);
        if (scroll.hasClients) scroll.jumpTo(0);
      case 'read':
        await perform(context, () => store.act('notificationsRead'));
    }
  }

  Future<void> decide(GpixStore store, String id, bool accept) async {
    if (!deciding.add(id)) return;
    setState(() {});
    try {
      await perform(
        context,
        () => store.act('accept', {'user': id, 'enabled': accept}),
      );
    } finally {
      if (mounted) setState(() => deciding.remove(id));
    }
  }

  String _label(J notification, J post) {
    final custom = notification.str('message').trim();
    if (custom.isNotEmpty) return custom;
    return switch (notification.str('type')) {
      'comment' => 'ha commentato il tuo post.',
      'storyLike' => 'ha messo Mi piace alla tua storia.',
      'like' when post.str('kind') == 'story' =>
        'ha messo Mi piace alla tua storia.',
      'like' => 'ha messo Mi piace al tuo post.',
      'follow' => 'ha iniziato a seguirti.',
      'followRequest' => 'ha chiesto di seguirti.',
      'followAccepted' => 'ha accettato la tua richiesta.',
      'repost' => 'ha ripubblicato il tuo post.',
      'noteLike' => 'ha messo Mi piace alla tua nota.',
      _ => 'ha interagito con te.',
    };
  }

  Future<void> openNotification(GpixStore store, J notification) async {
    await perform(context, () async {
      if (!notification.flag('seen')) {
        await store.act('notificationsRead', {'id': notification['id']});
      }
      if (!mounted) return;
      final type = notification.str('type');
      final actor = notification.str('actor');
      final post = store.post(notification.str('ref'));
      if (type == 'followRequest') {
        open(context, const Requests());
      } else if (type == 'noteLike') {
        manageOwnNote(context);
      } else if (type == 'storyLike' || post.str('kind') == 'story') {
        if (post.isNotEmpty && post.number('expires') > now) {
          open(
            context,
            StoryViewer(user: post.str('author'), ids: [post.str('id')]),
          );
        } else {
          notice(context, 'Questa storia non è più disponibile');
        }
      } else if (post.isNotEmpty) {
        open(context, PostPage(id: post.str('id')));
      } else if (actor.isNotEmpty) {
        open(context, Profile(user: actor));
      }
    });
  }

  List<List<J>> _sections(List<J> notifications) {
    final date = DateTime.now();
    double midnight(int offset) =>
        DateTime(
          date.year,
          date.month,
          date.day - offset,
        ).millisecondsSinceEpoch /
        1000;
    final today = midnight(0), yesterday = midnight(1), week = midnight(7);
    final rows = List.generate(headings.length, (_) => <J>[]);
    for (final item in notifications) {
      final type = item.str('type');
      if (unreadOnly && item.flag('seen')) continue;
      final matches = switch (selected) {
        1 => const ['like', 'storyLike', 'noteLike'].contains(type),
        2 => type == 'comment',
        3 => const ['follow', 'followRequest', 'followAccepted'].contains(type),
        _ => true,
      };
      if (!matches) continue;
      final time = item.number('created');
      final index = item.flag('highlighted') || type == 'system'
          ? 0
          : time >= today
          ? 1
          : time >= yesterday
          ? 2
          : time >= week
          ? 3
          : 4;
      rows[index].add(item);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final requests = store.state
        .ids('requests')
        .where((id) => !store.blocked(id))
        .toSet();
    final notifications = store.socialNotifications;
    final sections = _sections(notifications);
    final allEmpty = sections.every((section) => section.isEmpty);
    final colors = Theme.of(context).colorScheme;
    return AccountSheetBackdrop(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          leading: const BackButton(),
          title: Tooltip(
            message: 'Cambia account',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => inboxAccounts(context, store),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        store.me.str('username', 'Attività'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 7),
                    GIcon(
                      CupertinoIcons.chevron_down,
                      size: 12,
                      color: secondaryText(context),
                    ),
                    if (notifications.any((item) => !item.flag('seen'))) ...[
                      const SizedBox(width: 8),
                      const CircleAvatar(radius: 3.5, backgroundColor: danger),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            Builder(
              builder: (anchor) => IconButton(
                tooltip: 'Opzioni attività',
                icon: const GIcon(CupertinoIcons.bell, size: 23),
                onPressed: () => showOptions(anchor, store),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attività',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.65,
                          ),
                    ),
                  ),
                  if (unreadOnly)
                    TextButton.icon(
                      onPressed: () => setState(() => unreadOnly = false),
                      icon: const GIcon(CupertinoIcons.xmark, size: 12),
                      label: const Text('Da leggere'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: CommunityTabs(
                filters,
                filters[selected],
                (label) => selectFilter(filters.indexOf(label)),
              ),
            ),
            Expanded(
              child: SectionSwipe(
                section: selected,
                onStep: (step) {
                  final next = selected + step;
                  if (next >= 0 && next < filters.length) selectFilter(next);
                },
                child: RefreshIndicator(
                  onRefresh: () => store.sync(silent: true),
                  child: CustomScrollView(
                    controller: scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (selected == 0 || selected == 3)
                        SliverToBoxAdapter(
                          child: _requestSummary(context, store, requests),
                        ),
                      if (allEmpty)
                        SliverToBoxAdapter(
                          child: EmptyState(
                            CupertinoIcons.heart,
                            unreadOnly
                                ? 'Tutto letto'
                                : 'Nessuna nuova attività',
                            unreadOnly
                                ? 'Le nuove attività appariranno qui.'
                                : 'Qui trovi Mi piace, commenti e nuovi follower.',
                          ),
                        ),
                      for (final (index, section) in sections.indexed)
                        if (section.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 19, 16, 7),
                              child: Text(
                                headings[index],
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                          SliverList.builder(
                            itemCount: section.length,
                            itemBuilder: (context, row) => _notificationRow(
                              context,
                              store,
                              section[row],
                              requests,
                            ),
                          ),
                        ],
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: MediaQuery.paddingOf(context).bottom + 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestSummary(
    BuildContext context,
    GpixStore store,
    Set<String> requests,
  ) {
    final colors = Theme.of(context).colorScheme;
    final multiple = requests.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Material(
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          horizontalTitleGap: 11,
          leading: SizedBox.square(
            dimension: 48,
            child: requests.isEmpty
                ? CircleAvatar(
                    backgroundColor: subdued(context),
                    child: GIcon(
                      CupertinoIcons.person_add,
                      color: foreground(context),
                      size: 20,
                    ),
                  )
                : Stack(
                    children: [
                      Avatar(requests.first, size: multiple ? 34 : 48),
                      if (multiple)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceContainerLow,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Avatar(requests.elementAt(1), size: 32),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          title: const Text(
            'Richieste di seguirti',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            requests.isEmpty
                ? 'Nessuna richiesta in attesa'
                : '${store.user(requests.first).str('username')}${multiple ? ' + altri ${requests.length - 1}' : ''}',
            style: TextStyle(color: secondaryText(context), fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (requests.isNotEmpty) ...[
                CircleAvatar(radius: 3.5, backgroundColor: accent(context)),
                const SizedBox(width: 8),
              ],
              GIcon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: secondaryText(context),
              ),
            ],
          ),
          onTap: () => open(context, const Requests()),
        ),
      ),
    );
  }

  Widget _notificationRow(
    BuildContext context,
    GpixStore store,
    J item,
    Set<String> requests,
  ) {
    final actor = item.str('actor');
    final post = store.post(item.str('ref'));
    final type = item.str('type');
    final unread = !item.flag('seen');
    final pending = type == 'followRequest' && requests.contains(actor);
    final thumbnail = post.str('kind') == 'reel'
        ? post.obj('style').str('cover')
        : store.media(post).firstOrNull ?? '';
    final time = item.number('created');
    final badge = switch (type) {
      'like' ||
      'storyLike' ||
      'noteLike' => (CupertinoIcons.heart_fill, danger),
      'comment' => (CupertinoIcons.chat_bubble_fill, accent(context)),
      'follow' ||
      'followRequest' ||
      'followAccepted' => (CupertinoIcons.person_add, accent(context)),
      'repost' => (CupertinoIcons.repeat, accent(context)),
      _ => null,
    };
    final avatar = actor.isEmpty
        ? CircleAvatar(
            radius: 23,
            backgroundColor: subdued(context),
            child: GIcon(
              CupertinoIcons.bell,
              color: foreground(context),
              size: 20,
            ),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Avatar(actor, size: 46),
              if (badge != null)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: badge.$2,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface(context), width: 1.5),
                    ),
                    child: GIcon(badge.$1, size: 10, color: Colors.white),
                  ),
                ),
            ],
          );
    final description = Text.rich(
      TextSpan(
        children: [
          if (actor.isNotEmpty)
            TextSpan(
              text: '${store.user(actor).str('username')} ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          TextSpan(text: _label(item, post)),
          if (time > 0)
            TextSpan(
              text: '  ${relative(time)}',
              style: TextStyle(color: secondaryText(context), fontSize: 12),
            ),
        ],
      ),
      style: TextStyle(fontSize: 14, height: 1.28, color: foreground(context)),
    );
    return Padding(
      key: ValueKey(item.str('id')),
      padding: const EdgeInsets.fromLTRB(12, 1, 12, 1),
      child: Material(
        color: unread
            ? accent(context).withValues(alpha: .06)
            : surface(context),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => openNotification(store, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 9, 7, 9),
            child: LayoutBuilder(
              builder: (context, size) {
                final inline =
                    pending &&
                    size.maxWidth >= 342 &&
                    MediaQuery.textScalerOf(context).scale(13) < 15;
                return Row(
                  children: [
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          description,
                          if (pending && !inline) ...[
                            const SizedBox(height: 4),
                            _requestActions(context, store, actor),
                          ],
                        ],
                      ),
                    ),
                    if (inline) ...[
                      const SizedBox(width: 8),
                      _requestActions(context, store, actor),
                    ],
                    if (!pending && thumbnail.isNotEmpty) ...[
                      const SizedBox(width: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MediaView(
                          thumbnail,
                          width: 44,
                          height: 47,
                          thumbnail: true,
                        ),
                      ),
                    ],
                    if (!pending && unread) ...[
                      const SizedBox(width: 7),
                      CircleAvatar(radius: 3, backgroundColor: accent(context)),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _requestActions(BuildContext context, GpixStore store, String actor) =>
      Wrap(
        spacing: 6,
        children: [
          for (final accept in [true, false])
            FilledButton(
              onPressed: deciding.contains(actor)
                  ? null
                  : () => decide(store, actor, accept),
              style: FilledButton.styleFrom(
                backgroundColor: accept ? auraBlue : subdued(context),
                foregroundColor: accept ? Colors.white : foreground(context),
                minimumSize: const Size(44, 35),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(accept ? 'Conferma' : 'Elimina'),
            ),
        ],
      );
}

class Requests extends StatefulWidget {
  const Requests({super.key});
  @override
  State<Requests> createState() => _RequestsState();
}

class _RequestsState extends State<Requests> {
  String query = '';
  bool editing = false, busy = false;
  final selected = <String>{}, accepted = <String>{};
  final order = <String>[];
  Future<void> decide(List<String> ids, bool accept) async {
    if (busy) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      for (final id in ids) {
        if (s.state.ids('requests').contains(id)) {
          await s.act('accept', {'user': id, 'enabled': accept});
          if (accept && mounted) setState(() => accepted.add(id));
        }
      }
      if (mounted) setState(() => selected.removeAll(ids));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    for (final id in s.state.ids('requests')) {
      if (!order.contains(id)) order.add(id);
    }
    final width = MediaQuery.sizeOf(c).width, compact = width < 360;
    final requests = order
        .where(
          (id) => s.state.ids('requests').contains(id) || accepted.contains(id),
        )
        .where(
          (id) => '${s.user(id).str('name')} ${s.user(id).str('username')}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
        )
        .toList();
    selected.removeWhere((id) => !s.state.ids('requests').contains(id));
    Widget button(String text, bool accept, VoidCallback? action) =>
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size(
              accept ? (compact ? 70 : 84) : (compact ? 60 : 70),
              36,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: accept ? auraBlue : subdued(c),
            foregroundColor: accept ? Colors.white : foreground(c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          onPressed: action,
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 64,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton.outlined(
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              side: BorderSide(
                color: Theme.of(c).dividerColor.withValues(alpha: .35),
              ),
            ),
            tooltip: 'Indietro',
            onPressed: () => Navigator.maybePop(c),
            icon: const GIcon(CupertinoIcons.chevron_left, size: 24),
          ),
        ),
        title: Text(
          'Richieste di seguirti',
          maxLines: 1,
          style: TextStyle(
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(78, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                foregroundColor: auraBlue,
              ),
              onPressed: busy
                  ? null
                  : () => setState(() {
                      editing = !editing;
                      selected.clear();
                    }),
              child: Text(
                editing ? 'Fine' : 'Modifica',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca nome utente o nome visualizzato',
                hintStyle: TextStyle(fontSize: compact ? 12 : 14, color: muted),
                prefixIcon: const GIcon(
                  CupertinoIcons.search,
                  color: muted,
                  size: 20,
                ),
                filled: true,
                fillColor: subdued(c),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            leading: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: foreground(c)),
              ),
              child: const Stack(
                children: [
                  Center(child: GIcon(CupertinoIcons.search, size: 29)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GIcon(CupertinoIcons.sparkles, size: 12),
                  ),
                ],
              ),
            ),
            title: const Text(
              'Scopri altri profili',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: const Text(
              'Vedi suggerimenti non personalizzati',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: const GIcon(
              CupertinoIcons.chevron_right,
              color: muted,
              size: 19,
            ),
            onTap: () => open(
              c,
              Scaffold(
                appBar: AppBar(title: pageTitle('Scopri altri profili')),
                body: ListView(
                  children: [
                    for (final u
                        in (s.users
                            .where(
                              (u) =>
                                  u.str('id') != s.myId &&
                                  !s.blocked(u.str('id')) &&
                                  !s.follows(u.str('id')),
                            )
                            .toList()
                          ..sort(
                            (a, b) =>
                                a.str('username').compareTo(b.str('username')),
                          )))
                      PersonTile(
                        u.str('id'),
                        onTap: () => open(c, Profile(user: u.str('id'))),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: requests.isEmpty
                ? Center(
                    child: EmptyState(
                      CupertinoIcons.person_add,
                      query.isEmpty ? 'Nessuna richiesta' : 'Nessun risultato',
                      query.isEmpty
                          ? 'Le nuove richieste appariranno qui.'
                          : 'Prova un altro nome.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    itemCount: requests.length,
                    itemBuilder: (c, i) {
                      final id = requests[i],
                          u = s.user(id),
                          detail = s.state.obj('requestDetails').obj(id);
                      final common = detail.containsKey('mutualUsers')
                              ? detail.ids('mutualUsers')
                              : u
                                    .ids('followersList')
                                    .where(s.state.ids('following').contains)
                                    .take(3)
                                    .toList(),
                          count = detail
                              .number(
                                'mutualCount',
                                u
                                    .ids('followersList')
                                    .where(s.state.ids('following').contains)
                                    .length
                                    .toDouble(),
                              )
                              .toInt();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => editing
                                  ? setState(
                                      () => selected.contains(id)
                                          ? selected.remove(id)
                                          : selected.add(id),
                                    )
                                  : open(c, Profile(user: id)),
                              child: Stack(
                                children: [
                                  Avatar(id, size: compact ? 48 : 54),
                                  if (editing)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Icon(
                                        selected.contains(id)
                                            ? CupertinoIcons
                                                  .checkmark_circle_fill
                                            : CupertinoIcons.circle_fill,
                                        color: selected.contains(id)
                                            ? auraBlue
                                            : muted,
                                        size: 21,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => editing
                                    ? setState(
                                        () => selected.contains(id)
                                            ? selected.remove(id)
                                            : selected.add(id),
                                      )
                                    : open(c, Profile(user: id)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.str('name', u.str('username')),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (common.isNotEmpty) ...[
                                          SizedBox(
                                            width:
                                                common.take(3).length * 12 + 8,
                                            height: 20,
                                            child: Stack(
                                              children: [
                                                for (
                                                  var j = 0;
                                                  j < common.take(3).length;
                                                  j++
                                                )
                                                  Positioned(
                                                    left: j * 12.0,
                                                    child: Avatar(
                                                      common[j],
                                                      size: 20,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            count > 0
                                                ? '$count in comune'
                                                : accepted.contains(id)
                                                ? 'Richiesta accettata'
                                                : 'Vuole seguirti',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: muted,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (accepted.contains(id))
                              button(
                                s.follows(id)
                                    ? 'Segui già'
                                    : s.state.ids('pending').contains(id)
                                    ? 'Richiesta inviata'
                                    : 'Segui anche tu',
                                true,
                                busy || s.follows(id)
                                    ? null
                                    : () => perform(
                                        c,
                                        () => s.act('follow', {
                                          'user': id,
                                          'enabled': !s.state
                                              .ids('pending')
                                              .contains(id),
                                        }),
                                      ),
                              )
                            else if (!editing) ...[
                              button(
                                'Conferma',
                                true,
                                busy ? null : () => decide([id], true),
                              ),
                              const SizedBox(width: 5),
                              Tooltip(
                                message: 'Rifiuta richiesta',
                                child: button(
                                  'Elimina',
                                  false,
                                  busy ? null : () => decide([id], false),
                                ),
                              ),
                            ] else
                              IconButton(
                                tooltip: selected.contains(id)
                                    ? 'Deseleziona'
                                    : 'Seleziona',
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => selected.contains(id)
                                            ? selected.remove(id)
                                            : selected.add(id),
                                      ),
                                icon: Icon(
                                  selected.contains(id)
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  color: auraBlue,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${selected.length} selezionate',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: button(
                            'Elimina',
                            false,
                            busy || selected.isEmpty
                                ? null
                                : () => decide(selected.toList(), false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: button(
                            busy ? 'Attendi…' : 'Conferma',
                            true,
                            busy || selected.isEmpty
                                ? null
                                : () => decide(selected.toList(), true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class Settings extends StatefulWidget {
  final String? _area;
  const Settings({super.key}) : _area = null;
  const Settings._category(this._area);
  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    Widget row(
      IconData icon,
      String title,
      VoidCallback tap, {
      String? value,
      String? subtitle,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
      minLeadingWidth: 30,
      leading: GIcon(icon, size: 25, color: foreground(c)),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: secondaryText(c),
                fontSize: 12,
                height: 1.35,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) ...[
            Text(
              value,
              style: TextStyle(color: secondaryText(c), fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
          GIcon(
            CupertinoIcons.chevron_right,
            size: 15,
            color: secondaryText(c),
          ),
        ],
      ),
      onTap: tap,
    );
    void controls(String title, List<Widget> children) =>
        open(c, _SettingsDetail(title: title, children: children));
    final privacy = row(
      CupertinoIcons.lock,
      "Privacy dell'account",
      () => open(c, const _AccountPrivacy()),
      value: s.me.flag('private') ? 'Privato' : 'Pubblico',
    );
    final blocked = row(
      CupertinoIcons.person_crop_circle_badge_xmark,
      'Utenti bloccati',
      () => open(c, const _BlockedAccounts()),
      value: '${s.state.ids('blocks').length}',
    );
    final groups = <(String, String, IconData, List<(String, Widget)>)>[
      (
        'Account',
        'Dati, accesso e sicurezza',
        CupertinoIcons.person_crop_circle,
        [
          (
            'Dispositivi collegati',
            row(
              CupertinoIcons.device_phone_portrait,
              'Dispositivi collegati',
              () => open(c, const DeviceSessions()),
            ),
          ),
          (
            'Modifica profilo',
            row(
              CupertinoIcons.person_crop_circle,
              'Modifica profilo',
              () => open(c, const EditProfile()),
            ),
          ),
          (
            'Password e sicurezza',
            row(
              CupertinoIcons.lock_shield,
              'Password e sicurezza',
              () => open(c, const AccountSecurity()),
            ),
          ),
          (
            'Verifica email',
            row(
              CupertinoIcons.envelope_badge,
              'Verifica email',
              () => open(c, const AccountSecurity(mode: 'verify')),
            ),
          ),
        ],
      ),
      (
        'Privacy',
        'Visibilità e interazioni',
        CupertinoIcons.shield,
        [
          ("Privacy dell'account", privacy),
          (
            'Amici più stretti',
            row(
              CupertinoIcons.star_circle,
              'Amici più stretti',
              () => open(c, const CloseFriends()),
              value: '${s.state.ids('closeFriends').length}',
            ),
          ),
          ('Utenti bloccati', blocked),
          (
            'Nascondi anteprima notifiche messaggi privacy',
            row(
              CupertinoIcons.bell_slash,
              'Nascondi anteprima nelle notifiche',
              () => open(
                c,
                const MessageToggleSetting(setting: 'hideNotificationPreviews'),
              ),
              value: s.preferences.flag('hideNotificationPreviews')
                  ? 'Sì'
                  : 'No',
            ),
          ),
          (
            'Storie nascoste silenziati restrizioni messaggi tag menzioni',
            row(
              CupertinoIcons.shield,
              'Gestisci le interazioni',
              () => open(c, const PrivacyTools()),
              subtitle: 'Storie, messaggi, menzioni e account silenziati.',
            ),
          ),
          (
            'Messaggi e risposte alle storie attività conferme lettura anteprime protezione',
            row(
              CupertinoIcons.check_mark_circled,
              'Messaggi e risposte alle storie',
              () => open(c, const _MessagePrivacy()),
            ),
          ),
          (
            'Richieste di seguirti',
            row(
              CupertinoIcons.person_add,
              'Richieste di seguirti',
              () => open(c, const Requests()),
              value: '${s.state.ids('requests').length}',
            ),
          ),
        ],
      ),
      (
        'Notifiche',
        'Avvisi e attività',
        CupertinoIcons.bell,
        [
          (
            'Notifiche push',
            row(
              CupertinoIcons.bell,
              'Notifiche push',
              () => open(c, const PushSettings()),
            ),
          ),
          (
            'Attività ricevuta',
            row(
              CupertinoIcons.heart,
              'Attività ricevuta',
              () => open(c, const Activity()),
            ),
          ),
        ],
      ),
      (
        'I tuoi contenuti',
        'Bozze, salvati e archivio',
        CupertinoIcons.photo_on_rectangle,
        [
          (
            'Bozze',
            row(
              CupertinoIcons.doc_text,
              'Bozze',
              () => open(c, const DraftList()),
            ),
          ),
          (
            'Salvati',
            row(
              CupertinoIcons.bookmark,
              'Salvati',
              () => open(c, const CollectionPage(kind: 'saved')),
            ),
          ),
          (
            'Archivio',
            row(
              CupertinoIcons.archivebox,
              'Archivio',
              () => open(c, const CollectionPage(kind: 'archive')),
            ),
          ),
          (
            'Note',
            row(CupertinoIcons.text_bubble, 'Note', () => manageOwnNote(c)),
          ),
        ],
      ),
      (
        'Aspetto',
        'Tema e visualizzazione',
        CupertinoIcons.moon,
        [
          (
            'Istantanee bolla nascondi',
            row(
              CupertinoIcons.photo_on_rectangle,
              'Bolla delle istantanee',
              () => open(c, const InstantBubbleSetting()),
            ),
          ),
          (
            'Aspetto chiaro scuro tema',
            row(
              CupertinoIcons.moon,
              'Aspetto',
              () => open(c, const AppearancePage()),
              value: s.appearance == 'dark'
                  ? 'Scuro'
                  : s.appearance == 'light'
                  ? 'Chiaro'
                  : 'Dispositivo',
            ),
          ),
        ],
      ),
      (
        'Assistenza',
        'Aiuto e contatti',
        CupertinoIcons.question_circle,
        [
          (
            'Trova persone',
            row(
              CupertinoIcons.search,
              'Trova persone',
              () => open(c, const Explore()),
            ),
          ),
          (
            'Invita amici',
            row(
              CupertinoIcons.share,
              'Invita amici',
              () => SharePlus.instance.share(
                ShareParams(text: 'Seguimi su GPIX: @${s.me.str('username')}'),
              ),
            ),
          ),
          (
            'Aiuto',
            row(
              CupertinoIcons.question_circle,
              'Aiuto',
              () => controls('Aiuto', const [
                ListTile(
                  leading: GIcon(CupertinoIcons.person_crop_circle),
                  title: Text('Modificare il profilo'),
                  subtitle: Text(
                    'Apri Profilo → Modifica profilo e premi Fine per salvare.',
                  ),
                ),
                ListTile(
                  leading: GIcon(CupertinoIcons.doc_text),
                  title: Text('Salvare una bozza'),
                  subtitle: Text(
                    'Durante la creazione di un post o reel tocca Salva bozza. Ritrovi il contenuto in Crea → Bozze.',
                  ),
                ),
                ListTile(
                  leading: GIcon(CupertinoIcons.text_bubble),
                  title: Text('Pubblicare una nota'),
                  subtitle: Text(
                    'Nei Messaggi tocca La tua nota. Massimo 60 caratteri.',
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    ];
    final access = row(
      CupertinoIcons.square_arrow_left,
      'Gestisci accesso e account',
      () => open(c, const _AccountSettings()),
    );
    final area = widget._area;
    if (area != null) {
      final group = groups.firstWhere((group) => group.$1 == area);
      return Scaffold(
        appBar: AppBar(title: pageTitle(area)),
        body: SectionSwipe(
          onStep: (step) {
            final next = groups.indexWhere((group) => group.$1 == area) + step;
            if (next >= 0 && next < groups.length) {
              Navigator.of(c).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => Settings._category(groups[next].$1),
                ),
              );
            }
          },
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              for (final entry in group.$4) entry.$2,
              if (area == 'Account') access,
            ],
          ),
        ),
      );
    }
    final filter = query.trim().toLowerCase();
    final results = [
      for (final group in groups)
        for (final entry in group.$4)
          if ('${group.$1} ${entry.$1}'.toLowerCase().contains(filter))
            entry.$2,
      if ('gestisci accesso esci elimina account'.contains(filter)) access,
    ];
    return Scaffold(
      appBar: AppBar(
        title: pageTitle('Impostazioni e attività'),
        centerTitle: true,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: TextField(
              key: const ValueKey('settings-search'),
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca un’impostazione',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(13),
                  child: GIcon(CupertinoIcons.search, size: 21, color: muted),
                ),
                filled: true,
                fillColor: subdued(c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (filter.isEmpty) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 6,
              ),
              leading: Avatar(s.myId, size: 48),
              title: Text(
                s.me.str('name'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('@${s.me.str('username')}'),
              trailing: const GIcon(CupertinoIcons.chevron_right, size: 17),
              onTap: () => open(c, const EditProfile()),
            ),
            const Divider(height: 19),
            for (final group in groups) ...[
              ListTile(
                onTap: () => open(c, Settings._category(group.$1)),
                leading: SizedBox.square(
                  dimension: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: subdued(c),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GIcon(group.$3, size: 22),
                  ),
                ),
                title: Text(
                  group.$1,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  group.$2,
                  style: TextStyle(color: secondaryText(c), fontSize: 12),
                ),
                trailing: const GIcon(CupertinoIcons.chevron_right, size: 15),
              ),
            ],
            const Divider(height: 21),
            row(
              CupertinoIcons.bell,
              'La tua attività',
              () => open(c, const Activity()),
            ),
            row(
              CupertinoIcons.bookmark,
              'Elementi salvati',
              () => open(c, const CollectionPage(kind: 'saved')),
            ),
            row(
              CupertinoIcons.calendar,
              'Eventi e momenti',
              () => open(
                c,
                const Scaffold(body: SafeArea(child: CommunityDirectory())),
              ),
            ),
            access,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: OutlinedButton.icon(
                onPressed: () => _logout(c, s),
                style: OutlinedButton.styleFrom(foregroundColor: danger),
                icon: const GIcon(
                  CupertinoIcons.square_arrow_left,
                  size: 20,
                  color: danger,
                ),
                label: const Text('Esci'),
              ),
            ),
          ] else if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nessuna impostazione trovata'),
            )
          else
            ...results,
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _SettingsDetail extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsDetail({required this.title, required this.children});
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: pageTitle(title), centerTitle: true),
    body: ListView(children: children),
  );
}

class _AccountPrivacy extends StatelessWidget {
  const _AccountPrivacy();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle("Privacy dell'account")),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: const GIcon(CupertinoIcons.lock),
            title: const Text('Account privato'),
            subtitle: const Text(
              'Solo i follower approvati possono vedere i tuoi contenuti.',
            ),
            value: s.me.flag('private'),
            onChanged: (v) =>
                perform(c, () => s.act('profile', {'private': v})),
          ),
        ],
      ),
    );
  }
}

class _MessagePrivacy extends StatelessWidget {
  const _MessagePrivacy();
  @override
  Widget build(BuildContext c) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Text(
        text,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w600),
      ),
    );
    Widget link(IconData icon, String title, Widget page) => ListTile(
      leading: GIcon(icon),
      title: Text(title),
      trailing: const GIcon(CupertinoIcons.chevron_right, size: 18),
      onTap: () => open(c, page),
    );
    return Scaffold(
      appBar: AppBar(title: pageTitle('Messaggi e risposte alle storie')),
      body: ListView(
        children: [
          heading('In che modo le persone possono contattarti'),
          link(
            CupertinoIcons.paperplane,
            'Richieste di messaggi',
            const MessageAudienceSetting(),
          ),
          link(
            CupertinoIcons.chat_bubble,
            'Risposte alle storie',
            const MessageAudienceSetting(story: true),
          ),
          const Divider(thickness: 7, height: 30),
          heading('Chi può vedere che sei online'),
          link(
            CupertinoIcons.circle,
            'Mostra stato di attività',
            const MessageToggleSetting(setting: 'activityStatus'),
          ),
          link(
            CupertinoIcons.check_mark_circled,
            'Mostra conferme di lettura',
            const MessageToggleSetting(setting: 'readReceipts'),
          ),
          const Divider(thickness: 7, height: 30),
          heading('Cosa vedi nei messaggi'),
          link(
            CupertinoIcons.eye_slash,
            'Protezione delle immagini',
            const MessageToggleSetting(setting: 'imageProtection'),
          ),
          link(
            CupertinoIcons.text_bubble,
            'Anteprime',
            const MessageToggleSetting(setting: 'messagePreviews'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class MessageAudienceSetting extends StatelessWidget {
  final bool story;
  const MessageAudienceSetting({super.key, this.story = false});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        key = story ? 'storyReplies' : 'allowMessages',
        value = s.preferences.str(key, 'all');
    return Scaffold(
      appBar: AppBar(
        title: pageTitle(
          story ? 'Risposte alle storie' : 'Richieste di messaggi',
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              story
                  ? 'Scegli chi può rispondere alle tue storie.'
                  : 'Scegli chi può inviarti messaggi e richieste. Gli account che segui compaiono nella tua posta; le altre persone nelle richieste.',
            ),
          ),
          RadioGroup<String>(
            groupValue: value,
            onChanged: (v) {
              if (v != null) perform(c, () => s.setPreference(key, v));
            },
            child: Column(
              children: [
                for (final entry in {
                  'all': 'Tutti',
                  'following': 'Persone che segui',
                  'none': story ? 'Nessuno' : 'Non ricevere messaggi',
                }.entries)
                  RadioListTile<String>(
                    title: Text(entry.value),
                    value: entry.key,
                  ),
              ],
            ),
          ),
          if (!story)
            ListTile(
              leading: const GIcon(CupertinoIcons.tray),
              title: const Text('Apri richieste ricevute'),
              trailing: const GIcon(CupertinoIcons.chevron_right),
              onTap: () => open(c, const MessageRequests()),
            ),
        ],
      ),
    );
  }
}

class MessageToggleSetting extends StatelessWidget {
  final String setting;
  const MessageToggleSetting({super.key, required this.setting});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final info = <String, (String, String, IconData, bool)>{
      'activityStatus': (
        'Mostra stato di attività',
        'Le persone che segui e con cui hai una conversazione possono vedere quando sei attivo. Se lo disattivi, non vedrai il loro stato.',
        CupertinoIcons.circle,
        true,
      ),
      'readReceipts': (
        'Mostra conferme di lettura',
        'Mostra quando leggi i messaggi e visualizza le conferme degli altri.',
        CupertinoIcons.check_mark_circled,
        true,
      ),
      'imageProtection': (
        'Protezione delle immagini',
        'Sfoca tutte le foto e GIF ricevute nelle chat finché non scegli di mostrarle. La protezione è preventiva: non analizza né identifica automaticamente immagini di nudo.',
        CupertinoIcons.eye_slash,
        false,
      ),
      'hideNotificationPreviews': (
        'Nascondi anteprima nelle notifiche',
        'Nasconde il testo dei messaggi nelle notifiche. Il titolo indica “Nuovo messaggio” e puoi aprire GPIX per leggerlo. Disattiva questa opzione per mostrare il testo ricevuto.',
        CupertinoIcons.bell_slash,
        false,
      ),
      'messagePreviews': (
        'Anteprime',
        'Mostra il testo dell’ultimo messaggio nell’elenco delle conversazioni. Questa scelta non modifica le anteprime delle notifiche di sistema.',
        CupertinoIcons.text_bubble,
        true,
      ),
    }[setting]!;
    final value = setting == 'readReceipts'
        ? s.readReceipts
        : s.preferences[setting] as bool? ?? info.$4;
    return Scaffold(
      appBar: AppBar(title: pageTitle(info.$1)),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: GIcon(info.$3),
            title: Text(info.$1),
            subtitle: Text(info.$2),
            value: value,
            onChanged: (v) => perform(
              c,
              () => setting == 'readReceipts'
                  ? s.act('profile', {'readReceipts': v})
                  : s.setPreference(setting, v),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedAccounts extends StatelessWidget {
  const _BlockedAccounts();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), ids = s.state.ids('blocks');
    return Scaffold(
      appBar: AppBar(title: pageTitle('Utenti bloccati')),
      body: ids.isEmpty
          ? const Center(child: Text('Nessun account bloccato.'))
          : ListView(
              children: [
                for (final id in ids)
                  PersonTile(
                    id,
                    trailing: TextButton(
                      onPressed: () => perform(
                        c,
                        () => s.act('block', {'user': id, 'enabled': false}),
                      ),
                      child: const Text('Sblocca'),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> _logout(BuildContext c, GpixStore store) async {
  if (await gpixAlert(
        c,
        'Uscire da GPIX?',
        'Puoi accedere di nuovo in qualsiasi momento.',
        confirm: 'Esci',
        cancel: true,
      ) &&
      c.mounted) {
    await store.logout();
    if (c.mounted) Navigator.popUntil(c, (route) => route.isFirst);
  }
}

class _AccountSettings extends StatelessWidget {
  const _AccountSettings();
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Centro gestione account')),
      body: ListView(
        children: [
          PersonTile(s.myId),
          const Divider(),
          if (s.demo)
            ActionRow(
              CupertinoIcons.arrow_counterclockwise,
              'Reimposta demo',
              () async {
                if (await gpixAlert(
                      c,
                      'Reimpostare la demo?',
                      'Elimina tutte le modifiche locali e ripristina i dati di prova.',
                      confirm: 'Reimposta',
                      cancel: true,
                    ) &&
                    c.mounted)
                  perform(c, () => s.startDemo(reset: true));
              },
            ),
          ActionRow(
            CupertinoIcons.square_arrow_left,
            'Esci',
            () => _logout(c, s),
            destructive: true,
          ),
          ActionRow(CupertinoIcons.trash, 'Elimina account', () async {
            final pass = s.demo
                ? 'demo'
                : await textDialog(c, 'Conferma password', '', obscure: true);
            if (pass == null || !c.mounted) return;
            if (await gpixAlert(
                  c,
                  'Eliminare definitivamente l’account?',
                  'Post, messaggi e profilo verranno rimossi. Non puoi annullare questa azione.',
                  confirm: 'Elimina account',
                  destructive: true,
                  cancel: true,
                ) &&
                c.mounted)
              perform(c, () async {
                await s.act('deleteAccount', {'password': pass});
                if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
              });
          }, destructive: true),
          const SizedBox(height: 30),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

Future<void> createMenu(BuildContext c) async {
  final selected = await sheet<String>(
    c,
    Builder(
      builder: (menu) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Text('Crea', style: Theme.of(menu).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final mode in CreationMode.values)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: subdued(menu),
                        foregroundColor: foreground(menu),
                      ),
                      icon: GIcon(mode.icon, size: 21),
                      label: Text(mode.label),
                      onPressed: () => Navigator.pop(menu, mode.name),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              ActionRow(
                CupertinoIcons.person_2,
                'Momento',
                () => Navigator.pop(menu, 'moment'),
              ),
              ActionRow(
                CupertinoIcons.person_3,
                'Gruppo',
                () => Navigator.pop(menu, 'group'),
              ),
              ActionRow(
                CupertinoIcons.doc_text,
                'Bozze',
                () => Navigator.pop(menu, 'drafts'),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (selected == null || !c.mounted) return;
  switch (selected) {
    case 'drafts':
      await open(c, const DraftList());
    case 'group':
      await composeCommunity(c, 'communityGroup');
    case 'moment':
      await composeCommunity(c, 'communityMoment');
    default:
      await open(
        c,
        CreationStudio(initial: CreationMode.values.byName(selected)),
      );
  }
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Aspetto')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: BrandLogo(width: 210)),
          ),
          for (final item in const {
            'light': 'Chiaro',
            'dark': 'Scuro',
            'system': 'Come il dispositivo',
          }.entries)
            ListTile(
              title: Text(item.value),
              leading: GIcon(
                item.key == 'light'
                    ? CupertinoIcons.sun_max
                    : item.key == 'dark'
                    ? CupertinoIcons.moon
                    : CupertinoIcons.device_phone_portrait,
              ),
              trailing: s.appearance == item.key
                  ? const Icon(CupertinoIcons.check_mark, color: auraBlue)
                  : null,
              onTap: () => s.setAppearance(item.key),
            ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'La scelta viene salvata su questo dispositivo. Con “Come il dispositivo” GPIX segue automaticamente il tema del telefono.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class InstantBubbleSetting extends StatelessWidget {
  const InstantBubbleSetting({super.key});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Bolla delle istantanee')),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            secondary: const GIcon(CupertinoIcons.photo_on_rectangle),
            title: const Text('Mostra bolla nei messaggi'),
            subtitle: const Text(
              'Nasconde solo la bolla. Le istantanee restano accessibili dall’icona nella pagina Messaggi.',
            ),
            value: !s.preferences.flag('hideInstantBubble'),
            onChanged: (v) =>
                perform(c, () => s.setPreference('hideInstantBubble', !v)),
          ),
        ],
      ),
    );
  }
}
