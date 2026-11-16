import 'package:flutter/foundation.dart' show setEquals;
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'stories.dart';
import 'reel_editor.dart';
import 'features13.dart';
import 'sessions_instants.dart';
import 'messages.dart';
import 'inbox_widgets.dart' show DirectSearchField, directSearchTerm;
import 'video.dart';
import 'live.dart';
import 'community.dart';
import 'notes.dart';
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
  bool pickingStoryMedia = false;

  Future<void> addStory() async {
    if (pickingStoryMedia) return;
    pickingStoryMedia = true;
    try {
      await perform(context, () async {
        final selected = await ImagePicker().pickMedia();
        if (selected == null || !mounted) return;
        await open(
          context,
          Composer(kind: 'story', initialMedia: selected.path),
        );
      });
    } finally {
      pickingStoryMedia = false;
    }
  }

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
    final width = MediaQuery.sizeOf(c).width;
    final slot = (width * .247).clamp(74.0, 105.0);
    final avatar = slot - 16;
    final ringDiameter = avatar + 10.2;
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
        SizedBox(
          height:
              ringDiameter +
              30 +
              (MediaQuery.textScalerOf(c).scale(10) - 10).clamp(0.0, 32.0),
          child: ListView.separated(
            key: const ValueKey('stories-strip'),
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(5, 2, 5, 7),
            scrollDirection: Axis.horizontal,
            itemCount: users.length + 1,
            separatorBuilder: (_, i) => const SizedBox(width: 5),
            itemBuilder: (c, i) {
              final uid = i == 0 ? s.myId : users[i - 1].str('id');
              final stories = s.stories(uid);
              return InkWell(
                onTap: i == 0 && stories.isEmpty
                    ? addStory
                    : () => open(c, StoryViewer(user: uid)),
                onLongPress: i == 0 ? addStory : null,
                child: SizedBox(
                  width: slot,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Avatar(
                            uid,
                            size: avatar,
                            ring: i == 0 || stories.isNotEmpty,
                            viewed:
                                (i == 0 && stories.isEmpty) ||
                                (i != 0 &&
                                    stories.every(
                                      (p) =>
                                          (p.flag('seenByMe') ||
                                          p.ids('viewers').contains(s.myId)),
                                    )),
                          ),
                          if (i == 0)
                            Positioned(
                              right: 3,
                              bottom: 0,
                              child: GestureDetector(
                                key: const ValueKey('create-own-story'),
                                onTap: addStory,
                                child: Container(
                                  width: 29,
                                  height: 29,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff15171b),
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
                          fontSize: 10.5,
                          color: i == 0 ? secondaryText(c) : foreground(c),
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
    this.feed = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color? color;
  final bool feed;

  @override
  Widget build(BuildContext context) {
    final value = feed && count == 0 ? null : count;
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
            constraints: const BoxConstraints(minWidth: 0, minHeight: 44),
            padding: EdgeInsets.symmetric(horizontal: feed ? 0 : 4),
            child: Center(
              widthFactor: 1,
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
                        size: feed ? 25 : 23,
                        postAction: feed,
                      ),
                    ),
                    if (display != null) ...[
                      const SizedBox(width: 5),
                      Text(
                        display,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
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
Future<void> postMenu(BuildContext c, J p, {bool detail = false}) async {
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
            if (Platform.isAndroid && p.obj('style').flag('video'))
              ActionRow(
                CupertinoIcons.play_rectangle,
                'Condividi come reel',
                () => Navigator.pop(menu, 'reel'),
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
    if (action == 'reel') {
      await open(c, ReelEditor(story: p));
    } else if (action == 'highlight') {
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
  if (detail && !own) {
    final selected = await sheet<String>(
      c,
      Builder(
        builder: (menu) => _PostMenuGroup(
          children: [
            if (p.ids('collaborators').contains(s.myId))
              ActionRow(
                CupertinoIcons.person_badge_minus,
                'Abbandona collaborazione',
                () => Navigator.pop(menu, 'leave'),
                destructive: true,
              ),
            ActionRow(
              CupertinoIcons.flag,
              'Segnala',
              () => Navigator.pop(menu, 'report'),
              destructive: true,
            ),
          ],
        ),
      ),
    );
    if (!c.mounted) return;
    if (selected == 'report') await report(c, p.str('id'));
    if (selected == 'leave' &&
        await gpixAlert(
          c,
          'Abbandonare la collaborazione?',
          'Il post verrà rimosso dal tuo profilo.',
          confirm: 'Abbandona',
          cancel: true,
          destructive: true,
        ) &&
        c.mounted) {
      await perform(
        c,
        () => s.act('postCollaboration', {
          'id': p.str('id'),
          'decision': 'leave',
        }),
      );
    }
    return;
  }

  await sheet(
    c,
    Builder(
      builder: (menu) {
        final save = ActionRow(
          p.flag('saved')
              ? CupertinoIcons.bookmark_fill
              : CupertinoIcons.bookmark,
          p.flag('saved') ? 'Rimuovi dai salvati' : 'Salva',
          () {
            Navigator.pop(menu);
            toggleSavedPost(c, p.str('id'));
          },
        );
        return Column(
          children: [
            if (detail)
              ListTile(
                title: const Text(
                  'Informazioni su questo post',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const GIcon(CupertinoIcons.chevron_forward, size: 16),
                onTap: () {
                  Navigator.pop(menu);
                  _showPostInfo(c, p);
                },
              ),
            _PostMenuGroup(grouped: detail, children: [save]),
            if (!detail)
              ActionRow(CupertinoIcons.paperplane, 'Invia a…', () {
                Navigator.pop(menu);
                sharePost(c, p);
              }),
            if (!own && p.str('kind') != 'story')
              ActionRow(
                s.feedFavorites.contains(p.str('author'))
                    ? CupertinoIcons.star_fill
                    : CupertinoIcons.star,
                s.feedFavorites.contains(p.str('author'))
                    ? 'Rimuovi dai preferiti'
                    : 'Aggiungi ai preferiti',
                () {
                  Navigator.pop(menu);
                  perform(
                    c,
                    () => s.setFeedFavorite(
                      p.str('author'),
                      !s.feedFavorites.contains(p.str('author')),
                    ),
                  );
                },
              ),
            if (own) ...[
              _PostMenuGroup(
                children: [
                  ActionRow(
                    CupertinoIcons.archivebox,
                    p.flag('archived') ? 'Mostra nel profilo' : 'Archivia',
                    () {
                      Navigator.pop(menu);
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
                    CupertinoIcons.eye_slash,
                    p.flag('hideLikes')
                        ? 'Mostra numero di Mi piace'
                        : 'Nascondi numero di Mi piace',
                    () {
                      Navigator.pop(menu);
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
                  ActionRow(
                    CupertinoIcons.chat_bubble,
                    p.flag('commentsOff')
                        ? 'Attiva commenti'
                        : 'Disattiva commenti',
                    () {
                      Navigator.pop(menu);
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
                  ActionRow(CupertinoIcons.pencil, 'Modifica', () async {
                    Navigator.pop(menu);
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
                    CupertinoIcons.placemark,
                    'Modifica luogo',
                    () async {
                      Navigator.pop(menu);
                      final value = await chooseGpixPlace(
                        c,
                        initial: p.str('location'),
                      );
                      if (value != null && c.mounted) {
                        await perform(
                          c,
                          () => s.act('editPost', {
                            'id': p['id'],
                            'text': p.str('text'),
                            'location': value,
                          }),
                        );
                      }
                    },
                  ),
                  if (p.str('kind') != 'story')
                    ActionRow(
                      CupertinoIcons.pin,
                      s.me.ids('pinnedPosts').contains(p.str('id'))
                          ? 'Rimuovi dal profilo fissato'
                          : detail
                          ? 'Fissa nella griglia principale'
                          : 'Fissa nel profilo',
                      () {
                        Navigator.pop(menu);
                        perform(
                          c,
                          () => s.act('pinPost', {
                            'id': p['id'],
                            'enabled': !s.me
                                .ids('pinnedPosts')
                                .contains(p.str('id')),
                          }),
                        );
                      },
                    ),
                  if (p.str('kind') == 'story')
                    ActionRow(
                      CupertinoIcons.star_circle,
                      'Metti in evidenza',
                      () {
                        Navigator.pop(menu);
                        addStoryHighlight(c, p);
                      },
                    ),
                  if (p.str('kind') == 'post' &&
                      s.state.number('communityVersion') > 0 &&
                      !s.state
                          .rows('socialItems')
                          .any((item) => item.str('post') == p.str('id')))
                    ActionRow(
                      CupertinoIcons.person_2,
                      'Crea un Momento da questo post',
                      () {
                        Navigator.pop(menu);
                        composeCommunity(
                          c,
                          'communityMoment',
                          post: p.str('id'),
                        );
                      },
                    ),
                  ActionRow(CupertinoIcons.trash, 'Elimina', () async {
                    Navigator.pop(menu);
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
                ],
                grouped: detail,
              ),
            ] else ...[
              ActionRow(
                CupertinoIcons.person,
                s.follows(p.str('author')) ? 'Non seguire più' : 'Segui',
                () {
                  Navigator.pop(menu);
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
                Navigator.pop(menu);
                report(c, p.str('id'));
              }, destructive: true),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    ),
  );
}

class _PostMenuGroup extends StatelessWidget {
  const _PostMenuGroup({required this.children, this.grouped = true});
  final List<Widget> children;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final list = Column(children: children);
    if (!grouped) return list;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Material(
        color: subdued(context),
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: list,
      ),
    );
  }
}

Future<void> _showPostInfo(BuildContext context, J post) {
  final created = post.number('created');
  return sheet<void>(
    context,
    Column(
      children: [
        const Text(
          'Informazioni su questo post',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        PersonTile(post.str('author')),
        if (created > 0)
          ListTile(
            leading: const GIcon(CupertinoIcons.calendar),
            title: const Text('Data di pubblicazione'),
            subtitle: Text(
              MaterialLocalizations.of(context).formatFullDate(
                DateTime.fromMillisecondsSinceEpoch((created * 1000).round()),
              ),
            ),
          ),
        if (post.str('location').isNotEmpty)
          ListTile(
            leading: const GIcon(CupertinoIcons.location),
            title: Text(post.str('location')),
          ),
        const SizedBox(height: 12),
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
Future<void> sharePost(BuildContext c, J p) => showModalBottomSheet<void>(
  context: c,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: surface(c),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (menu) {
    final keyboard = MediaQuery.viewInsetsOf(menu).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (menu, bounds) => SizedBox(
          height: keyboard > 0
              ? bounds.maxHeight
              : MediaQuery.sizeOf(menu).height * .57,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: foreground(menu).withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: SharePanel(
                    post: p,
                    onDone: () => Navigator.pop(menu),
                    onStory: () {
                      Navigator.pop(menu);
                      if (c.mounted) openSharedStory(c, p.str('id'));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);

void openSharedStory(BuildContext context, String id) {
  final store = GpixScope.of(context, listen: false);
  if (!store.canSharePostOutsideChat(store.post(id))) {
    notice(context, 'Contenuto non disponibile');
    return;
  }
  open(
    context,
    Composer(
      kind: 'story',
      initialDraft: {
        'style': {
          'stickers': [
            {'type': 'sharedPost', 'postId': id, 'x': .17, 'y': .22},
          ],
        },
      },
    ),
  );
}

class SharePanel extends StatefulWidget {
  const SharePanel({
    super.key,
    required this.post,
    required this.onDone,
    this.onStory,
  });

  final J post;
  final VoidCallback onDone;
  final VoidCallback? onStory;

  @override
  State<SharePanel> createState() => _SharePanelState();
}

class _SharePanelState extends State<SharePanel> {
  final selected = <String>{};
  final sentShares = <String>{};
  final search = TextEditingController();
  final message = TextEditingController();
  bool busy = false;
  String? groupThread;
  bool groupShared = false;
  Set<String>? groupMembers;

  Future<void> sendGroup(GpixStore store) async {
    if (busy || selected.length < 2 || sentShares.isNotEmpty) return;
    final members = Set<String>.of(selected);
    if (groupMembers != null && !setEquals(groupMembers, members)) return;
    final identity = (store.server, store.myId, store.token);
    bool active() =>
        mounted && identity == (store.server, store.myId, store.token);
    final note = message.text.trim();
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    await perform(context, () async {
      if (groupThread == null) {
        final titles = members
            .map((id) => store.user(id).str('username'))
            .join(', ');
        final name = titles.characters.take(60).toString();
        final existing = store.threads
            .map((thread) => thread.str('id'))
            .toSet();
        await store.act('group', {'users': members.toList(), 'title': name});
        if (!active()) return;
        final created = store.threads
            .where(
              (thread) =>
                  thread.str('owner') == store.myId &&
                  !existing.contains(thread.str('id')) &&
                  setEquals(thread.ids('members').toSet(), {
                    ...members,
                    store.myId,
                  }),
            )
            .firstOrNull;
        if (created == null)
          throw Exception('La chat di gruppo non è disponibile');
        groupThread = created.str('id');
        groupMembers = members;
      }
      final thread = groupThread!;
      if (!groupShared) {
        await store.act('sharePost', {
          'id': thread,
          'post': widget.post.str('id'),
        });
        groupShared = true;
      }
      if (!active()) return;
      if (note.isNotEmpty) await store.send(thread, note);
      if (!active()) return;
      notice(context, 'Inviato alla nuova chat di gruppo');
      widget.onDone();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  void dispose() {
    search.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> send(GpixStore store) async {
    if (busy || selected.isEmpty) return;
    FocusScope.of(context).unfocus();
    final identity = (store.server, store.myId, store.token);
    bool active() =>
        mounted && identity == (store.server, store.myId, store.token);
    final note = message.text.trim();
    final source = widget.post.str('id');
    setState(() => busy = true);
    await perform(context, () async {
      for (final user in selected.toList()) {
        if (!active()) return;
        final direct = !user.startsWith('thread:');
        final thread = direct
            ? await store.openThread(user)
            : user.substring(7);
        if (!active()) return;
        if (!sentShares.contains(user)) {
          await store.act('sharePost', {'id': thread, 'post': source});
          sentShares.add(user);
        }
        if (!active()) return;
        if (note.isNotEmpty) await store.send(thread, note);
        if (!active()) return;
        setState(() => selected.remove(user));
      }
      if (!active()) return;
      notice(context, switch (widget.post.str('kind')) {
        'reel' => 'Reel inviato',
        'story' => 'Storia inviata',
        _ => 'Post inviato',
      });
      widget.onDone();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> shareExternally(String caption, String id) async {
    if (busy) return;
    final store = GpixScope.of(context, listen: false);
    final identity = (store.server, store.myId, store.token);
    final box = context.findRenderObject();
    final origin = box is RenderBox
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    bool active() =>
        mounted &&
        identity == (store.server, store.myId, store.token) &&
        store.canSharePostOutsideChat(store.post(id));

    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      await perform(context, () async {
        if (!active()) return;
        final post = store.post(id);
        final media = store.media(post);
        final primary = post.str('media');
        final references = store.isVideoPost(post) && primary.isNotEmpty
            ? [primary]
            : media;
        if (references.isEmpty) {
          await SharePlus.instance.share(
            ShareParams(text: caption, sharePositionOrigin: origin),
          );
          return;
        }
        final folder = await (await getTemporaryDirectory()).createTemp(
          'gpix-share-',
        );
        try {
          final files = <XFile>[];
          for (final (index, reference) in references.indexed) {
            if (!active()) return;
            files.add(await _sharedMedia(store, folder, reference, index + 1));
          }
          if (active())
            await SharePlus.instance.share(
              ShareParams(
                files: files,
                text: caption,
                sharePositionOrigin: origin,
              ),
            );
        } finally {
          await folder.delete(recursive: true).catchError((Object _) => folder);
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final store = GpixScope.of(c);
    final id = widget.post.str('id');
    final post = store.post(id);
    final canShareOutside = store.canSharePostOutsideChat(post);
    final link =
        store.state.flag('publicShareLinks') && store.canSharePublicPost(post)
        ? Uri.parse(
            store.server,
          ).resolve('/p/${Uri.encodeComponent(id)}').toString()
        : null;
    final caption = [
      store.user(post.str('author')).str('username'),
      post.str('text').trim(),
    ].where((part) => part.isNotEmpty).join(' su GPIX\n');
    final query = directSearchTerm(
      search.text.trim().replaceFirst(RegExp(r'^@'), ''),
    );
    final recent = store.inboxThreads.map(store.other).toSet();
    final users =
        store.users
            .where(
              (user) =>
                  user.str('id') != store.myId &&
                  !store.blocked(user.str('id')) &&
                  directSearchTerm(
                    '${user.str('name')} ${user.str('username')}',
                  ).contains(query),
            )
            .toList()
          ..sort((a, b) {
            final rank =
                (recent.contains(b.str('id')) ? 1 : 0) -
                (recent.contains(a.str('id')) ? 1 : 0);
            return rank != 0
                ? rank
                : a.str('username').compareTo(b.str('username'));
          });
    final recipients = [
      for (final user in users)
        (
          key: user.str('id'),
          label: user.str('name', user.str('username')),
          avatar: user.str('id'),
        ),
      for (final thread in store.inboxThreads)
        if (thread.str('owner').isNotEmpty &&
            directSearchTerm(store.threadName(thread)).contains(query))
          (
            key: 'thread:${thread.str('id')}',
            label: store.threadName(thread),
            avatar: thread
                .ids('members')
                .firstWhere((id) => id != store.myId, orElse: () => store.myId),
          ),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: DirectSearchField(
            controller: search,
            hint: 'Cerca',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: recipients.isEmpty
              ? const Center(child: Text('Nessuna persona trovata'))
              : GridView.builder(
                  key: ValueKey(query),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(c).width < 580 ? 3 : 5,
                    mainAxisExtent: 103,
                  ),
                  itemCount: recipients.length,
                  itemBuilder: (c, index) {
                    final entry = recipients[index];
                    final recipient = entry.key;
                    final checked = selected.contains(recipient);
                    return Semantics(
                      selected: checked,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap:
                            busy ||
                                groupMembers != null ||
                                sentShares.contains(recipient)
                            ? null
                            : () => setState(() {
                                if (!selected.add(recipient))
                                  selected.remove(recipient);
                              }),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Avatar(entry.avatar, size: 64),
                                if (checked)
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: Container(
                                      width: 21,
                                      height: 21,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: auraBlue,
                                        border: Border.all(
                                          color: surface(c),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.check_mark,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Text(
                                  entry.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: message,
                  enabled: !busy,
                  maxLength: 4000,
                  maxLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Scrivi un messaggio…',
                    counterText: '',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: busy || groupMembers != null
                      ? null
                      : () => send(store),
                  child: Text(
                    busy
                        ? 'Invio…'
                        : selected.length == 1
                        ? 'Invia'
                        : 'Invia separatamente',
                  ),
                ),
                if (selected.length > 1 &&
                    sentShares.isEmpty &&
                    selected.every((id) => !id.startsWith('thread:')))
                  FilledButton.tonal(
                    onPressed: busy || selected.length > 30
                        ? null
                        : () => sendGroup(store),
                    child: Text(
                      'Invia a nuova chat di gruppo (${selected.length})',
                    ),
                  ),
              ],
            ),
          )
        else if (canShareOutside)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 9),
            child: Row(
              children: [
                if (widget.onStory != null)
                  action(
                    c,
                    CupertinoIcons.plus_circle,
                    'Aggiungi alla storia',
                    widget.onStory!,
                  ),
                if (link != null)
                  action(
                    c,
                    CupertinoIcons.chat_bubble,
                    'WhatsApp',
                    () => perform(c, () async {
                      final uri = Uri.https('wa.me', '/', {'text': link});
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        throw Exception('Impossibile aprire WhatsApp');
                      }
                    }),
                    background: const Color(0xff25d366),
                    iconColor: Colors.white,
                  ),
                action(
                  c,
                  CupertinoIcons.share,
                  'Condividi in…',
                  () => shareExternally(
                    link == null ? caption : '$caption\n$link',
                    id,
                  ),
                ),
                if (link != null)
                  action(c, CupertinoIcons.link, 'Copia link', () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (c.mounted) notice(c, 'Link copiato');
                  })
                else if (post.str('text').trim().isNotEmpty)
                  action(c, CupertinoIcons.doc_on_doc, 'Copia testo', () async {
                    await Clipboard.setData(
                      ClipboardData(text: post.str('text')),
                    );
                    if (c.mounted) notice(c, 'Testo copiato');
                  }),
              ],
            ),
          ),
      ],
    );
  }

  Widget action(
    BuildContext c,
    IconData icon,
    String label,
    VoidCallback tap, {
    Color? background,
    Color? iconColor,
  }) => SizedBox(
    width: 78,
    child: InkWell(
      onTap: busy ? null : tap,
      borderRadius: BorderRadius.circular(13),
      child: Column(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: background ?? subdued(c),
            child: GIcon(icon, color: iconColor ?? foreground(c), size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

const _sharedMediaExtensions = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
};

Future<XFile> _sharedMedia(
  GpixStore store,
  Directory folder,
  String reference,
  int index,
) async {
  final source = store.url(reference);
  final uri = Uri.parse(source);
  if (store.demo && !uri.hasScheme) {
    final extension = (uri.pathSegments.lastOrNull ?? '')
        .split('.')
        .last
        .toLowerCase();
    final suffix = extension == 'jpeg' ? 'jpg' : extension;
    final mime = _sharedMediaExtensions.entries
        .where((entry) => entry.value == suffix)
        .firstOrNull
        ?.key;
    if (mime == null) throw Exception('Formato del contenuto non supportato.');
    final output = File('${folder.path}/GPIX-$index.$suffix');
    if (source.startsWith('/')) {
      await File(source).copy(output.path);
    } else {
      final bytes = await rootBundle.load('assets/media/$source');
      await output.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
    return XFile(output.path, mimeType: mime);
  }
  final server = Uri.parse(store.server);
  if (uri.scheme != 'https' ||
      uri.host != server.host ||
      uri.port != server.port ||
      !uri.path.startsWith('/media/')) {
    throw Exception('Contenuto non disponibile per la condivisione.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 20));
    final mime = response.headers.contentType?.mimeType;
    final suffix = _sharedMediaExtensions[mime];
    if (response.statusCode != HttpStatus.ok || suffix == null) {
      throw Exception('Impossibile scaricare il contenuto.');
    }
    final output = File('${folder.path}/GPIX-$index.$suffix');
    await response
        .timeout(const Duration(seconds: 30))
        .pipe(output.openWrite());
    if (await output.length() == 0) throw Exception('Il contenuto è vuoto.');
    return XFile(output.path, mimeType: mime);
  } finally {
    client.close(force: true);
  }
}

Future<void> comments(BuildContext c, String id) => showModalBottomSheet<void>(
  context: c,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: surface(c),
  barrierColor: Colors.black54,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: LayoutBuilder(
        builder: (context, bounds) => SizedBox(
          key: const ValueKey('post-comment-sheet'),
          height: keyboard > 0
              ? bounds.maxHeight
              : MediaQuery.sizeOf(context).height * .70,
          child: SafeArea(top: false, child: Comments(id: id)),
        ),
      ),
    );
  },
);

class Comments extends StatefulWidget {
  final String id;
  final bool reel;
  const Comments({super.key, required this.id, this.reel = false});
  @override
  State<Comments> createState() => _CommentsState();
}

class _CommentsState extends State<Comments> {
  final input = TextEditingController();
  String parent = '', replyName = '', media = '', replyTarget = '';
  String replyPrefix = '';
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
    if (widget.reel) return _commentPanel(c, s, p, comments);
    return Column(
      children: [
        const SizedBox(height: 7),
        Container(
          width: 35,
          height: 3,
          decoration: BoxDecoration(
            color: foreground(c).withValues(alpha: .25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(
          height: 43,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Center(
                child: Text(
                  'Commenti',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (p.isNotEmpty)
                Positioned(
                  right: 10,
                  child: IconButton(
                    tooltip: 'Condividi post',
                    icon: const GIcon(CupertinoIcons.paperplane, size: 22),
                    onPressed: () {
                      focus.unfocus();
                      sharePost(c, p);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _commentPanel(c, s, p, comments)),
      ],
    );
  }

  final _expandedReplies = <String>{};
  bool _recent = false, _submitting = false;

  bool get _hasText {
    final text = input.text.trim();
    return text.isNotEmpty && text != replyPrefix.trim();
  }

  void _cancelReply() {
    if (replyPrefix.isNotEmpty && input.text.startsWith(replyPrefix)) {
      final remaining = input.text.substring(replyPrefix.length);
      input.value = TextEditingValue(
        text: remaining,
        selection: TextSelection.collapsed(offset: remaining.length),
      );
    }
    parent = '';
    replyTarget = '';
    replyPrefix = '';
  }

  void _replyTo(J comment, String name) {
    setState(() {
      _cancelReply();
      replyTarget = comment.str('id');
      final root = comment.str('parent');
      parent = root.isEmpty ? replyTarget : root;
      replyName = name;
      if (!widget.reel && input.text.isEmpty && name.isNotEmpty) {
        replyPrefix = '@$name ';
        input.value = TextEditingValue(
          text: replyPrefix,
          selection: TextSelection.collapsed(offset: replyPrefix.length),
        );
      }
    });
    focus.requestFocus();
  }

  Future<void> _submit(BuildContext c, GpixStore s) async {
    final text = _hasText ? input.text.trim() : '',
        reply = parent,
        attachment = media;
    if (_submitting || (text.isEmpty && attachment.isEmpty)) return;
    setState(() => _submitting = true);
    await perform(c, () async {
      await s.act('comment', {
        'id': widget.id,
        'text': text,
        'parent': reply,
        'media': attachment,
      });
      if (!mounted) return;
      setState(() {
        if (input.text.trim() == text ||
            input.text.trim() == replyPrefix.trim())
          input.clear();
        if (parent == reply) {
          parent = '';
          replyTarget = '';
          replyPrefix = '';
        }
        if (media == attachment) media = '';
        if (reply.isNotEmpty) _expandedReplies.add(reply);
      });
    });
    if (mounted) setState(() => _submitting = false);
  }

  Widget _commentPanel(BuildContext c, GpixStore s, J post, List<J> comments) {
    final canSend =
        post.isNotEmpty &&
        (!post.flag('commentsOff') || post.str('author') == s.myId);
    final roots = comments.where((m) => m.str('parent').isEmpty).toList()
      ..sort((a, b) {
        final age = b.number('created').compareTo(a.number('created'));
        final likes = b.ids('likes').length.compareTo(a.ids('likes').length);
        return _recent || likes == 0 ? age : likes;
      });
    final replies = <String, List<J>>{};
    for (final comment in comments) {
      final parent = comment.str('parent');
      if (parent.isNotEmpty) (replies[parent] ??= []).add(comment);
    }
    const scroll = ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: PopupMenuButton<bool>(
              tooltip: 'Ordina commenti',
              onSelected: (v) => setState(() => _recent = v),
              initialValue: _recent,
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Per te')),
                PopupMenuItem(value: true, child: Text('Più recenti')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _recent ? 'Più recenti' : 'Per te',
                      style: TextStyle(
                        color: secondaryText(c),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 5),
                    GIcon(
                      CupertinoIcons.chevron_down,
                      color: secondaryText(c),
                      size: 11,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: roots.isEmpty
              ? CustomScrollView(
                  physics: scroll,
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Ancora nessun commento',
                            style: TextStyle(
                              color: secondaryText(c),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 6),
                  physics: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: roots.length,
                  itemBuilder: (c, i) {
                    final root = roots[i], id = roots[i].str('id');
                    final children = replies[id] ?? const <J>[];
                    final expanded = _expandedReplies.contains(id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _comment(c, root, false, canReply: canSend),
                        if (expanded)
                          for (final child in children)
                            _comment(c, child, true, canReply: canSend),
                        if (children.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 52),
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: secondaryText(c),
                                minimumSize: const Size(0, 31),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(() {
                                if (!_expandedReplies.add(id))
                                  _expandedReplies.remove(id);
                              }),
                              icon: const SizedBox(
                                width: 19,
                                child: Divider(height: 1),
                              ),
                              label: Text(
                                expanded
                                    ? 'Nascondi risposte'
                                    : children.length == 1
                                    ? 'Visualizza 1 risposta'
                                    : 'Visualizza ${children.length} risposte',
                                style: const TextStyle(fontSize: 10.5),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        if (canSend)
          _composer(c, s)
        else
          Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              post.isEmpty
                  ? 'Contenuto non disponibile'
                  : 'Commenti disattivati',
              style: TextStyle(color: secondaryText(c), fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _composer(BuildContext c, GpixStore s) {
    final sending = _hasText || media.isNotEmpty;
    final dark = Theme.of(c).brightness == Brightness.dark;
    final compact =
        MediaQuery.sizeOf(c).height - MediaQuery.viewInsetsOf(c).bottom < 420;
    return Column(
      children: [
        if (!compact)
          SizedBox(
            height: 41,
            child: Row(
              children: [
                for (final emoji in const [
                  '❤️',
                  '🙌',
                  '🔥',
                  '👏',
                  '😢',
                  '😍',
                  '😮',
                  '😂',
                ])
                  Expanded(
                    child: InkResponse(
                      onTap: () {
                        final selection = input.selection.isValid
                            ? input.selection
                            : TextSelection.collapsed(
                                offset: input.text.length,
                              );
                        input.value = TextEditingValue(
                          text: input.text.replaceRange(
                            selection.start,
                            selection.end,
                            emoji,
                          ),
                          selection: TextSelection.collapsed(
                            offset: selection.start + emoji.length,
                          ),
                        );
                        setState(() {});
                        focus.requestFocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (parent.isNotEmpty || media.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 8, 2),
            child: Row(
              children: [
                if (media.isNotEmpty)
                  SizedBox.square(
                    dimension: 25,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: MediaView(media),
                    ),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    parent.isNotEmpty
                        ? 'Stai rispondendo a $replyName'
                        : 'Allegato',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: secondaryText(c), fontSize: 11),
                  ),
                ),
                IconButton(
                  tooltip: media.isNotEmpty
                      ? 'Rimuovi allegato'
                      : 'Rimuovi risposta',
                  constraints: const BoxConstraints.tightFor(
                    width: 35,
                    height: 29,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() {
                    if (media.isNotEmpty) {
                      media = '';
                    } else {
                      _cancelReply();
                    }
                  }),
                  icon: const GIcon(CupertinoIcons.xmark, size: 14),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 11, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Avatar(s.myId, size: 32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: dark ? const Color(0xff25262b) : subdued(c),
                  borderRadius: BorderRadius.circular(25),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: TextField(
                            key: ValueKey(
                              widget.reel
                                  ? 'reel-comment-input'
                                  : 'post-comment-input',
                            ),
                            controller: input,
                            focusNode: focus,
                            minLines: 1,
                            maxLines: compact ? 2 : 3,
                            maxLength: 2000,
                            keyboardAppearance: Theme.of(c).brightness,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(
                              fontSize: 14,
                              color: foreground(c),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Cosa ne pensi?',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: secondaryText(c),
                              ),
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      if (sending)
                        IconButton(
                          tooltip: 'Pubblica commento',
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 39,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _submitting ? null : () => _submit(c, s),
                          icon: GIcon(
                            CupertinoIcons.arrow_up_circle_fill,
                            color: dark ? const Color(0xff699dff) : auraBlue,
                            size: 26,
                          ),
                        )
                      else
                        for (final (gif, label, icon) in const [
                          (false, 'Foto nel commento', CupertinoIcons.photo),
                          (true, 'GIF nel commento', Icons.gif_box_outlined),
                        ])
                          IconButton(
                            tooltip: label,
                            constraints: const BoxConstraints.tightFor(
                              width: 35,
                              height: 40,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => pickComment(gif),
                            icon: GIcon(icon, size: 22, color: foreground(c)),
                          ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _comment(BuildContext c, J m, bool child, {bool canReply = true}) {
    final s = GpixScope.of(c),
        uid = m.str('author'),
        liked = m.ids('likes').contains(s.myId);
    return Container(
      color: replyTarget == m.str('id')
          ? accent(c).withValues(alpha: .075)
          : null,
      padding: EdgeInsets.fromLTRB(child ? 48 : 14, 7, 12, 1),
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
                        if (m.number('created') > 0)
                          TextSpan(
                            text: relative(m['created']),
                            style: TextStyle(
                              color: secondaryText(c),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                  if (m.str('text').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        m.str('text'),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.26,
                          color: foreground(c),
                        ),
                      ),
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
                          width: widget.reel ? 122 : 160,
                          height: widget.reel ? 122 : 160,
                          child: MediaView(m.str('media')),
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      if (canReply)
                        InkWell(
                          onTap: () => _replyTo(m, s.user(uid).str('username')),
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
                  const SizedBox(height: 4),
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
              IconButton(
                tooltip: liked
                    ? 'Rimuovi Mi piace al commento'
                    : 'Mi piace al commento',
                constraints: const BoxConstraints.tightFor(
                  width: 35,
                  height: 30,
                ),
                padding: EdgeInsets.zero,
                onPressed: () => perform(
                  c,
                  () =>
                      s.act('likeComment', {'id': m['id'], 'enabled': !liked}),
                ),
                icon: GIcon(
                  liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  size: 17,
                  color: liked ? danger : secondaryText(c),
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

class TagPrivacyPage extends StatelessWidget {
  const TagPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final pending = store.posts
        .where((post) => post.ids('pendingTagUsers').contains(store.myId))
        .toList();
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Tag e menzioni')),
      body: ListView(
        children: [
          for (final (key, heading, labels) in [
            (
              'allowTags',
              'Chi può taggarti?',
              [
                'Consenti i tag di chiunque',
                'Consenti i tag delle persone che segui',
                'Non consentire i tag',
              ],
            ),
            (
              'allowMentions',
              'Chi può menzionarti?',
              [
                'Consenti a tutti di menzionarti',
                'Consenti alle persone che segui di menzionarti',
                'Non consentire le menzioni',
              ],
            ),
          ]) ...[
            ListTile(title: Text(heading)),
            RadioGroup<String>(
              groupValue: store.preferences.str(
                key,
                key == 'allowTags'
                    ? store.preferences.str('allowMentions', 'all')
                    : 'all',
              ),
              onChanged: (value) {
                if (value != null)
                  perform(context, () => store.setPreference(key, value));
              },
              child: Column(
                children: [
                  for (final (index, value) in [
                    'all',
                    'following',
                    'none',
                  ].indexed)
                    RadioListTile<String>(
                      value: value,
                      title: Text(labels[index]),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                ],
              ),
            ),
            if (key == 'allowTags') ...[
              const Divider(),
              SwitchListTile(
                title: const Text('Approva manualmente i tag'),
                value: store.preferences.flag('approveTags'),
                onChanged: (value) => perform(
                  context,
                  () => store.setPreference('approveTags', value),
                ),
              ),
              ListTile(
                title: const Text('Controlla i tag'),
                trailing: const GIcon(CupertinoIcons.chevron_forward, size: 16),
                subtitle: Text('${pending.length} in attesa'),
                onTap: () => open(context, const PendingPostTagsPage()),
              ),
            ],
            const Divider(),
          ],
        ],
      ),
    );
  }
}

class PendingPostTagsPage extends StatelessWidget {
  const PendingPostTagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final pending = store.posts
        .where((post) => post.ids('pendingTagUsers').contains(store.myId))
        .toList();
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: pageTitle('Tag in attesa')),
      body: pending.isEmpty
          ? const EmptyState(CupertinoIcons.tag, 'Nessun tag in attesa', '')
          : ListView(
              children: [
                for (final post in pending)
                  PersonTile(
                    post.str('author'),
                    subtitle: 'Tocca per controllare il tag',
                    onTap: () => open(
                      context,
                      PostPage(id: post.str('id'), taggedUser: store.myId),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> managePostTag(BuildContext context, J post) async {
  final store = GpixScope.of(context, listen: false);
  final hidden = post.ids('hiddenTagUsers').contains(store.myId);
  final pending = post.ids('pendingTagUsers').contains(store.myId);
  final decision = await sheet<String>(
    context,
    Builder(
      builder: (menu) => Column(
        children: [
          ActionRow(
            hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            pending
                ? 'Approva sul mio profilo'
                : hidden
                ? 'Mostra sul mio profilo'
                : 'Nascondi dal mio profilo',
            () => Navigator.pop(menu, hidden || pending ? 'show' : 'hide'),
          ),
          ActionRow(
            CupertinoIcons.tag,
            'Rimuovi il mio tag dal post',
            () => Navigator.pop(menu, 'remove'),
            destructive: true,
          ),
        ],
      ),
    ),
  );
  if (decision == null || !context.mounted) return;
  if (decision == 'remove' &&
      !await gpixAlert(
        context,
        'Rimuovere il tuo tag?',
        'Il tag sarà rimosso da tutto il post.',
        confirm: 'Rimuovi',
        cancel: true,
        destructive: true,
      ))
    return;
  if (!context.mounted) return;
  await perform(context, () async {
    await store.act('managePostTag', {
      'id': post.str('id'),
      'decision': decision,
    });
    if (context.mounted)
      notice(context, switch (decision) {
        'hide' => 'Post nascosto dal profilo',
        'show' => 'Post visibile sul profilo',
        _ => 'Tag rimosso',
      });
  });
}

class PostPage extends StatelessWidget {
  const PostPage({
    super.key,
    required this.id,
    this.postIds = const [],
    this.taggedUser,
  });
  final String? taggedUser;
  final String id;
  final List<String> postIds;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final post = store.post(id);
    final author = post.str('author');
    final kind = post.str('kind');
    if (kind == 'story') return StoryViewer(user: author, ids: [id]);
    if (kind == 'reel') return Reels(initial: id);
    final selection = postIds.indexOf(id);
    final posts = {for (final item in store.allPosts) item.str('id'): item};
    bool visible(String id) {
      final item = posts[id];
      return item != null &&
          item.str('kind') == 'post' &&
          !item.flag('archived') &&
          !store.blocked(item.str('author'));
    }

    final before = selection < 0
        ? <String>[]
        : postIds.take(selection).where(visible).toList().reversed.toList();
    final after = [
      if (post.isNotEmpty && (!post.flag('archived') || postIds.isEmpty)) id,
      if (selection >= 0) ...postIds.skip(selection + 1).where(visible),
    ];
    const anchor = ValueKey('post-view-anchor');

    Widget list(List<String> ids, {Key? key}) => SliverList.builder(
      key: key,
      itemCount: ids.length,
      findChildIndexCallback: (key) {
        final index = ids.indexOf((key as ValueKey<String>).value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) {
        final postId = ids[index];
        return TimelinePost(
          key: ValueKey(postId),
          post: posts[postId]!,
          detail: true,
          taggedUser: taggedUser,
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(7),
          child: IconButton.outlined(
            tooltip: 'Indietro',
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            icon: const GIcon(CupertinoIcons.chevron_back, size: 22),
          ),
        ),
        actions: [
          if (store.supportsPostTagManagement &&
              store.taggedInPost(post, store.myId))
            TextButton(
              onPressed: () => managePostTag(context, post),
              child: const Text('Gestisci'),
            ),
        ],
        title: Column(
          children: [
            pageTitle(taggedUser == null ? 'Post' : 'Tag'),
            if (author.isNotEmpty)
              Text(
                store.user(author).str('username'),
                style: TextStyle(fontSize: 12, color: secondaryText(context)),
              ),
          ],
        ),
      ),
      body: CustomScrollView(
        center: anchor,
        slivers: [
          if (before.isNotEmpty) list(before),
          list(after, key: anchor),
          if (before.isEmpty && after.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                CupertinoIcons.photo,
                'Contenuto non disponibile',
                '',
              ),
            ),
          const SliverToBoxAdapter(
            child: SafeArea(top: false, child: SizedBox(height: 12)),
          ),
        ],
      ),
    );
  }
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

  Future<void> save(GpixStore store) => perform(context, () async {
    if (fields['name']!.text.trim().isEmpty ||
        fields['username']!.text.trim().isEmpty) {
      throw Exception('Nome e nome utente sono obbligatori.');
    }
    final site = fields['website']!.text.trim();
    if (site.isNotEmpty && !site.startsWith('https://')) {
      throw Exception('Il sito deve iniziare con https://');
    }
    setState(() => busy = true);
    try {
      await store.act('profile', {
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
        'avatar': avatar,
        'private': store.me.flag('private'),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  });

  Future<void> changePhoto(GpixStore store) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await sheet<_ProfileImageAction>(
      context,
      _ProfileImageSheet(user: store.myId, photo: previewPhoto(store)),
    );
    if (choice == null || !mounted) return;
    if (choice == _ProfileImageAction.removePhoto) {
      setState(() => avatar = '');
      return;
    }
    await changeImage(store, () async {
      final file = await ImagePicker().pickImage(
        source: choice == _ProfileImageAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (!mounted || file == null) return null;
      final type = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      return store.upload(file.path, 'image/$type');
    });
  }

  Future<void> changeImage(
    GpixStore store,
    Future<String?> Function() upload,
  ) async {
    final account = store.myId;
    setState(() => busy = true);
    try {
      await perform(context, () async {
        final ref = await upload();
        if (mounted && store.myId == account && ref != null) {
          setState(() => avatar = ref);
        }
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editWebsite() async {
    final website = fields['website']!;
    final value = await textDialog(
      context,
      'Link del profilo',
      website.text,
      hint: 'https://',
    );
    if (value != null && mounted) setState(() => website.text = value);
  }

  String previewPhoto(GpixStore store) => avatar.isEmpty
      ? ''
      : avatar == store.me.str('avatarId')
      ? store.me.str('avatar')
      : avatar;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final links = s.me.rows('links');
    return Scaffold(
      appBar: AppBar(
        leading: const _ProfileScreenBack(),
        centerTitle: true,
        title: const Text(
          'Modifica profilo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => save(s),
            child: Text(busy ? 'Attendi…' : 'Salva'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const SizedBox(height: 17),
          Center(
            child: InkWell(
              onTap: busy ? null : () => changePhoto(s),
              customBorder: const CircleBorder(),
              child: Avatar(s.myId, size: 80, image: previewPhoto(s)),
            ),
          ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(c).brightness == Brightness.light
                    ? const Color(0xff4656f6)
                    : accent(c),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: busy ? null : () => changePhoto(s),
              child: const Text('Modifica immagine del profilo'),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),
          for (final field in const [
            (key: 'name', label: 'Nome', max: 60),
            (key: 'username', label: 'Nome utente', max: 30),
            (key: 'pronouns', label: 'Pronomi', max: 40),
            (key: 'bio', label: 'Biografia', max: 150),
          ])
            _ProfileEditRow(
              label: field.label,
              child: Semantics(
                label: field.label,
                child: TextField(
                  key: ValueKey('edit-profile-${field.key}'),
                  controller: fields[field.key],
                  enabled: !busy,
                  maxLength: field.max,
                  minLines: field.key == 'bio' ? 2 : 1,
                  maxLines: field.key == 'bio' ? 5 : 1,
                  textInputAction: field.key == 'bio'
                      ? TextInputAction.newline
                      : TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: field.label,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),
          InkWell(
            onTap: busy ? null : editWebsite,
            child: _ProfileEditRow(
              label: 'Link',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        fields['website']!.text.isEmpty
                            ? 'Aggiungi link'
                            : fields['website']!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: secondaryText(c)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const GIcon(CupertinoIcons.chevron_right, size: 15),
                  ],
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('Banner'),
            subtitle: const Text(
              'Aggiungi profili social e altri collegamenti.',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (links.isNotEmpty) Text('${links.length}'),
                const SizedBox(width: 8),
                const GIcon(CupertinoIcons.chevron_right, size: 15),
              ],
            ),
            onTap: busy ? null : () => open(c, const ProfileLinks()),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Riordina griglia'),
            trailing: const GIcon(CupertinoIcons.chevron_right, size: 15),
            onTap: busy ? null : () => open(c, const GridOrder()),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: busy
                ? null
                : () async {
                    final selected = await sheet<String>(
                      c,
                      Builder(
                        builder: (menu) => Column(
                          mainAxisSize: MainAxisSize.min,
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
                                onTap: () => Navigator.pop(menu, gender),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (selected != null && mounted) {
                      setState(() => fields['gender']!.text = selected);
                    }
                  },
            child: _ProfileEditRow(
              label: 'Genere',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        fields['gender']!.text.isEmpty
                            ? 'Non specificato'
                            : fields['gender']!.text,
                      ),
                    ),
                    const GIcon(CupertinoIcons.chevron_right, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
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

enum _ProfileImageAction { gallery, camera, removePhoto }

class _ProfileImageSheet extends StatelessWidget {
  const _ProfileImageSheet({required this.user, required this.photo});

  final String user, photo;

  @override
  Widget build(BuildContext context) {
    void choose(_ProfileImageAction action) => Navigator.pop(context, action);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: Avatar(user, size: 54, image: photo)),
        const SizedBox(height: 9),
        const Center(
          child: Text(
            'Immagine del profilo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 9),
        ActionRow(
          CupertinoIcons.photo,
          'Scegli dalla libreria',
          () => choose(_ProfileImageAction.gallery),
        ),
        ActionRow(
          CupertinoIcons.camera,
          'Scatta foto',
          () => choose(_ProfileImageAction.camera),
        ),
        if (photo.isNotEmpty)
          ActionRow(
            CupertinoIcons.trash,
            'Rimuovi immagine attuale',
            () => choose(_ProfileImageAction.removePhoto),
            destructive: true,
          ),
      ],
    );
  }
}

class _ProfileEditRow extends StatelessWidget {
  const _ProfileEditRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(flex: 3, child: Text(label)),
            const SizedBox(width: 12),
            Expanded(flex: 7, child: child),
          ],
        ),
      ),
      const Divider(height: 1),
    ],
  );
}

class _ProfileScreenBack extends StatelessWidget {
  const _ProfileScreenBack();

  @override
  Widget build(BuildContext context) => Center(
    child: IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.maybePop(context),
      style: IconButton.styleFrom(
        backgroundColor: subdued(context),
        foregroundColor: foreground(context),
      ),
      icon: const GIcon(CupertinoIcons.chevron_back, size: 23),
    ),
  );
}

class CollectionPage extends StatelessWidget {
  final String kind;
  const CollectionPage({super.key, required this.kind});
  @override
  Widget build(BuildContext c) {
    if (kind == 'saved') return const _SavedLibrary();
    final s = GpixScope.of(c);
    final posts = s.allPosts
        .where(
          (p) =>
              p.str('author') == s.myId &&
              (p.flag('archived') || p.str('kind') == 'story'),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: pageTitle('Archivio')),
      body: posts.isEmpty
          ? const EmptyState(
              CupertinoIcons.archivebox,
              'Il tuo archivio',
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

Future<void> toggleSavedPost(BuildContext context, String id) async {
  final store = GpixScope.of(context, listen: false);
  final post = store.post(id);
  if (post.isEmpty) return;
  final enabled = !post.flag('saved');
  await perform(context, () async {
    await store.act('save', {'id': id, 'enabled': enabled});
    if (!enabled || !context.mounted) return;
    final choice = await sheet<String>(
      context,
      Builder(
        builder: (menu) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const GIcon(CupertinoIcons.bookmark_fill, size: 23),
              title: const Text('Salvato'),
              trailing: TextButton(
                onPressed: () => Navigator.pop(menu, 'all'),
                child: const Text('Visualizza tutto'),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                child: Text(
                  'Organizza i post che salvi',
                  style: Theme.of(menu).textTheme.titleMedium,
                ),
              ),
            ),
            for (final collection in store.savedCollections)
              ListTile(
                leading: const GIcon(CupertinoIcons.folder),
                title: Text(collection.str('name')),
                onTap: () => Navigator.pop(menu, collection.str('id')),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.pop(menu, 'create'),
                child: const Text('Crea una raccolta'),
              ),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'all') {
      await open(context, const CollectionPage(kind: 'saved'));
    } else if (choice == 'create') {
      await editSavedCollection(context, store, initial: [id]);
    } else {
      final album = store.savedCollections
          .where((item) => item.str('id') == choice)
          .firstOrNull;
      if (album == null) return;
      await store.saveCollection(choice, album.str('name'), [
        ...album.ids('posts'),
        id,
      ]);
      if (context.mounted) notice(context, 'Aggiunto alla raccolta');
    }
  });
}

Future<void> editSavedCollection(
  BuildContext context,
  GpixStore store, {
  List<String> initial = const [],
  J? album,
}) async {
  final name = await textDialog(
    context,
    album == null ? 'Nuova raccolta' : 'Rinomina raccolta',
    album?.str('name') ?? '',
  );
  final title = name?.trim() ?? '';
  if (title.isEmpty || !context.mounted) return;
  await perform(
    context,
    () => store.saveCollection(
      album?.str('id') ?? newId(),
      title.characters.take(70).toString(),
      album?.ids('posts') ?? initial,
    ),
  );
}

class _SavedLibrary extends StatefulWidget {
  const _SavedLibrary({this.collectionId});

  final String? collectionId;

  @override
  State<_SavedLibrary> createState() => _SavedLibraryState();
}

class _SavedLibraryState extends State<_SavedLibrary> {
  static const labels = ['Tutti', 'Raccolte', 'Reel', 'Post'];
  final search = TextEditingController();
  final selected = <String>{};
  int tab = 0;
  bool searching = false, managing = false, busy = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void stopManaging() => setState(() {
    managing = false;
    selected.clear();
  });

  Future<void> addToCollection(GpixStore store) async {
    final choice = await sheet<String>(
      context,
      Builder(
        builder: (menu) => Column(
          children: [
            const ListTile(title: Text('Aggiungi alla raccolta')),
            for (final album in store.savedCollections)
              ListTile(
                leading: const GIcon(CupertinoIcons.folder),
                title: Text(album.str('name')),
                onTap: () => Navigator.pop(menu, album.str('id')),
              ),
            ListTile(
              leading: const GIcon(CupertinoIcons.plus),
              title: const Text('Nuova raccolta'),
              onTap: () => Navigator.pop(menu, 'create'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'create') {
      await editSavedCollection(context, store, initial: selected.toList());
    } else {
      final album = store.savedCollections
          .where((item) => item.str('id') == choice)
          .firstOrNull;
      if (album != null)
        await perform(
          context,
          () => store.saveCollection(choice, album.str('name'), [
            ...album.ids('posts'),
            ...selected,
          ]),
        );
    }
    if (mounted) stopManaging();
  }

  Future<void> removeSelected(GpixStore store, J? album) async {
    if (busy || selected.isEmpty) return;
    setState(() => busy = true);
    await perform(context, () async {
      if (album != null) {
        await store.saveCollection(
          album.str('id'),
          album.str('name'),
          album.ids('posts').where((id) => !selected.contains(id)),
        );
      } else {
        for (final id in selected.toList()) {
          await store.act('save', {'id': id, 'enabled': false});
        }
      }
      if (mounted) stopManaging();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final saved = store.allPosts.where((item) => item.flag('saved'));
    final query = search.text.trim().toLowerCase();
    final album = store.savedCollections
        .where((item) => item.str('id') == widget.collectionId)
        .firstOrNull;
    final albums = store.savedCollections
        .where((item) => item.str('name').toLowerCase().contains(query))
        .toList();
    final contents = saved.where((item) {
      if (album != null && !album.ids('posts').contains(item.str('id')))
        return false;
      final reel = item.str('kind') == 'reel';
      if (album == null && ((tab == 2 && !reel) || (tab == 3 && reel)))
        return false;
      final author = store.user(item.str('author'));
      return '${item.str('text')} ${author.str('username')} ${author.str('name')}'
          .toLowerCase()
          .contains(query);
    }).toList();
    final visibleIds = contents.map((item) => item.str('id')).toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(selected.contains);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        centerTitle: true,
        title: searching
            ? DirectSearchField(
                controller: search,
                autofocus: true,
                hint: 'Cerca nei salvati',
                onChanged: (_) => setState(() {}),
              )
            : Text(
                managing
                    ? 'Seleziona contenuti'
                    : album?.str('name') ?? 'Salvato',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
        leading: IconButton(
          tooltip: managing || searching ? 'Annulla' : 'Indietro',
          icon: GIcon(
            managing || searching
                ? CupertinoIcons.xmark
                : CupertinoIcons.chevron_left,
          ),
          onPressed: () {
            if (busy) return;
            if (managing) {
              stopManaging();
            } else if (searching) {
              setState(() {
                searching = false;
                search.clear();
              });
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
        actions: [
          if (managing)
            TextButton(
              onPressed: busy || visibleIds.isEmpty
                  ? null
                  : () => setState(() {
                      if (allSelected) {
                        selected.removeAll(visibleIds);
                      } else {
                        selected.addAll(visibleIds);
                      }
                    }),
              child: Text(allSelected ? 'Deseleziona' : 'Seleziona tutti'),
            )
          else if (!searching) ...[
            IconButton(
              tooltip: 'Cerca nei salvati',
              icon: const GIcon(CupertinoIcons.search),
              onPressed: () => setState(() => searching = true),
            ),
            IconButton(
              tooltip: album == null ? 'Nuova raccolta' : 'Opzioni raccolta',
              icon: GIcon(
                album == null ? CupertinoIcons.plus : CupertinoIcons.ellipsis,
              ),
              onPressed: album == null
                  ? () => editSavedCollection(context, store)
                  : () => collectionOptions(store, album),
            ),
          ],
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (album == null && !managing)
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  children: [
                    for (final (index, label) in labels.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: tab == index,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => tab = index),
                          shape: const StadiumBorder(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (album == null && !managing && (tab == 0 || tab == 1))
            SliverToBoxAdapter(
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'Raccolte',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: tab == 0
                        ? TextButton(
                            onPressed: () => setState(() => tab = 1),
                            child: const Text('Mostra tutte'),
                          )
                        : null,
                  ),
                  if (albums.isEmpty)
                    ListTile(
                      leading: const GIcon(
                        CupertinoIcons.folder_badge_plus,
                        size: 24,
                      ),
                      title: const Text('Crea una raccolta'),
                      onTap: () => editSavedCollection(context, store),
                    ),
                  for (final item in (tab == 0 ? albums.take(3) : albums))
                    ListTile(
                      leading: SizedBox.square(
                        dimension: 54,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _SavedThumbnail(
                            post:
                                saved
                                    .where(
                                      (post) => item
                                          .ids('posts')
                                          .contains(post.str('id')),
                                    )
                                    .firstOrNull ??
                                {},
                          ),
                        ),
                      ),
                      title: Text(
                        item.str('name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('🔒 Privata'),
                      onTap: () => open(
                        context,
                        _SavedLibrary(collectionId: item.str('id')),
                      ),
                    ),
                ],
              ),
            ),
          if (tab != 1 || album != null || managing) ...[
            SliverToBoxAdapter(
              child: ListTile(
                title: Text(
                  album != null
                      ? 'Contenuti'
                      : tab == 2
                      ? 'Reel'
                      : tab == 3
                      ? 'Post'
                      : 'Reel e post',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: !managing && contents.isNotEmpty
                    ? TextButton(
                        onPressed: () => setState(() => managing = true),
                        child: const Text('Gestisci'),
                      )
                    : null,
              ),
            ),
            if (contents.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyState(
                  CupertinoIcons.bookmark,
                  'Nessun contenuto',
                  'I contenuti salvati appariranno qui.',
                ),
              ),
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                childAspectRatio: .75,
              ),
              itemCount: contents.length,
              itemBuilder: (c, index) {
                final post = contents[index], id = contents[index].str('id');
                return Semantics(
                  selected: managing ? selected.contains(id) : null,
                  button: true,
                  label: post.str('text', 'Contenuto salvato'),
                  child: InkWell(
                    onTap: busy
                        ? null
                        : managing
                        ? () => setState(() {
                            if (!selected.add(id)) selected.remove(id);
                          })
                        : () => open(
                            context,
                            PostPage(
                              id: id,
                              postIds: contents
                                  .map((post) => post.str('id'))
                                  .toList(),
                            ),
                          ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _SavedThumbnail(post: post),
                        if (managing ||
                            store.isVideoPost(post) ||
                            store.media(post).length > 1)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GIcon(
                              managing
                                  ? selected.contains(id)
                                        ? CupertinoIcons
                                              .check_mark_circled_solid
                                        : CupertinoIcons.circle
                                  : store.isVideoPost(post)
                                  ? CupertinoIcons.play_rectangle_fill
                                  : CupertinoIcons.square_stack_fill,
                              size: 19,
                              color: managing && selected.contains(id)
                                  ? const Color(0xff78a7ff)
                                  : Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: !managing
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: busy || selected.isEmpty
                            ? null
                            : () => removeSelected(store, album),
                        child: Text(
                          album == null
                              ? 'Rimuovi dai salvati'
                              : 'Rimuovi dalla raccolta',
                        ),
                      ),
                    ),
                    if (album == null)
                      Expanded(
                        child: FilledButton(
                          onPressed: busy || selected.isEmpty
                              ? null
                              : () => addToCollection(store),
                          child: const Text('Aggiungi alla raccolta'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> collectionOptions(GpixStore store, J album) async {
    final choice = await sheet<String>(
      context,
      Builder(
        builder: (menu) => Column(
          children: [
            ListTile(
              title: const Text('Rinomina raccolta'),
              onTap: () => Navigator.pop(menu, 'rename'),
            ),
            ListTile(
              title: const Text('Elimina raccolta'),
              onTap: () => Navigator.pop(menu, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'rename') {
      await editSavedCollection(context, store, album: album);
    } else if (choice == 'delete' &&
        await gpixAlert(
          context,
          'Eliminare la raccolta?',
          'I contenuti resteranno nei salvati.',
          destructive: true,
          cancel: true,
          confirm: 'Elimina',
        )) {
      if (!mounted) return;
      await perform(context, () async {
        await store.deleteCollection(album.str('id'));
        if (mounted) Navigator.pop(context);
      });
    }
  }
}

class _SavedThumbnail extends StatelessWidget {
  const _SavedThumbnail({required this.post});

  final J post;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final cover = store.isVideoPost(post)
        ? store.reelCover(post)
        : store.media(post).firstOrNull ?? '';
    final fallback = ColoredBox(
      color: subdued(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: post.str('text').isEmpty
              ? const GIcon(CupertinoIcons.bookmark, size: 24)
              : Text(
                  post.str('text'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
    return cover.isEmpty
        ? fallback
        : MediaView(
            cover,
            fit: BoxFit.cover,
            thumbnail: true,
            fallback: fallback,
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
    'In primo piano',
    'Oggi',
    'Ieri',
    'Ultimi 7 giorni',
    'Precedenti',
  ];

  final initiallyUnread = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = GpixScope.of(context, listen: false);
      initiallyUnread.addAll(
        store.socialNotifications
            .where((item) => !item.flag('seen'))
            .map((item) => item.str('id')),
      );
      if (store.hasActivity)
        perform(context, () => store.act('notificationsRead'));
    });
  }

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
        for (final (index, filter) in filters.indexed)
          dropdownRow(
            anchor,
            'filter-$index',
            filter,
            CupertinoIcons.line_horizontal_3_decrease,
            selected: index == selected,
          ),
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
    if (result != null && result.startsWith('filter-')) {
      selectFilter(int.parse(result.substring(7)));
      return;
    }
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
      'postTag' => 'ti ha taggato in un post.',
      'collaborationInvite' => 'ti ha invitato a collaborare a un post.',
      'collaborationAccepted' => 'ha accettato il tuo invito a collaborare.',
      'followAccepted' => 'ha accettato la tua richiesta.',
      'repost' => 'ha ripubblicato il tuo post.',
      'noteLike' => 'ha messo Mi piace alla tua nota.',
      _ => 'ha interagito con te.',
    };
  }

  Future<void> openNotification(GpixStore store, List<J> group) async {
    final notification = group.first;
    await perform(context, () async {
      for (final entry in group.where((item) => !item.flag('seen'))) {
        await store.act('notificationsRead', {'id': entry['id']});
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
        open(
          context,
          PostPage(
            id: post.str('id'),
            taggedUser: type == 'postTag' ? store.myId : null,
          ),
        );
      } else if (const [
        'collaborationInvite',
        'collaborationAccepted',
      ].contains(type)) {
        notice(context, 'Questo post non è più disponibile');
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
      final index =
          item.flag('highlighted') ||
              type == 'system' ||
              (type == 'storyLike' &&
                  (!item.flag('seen') ||
                      initiallyUnread.contains(item.str('id'))) &&
                  time >= today)
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

  List<List<J>> _groupLikes(List<J> section) {
    final rows = <List<J>>[];
    final likes = <(String, String), List<J>>{};
    for (final notification in section) {
      final type = notification.str('type');
      final ref = notification.str('ref');
      if (ref.isNotEmpty && (type == 'like' || type == 'storyLike')) {
        likes
            .putIfAbsent((type, ref), () {
              final row = <J>[];
              rows.add(row);
              return row;
            })
            .add(notification);
      } else {
        rows.add([notification]);
      }
    }
    return rows;
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
    child: Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final requests = store.state
        .ids('requests')
        .where((id) => !store.blocked(id))
        .toSet();
    final notifications = store.socialNotifications;
    final sections = _sections(notifications).map(_groupLikes).toList();
    final username = store.me.str('username').toLowerCase();
    final mentions = [
      for (final post in store.allPosts)
        if (username.isNotEmpty &&
            post.str('kind') == 'story' &&
            post.str('author') != store.myId &&
            !store.blocked(post.str('author')) &&
            !post.flag('archived') &&
            post.number('expires') > now &&
            !store.preferences
                .ids('hiddenStories')
                .contains(post.str('author')) &&
            post
                .obj('style')
                .rows('stickers')
                .any(
                  (sticker) =>
                      sticker.str('type') == 'mention' &&
                      sticker
                              .str('label')
                              .toLowerCase()
                              .replaceFirst('@', '') ==
                          username,
                ))
          post,
    ]..sort((a, b) => b.number('created').compareTo(a.number('created')));
    return AccountSheetBackdrop(
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 5,
          toolbarHeight: 60,
          leadingWidth: 70,
          backgroundColor: surface(context),
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(15, 8, 8, 8),
            child: IconButton.outlined(
              tooltip: 'Indietro',
              onPressed: () => Navigator.maybePop(context),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                side: BorderSide(color: Theme.of(context).dividerColor),
                shape: const CircleBorder(),
              ),
              icon: const GIcon(CupertinoIcons.chevron_left, size: 23),
            ),
          ),
          title: Tooltip(
            message: 'Cambia account',
            child: InkWell(
              onTap: () => inboxAccounts(context, store),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      store.me.str('username', 'Attività'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground(context),
                        fontSize: 23,
                        letterSpacing: -.65,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const GIcon(CupertinoIcons.chevron_down, size: 11),
                  if (store.hasActivity) ...[
                    const SizedBox(width: 6),
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(0xffff0035),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            Builder(
              builder: (anchor) => IconButton(
                tooltip: 'Opzioni attività',
                icon: const GIcon(CupertinoIcons.ellipsis, size: 20),
                onPressed: () => showOptions(anchor, store),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => store.sync(silent: true),
          child: CustomScrollView(
            controller: scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (selected == 0 || selected == 3)
                SliverToBoxAdapter(
                  child: _requestSummary(context, store, requests),
                ),
              if (selected == 0 && !unreadOnly && mentions.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      _sectionTitle('Storie su di te'),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Avatar(
                          mentions.first.str('author'),
                          size: 47,
                          ring: true,
                        ),
                        title: const Text(
                          'Menzioni',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          mentions.length == 1
                              ? 'Ti hanno menzionato in 1 storia.'
                              : 'Ti hanno menzionato in ${mentions.length} storie.',
                        ),
                        onTap: () => _openMentions(mentions),
                      ),
                    ],
                  ),
                ),
              if (selected != 0 || unreadOnly)
                SliverToBoxAdapter(
                  child: ListTile(
                    title: Text(unreadOnly ? 'Da leggere' : filters[selected]),
                    trailing: IconButton(
                      tooltip: 'Ripristina tutte le attività',
                      icon: const GIcon(CupertinoIcons.xmark),
                      onPressed: () => setState(() {
                        selected = 0;
                        unreadOnly = false;
                      }),
                    ),
                  ),
                ),
              if (sections.every((section) => section.isEmpty) &&
                  (mentions.isEmpty || selected != 0 || unreadOnly))
                SliverToBoxAdapter(
                  child: EmptyState(
                    CupertinoIcons.heart,
                    unreadOnly ? 'Tutto letto' : 'Nessuna nuova attività',
                    unreadOnly
                        ? 'Le nuove attività appariranno qui.'
                        : 'Qui trovi Mi piace, commenti e nuovi follower.',
                  ),
                ),
              for (final (index, section) in sections.indexed)
                if (section.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionTitle(headings[index])),
                  SliverList.builder(
                    itemCount: section.length,
                    itemBuilder: (context, index) => _notificationRow(
                      context,
                      store,
                      section[index],
                      requests,
                    ),
                  ),
                ],
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMentions(List<J> stories) {
    if (stories.length == 1) {
      final post = stories.single;
      open(
        context,
        StoryViewer(user: post.str('author'), ids: [post.str('id')]),
      );
      return;
    }
    open(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Menzioni')),
        body: ListView.builder(
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final post = stories[index];
            final actor = post.str('author');
            final store = GpixScope.of(context);
            return ListTile(
              leading: Avatar(actor, size: 44),
              title: Text(store.user(actor).str('username')),
              onTap: () => open(
                context,
                StoryViewer(user: actor, ids: [post.str('id')]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _requestSummary(
    BuildContext context,
    GpixStore store,
    Set<String> requests,
  ) {
    final multiple = requests.length > 1;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      horizontalTitleGap: 12,
      leading: requests.isEmpty
          ? CircleAvatar(
              radius: 27,
              backgroundColor: subdued(context),
              child: const GIcon(CupertinoIcons.person_add, size: 22),
            )
          : _avatars(context, requests.take(2).toList()),
      title: const Text(
        'Richieste di seguirti',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        requests.isEmpty
            ? 'Nessuna richiesta in attesa'
            : '${store.user(requests.first).str('username')}${multiple ? ' + altri ${requests.length - 1}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (requests.isNotEmpty) ...[
            CircleAvatar(radius: 4, backgroundColor: accent(context)),
            const SizedBox(width: 10),
          ],
          const GIcon(CupertinoIcons.chevron_right, size: 18),
        ],
      ),
      onTap: () => open(context, const Requests()),
    );
  }

  Widget _avatars(
    BuildContext context,
    List<String> actors, {
    bool like = false,
  }) => SizedBox.square(
    dimension: 56,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (actors.isEmpty)
          const Center(child: GIcon(CupertinoIcons.bell, size: 23))
        else if (actors.length == 1)
          Center(child: Avatar(actors.first, size: 50))
        else ...[
          Positioned(top: 0, left: 0, child: Avatar(actors[1], size: 37)),
          Positioned(
            bottom: 0,
            right: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface(context),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: Avatar(actors.first, size: 39),
              ),
            ),
          ),
        ],
        if (like)
          Positioned(
            bottom: -1,
            right: -1,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xffff0035),
                shape: BoxShape.circle,
                border: Border.all(color: surface(context), width: 1.5),
              ),
              child: const GIcon(
                CupertinoIcons.heart_fill,
                color: Colors.white,
                size: 11,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _notificationRow(
    BuildContext context,
    GpixStore store,
    List<J> group,
    Set<String> requests,
  ) {
    final item = group.first;
    final actors = group
        .map((entry) => entry.str('actor'))
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final actor = item.str('actor');
    final post = store.post(item.str('ref'));
    final type = item.str('type');
    final pending = type == 'followRequest' && requests.contains(actor);
    final like = const ['like', 'storyLike', 'noteLike'].contains(type);
    final thumbnail = post.str('kind') == 'reel'
        ? store.reelCover(post)
        : store.media(post).firstOrNull ?? '';
    final time = item.number('created');
    final description = Text.rich(
      TextSpan(
        children: [
          if (actors.isNotEmpty)
            TextSpan(
              text: actors
                  .take(2)
                  .map((id) => store.user(id).str('username'))
                  .join(', '),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (actors.length > 2)
            TextSpan(text: ' e altri ${actors.length - 2}'),
          TextSpan(
            text: actors.length > 1 && like
                ? (type == 'storyLike' || post.str('kind') == 'story'
                      ? ' hanno messo Mi piace alla tua storia.'
                      : ' hanno messo Mi piace al tuo post.')
                : '${actors.isEmpty ? '' : ' '}${_label(item, post)}',
          ),
          if (time > 0)
            TextSpan(
              text: '  ${relative(time)}',
              style: TextStyle(color: secondaryText(context), fontSize: 11),
            ),
        ],
      ),
      style: TextStyle(fontSize: 13, height: 1.22, color: foreground(context)),
    );
    return InkWell(
      key: ValueKey(item.str('id')),
      onTap: () => openNotification(store, group),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            _avatars(context, actors, like: like),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  description,
                  if (pending) _requestActions(context, store, actor),
                ],
              ),
            ),
            if (thumbnail.isNotEmpty) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MediaView(
                  thumbnail,
                  width: 40,
                  height: 55,
                  thumbnail: true,
                ),
              ),
            ] else if (type == 'follow' && actor.isNotEmpty) ...[
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: subdued(context),
                  foregroundColor: foreground(context),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => perform(context, () async {
                  final thread = await store.openThread(actor);
                  if (context.mounted) open(context, Chat(id: thread));
                }),
                child: const Text('Messaggio'),
              ),
            ],
          ],
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
          (id) =>
              s.state.ids('requests').contains(id) ||
              (!editing && accepted.contains(id)),
        )
        .where(
          (id) => '${s.user(id).str('name')} ${s.user(id).str('username')}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
        )
        .toList();
    selected.removeWhere((id) => !s.state.ids('requests').contains(id));
    final allSelected =
        requests.isNotEmpty && requests.every(selected.contains);
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
            tooltip: editing ? 'Annulla selezione' : 'Indietro',
            onPressed: busy
                ? null
                : editing
                ? () => setState(() {
                    editing = false;
                    selected.clear();
                  })
                : () => Navigator.maybePop(c),
            icon: GIcon(
              editing ? CupertinoIcons.xmark : CupertinoIcons.chevron_left,
              size: 23,
            ),
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
                  : editing && requests.isEmpty
                  ? null
                  : () => setState(() {
                      if (!editing) {
                        editing = true;
                        selected.clear();
                      } else if (allSelected) {
                        selected.removeAll(requests);
                      } else {
                        selected.addAll(requests);
                      }
                    }),
              child: Text(
                editing
                    ? (allSelected ? 'Deseleziona tutti' : 'Seleziona tutti')
                    : 'Gestisci',
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
          if (!editing)
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
                              (a, b) => a
                                  .str('username')
                                  .compareTo(b.str('username')),
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
                            'Elimina (${selected.length})',
                            false,
                            busy || selected.isEmpty
                                ? null
                                : () => decide(selected.toList(), false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: button(
                            busy ? 'Attendi…' : 'Conferma (${selected.length})',
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
      bool emphasized = false,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minLeadingWidth: 22,
      horizontalTitleGap: 12,
      minTileHeight: 48,
      leading: GIcon(icon, size: 25, color: foreground(c)),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
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
            'Tag e menzioni',
            row(
              CupertinoIcons.at,
              'Tag e menzioni',
              () => open(c, const TagPrivacyPage()),
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
            'Bozze',
            row(
              CupertinoIcons.doc_text,
              'Bozze',
              () => open(c, const DraftList()),
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
                    'Apri Profilo → Modifica profilo e premi Salva per applicare le modifiche.',
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
    final activity = row(
      CupertinoIcons.clock,
      'La tua attività',
      () => open(c, const Activity()),
    );
    final events = row(
      CupertinoIcons.calendar,
      'Eventi e momenti',
      () =>
          open(c, const Scaffold(body: SafeArea(child: CommunityDirectory()))),
    );
    List<Widget> entries(String name, {Set<String> excluding = const {}}) => [
      for (final entry in groups.firstWhere((group) => group.$1 == name).$4)
        if (!excluding.contains(entry.$1)) entry.$2,
    ];
    const visibility = {
      "Privacy dell'account",
      'Amici più stretti',
      'Utenti bloccati',
    };
    final privacyEntries = groups
        .firstWhere((group) => group.$1 == 'Privacy')
        .$4;
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 5),
      child: Text(
        title,
        style: TextStyle(
          color: secondaryText(c),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final sectionDivider = SizedBox(
      height: 4,
      child: ColoredBox(
        color: Theme.of(c).brightness == Brightness.light
            ? const Color(0xfff0f0f2)
            : Theme.of(c).dividerColor,
      ),
    );
    final accountCenter = row(
      CupertinoIcons.person_crop_circle,
      'Centro gestione account',
      () => open(c, const Settings._category('Account')),
      subtitle: 'Profilo, dispositivi, password e sicurezza',
      emphasized: true,
    );
    final filter = query.trim().toLowerCase();
    final results = [
      if ('centro gestione account'.contains(filter)) accountCenter,
      for (final group in groups)
        for (final entry in group.$4)
          if ('${group.$1} ${entry.$1}'.toLowerCase().contains(filter))
            entry.$2,
      if ('la tua attività'.contains(filter)) activity,
      if ('eventi e momenti'.contains(filter)) events,
      if ('gestisci accesso esci elimina account'.contains(filter)) access,
    ];
    return Scaffold(
      appBar: AppBar(
        leading: const _ProfileScreenBack(),
        title: const Text(
          'Impostazioni e attività',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              key: const ValueKey('settings-search'),
              onChanged: (v) => setState(() => query = v),
              decoration: InputDecoration(
                hintText: 'Cerca',
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(13),
                  child: GIcon(CupertinoIcons.search, size: 21, color: muted),
                ),
                filled: true,
                fillColor: Theme.of(c).brightness == Brightness.light
                    ? const Color(0xffeff0f4)
                    : subdued(c),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (filter.isEmpty) ...[
            heading('Il tuo account'),
            accountCenter,
            sectionDivider,
            heading('Come usi GPIX'),
            for (final entry
                in groups
                    .firstWhere((group) => group.$1 == 'I tuoi contenuti')
                    .$4)
              if (entry.$1 == 'Salvati' || entry.$1 == 'Archivio') entry.$2,
            activity,
            ...entries('Notifiche'),
            ...entries(
              'I tuoi contenuti',
              excluding: const {'Salvati', 'Archivio'},
            ),
            events,
            sectionDivider,
            heading('Chi può vedere i tuoi contenuti'),
            for (final entry in privacyEntries)
              if (visibility.contains(entry.$1)) entry.$2,
            sectionDivider,
            heading('Come possono interagire gli altri con te'),
            ...entries('Privacy', excluding: visibility),
            sectionDivider,
            heading('Preferenze'),
            ...entries('Aspetto'),
            sectionDivider,
            heading('Maggiori informazioni e assistenza'),
            ...entries('Assistenza'),
            sectionDivider,
            heading('Accesso'),
            access,
            row(CupertinoIcons.square_arrow_left, 'Esci', () => _logout(c, s)),
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
