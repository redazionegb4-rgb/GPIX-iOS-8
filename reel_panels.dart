import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart' show Profile, SharePanel, openSharedStory;

Future<String?> showReelOptions(BuildContext c, J reel, {required bool own}) =>
    sheet<String>(
      c,
      Builder(
        builder: (menu) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text(
                  'Informazioni su questo reel',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                trailing: const GIcon(CupertinoIcons.chevron_right, size: 15),
                onTap: () => Navigator.pop(menu, 'info'),
              ),
              const SizedBox(height: 5),
              _Group(
                children: [
                  _Row(
                    reel.flag('saved')
                        ? CupertinoIcons.bookmark_fill
                        : CupertinoIcons.bookmark,
                    reel.flag('saved') ? 'Rimuovi dai salvati' : 'Salva',
                    () => Navigator.pop(menu, 'save'),
                  ),
                  _Row(
                    CupertinoIcons.play_circle,
                    'Riproduzione',
                    () => Navigator.pop(menu, 'playback'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Group(
                children: [
                  if (own)
                    _Row(
                      CupertinoIcons.pencil,
                      'Gestisci reel',
                      () => Navigator.pop(menu, 'manage'),
                    )
                  else ...[
                    _Row(
                      CupertinoIcons.info_circle,
                      'Perché vedi questo reel',
                      () => Navigator.pop(menu, 'why'),
                    ),
                    _Row(
                      CupertinoIcons.check_mark_circled,
                      'Mi interessa',
                      () => Navigator.pop(menu, 'prefer'),
                    ),
                    _Row(
                      CupertinoIcons.xmark_circle,
                      'Non mi interessa',
                      () => Navigator.pop(menu, 'hide'),
                    ),
                    _Row(
                      CupertinoIcons.exclamationmark_bubble,
                      'Segnala',
                      () => Navigator.pop(menu, 'report'),
                      destructive: true,
                    ),
                  ],
                  _Row(
                    CupertinoIcons.camera,
                    'Crea reel',
                    () => Navigator.pop(menu, 'create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

Future<bool?> showReelPlayback(
  BuildContext c, {
  required ValueListenable<bool> subtitles,
  required bool auto,
  required bool muted,
  required bool captions,
  required ValueChanged<bool> onAuto,
  required VoidCallback onMute,
  required ValueChanged<bool> onCaptions,
}) => sheet<bool>(
  c,
  StatefulBuilder(
    builder: (menu, update) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 1, 12, 14),
      child: Column(
        children: [
          const Text(
            'Riproduzione',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 13),
          _Group(
            children: [
              _Row(
                CupertinoIcons.fullscreen,
                'Visualizza a schermo intero',
                () => Navigator.pop(menu, true),
              ),
              _Row(
                CupertinoIcons.arrow_clockwise,
                'Scorrimento automatico',
                () => update(() => onAuto(auto = !auto)),
                trailing: Switch.adaptive(
                  value: auto,
                  onChanged: (v) => update(() => onAuto(auto = v)),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: subtitles,
                builder: (_, available, child) => _Row(
                  CupertinoIcons.captions_bubble,
                  'Sottotitoli',
                  available
                      ? () => update(() => onCaptions(captions = !captions))
                      : null,
                  detail: available ? null : 'Traccia non disponibile',
                  trailing: Switch.adaptive(
                    value: available && captions,
                    onChanged: available
                        ? (v) => update(() => onCaptions(captions = v))
                        : null,
                  ),
                ),
              ),
              _Row(
                muted ? CupertinoIcons.speaker_slash : CupertinoIcons.speaker_2,
                muted ? 'Attiva audio' : 'Disattiva audio',
                () => update(() {
                  muted = !muted;
                  onMute();
                }),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

Future<void> showReelInfo(BuildContext c, J reel) {
  final s = GpixScope.of(c, listen: false);
  final uid = reel.str('author');
  return sheet(
    c,
    Builder(
      builder: (menu) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Column(
          children: [
            const Text(
              'Informazioni su questo reel',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            PersonTile(
              uid,
              subtitle: '@${s.user(uid).str('username')}',
              trailing: const GIcon(CupertinoIcons.chevron_right, size: 15),
              onTap: () {
                Navigator.pop(menu);
                open(c, Profile(user: uid));
              },
            ),
            ListTile(
              leading: const GIcon(CupertinoIcons.clock, size: 21),
              title: Text('Pubblicato · ${relative(reel['created'])}'),
            ),
            ListTile(
              leading: const GIcon(CupertinoIcons.person_2, size: 21),
              title: Text(switch (reel.str('audience')) {
                'close' => 'Amici più stretti',
                'followers' => 'Follower',
                _ =>
                  s.user(uid).flag('private')
                      ? 'Follower approvati'
                      : 'Pubblico',
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showReelReason(
  BuildContext c,
  bool following,
  bool priority,
) => sheet(
  c,
  Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Perché vedi questo reel',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 9),
        Text(
          priority
              ? 'Hai dato priorità ai reel di questo autore su questo dispositivo.'
              : following
              ? 'Segui l’autore. I suoi reel visibili compaiono in questa sezione.'
              : 'Questo reel è visibile al tuo account e compare in base alla data di pubblicazione.',
        ),
      ],
    ),
  ),
);

Future<void> showReelAudio(
  BuildContext c,
  J reel,
  bool muted,
  VoidCallback onMute,
) {
  final s = GpixScope.of(c, listen: false);
  final uid = reel.str('author'), track = reel.obj('style').obj('music');
  return sheet(
    c,
    Builder(
      builder: (menu) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: Column(
          children: [
            ListTile(
              leading: Avatar(uid, size: 43),
              title: Text(
                track.str('title', 'Audio originale'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(track.str('artist', s.user(uid).str('username'))),
            ),
            _Group(
              children: [
                _Row(
                  muted
                      ? CupertinoIcons.speaker_slash
                      : CupertinoIcons.speaker_2,
                  muted ? 'Attiva audio' : 'Disattiva audio',
                  () {
                    onMute();
                    Navigator.pop(menu);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext c) => Material(
    color: Theme.of(c).brightness == Brightness.dark
        ? const Color(0xff25262b)
        : const Color(0xffeff0f3),
    borderRadius: BorderRadius.circular(13),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  const _Row(
    this.icon,
    this.label,
    this.onTap, {
    this.trailing,
    this.detail,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? detail;
  final bool destructive;

  @override
  Widget build(BuildContext c) {
    final color = destructive
        ? danger
        : onTap == null
        ? secondaryText(c)
        : foreground(c);
    return ListTile(
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      horizontalTitleGap: 12,
      leading: GIcon(icon, size: 22, color: color),
      title: Text(label, style: TextStyle(fontSize: 14, color: color)),
      subtitle: detail == null
          ? null
          : Text(
              detail!,
              style: TextStyle(fontSize: 11, color: secondaryText(c)),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class ReelSharePanel extends StatelessWidget {
  const ReelSharePanel({super.key, required this.id, required this.onDone});
  final String id;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final reel = store.post(id);
    return SharePanel(
      post: reel,
      onDone: onDone,
      onStory: () {
        onDone();
        openSharedStory(context, id);
      },
    );
  }
}
