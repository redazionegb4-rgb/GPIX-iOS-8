import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import '../rebuild/surfaces.dart' show DirectHome;
import 'social.dart';
import 'features13.dart';
import 'stories.dart';
import 'calls.dart';
import 'emoji_picker.dart';
import 'chat_media.dart';
import 'chat_ui.dart';
import 'chat_translation.dart';
import 'giphy.dart';
import 'inbox_widgets.dart';
import 'photo_send.dart';
import 'auth.dart';

Future<void> inboxAccounts(BuildContext context, GpixStore store) async {
  final navigator = Navigator.of(context);
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  final controller = AnimationController(
    vsync: navigator,
    duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 340),
    reverseDuration: reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 250),
  );
  void updateBackdrop() {
    if (!reducedMotion) {
      accountSheetProgress.value = Curves.easeOutCubic.transform(
        controller.value,
      );
    }
  }

  controller.addListener(updateBackdrop);
  final route = ModalBottomSheetRoute<String>(
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    modalBarrierColor: Colors.black54,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    transitionAnimationController: controller,
    backgroundColor: surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (menu) {
      final accounts = [
        store.me,
        ...store.savedAccounts.where(
          (account) => account.str('id') != store.myId,
        ),
      ];
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(menu).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Theme.of(menu).dividerColor),
                ),
                child: Column(
                  children: [
                    for (final account in accounts) ...[
                      ListTile(
                        minTileHeight: 56,
                        leading: account.str('avatar').isEmpty
                            ? CircleAvatar(
                                child: Text(
                                  account
                                      .str('username')
                                      .characters
                                      .take(1)
                                      .toString()
                                      .toUpperCase(),
                                ),
                              )
                            : Avatar(
                                account.str('id'),
                                image: account.str('avatar'),
                                size: 41,
                              ),
                        title: Text(
                          account.str('username'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: account.str('id') == store.myId
                            ? Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: accent(menu),
                              )
                            : null,
                        onTap: () => Navigator.pop(menu, account.str('id')),
                      ),
                      const Divider(height: 1),
                    ],
                    ListTile(
                      minTileHeight: 56,
                      leading: CircleAvatar(
                        backgroundColor: subdued(menu),
                        foregroundColor: foreground(menu),
                        child: const Icon(CupertinoIcons.plus),
                      ),
                      title: const Text('Aggiungi account'),
                      onTap: () => Navigator.pop(menu, 'add'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(menu, 'settings'),
                child: const Text('Impostazioni dell’account'),
              ),
            ],
          ),
        ),
      );
    },
  );
  final result = await navigator.push(route);
  await route.completed;
  controller.removeListener(updateBackdrop);
  controller.dispose();
  accountSheetProgress.value = 0;
  if (result == null || result == store.myId || !context.mounted) return;
  if (result == 'settings') {
    await open(context, const Settings());
  } else if (result == 'add') {
    await open(context, const Welcome(addingAccount: true));
  } else {
    await perform(context, () => store.useSavedAccount(result));
  }
}

Future<void> inboxThreadOptions(
  BuildContext context,
  GpixStore store,
  J thread,
) async {
  final settings = thread.obj('chatSettings');
  final choice = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chiudi anteprima',
    barrierColor: Colors.black38,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionBuilder: (_, animation, __, child) {
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween(begin: .94, end: 1.0).animate(eased),
          child: child,
        ),
      );
    },
    pageBuilder: (menu, _, __) => SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InboxChatPreview(thread: thread, store: store),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Material(
                      color: surface(menu).withValues(alpha: .93),
                      child: SizedBox(
                        width: 238,
                        child: Column(
                          children: [
                            ActionRow(
                              CupertinoIcons.envelope_badge,
                              store.chatHasUnread(thread)
                                  ? 'Segna come letta'
                                  : 'Segna come non letta',
                              () => Navigator.pop(menu, 'unread'),
                            ),
                            ActionRow(
                              CupertinoIcons.pin,
                              settings.flag('pinned')
                                  ? 'Rimuovi fissaggio'
                                  : 'Fissa',
                              () => Navigator.pop(menu, 'pinned'),
                            ),
                            ActionRow(
                              CupertinoIcons.bell_slash,
                              settings.flag('muted')
                                  ? 'Riattiva notifiche'
                                  : 'Silenzia',
                              () => Navigator.pop(menu, 'muted'),
                            ),
                            ActionRow(
                              CupertinoIcons.trash,
                              'Elimina',
                              () => Navigator.pop(menu, 'clear'),
                              destructive: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final id = thread.str('id');
  if (choice == 'clear') {
    final confirmed = await gpixAlert(
      context,
      'Eliminare la conversazione?',
      'La cronologia verrà rimossa solo dal tuo account.',
      confirm: 'Elimina',
      cancel: true,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
  }
  await perform(context, () async {
    if (choice == 'unread' && store.chatHasUnread(thread)) {
      await store.markRead(id);
    } else {
      await store.act('chatSettings', {
        'id': id,
        'field': choice,
        'enabled': !settings.flag(choice),
      });
    }
  });
}

class _InboxChatPreview extends StatelessWidget {
  const _InboxChatPreview({required this.thread, required this.store});
  final J thread;
  final GpixStore store;

  @override
  Widget build(BuildContext context) {
    final messages = thread
        .rows('messages')
        .where((m) => !m.flag('afterRead') || !store.expired(m))
        .toList();
    final showPreviews = store.preferences['messagePreviews'] != false;
    final colors = ChatColors.fromName(thread.obj('chatStyle').str('theme'));
    final recent = messages.skip(
      (messages.length - 5).clamp(0, messages.length),
    );
    return Material(
      color: surface(context),
      borderRadius: BorderRadius.circular(19),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: 242,
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: thread.str('owner').isEmpty
                  ? Avatar(store.other(thread), size: 29)
                  : groupAvatar(),
              title: Text(
                store.threadName(thread),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                children: [
                  for (final message in recent.toList().reversed)
                    Align(
                      alignment: message.str('author') == store.myId
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 242),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ChatBubble(
                            colors: colors,
                            own: message.str('author') == store.myId,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            child: Text(
                              showPreviews
                                  ? _messagePreview(store, message)
                                  : 'Messaggio',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: message.str('author') == store.myId
                                    ? Colors.white
                                    : foreground(context),
                              ),
                            ),
                          ),
                        ),
                      ),
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

class Inbox extends StatelessWidget {
  const Inbox({super.key});

  @override
  Widget build(BuildContext context) =>
      const AccountSheetBackdrop(child: DirectHome(embedded: false));
}

class MessageRequests extends StatefulWidget {
  const MessageRequests({super.key, this.hidden = false});

  final bool hidden;

  @override
  State<MessageRequests> createState() => _MessageRequestsState();
}

class _MessageRequestsState extends State<MessageRequests> {
  bool editing = false, busy = false;
  final selected = <String>{};

  Future<void> decideRequests(List<String> ids) async {
    if (busy || ids.isEmpty) return;
    final s = GpixScope.of(context, listen: false);
    final account = s.myId;
    setState(() => busy = true);
    await perform(context, () async {
      for (final id in ids) {
        if (!mounted || s.myId != account) return;
        if (widget.hidden) {
          await s.acceptChatRequest(id);
        } else {
          await s.act('messageRequest', {'id': id, 'decision': 'hidden'});
        }
        if (mounted) setState(() => selected.remove(id));
      }
      if (mounted) setState(() => editing = false);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final requests = widget.hidden ? s.hiddenRequests : s.requestedThreads;
    final editingRequests = selected.intersection(
      requests.map((t) => t.str('id')).toSet(),
    );
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.hidden ? 'Richieste nascoste' : 'Richieste di messaggi',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -.25,
          ),
        ),
        actions: [
          if (requests.isNotEmpty || editing)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      editing = !editing;
                      selected.clear();
                    }),
              child: Text(editing ? 'Fine' : 'Modifica'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: s.refreshHome,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (!widget.hidden)
              SliverToBoxAdapter(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    radius: 23,
                    backgroundColor: chatReplyColor(c),
                    foregroundColor: foreground(c),
                    child: const GIcon(CupertinoIcons.eye_slash, size: 22),
                  ),
                  title: const Text(
                    'Richieste nascoste',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.hiddenRequests.isNotEmpty)
                        Text(
                          '${s.hiddenRequests.length}',
                          style: TextStyle(color: secondaryText(c)),
                        ),
                      const SizedBox(width: 8),
                      GIcon(
                        CupertinoIcons.chevron_right,
                        color: secondaryText(c),
                        size: 15,
                      ),
                    ],
                  ),
                  onTap: () => open(c, const MessageRequests(hidden: true)),
                ),
              ),
            if (requests.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    widget.hidden
                        ? CupertinoIcons.eye_slash
                        : CupertinoIcons.paperplane,
                    widget.hidden
                        ? 'Nessuna richiesta nascosta'
                        : 'Nessuna richiesta di messaggi',
                    '',
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: requests.length,
                itemBuilder: (c, index) {
                  final t = requests[index];
                  final id = t.str('id');
                  final peer = s.other(t);
                  final info = inboxSummary(s, t);
                  final canSelect =
                      !widget.hidden || !s.threadContactRestricted(t);
                  void toggle() {
                    if (busy || !canSelect) return;
                    setState(() {
                      if (!selected.add(id)) selected.remove(id);
                    });
                  }

                  return DirectThreadRow(
                    key: ValueKey('message-request-$id'),
                    name: s.threadName(t),
                    portrait: Avatar(peer, size: 53),
                    preview: Text(
                      s.threadContactRestricted(t)
                          ? 'Account con restrizioni'
                          : info.caption,
                    ),
                    time: info.time,
                    unread: s.chatHasUnread(t),
                    trailing: editing
                        ? Checkbox(
                            value: selected.contains(id),
                            onChanged: busy || !canSelect
                                ? null
                                : (_) => toggle(),
                          )
                        : GIcon(
                            CupertinoIcons.chevron_right,
                            size: 15,
                            color: secondaryText(c),
                          ),
                    onTap: editing ? toggle : () => open(c, Chat(id: id)),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: busy || editingRequests.isEmpty
                      ? null
                      : () => decideRequests(editingRequests.toList()),
                  child: Text(
                    widget.hidden
                        ? 'Accetta selezionate (${editingRequests.length})'
                        : 'Nascondi selezionate (${editingRequests.length})',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

Widget groupAvatar() => Container(
  width: 54,
  height: 54,
  decoration: const BoxDecoration(
    shape: BoxShape.circle,
    color: Color(0xffe8f1ff),
  ),
  child: const GIcon(CupertinoIcons.person_2_fill, color: auraBlue, size: 25),
);
({String caption, String time}) inboxSummary(GpixStore s, J t) {
  final messages = t
      .rows('messages')
      .where((m) => !m.flag('afterRead') || !s.expired(m))
      .toList();
  final composing = s.typingPeers(t.str('id'));
  if (composing.isNotEmpty) {
    return (
      caption: composing.any((x) => x.str('kind') == 'recording')
          ? 'Sta registrando un audio…'
          : 'Sta scrivendo…',
      time: '',
    );
  }
  final reactions = s.chatReactions(t);
  final last = messages.lastOrNull;
  final showPreviews = s.preferences['messagePreviews'] != false;
  if (reactions.isNotEmpty &&
      (last == null ||
          reactions.first.number('created') >= last.number('created'))) {
    final n = reactions.first;
    return (
      caption: showPreviews
          ? '${s.user(n.str('actor')).str('name')} ha reagito a un tuo messaggio'
          : 'Nuova reazione',
      time: directTimeAgo(n.number('created'), compact: true),
    );
  }
  if (last == null) return (caption: 'Inizia la conversazione', time: '');
  final time = directTimeAgo(last.number('created'), compact: true);
  final unread = s.unread(t);
  if (unread > 1) return (caption: '$unread nuovi messaggi', time: time);
  if (!showPreviews) {
    return (
      caption: s.chatHasUnread(t) ? 'Nuovo messaggio' : 'Messaggio',
      time: time,
    );
  }
  if (s.expired(last)) return (caption: 'Messaggio scaduto', time: time);
  if (last.flag('viewOnce') ||
      last.flag('afterRead') ||
      last.number('expires') > 0) {
    return (
      caption: last.flag('viewOnce')
          ? 'Foto a visualizzazione limitata'
          : 'Messaggio temporaneo',
      time: time,
    );
  }
  if (last.str('author') == s.myId) {
    return (caption: _messageStatus(s, last), time: '');
  }
  return (caption: preview(last), time: time);
}

String inboxPreview(GpixStore s, J t) {
  final info = inboxSummary(s, t);
  return info.time.isEmpty ? info.caption : '${info.caption} · ${info.time}';
}

bool matchesDirectMessage(GpixStore s, J m, String term) =>
    term.isNotEmpty &&
    m.str('kind') == 'text' &&
    !s.expired(m) &&
    !m.flag('viewOnce') &&
    !m.flag('afterRead') &&
    m.number('expires') == 0 &&
    directSearchTerm(m.str('text')).contains(term);

String _messageStatus(GpixStore s, J m) {
  if (m.ids('openedBy').any((id) => id != s.myId)) return 'Foto aperta';
  if (s.readReceipts && m.ids('readBy').any((id) => id != s.myId)) {
    final times = m
        .obj('readAt')
        .entries
        .where((e) => e.key != s.myId && e.value is num);
    final last = times.fold<num>(0, (latest, item) {
      final timestamp = item.value as num;
      return timestamp > latest ? timestamp : latest;
    });
    final time = directTimeAgo(last);
    return time.isEmpty ? 'Visualizzato' : 'Visualizzato $time';
  }
  final time = directTimeAgo(m.number('created'));
  return time.isEmpty ? 'Inviato' : 'Inviato $time';
}

String preview(J m) =>
    (m.flag('expired') ||
        (m.number('expires') > 0 && m.number('expires') <= now))
    ? 'Messaggio scaduto'
    : switch (m.str('kind')) {
        'image' => 'Foto',
        'gif' => 'GIF',
        'audio' => 'Messaggio vocale',
        'story' =>
          m.str('text').isEmpty
              ? 'Ha risposto alla tua storia'
              : 'Ha risposto alla tua storia: ${m.str('text')}',
        'post' => 'Post condiviso',
        _ => m.str('text'),
      };

Future<void> newConversation(
  BuildContext c, {
  bool startGroup = false,
  String initialMember = '',
}) async {
  final id = await open<String>(
    c,
    NewConversation(startGroup: startGroup, initialMember: initialMember),
  );
  if (id != null && c.mounted) await open(c, Chat(id: id));
}

class NewConversation extends StatefulWidget {
  const NewConversation({
    super.key,
    this.startGroup = false,
    this.initialMember = '',
  });

  final bool startGroup;
  final String initialMember;

  @override
  State<NewConversation> createState() => _NewConversationState();
}

class _NewConversationState extends State<NewConversation> {
  late bool group = widget.startGroup;
  late final Set<String> selected = {
    if (widget.initialMember.isNotEmpty) widget.initialMember,
  };
  final title = TextEditingController();
  final search = TextEditingController();
  String query = '';
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> select(GpixStore s, String id) async {
    if (busy) return;
    if (group) {
      setState(() {
        if (!selected.add(id)) selected.remove(id);
      });
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      final thread = await s.openThread(id);
      if (mounted) Navigator.pop(context, thread);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> createGroup(GpixStore s) async {
    if (busy || selected.length < 2 || title.text.trim().isEmpty) return;
    setState(() => busy = true);
    final name = title.text.trim();
    final existing = s.threads.map((t) => t.str('id')).toSet();
    await perform(context, () async {
      await s.act('group', {'title': name, 'users': selected.toList()});
      final thread = s.threads
          .where(
            (t) =>
                t.str('title') == name &&
                t.str('owner') == s.myId &&
                !existing.contains(t.str('id')),
          )
          .firstOrNull;
      if (thread == null)
        throw Exception('Il gruppo non è ancora disponibile.');
      if (mounted) Navigator.pop(context, thread.str('id'));
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final term = directSearchTerm(query);
    final users =
        s.users
            .where(
              (u) =>
                  u.str('id') != s.myId &&
                  !s.blocked(u.str('id')) &&
                  directSearchTerm(
                    '${u.str('name')} ${u.str('username')}',
                  ).contains(term),
            )
            .toList()
          ..sort((a, b) {
            final following =
                (s.follows(b.str('id')) ? 1 : 0) -
                (s.follows(a.str('id')) ? 1 : 0);
            return following == 0
                ? a
                      .str('name')
                      .toLowerCase()
                      .compareTo(b.str('name').toLowerCase())
                : following;
          });
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          group ? 'Nuovo gruppo' : 'Nuovo messaggio',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (group)
            TextButton(
              onPressed:
                  busy || selected.length < 2 || title.text.trim().isEmpty
                  ? null
                  : () => createGroup(s),
              child: const Text('Crea'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (group)
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 6, 15, 8),
              child: TextField(
                controller: title,
                onChanged: (_) => setState(() {}),
                maxLength: 50,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nome del gruppo',
                  counterText: '',
                ),
              ),
            )
          else
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: chatReplyColor(c),
                foregroundColor: foreground(c),
                child: const GIcon(CupertinoIcons.person_2, size: 22),
              ),
              title: const Text(
                'Crea una chat di gruppo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              trailing: const GIcon(CupertinoIcons.chevron_right, size: 14),
              onTap: busy ? null : () => setState(() => group = true),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: DirectSearchField(
              controller: search,
              hint: 'Cerca persone',
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          if (group && selected.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  for (final id in selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        avatar: Avatar(id, size: 22),
                        label: Text(
                          s.user(id).str('name', s.user(id).str('username')),
                        ),
                        onDeleted: busy
                            ? null
                            : () => setState(() => selected.remove(id)),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: users.isEmpty
                ? const Center(child: Text('Nessun risultato'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: users.length,
                    itemBuilder: (_, index) {
                      final u = users[index];
                      final id = u.str('id');
                      return PersonTile(
                        id,
                        subtitle: '@${u.str('username')}',
                        onTap: () => select(s, id),
                        trailing: group
                            ? Checkbox(
                                value: selected.contains(id),
                                onChanged: busy ? null : (_) => select(s, id),
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class Chat extends StatefulWidget {
  final String id;
  final bool openCamera;
  final String initialMessage;
  const Chat({
    super.key,
    required this.id,
    this.openCamera = false,
    this.initialMessage = '',
  });
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? presenceTimer;
  double lastEdit = 0;
  bool wasTyping = false;
  void signalTyping(bool active, {String kind = 'typing'}) {
    final s = store;
    if (s == null || (active && _pendingRequest)) return;
    wasTyping = active;
    unawaited(s.typingSignal(widget.id, active, kind: kind).catchError((_) {}));
  }

  void edited() {
    lastEdit = now;
    if (!recording) signalTyping(input.text.trim().isNotEmpty);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState value) {
    if (value != AppLifecycleState.resumed) signalTyping(false);
  }

  void focusChanged() {
    if (!focus.hasFocus && !recording) signalTyping(false);
  }

  final input = TextEditingController();
  final scroll = ScrollController(keepScrollOffset: false);
  late String anchorMessage = widget.initialMessage;
  int timelineRevision = 0;
  bool decidingRequest = false;
  bool get _pendingRequest =>
      store!.needsMessageAcceptance(store!.thread(widget.id));

  void _goToMessage(String id) {
    if (!mounted || id.isNotEmpty && store!.message(id).isEmpty) return;
    focus.unfocus();
    setState(() {
      anchorMessage = id;
      timelineRevision++;
    });
  }

  void _scrollToLatest() {
    if (anchorMessage.isNotEmpty) {
      setState(() {
        anchorMessage = '';
        timelineRevision++;
      });
    } else if (scroll.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(0);
      } else {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  final focus = FocusNode();
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  String replyId = '', editId = '';
  String draftBeforeEdit = '';
  bool hasReplied = false;
  final timeOffset = ValueNotifier<double>(0);
  late final AnimationController timeRelease;

  @override
  void initState() {
    super.initState();
    timeRelease =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 195),
        )..addListener(() {
          timeOffset.value = timeRelease.value * ChatSwipeRow.timeWidth;
        });
  }

  void _dragTimes(double value) {
    timeRelease.stop();
    timeOffset.value = value;
  }

  void _releaseTimes() {
    timeRelease.value = timeOffset.value / ChatSwipeRow.timeWidth;
    if (MediaQuery.disableAnimationsOf(context)) {
      timeRelease.value = 0;
    } else {
      timeRelease.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  void _restoreDraft() {
    input.value = TextEditingValue(
      text: draftBeforeEdit,
      selection: TextSelection.collapsed(offset: draftBeforeEdit.length),
    );
    draftBeforeEdit = '';
  }

  void _replyTo(J message) {
    if (sending || store!.expired(message)) return;
    setState(() {
      if (editId.isNotEmpty) _restoreDraft();
      replyId = message.str('id');
      editId = '';
      hasReplied = true;
    });
    focus.requestFocus();
  }

  void _editMessage(J message) {
    if (sending) return;
    setState(() {
      if (editId.isEmpty) draftBeforeEdit = input.text;
      editId = message.str('id');
      replyId = '';
      final text = message.str('text');
      input.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
    focus.requestFocus();
  }

  int expiresIn = 0;
  bool recording = false, sending = false;
  Timer? timer, expiryTimer;
  int seconds = 0;
  GpixStore? store;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = GpixScope.of(context, listen: false);
    if (store == null) {
      store = s;
      WidgetsBinding.instance.addObserver(this);
      focus.addListener(focusChanged);
      presenceTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!mounted) return;
        final active =
            s.foreground && ModalRoute.of(context)?.isCurrent == true;
        if (active && !_pendingRequest) {
          changed();
          unawaited(s.threadPresence(widget.id).catchError((_) {}));
          final typing =
              recording ||
              (focus.hasFocus &&
                  input.text.trim().isNotEmpty &&
                  now - lastEdit < 4);
          if (typing)
            signalTyping(true, kind: recording ? 'recording' : 'typing');
          else if (wasTyping)
            signalTyping(false);
          setState(() {});
        } else if (wasTyping) {
          signalTyping(false);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_pendingRequest)
          unawaited(s.threadPresence(widget.id).catchError((_) {}));
      });
      if (widget.openCamera)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_pendingRequest) photo(camera: true);
        });
      expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        var changed = false;
        for (final m in s.thread(widget.id).rows('messages')) {
          if (s.expired(m) && !m.flag('expired')) {
            m['expired'] = true;
            changed = true;
          }
        }
        if (changed) setState(() {});
      });
      s.addListener(changed);
      WidgetsBinding.instance.addPostFrameCallback((_) => changed());
    }
  }

  void changed() {
    if (!mounted ||
        !store!.foreground ||
        ModalRoute.of(context)?.isCurrent != true ||
        _pendingRequest)
      return;
    unawaited(store!.markRead(widget.id).catchError((_) {}));
  }

  @override
  void dispose() {
    signalTyping(false);
    presenceTimer?.cancel();
    focus.removeListener(focusChanged);
    WidgetsBinding.instance.removeObserver(this);
    store?.removeListener(changed);
    input.dispose();
    scroll.dispose();
    focus.dispose();
    timer?.cancel();
    expiryTimer?.cancel();
    _recorder?.dispose();
    timeRelease.dispose();
    timeOffset.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending || _pendingRequest) return;
    signalTyping(false);
    setState(() => sending = true);
    await perform(context, () async {
      final s = store!;
      if (editId.isNotEmpty) {
        final editing = s.message(editId);
        if (editing.isEmpty || s.expired(editing)) {
          _forgetSelection(editId);
          throw Exception('Il messaggio non è più disponibile.');
        }
        await s.act('editMessage', {'id': editId, 'text': input.text.trim()});
      } else {
        final target = s.message(replyId);
        await s.send(
          widget.id,
          input.text.trim(),
          reply: target.isNotEmpty && !s.expired(target) ? replyId : '',
          expiresIn: expiresIn,
        );
      }
      if (!mounted) return;
      setState(() {
        if (editId.isNotEmpty) {
          _restoreDraft();
        } else {
          input.clear();
        }
        replyId = '';
        editId = '';
      });
      _scrollToLatest();
    });
    if (mounted) setState(() => sending = false);
  }

  Future<void> photo({bool camera = false, String? replyingTo}) async {
    final draftReply = replyingTo ?? replyId;
    focus.unfocus();
    await perform(context, () async {
      final f = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 90,
      );
      if (f == null || !mounted) return;
      final mode = await open<int>(
        context,
        PhotoSend(
          path: f.path,
          recipient: store!.threadName(store!.thread(widget.id)),
        ),
      );
      if (mode == null || !mounted) return;
      final ref = await store!.upload(
        f.path,
        f.path.endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      await store!.send(
        widget.id,
        '',
        kind: 'image',
        media: ref,
        reply: draftReply,
        viewOnce: mode != 0,
        maxOpens: mode == 2 ? 2 : 1,
        expiresIn: mode != 0 ? 86400 : expiresIn,
      );
      if (mounted && replyId == draftReply) setState(() => replyId = '');
    });
  }

  void attachments() {
    focus.unfocus();
    sheet(
      context,
      Column(
        children: [
          const Text(
            'Invia un contenuto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ActionRow(CupertinoIcons.photo, 'Foto', () {
            Navigator.pop(context);
            photo();
          }),
          ActionRow(CupertinoIcons.play_rectangle, 'GIF', () {
            Navigator.pop(context);
            gifs();
          }),
          ActionRow(CupertinoIcons.smiley, 'Sticker', () {
            Navigator.pop(context);
            pickSticker();
          }),
          ActionRow(CupertinoIcons.clock, 'Messaggi a scadenza', () {
            Navigator.pop(context);
            expirySettings();
          }),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Future<void> expirySettings() {
    focus.unfocus();
    return _editExpiry(context, store!, widget.id);
  }

  void gifs() => sheet(
    context,
    GiphyGallery(
      onSelected: (ref) {
        Navigator.pop(context);
        perform(context, () async {
          final media = await store!.uploadAsset(ref, 'image/gif');
          await store!.send(
            widget.id,
            '',
            kind: 'gif',
            media: media,
            expiresIn: expiresIn,
          );
        });
      },
      onImport: () {
        Navigator.pop(context);
        perform(context, () async {
          final picked = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['gif'],
          );
          final path = picked?.files.single.path;
          if (path == null) return;
          final media = await store!.upload(path, 'image/gif');
          await store!.send(
            widget.id,
            '',
            kind: 'gif',
            media: media,
            expiresIn: expiresIn,
          );
        });
      },
    ),
  );
  Future<void> voice({bool cancel = false}) async {
    await perform(context, () async {
      if (recording) {
        timer?.cancel();
        final path = await recorder.stop();
        signalTyping(false);
        setState(() => recording = false);
        if (cancel || path == null) return;
        final ref = await store!.upload(path, 'audio/mp4');
        await store!.send(
          widget.id,
          '',
          kind: 'audio',
          media: ref,
          reply: replyId,
          expiresIn: expiresIn,
        );
        setState(() => replyId = '');
      } else {
        if (!await recorder.hasPermission())
          throw Exception(
            'Consenti l’accesso al microfono nelle impostazioni del telefono.',
          );
        final dir = await getTemporaryDirectory();
        await recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: '${dir.path}/gpix-${newId()}.m4a',
        );
        signalTyping(true, kind: 'recording');
        setState(() {
          recording = true;
          seconds = 0;
        });
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => seconds++);
          if (seconds >= 120) voice();
        });
      }
    });
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final t = s.thread(widget.id);
    final pending = s.needsMessageAcceptance(t);
    if (t.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: pageTitle('Conversazione')),
        body: const EmptyState(
          CupertinoIcons.chat_bubble,
          'Conversazione non disponibile',
          'Potrebbe essere stata rimossa o l’account bloccato.',
        ),
      );
    }

    final messages = t
        .rows('messages')
        .where((m) => !m.flag('afterRead') || !s.expired(m))
        .toList();
    final byId = {for (final m in messages) m.str('id'): m};
    final group = t.str('owner').isNotEmpty;
    final style = t.obj('chatStyle');
    final colors = ChatColors.fromName(style.str('theme'));
    final messageFont = ChatFont.fromName(style.str('font'));
    final quote = byId[editId.isNotEmpty ? editId : replyId];
    final candidate =
        byId[style.str('pinnedMessage')] ?? style.obj('pinnedPreview');
    final pin = !pending && candidate.isNotEmpty && !_temporary(candidate)
        ? candidate
        : null;
    final lastOwn = messages
        .lastWhere((m) => m.str('author') == s.myId, orElse: () => {})
        .str('id');
    expiresIn = pending ? 0 : t.number('messageTTL').toInt();
    final statusHeight = MediaQuery.paddingOf(c).top;
    final dark = Theme.of(c).brightness == Brightness.dark;
    final motion = MediaQuery.disableAnimationsOf(c)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final textScaler = MediaQuery.textScalerOf(c);
    final toolbarHeight = math.max(
      63.0,
      15 + textScaler.scale(15) * 1.24 + textScaler.scale(12.5) * 2.52,
    );
    final headerHeight = statusHeight + toolbarHeight;
    final banners = (pin == null ? 0.0 : 40.0) + (expiresIn == 0 ? 0.0 : 35.0);
    final timelinePadding = EdgeInsets.only(
      top: headerHeight + banners + 8,
      bottom: 5,
    );
    final indices = {for (final (i, m) in messages.indexed) m.str('id'): i};
    final anchorIndex = pending ? -1 : indices[anchorMessage] ?? -1;

    Widget rowAt(BuildContext c, int index) {
      if (index < 0) {
        return KeyedSubtree(
          key: const ValueKey('chat-introduction'),
          child: _chatIntroduction(c, s, t, group),
        );
      }
      final m = messages[index];
      return KeyedSubtree(
        key: ValueKey(m.str('id')),
        child: message(
          c,
          m,
          quote: pending ? null : byId[m.str('reply')],
          before: index > 0 ? messages[index - 1] : null,
          after: index + 1 < messages.length ? messages[index + 1] : null,
          thread: t,
          group: group,
          pending: pending,
          focused: index == anchorIndex,
          showReceipt: !pending && m.str('id') == lastOwn,
          colors: colors,
          messageFont: messageFont,
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: surface(c),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: anchorIndex < 0
                      ? ListView.builder(
                          key: ValueKey(('chat-timeline', timelineRevision)),
                          reverse: true,
                          controller: scroll,
                          padding: timelinePadding,
                          itemCount: messages.length + 1,
                          itemBuilder: (c, i) =>
                              rowAt(c, messages.length - 1 - i),
                          findChildIndexCallback: (key) {
                            final id = (key as ValueKey<String>).value;
                            if (id == 'chat-introduction')
                              return messages.length;
                            final index = indices[id];
                            return index == null
                                ? null
                                : messages.length - 1 - index;
                          },
                        )
                      : CustomScrollView(
                          key: ValueKey((
                            'chat-search-timeline',
                            timelineRevision,
                          )),
                          controller: scroll,
                          reverse: true,
                          anchor: .40,
                          center: const ValueKey('chat-search-anchor'),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 8),
                              sliver: SliverList.builder(
                                itemCount: messages.length - 1 - anchorIndex,
                                itemBuilder: (c, i) =>
                                    rowAt(c, anchorIndex + 1 + i),
                                findChildIndexCallback: (key) {
                                  final index =
                                      indices[(key as ValueKey<String>).value];
                                  return index == null || index <= anchorIndex
                                      ? null
                                      : index - anchorIndex - 1;
                                },
                              ),
                            ),
                            SliverPadding(
                              key: const ValueKey('chat-search-anchor'),
                              padding: EdgeInsets.only(
                                top: timelinePadding.top,
                              ),
                              sliver: SliverList.builder(
                                itemCount: anchorIndex + 2,
                                itemBuilder: (c, i) =>
                                    rowAt(c, anchorIndex - i),
                                findChildIndexCallback: (key) {
                                  final id = (key as ValueKey<String>).value;
                                  if (id == 'chat-introduction')
                                    return anchorIndex + 1;
                                  final index = indices[id];
                                  return index == null || index > anchorIndex
                                      ? null
                                      : anchorIndex - index;
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                if (pending)
                  _requestActions(c, s, t)
                else ...[
                  if (anchorIndex >= 0)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ActionChip(
                          avatar: const Icon(
                            CupertinoIcons.arrow_down,
                            size: 15,
                          ),
                          label: const Text('Più recenti'),
                          onPressed: _scrollToLatest,
                        ),
                      ),
                    ),
                  if (s.typingPeers(widget.id).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 1, 16, 4),
                      child: ConversationActivity(thread: t),
                    ),
                  AnimatedSize(
                    duration: motion,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.bottomCenter,
                    child: quote == null
                        ? (messages.isNotEmpty && !hasReplied
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      57,
                                      1,
                                      12,
                                      4,
                                    ),
                                    child: Text(
                                      'Scorri un messaggio per rispondere',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: secondaryText(c),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink())
                        : _quoteBar(c, s, t, quote, colors),
                  ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ChatComposer(
                        input: input,
                        focus: focus,
                        colors: colors,
                        sending: sending,
                        recording: recording,
                        seconds: seconds,
                        onChanged: (_) => edited(),
                        onSend: send,
                        onCamera: () => photo(camera: true),
                        onGallery: photo,
                        onVoice: voice,
                        onCancelVoice: () => voice(cancel: true),
                        onSticker: () => pickSticker(),
                        onMore: attachments,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ChatBlurHeader(
                child: Padding(
                  padding: EdgeInsets.only(top: statusHeight),
                  child: Column(
                    children: [
                      _header(
                        c,
                        s,
                        t,
                        group,
                        pending: pending,
                        height: toolbarHeight,
                      ),
                      if (pin != null)
                        _headerBanner(
                          c,
                          CupertinoIcons.pin_fill,
                          'Messaggio fissato · ${preview(pin)}',
                          height: 40,
                          onTap: () => _showPinned(c, pin, colors),
                        ),
                      if (expiresIn != 0)
                        _headerBanner(
                          c,
                          CupertinoIcons.timer,
                          expiresIn == -1
                              ? 'Messaggi temporanei · Dopo la lettura'
                              : 'Messaggi temporanei · ${expiryLabel(expiresIn)}',
                          height: 35,
                          onTap: expirySettings,
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

  Widget _chatIntroduction(BuildContext c, GpixStore s, J thread, bool group) {
    final other = s.other(thread);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        children: [
          if (group) groupAvatar() else Avatar(other, size: 82),
          const SizedBox(height: 12),
          Text(
            s.threadName(thread),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          if (!group) ...[
            const SizedBox(height: 4),
            Text(
              s.user(other).str('username'),
              style: TextStyle(fontSize: 13, color: secondaryText(c)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => open(c, Profile(user: other)),
              style: TextButton.styleFrom(
                backgroundColor: chatReplyColor(c),
                foregroundColor: foreground(c),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: const Text('Visualizza profilo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(
    BuildContext c,
    GpixStore s,
    J thread,
    bool group, {
    required bool pending,
    required double height,
  }) {
    final other = s.other(thread);
    final small = MediaQuery.sizeOf(c).width < 355;
    final buttonSize = small ? 40.0 : 44.0;
    final presence = group || pending ? '' : activityLabel(s, other);
    final subtitle = group
        ? '${thread.ids('members').length} partecipanti'
        : presence.isNotEmpty
        ? presence
        : s.user(other).str('username');
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: small ? 10 : 15),
        child: Row(
          children: [
            ChatGlassButton(
              label: 'Indietro',
              icon: CupertinoIcons.chevron_back,
              size: buttonSize,
              onTap: () => Navigator.maybePop(c),
            ),
            SizedBox(width: small ? 7 : 9),
            if (group)
              SizedBox.square(
                dimension: 38,
                child: FittedBox(child: groupAvatar()),
              )
            else
              Semantics(
                button: true,
                label: pending || s.stories(other).isEmpty
                    ? 'Foto profilo'
                    : 'Visualizza storia',
                child: GestureDetector(
                  onTap: () {
                    focus.unfocus();
                    if (!pending && s.stories(other).isNotEmpty) {
                      open(c, StoryViewer(user: other));
                    } else {
                      open(c, Profile(user: other));
                    }
                  },
                  child: pending
                      ? Avatar(other, size: small ? 34 : 39)
                      : ChatPresenceAvatar(
                          other,
                          size: small ? 34 : 39,
                          ring: s.stories(other).isNotEmpty,
                        ),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                button: !pending,
                label: pending ? null : 'Dettagli chat',
                child: InkWell(
                  key: const ValueKey('chat-details'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: pending
                      ? null
                      : () async {
                          focus.unfocus();
                          final id = await open<String>(
                            c,
                            ThreadInfo(id: widget.id),
                          );
                          if (id != null && mounted) _goToMessage(id);
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                (group
                                    ? s.threadName(thread)
                                    : _participantName(s, thread, other)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (!pending) ...[
                              const SizedBox(width: 4),
                              const GIcon(
                                CupertinoIcons.chevron_right,
                                size: 13,
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              subtitle,
                              key: const ValueKey('chat-presence-label'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.12,
                                color: foreground(c),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: small ? 5 : 8),
            if (!group && !pending) ...[
              ChatGlassButton(
                label: 'Chiamata vocale',
                icon: CupertinoIcons.phone,
                size: buttonSize,
                onTap: () => launchCall(c, widget.id, false),
              ),
              SizedBox(width: small ? 7 : 10),
              ChatGlassButton(
                label: 'Videochiamata',
                icon: CupertinoIcons.video_camera,
                size: buttonSize,
                onTap: () => launchCall(c, widget.id, true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestActions(BuildContext c, GpixStore s, J thread) {
    final hidden = thread.str('requestDecision') == 'hidden';
    final restricted = s.threadContactRestricted(thread);
    final peer = s.other(thread);
    final name = s.user(peer).str('name', s.user(peer).str('username'));
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface(c),
          border: Border(top: BorderSide(color: Theme.of(c).dividerColor)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 9),
          child: Column(
            children: [
              Text(
                hidden ? 'Richiesta nascosta' : 'Richiesta di messaggio',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                restricted
                    ? 'Rimuovi le restrizioni per rispondere a $name.'
                    : 'Accetta per rispondere a $name.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryText(c)),
              ),
              const SizedBox(height: 11),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 5,
                children: [
                  if (!hidden)
                    TextButton(
                      onPressed: decidingRequest
                          ? null
                          : () => _respondToRequest('block'),
                      style: TextButton.styleFrom(foregroundColor: danger),
                      child: const Text('Blocca'),
                    ),
                  TextButton(
                    onPressed: decidingRequest
                        ? null
                        : () => _respondToRequest(hidden ? 'delete' : 'hide'),
                    child: Text(hidden ? 'Elimina' : 'Nascondi'),
                  ),
                  FilledButton(
                    onPressed: decidingRequest
                        ? null
                        : () => _respondToRequest('accept'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 39),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(restricted ? 'Rimuovi restrizioni' : 'Accetta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respondToRequest(String action) async {
    if (decidingRequest) return;
    final c = context, s = store!, thread = s.thread(widget.id);
    final restricted = s.threadContactRestricted(thread);
    if (action == 'block' ||
        action == 'delete' ||
        action == 'accept' && restricted) {
      final accepted = await gpixAlert(
        c,
        switch (action) {
          'block' => 'Bloccare l’account?',
          'delete' => 'Eliminare la richiesta?',
          _ => 'Rimuovere le restrizioni?',
        },
        switch (action) {
          'block' => 'L’account non potrà più contattarti su GPIX.',
          'delete' => 'La conversazione verrà rimossa dal tuo account.',
          _ =>
            'La conversazione tornerà nei Messaggi e seguirà le impostazioni di privacy del tuo account.',
        },
        confirm: switch (action) {
          'block' => 'Blocca',
          'delete' => 'Elimina',
          _ => 'Rimuovi restrizioni',
        },
        cancel: true,
        destructive: action != 'accept',
      );
      if (!accepted || !mounted) return;
    }
    setState(() => decidingRequest = true);
    await perform(c, () async {
      switch (action) {
        case 'accept':
          await s.acceptChatRequest(widget.id, unrestrict: restricted);
        case 'block':
          await s.act('block', {'user': s.other(thread), 'enabled': true});
        case 'delete':
          await s.act('chatSettings', {'id': widget.id, 'field': 'clear'});
        case 'hide':
          await s.act('messageRequest', {
            'id': widget.id,
            'decision': 'hidden',
          });
      }
      if (mounted && action != 'accept' && ModalRoute.of(c)?.isCurrent == true)
        Navigator.maybePop(c);
    });
    if (mounted) setState(() => decidingRequest = false);
  }

  Widget _headerBanner(
    BuildContext c,
    IconData icon,
    String label, {
    required double height,
    required VoidCallback onTap,
  }) => SizedBox(
    height: height,
    child: Material(
      color: chatReplyColor(c).withValues(alpha: .82),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GIcon(icon, size: 15, color: secondaryText(c)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: foreground(c)),
                ),
              ),
              const GIcon(CupertinoIcons.chevron_right, size: 12),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _quoteBar(
    BuildContext c,
    GpixStore s,
    J thread,
    J quote,
    ChatColors colors,
  ) {
    final author = quote.str('author');
    final title = editId.isNotEmpty
        ? 'Modifica messaggio'
        : author == s.myId
        ? 'Stai rispondendo a te'
        : 'Stai rispondendo a ${_participantName(s, thread, author)}';
    return Container(
      key: const ValueKey('chat-reply-bar'),
      padding: const EdgeInsets.fromLTRB(17, 0, 6, 0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(c).dividerColor, width: .6),
        ),
      ),
      child: Row(
        children: [
          Container(width: 2, height: 31, color: colors.bottom),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _messagePreview(s, quote),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondaryText(c)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: editId.isEmpty ? 'Chiudi risposta' : 'Annulla modifica',
            onPressed: () => setState(() {
              if (editId.isNotEmpty) _restoreDraft();
              editId = '';
              replyId = '';
            }),
            icon: const GIcon(CupertinoIcons.xmark, size: 17),
          ),
        ],
      ),
    );
  }

  bool _joinable(J a, J? b) =>
      b != null &&
      a.str('author') == b.str('author') &&
      (a.number('created') - b.number('created')).abs() <= 120 &&
      a.str('kind') == 'text' &&
      b.str('kind') == 'text' &&
      a.str('reply').isEmpty &&
      b.str('reply').isEmpty &&
      a.obj('reactions').isEmpty &&
      b.obj('reactions').isEmpty &&
      a.obj('stickers').isEmpty &&
      b.obj('stickers').isEmpty &&
      !_standaloneEmoji(a.str('text')) &&
      !_standaloneEmoji(b.str('text')) &&
      !_temporary(a) &&
      !_temporary(b);

  Widget message(
    BuildContext c,
    J m, {
    required J? quote,
    required J? before,
    required J? after,
    required J thread,
    required bool group,
    required bool pending,
    required bool focused,
    required bool showReceipt,
    required ChatColors colors,
    required ChatFont messageFont,
  }) {
    final s = GpixScope.of(c, listen: false);
    final id = m.str('id');
    final author = m.str('author');
    final own = author == s.myId;
    final reactions = pending ? <String, dynamic>{} : m.obj('reactions');
    final stickers = pending ? <String, dynamic>{} : m.obj('stickers');
    final gone = s.expired(m);
    final reactionSpace = !gone && reactions.isNotEmpty
        ? 13.0
        : !gone && stickers.isNotEmpty
        ? 10.0
        : 0.0;
    final joinAbove = _joinable(m, before);
    final joinBelow = _joinable(m, after);
    final showTime =
        before == null || m.number('created') - before.number('created') > 900;
    final side = own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textColor = own ? Colors.white : foreground(c);
    final width = MediaQuery.sizeOf(c).width;
    return Column(
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              '${relative(m['created'])} · ${clock(m['created'])}',
              style: TextStyle(color: secondaryText(c), fontSize: 10),
            ),
          ),
        ChatSwipeRow(
          key: ValueKey('swipe-$id'),
          time: clock(m['created']),
          timeOffset: timeOffset,
          onTimeDrag: _dragTimes,
          onTimeRelease: _releaseTimes,
          onReply: gone || pending ? null : () => _replyTo(m),
          replyIndicatorLeft: own ? 26 : 16,
          child: SizedBox(
            width: double.infinity,
            child: ColoredBox(
              key: focused ? const ValueKey('chat-search-highlight') : null,
              color: focused
                  ? accent(c).withValues(alpha: .08)
                  : Colors.transparent,
              child: Row(
                mainAxisAlignment: own
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!own) ...[
                    const SizedBox(width: 16),
                    if (joinBelow)
                      const SizedBox(width: 28)
                    else
                      Padding(
                        padding: EdgeInsets.only(bottom: reactionSpace),
                        child: Avatar(author, size: 28),
                      ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (width * (own ? .76 : .77)).clamp(0.0, 450.0),
                      ),
                      child: Column(
                        crossAxisAlignment: side,
                        children: [
                          if (group && !own && !joinAbove)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 10,
                                bottom: 4,
                              ),
                              child: Text(
                                _participantName(s, thread, author),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryText(c),
                                ),
                              ),
                            ),
                          if (quote != null && !gone)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                              decoration: BoxDecoration(
                                color: chatComposerColor(c),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: side,
                                children: [
                                  Text(
                                    _participantName(
                                      s,
                                      thread,
                                      quote.str('author'),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    _messagePreview(s, quote),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: secondaryText(c),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Builder(
                            builder: (anchor) => GestureDetector(
                              key: ValueKey('chat-message-$id'),
                              behavior: HitTestBehavior.opaque,
                              onDoubleTap: gone || pending
                                  ? null
                                  : () => _reactTo(m, '❤️'),
                              onLongPress: pending
                                  ? null
                                  : () => options(anchor, m, colors),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: reactionSpace,
                                    ),
                                    child: pending
                                        ? ChatBubble(
                                            colors: colors,
                                            own: own,
                                            child: Text(
                                              _messagePreview(s, m),
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                          )
                                        : _messageBody(
                                            c,
                                            s,
                                            m,
                                            own: own,
                                            gone: gone,
                                            colors: colors,
                                            messageFont: messageFont,
                                            joinAbove: joinAbove,
                                            joinBelow: joinBelow,
                                            textColor: textColor,
                                          ),
                                  ),
                                  if (!gone && reactions.isNotEmpty)
                                    Positioned(
                                      bottom: 0,
                                      right: own ? 6 : null,
                                      left: own ? null : 6,
                                      child: _messageReactions(c, reactions),
                                    ),
                                  if (!gone && stickers.isNotEmpty)
                                    Positioned(
                                      bottom: 0,
                                      left: own ? -10 : null,
                                      right: own ? null : -10,
                                      child: _messageStickers(c, stickers),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
        if (showReceipt)
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => messageInfo(c, m, thread),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 5),
                child: Text(
                  gone ? 'Messaggio scaduto' : _messageStatus(s, m),
                  style: TextStyle(fontSize: 10, color: secondaryText(c)),
                ),
              ),
            ),
          ),
        SizedBox(
          height: joinBelow
              ? 2
              : reactionSpace == 0
              ? 11
              : 7,
        ),
      ],
    );
  }

  Widget _messageBody(
    BuildContext c,
    GpixStore s,
    J m, {
    required bool own,
    required bool gone,
    required ChatColors colors,
    required ChatFont messageFont,
    required bool joinAbove,
    required bool joinBelow,
    required Color textColor,
  }) {
    final kind = m.str('kind');
    if (gone) {
      return ChatBubble(
        colors: colors,
        expired: true,
        child: const Text(
          'Messaggio scaduto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    if (m.flag('viewOnce')) return _onceBubble(c, s, m, colors, own);
    if (kind == 'sticker' ||
        kind == 'text' && _standaloneEmoji(m.str('text'))) {
      return Text(
        m.str('text'),
        style: const TextStyle(fontSize: 48, height: 1.23),
      );
    }

    final story = m.obj('story');
    final sharedId = m.str('post', story.str('postId'));
    final shared = s.post(sharedId);
    final sharedPhoto = shared.str('kind') == 'reel'
        ? shared.obj('style').str('cover')
        : s.media(shared).firstOrNull ?? '';
    final content = switch (kind) {
      'image' || 'gif' => ProtectedChatImage(
        key: ValueKey('protected-${m.str('id')}'),
        protected: !own && s.preferences.flag('imageProtection'),
        reference: m.str('media'),
        expiresAt: m.number('readExpiresAt'),
        child: _ChatPhoto(reference: m.str('media')),
      ),
      'audio' => ChatBubble(
        own: own,
        colors: colors,
        child: AudioBubble(
          key: ValueKey(m.str('id')),
          reference: m.str('media'),
          own: own,
        ),
      ),
      'post' => const SizedBox.shrink(),
      _ => ChatBubble(
        own: own,
        colors: colors,
        joinAbove: joinAbove,
        joinBelow: joinBelow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              m.str('text'),
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.24,
                fontFamily: messageFont.family,
                fontWeight: messageFont.weight,
              ),
            ),
            if (m.flag('edited'))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'modificato',
                  style: TextStyle(
                    fontSize: 9,
                    color: own ? Colors.white70 : secondaryText(c),
                  ),
                ),
              ),
          ],
        ),
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: own
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (sharedId.isNotEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: shared.isEmpty
                ? null
                : () => open(c, PostPage(id: sharedId)),
            child: Container(
              width: 195,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: chatReplyColor(c),
                borderRadius: BorderRadius.circular(17),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sharedPhoto.isNotEmpty)
                    MediaView(
                      sharedPhoto,
                      width: 195,
                      height: 177,
                      fit: BoxFit.cover,
                      thumbnail: true,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      shared.isEmpty
                          ? 'Questo post non è disponibile.'
                          : '${s.user(shared.str('author')).str('username')} · ${shared.str('text')}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (story.isNotEmpty && sharedId.isEmpty)
          Container(
            width: 135,
            height: 185,
            margin: const EdgeInsets.only(bottom: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StoryCanvas(story: story),
                  const Positioned(
                    top: 9,
                    left: 9,
                    right: 9,
                    child: Text(
                      'Risposta alla storia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        content,
      ],
    );
  }

  Widget _onceBubble(
    BuildContext c,
    GpixStore s,
    J m,
    ChatColors colors,
    bool own,
  ) {
    final opened = own
        ? m.ids('openedBy').isNotEmpty
        : m.ids('openedBy').contains(s.myId);
    final replay = m.number('maxOpens', 1) == 2;
    final replaying = m.obj('openCounts').number(s.myId) > 0;
    final label = opened
        ? 'Foto aperta'
        : replaying
        ? 'Riproduci di nuovo'
        : own
        ? (replay ? 'Foto · Consenti replay' : 'Foto · Una visualizzazione')
        : 'Foto';
    final color = own ? Colors.white : secondaryText(c);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: own || opened
                ? null
                : () => open(c, OncePhoto(id: m.str('id'))),
            child: ChatBubble(
              colors: colors,
              own: own,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GIcon(
                    opened
                        ? CupertinoIcons.check_mark_circled
                        : CupertinoIcons.timer,
                    color: color,
                    size: 21,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!own) ...[
          const SizedBox(width: 7),
          Material(
            color: chatReplyColor(c),
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Rispondi con la fotocamera',
              onPressed: () => photo(camera: true, replyingTo: m.str('id')),
              icon: GIcon(
                CupertinoIcons.camera,
                size: 19,
                color: foreground(c),
              ),
              constraints: const BoxConstraints.tightFor(width: 35, height: 35),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ],
    );
  }

  Widget _messageReactions(BuildContext c, J reactions) {
    final summary = reactions.values.toSet().take(3).join(' ');
    return GestureDetector(
      onTap: () => sheet(
        c,
        Column(
          children: [
            const Text(
              'Reazioni',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            for (final item in reactions.entries)
              PersonTile(
                item.key,
                trailing: Text(
                  '${item.value}',
                  style: const TextStyle(fontSize: 23),
                ),
              ),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: chatReplyColor(c),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: surface(c), width: 1.5),
        ),
        child: Text(summary, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _messageStickers(BuildContext c, J stickers) => Transform.rotate(
    angle: -.12,
    child: Text(
      stickers.values.take(3).join(''),
      style: TextStyle(
        fontSize: 24,
        shadows: [Shadow(color: surface(c), blurRadius: 4)],
      ),
    ),
  );

  bool _temporary(J m) =>
      m.flag('viewOnce') || m.flag('afterRead') || m.number('expires') > 0;

  Future<void> _reactTo(J m, String emoji) async {
    final s = store!;
    if (s.expired(m)) return;
    if (!s.supportsChatTools &&
        !const {'❤️', '😂', '😍', '🔥', '😢', '👏', '🌈'}.contains(emoji)) {
      await _chatTool(context, s, () {});
      return;
    }
    await perform(
      context,
      () => s.act('react', {
        'id': m.str('id'),
        'emoji': m.obj('reactions').str(s.myId) == emoji ? '' : emoji,
      }),
    );
  }

  void pickSticker({J? attachTo}) {
    final s = store!;
    final draftReply = replyId;
    focus.unfocus();
    _pickChatEmoji(
      context,
      title: attachTo == null ? 'Invia uno sticker' : 'Aggiungi adesivo',
      onSelected: (emoji) => perform(context, () async {
        if (attachTo != null) {
          await s.act('messageSticker', {
            'id': attachTo.str('id'),
            'emoji': emoji,
          });
          return;
        }
        await s.send(
          widget.id,
          emoji,
          kind: 'sticker',
          reply: draftReply,
          expiresIn: expiresIn,
        );
        if (mounted && replyId == draftReply) setState(() => replyId = '');
      }),
    );
  }

  Future<void> options(BuildContext anchor, J m, ChatColors colors) async {
    final s = store!;
    final id = m.str('id');
    final own = m.str('author') == s.myId;
    final gone = s.expired(m);
    final temporary = _temporary(m);
    final supportsTools = s.supportsChatTools;
    final pinned =
        s.thread(widget.id).obj('chatStyle').str('pinnedMessage') == id;
    final selected = anchor.findRenderObject();
    if (selected is! RenderBox || !selected.hasSize) return;
    final area = selected.localToGlobal(Offset.zero) & selected.size;
    final c = context;
    focus.unfocus();
    final choice = await showChatMessageMenu(
      c,
      anchor: area,
      own: own,
      time: clock(m['created']),
      selection: _messagePreview(s, m),
      colors: colors,
      reactionsAvailable: !gone,
      currentReaction: m.obj('reactions').str(s.myId),
      actions: [
        if (!gone)
          const ChatMenuAction('reply', CupertinoIcons.reply, 'Rispondi'),
        if (!gone && !temporary && supportsTools)
          const ChatMenuAction(
            'sticker',
            CupertinoIcons.smiley,
            'Aggiungi adesivo',
          ),
        if (!gone && !temporary)
          const ChatMenuAction('forward', CupertinoIcons.paperplane, 'Inoltra'),
        if (supportsTools)
          const ChatMenuAction('hide', CupertinoIcons.trash, 'Elimina per te'),
        if (!own)
          const ChatMenuAction(
            'report',
            CupertinoIcons.exclamationmark_bubble,
            'Segnala',
            dangerous: true,
          ),
        if (own && !gone)
          const ChatMenuAction(
            'unsend',
            CupertinoIcons.arrow_uturn_left,
            'Annulla invio',
            dangerous: true,
          ),
      ],
      moreActions: [
        if (!gone && !temporary && m.str('kind') == 'text')
          const ChatMenuAction('copy', CupertinoIcons.doc_on_doc, 'Copia'),
        if (!gone &&
            !temporary &&
            m.str('kind') == 'text' &&
            m.str('text').trim().isNotEmpty)
          const ChatMenuAction('translate', CupertinoIcons.globe, 'Traduci'),
        if (!gone && own && m.str('kind') == 'text')
          const ChatMenuAction('edit', CupertinoIcons.pencil, 'Modifica'),
        if (!gone && !temporary && supportsTools)
          ChatMenuAction(
            'pin',
            CupertinoIcons.pin,
            pinned ? 'Rimuovi fissaggio' : 'Fissa',
          ),
        if (!gone && !temporary && m.obj('stickers').str(s.myId).isNotEmpty)
          const ChatMenuAction(
            'remove-sticker',
            CupertinoIcons.xmark,
            'Rimuovi adesivo',
          ),
        const ChatMenuAction(
          'info',
          CupertinoIcons.info_circle,
          'Informazioni',
        ),
      ],
    );
    if (choice == null || !mounted) return;
    final live = s.message(id);
    if (live.isEmpty) return;
    if (choice.startsWith('reaction:')) {
      await _reactTo(live, choice.substring('reaction:'.length));
      return;
    }
    switch (choice) {
      case 'reaction-picker':
        _pickChatEmoji(
          c,
          title: 'Reagisci con un’emoji',
          onSelected: (emoji) => _reactTo(live, emoji),
        );
      case 'reply':
        _replyTo(live);
      case 'sticker':
        pickSticker(attachTo: live);
      case 'remove-sticker':
        await perform(
          c,
          () => s.act('messageSticker', {'id': id, 'emoji': ''}),
        );
      case 'forward':
        if (!s.expired(live)) _forwardMessage(c, s, live);
      case 'copy':
        if (!s.expired(live)) {
          await Clipboard.setData(ClipboardData(text: live.str('text')));
          if (mounted) notice(c, 'Messaggio copiato');
        }
      case 'translate':
        if (!s.expired(live) &&
            !_temporary(live) &&
            live.str('kind') == 'text') {
          await translateChatText(c, live.str('text'));
        }
      case 'edit':
        if (!s.expired(live)) _editMessage(live);
      case 'pin':
        await perform(
          c,
          () => s.act('pinMessage', {'id': id, 'enabled': !pinned}),
        );
      case 'info':
        await messageInfo(c, live, s.thread(widget.id));
      case 'report':
        await _reportChat(c, s, id, type: 'message');
      case 'hide':
        if (await gpixAlert(
              c,
              'Eliminare per te?',
              'Il messaggio verrà rimosso dalla tua visualizzazione della chat.',
              confirm: 'Elimina per te',
              destructive: true,
              cancel: true,
            ) &&
            mounted) {
          await perform(c, () async {
            await s.act('hideMessage', {'id': id});
            _forgetSelection(id);
          });
        }
      case 'unsend':
        if (await gpixAlert(
              c,
              'Annullare l’invio?',
              'Il messaggio verrà rimosso dalla conversazione.',
              confirm: 'Annulla invio',
              destructive: true,
              cancel: true,
            ) &&
            mounted) {
          await perform(c, () async {
            await s.act('deleteMessage', {'id': id});
            _forgetSelection(id);
          });
        }
    }
  }

  void _forgetSelection(String id) {
    if (!mounted || (id != editId && id != replyId)) return;
    setState(() {
      if (id == editId) _restoreDraft();
      editId = '';
      replyId = '';
    });
  }

  Future<void> _showPinned(BuildContext c, J message, ChatColors colors) =>
      sheet(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 14),
              child: Text(
                'Messaggio fissato',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ChatBubble(
                colors: colors,
                child: Text(
                  _messagePreview(store!, message),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (store!.message(message.str('id')).isNotEmpty)
              ActionRow(
                CupertinoIcons.arrow_turn_down_right,
                'Vai al messaggio',
                () {
                  Navigator.pop(c);
                  _goToMessage(message.str('id'));
                },
              ),
            ActionRow(CupertinoIcons.xmark, 'Rimuovi fissaggio', () {
              Navigator.pop(c);
              perform(
                c,
                () => store!.act('pinMessage', {
                  'id': message.str('id'),
                  'enabled': false,
                }),
              );
            }),
          ],
        ),
      );
}

String _participantName(GpixStore s, J thread, String user) {
  return thread
      .obj('chatStyle')
      .obj('nicknames')
      .str(user, s.user(user).str('name', s.user(user).str('username')));
}

String _messagePreview(GpixStore s, J m) {
  if (s.expired(m)) return 'Messaggio scaduto';
  if (m.flag('viewOnce')) return 'Foto a visualizzazione limitata';
  if (m.flag('afterRead') || m.number('expires') > 0)
    return 'Messaggio temporaneo';
  return m.str('kind') == 'gif' ? 'GIF' : preview(m);
}

bool _standaloneEmoji(String text) {
  final value = text.trim();
  return value.isNotEmpty &&
      value.characters.length <= 6 &&
      value.runes.every(
        (r) =>
            (r >= 0x1f000 && r <= 0x1faff) ||
            (r >= 0x2600 && r <= 0x27bf) ||
            r == 0xfe0f ||
            r == 0xfe0e ||
            r == 0x200d ||
            r == 32,
      );
}

Future<void> _pickChatEmoji(
  BuildContext c, {
  required String title,
  required ValueChanged<String> onSelected,
}) => sheet(
  c,
  EmojiPicker(
    title: title,
    onSelected: (emoji) {
      Navigator.pop(c);
      onSelected(emoji);
    },
  ),
  scroll: false,
);

Future<void> _forwardMessage(BuildContext c, GpixStore s, J message) async {
  final user = await open<String>(c, const _ForwardRecipient());
  if (user == null || !c.mounted) return;
  await perform(c, () async {
    await s.act('forward', {'id': message.str('id'), 'user': user});
    if (c.mounted) notice(c, 'Messaggio inoltrato');
  });
}

Future<void> _reportChat(
  BuildContext c,
  GpixStore s,
  String ref, {
  required String type,
}) async {
  final reason = await textDialog(
    c,
    type == 'message' ? 'Segnala il messaggio' : 'Qualcosa non funziona',
    '',
  );
  if (reason == null || reason.trim().isEmpty || !c.mounted) return;
  await perform(c, () async {
    await s.act('report', {'id': ref, 'reason': reason.trim(), 'type': type});
    if (c.mounted) notice(c, 'Segnalazione inviata');
  });
}

class ImagePage extends StatefulWidget {
  final String reference;
  final double expiresAt;
  const ImagePage({super.key, required this.reference, this.expiresAt = 0});
  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  Timer? expiry;
  bool expired = false;
  @override
  void initState() {
    super.initState();
    if (widget.expiresAt > 0)
      expiry = Timer(
        Duration(
          milliseconds: ((widget.expiresAt - now) * 1000)
              .clamp(0, 86400000)
              .toInt(),
        ),
        () {
          if (!mounted) return;
          if (ModalRoute.of(context)?.isCurrent == true) {
            Navigator.pop(context);
          } else {
            setState(() => expired = true);
          }
        },
      );
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: expired || widget.expiresAt > 0 && widget.expiresAt <= now
            ? const SizedBox()
            : MediaView(widget.reference, fit: BoxFit.contain),
      ),
    ),
  );
}

class AudioBubble extends StatefulWidget {
  final String reference;
  final bool own;
  const AudioBubble({super.key, required this.reference, required this.own});
  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  final player = AudioPlayer();
  bool playing = false, transcribing = false, transcriptVisible = false;
  String? transcript;

  Future<void> transcribe() async {
    if (transcribing) return;
    if (transcript != null) {
      setState(() => transcriptVisible = !transcriptVisible);
      return;
    }
    final ref = GpixScope.of(context, listen: false).url(widget.reference);
    setState(() => transcribing = true);
    Directory? temporary;
    try {
      var path = ref;
      if (ref.startsWith('https://')) {
        temporary = await (await getTemporaryDirectory()).createTemp(
          'gpix-voice-',
        );
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 15);
        try {
          final response = await (await client.getUrl(Uri.parse(ref))).close();
          if (response.statusCode != HttpStatus.ok) {
            throw const FileSystemException('Audio non disponibile');
          }
          final file = File('${temporary.path}/voice.m4a');
          await response
              .timeout(const Duration(seconds: 20))
              .pipe(file.openWrite());
          path = file.path;
        } finally {
          client.close(force: true);
        }
      } else if (ref.startsWith('file:')) {
        path = Uri.parse(ref).toFilePath();
      }
      if (!mounted) return;
      final value = await const MethodChannel(
        'GPIX/transcription',
      ).invokeMethod<String>('transcribe', {'path': path, 'language': 'it-IT'});
      if (!mounted) return;
      if (value == null || value.trim().isEmpty) {
        notice(context, 'Nessuna parola riconosciuta in questo vocale.');
      } else {
        setState(() {
          transcript = value.trim();
          transcriptVisible = true;
        });
      }
    } on PlatformException catch (error) {
      if (mounted)
        notice(context, error.message ?? 'Trascrizione non disponibile.');
    } on Exception {
      if (mounted) notice(context, 'Impossibile trascrivere il vocale.');
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } on FileSystemException {
          // The operating system can clear the temporary directory.
        }
      }
      if (mounted) setState(() => transcribing = false);
    }
  }

  StreamSubscription? completion;
  @override
  void initState() {
    super.initState();
    completion = player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => playing = false);
    });
  }

  @override
  void dispose() {
    completion?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final color = widget.own ? Colors.white : foreground(c);
    return SizedBox(
      width: 175,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => perform(c, () async {
                  if (playing) {
                    await player.pause();
                  } else {
                    final ref = GpixScope.of(
                      c,
                      listen: false,
                    ).url(widget.reference);
                    await player.play(
                      ref.startsWith('https://')
                          ? UrlSource(ref)
                          : DeviceFileSource(ref),
                    );
                  }
                  if (mounted) setState(() => playing = !playing);
                }),
                child: GIcon(
                  playing
                      ? CupertinoIcons.pause_fill
                      : CupertinoIcons.play_fill,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    22,
                    (i) => Container(
                      width: 2,
                      height: 7 + (i * 7 % 19).toDouble(),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .8),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GIcon(CupertinoIcons.mic_fill, color: color, size: 14),
            ],
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding: EdgeInsets.zero,
            ),
            onPressed: transcribing ? null : transcribe,
            child: Text(
              transcribing
                  ? 'Trascrizione in corso…'
                  : transcriptVisible
                  ? 'Nascondi trascrizione'
                  : transcript != null
                  ? 'Mostra trascrizione'
                  : 'Trascrivi',
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
          if (transcriptVisible)
            Text(
              transcript!,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
        ],
      ),
    );
  }
}

class ThreadInfo extends StatelessWidget {
  final String id;
  const ThreadInfo({super.key, required this.id});

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final t = s.thread(id);
    final group = t.str('owner').isNotEmpty;
    final admin = t.str('owner') == s.myId;
    final other = s.other(t);
    final mutedChat = t.obj('chatSettings').flag('muted');
    final colors = ChatColors.fromName(t.obj('chatStyle').str('theme'));
    final expiry = t.number('messageTTL').toInt();
    final name = group ? s.threadName(t) : _participantName(s, t, other);
    return Scaffold(
      backgroundColor: surface(c),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 6, bottom: 22),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChatGlassButton(
                  icon: CupertinoIcons.chevron_back,
                  label: 'Indietro',
                  onTap: () => Navigator.maybePop(c),
                ),
              ),
            ),
            if (t.isNotEmpty) ...[
              Center(
                child: group
                    ? SizedBox.square(
                        dimension: 96,
                        child: FittedBox(child: groupAvatar()),
                      )
                    : Avatar(other, size: 96),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 19, 20, 16),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ChatShortcut(
                      icon: group
                          ? CupertinoIcons.person_2
                          : CupertinoIcons.person,
                      label: group ? 'Persone' : 'Profilo',
                      onTap: () => group
                          ? _showMembers(c, s, t, admin)
                          : open(c, Profile(user: other)),
                    ),
                    _ChatShortcut(
                      icon: CupertinoIcons.search,
                      label: 'Cerca',
                      onTap: () async {
                        final message = await showSearchMessages(c, id);
                        if (message != null && c.mounted)
                          Navigator.pop(c, message);
                      },
                    ),
                    _ChatShortcut(
                      icon: mutedChat
                          ? CupertinoIcons.bell_slash
                          : CupertinoIcons.bell,
                      label: mutedChat ? 'Riattiva' : 'Silenzia',
                      onTap: () => perform(
                        c,
                        () => s.act('chatSettings', {
                          'id': id,
                          'field': 'muted',
                          'enabled': !mutedChat,
                        }),
                      ),
                    ),
                    _ChatShortcut(
                      icon: CupertinoIcons.ellipsis,
                      label: 'Opzioni',
                      onTap: () => _threadOptions(c, s, t, group, admin),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 29),
              _ThreadInfoRow(
                icon: CupertinoIcons.paintbrush,
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: colors.gradient,
                  ),
                ),
                label: 'Personalizza',
                subtitle: 'Tema e carattere',
                onTap: () =>
                    _chatTool(c, s, () => open(c, _ChatAppearance(id: id))),
              ),
              _ThreadInfoRow(
                icon: CupertinoIcons.person_crop_circle,
                label: 'Soprannomi',
                onTap: () =>
                    _chatTool(c, s, () => open(c, _ChatNicknames(id: id))),
              ),
              _ThreadInfoRow(
                icon: CupertinoIcons.timer,
                label: 'Messaggi temporanei',
                subtitle: expiry == 0
                    ? 'No'
                    : (expiry == -1 ? 'Dopo la lettura' : expiryLabel(expiry)),
                onTap: () => _editExpiry(c, s, id),
              ),
              _ThreadInfoRow(
                icon: CupertinoIcons.lock,
                label: 'Privacy e sicurezza',
                onTap: () => open(c, _ChatPrivacy(id: id)),
              ),
              if (!group)
                _ThreadInfoRow(
                  icon: CupertinoIcons.person_2,
                  label: 'Crea una chat di gruppo',
                  onTap: () => newConversation(
                    c,
                    startGroup: true,
                    initialMember: other,
                  ),
                ),
              _ThreadInfoRow(
                icon: CupertinoIcons.exclamationmark_bubble,
                label: 'Qualcosa non funziona',
                onTap: () => _reportChat(c, s, id, type: 'thread'),
              ),
            ] else
              const EmptyState(
                CupertinoIcons.chat_bubble,
                'Conversazione non disponibile',
                '',
              ),
          ],
        ),
      ),
    );
  }

  void _threadOptions(
    BuildContext c,
    GpixStore s,
    J t,
    bool group,
    bool admin,
  ) {
    sheet(
      c,
      Column(
        children: [
          const Text(
            'Opzioni',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          ActionRow(CupertinoIcons.photo, 'Contenuti condivisi', () {
            Navigator.pop(c);
            open(c, SharedMedia(thread: id));
          }),
          if (group && admin)
            ActionRow(CupertinoIcons.pencil, 'Cambia nome', () async {
              Navigator.pop(c);
              final value = await textDialog(
                c,
                'Nome del gruppo',
                t.str('title'),
              );
              if (value == null || value.trim().isEmpty || !c.mounted) return;
              await perform(
                c,
                () => s.act('renameGroup', {'id': id, 'title': value.trim()}),
              );
            }),
          if (group)
            ActionRow(
              CupertinoIcons.square_arrow_left,
              'Abbandona gruppo',
              () async {
                Navigator.pop(c);
                if (await gpixAlert(
                      c,
                      'Abbandonare il gruppo?',
                      'Non riceverai più i messaggi di questo gruppo.',
                      confirm: 'Abbandona',
                      cancel: true,
                      destructive: true,
                    ) &&
                    c.mounted) {
                  await perform(c, () async {
                    await s.act('leaveGroup', {'id': id});
                    if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
                  });
                }
              },
              destructive: true,
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _showMembers(BuildContext c, GpixStore s, J t, bool admin) {
    sheet(
      c,
      Column(
        children: [
          const Text(
            'Partecipanti',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (admin)
            ActionRow(CupertinoIcons.person_add, 'Aggiungi partecipanti', () {
              Navigator.pop(c);
              sheet(
                c,
                Column(
                  children: [
                    const Text(
                      'Aggiungi partecipanti',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final u in s.users.where(
                      (u) =>
                          !t.ids('members').contains(u.str('id')) &&
                          !s.blocked(u.str('id')),
                    ))
                      PersonTile(
                        u.str('id'),
                        onTap: () => perform(c, () async {
                          await s.act('addMember', {'id': id, 'user': u['id']});
                          if (c.mounted) Navigator.pop(c);
                        }),
                      ),
                  ],
                ),
              );
            }),
          for (final uid in t.ids('members'))
            PersonTile(
              uid,
              subtitle: uid == t.str('owner') ? 'Amministratore' : null,
              onTap: () => open(c, Profile(user: uid)),
              trailing: admin && uid != s.myId
                  ? IconButton(
                      tooltip: 'Rimuovi partecipante',
                      onPressed: () async {
                        if (await gpixAlert(
                              c,
                              'Rimuovere ${s.user(uid).str('username')}?',
                              'Non potrà più accedere al gruppo.',
                              confirm: 'Rimuovi',
                              cancel: true,
                            ) &&
                            c.mounted) {
                          await perform(
                            c,
                            () =>
                                s.act('removeMember', {'id': id, 'user': uid}),
                          );
                          if (c.mounted) Navigator.pop(c);
                        }
                      },
                      icon: const GIcon(
                        CupertinoIcons.minus_circled,
                        color: danger,
                        size: 22,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ChatShortcut extends StatelessWidget {
  const _ChatShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            GIcon(icon, size: 25, color: foreground(c)),
            const SizedBox(height: 14),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThreadInfoRow extends StatelessWidget {
  const _ThreadInfoRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) {
    final color = destructive ? danger : foreground(c);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: subtitle == null ? 48 : 55),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: leading ?? GIcon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.19,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.12,
                            color: secondaryText(c),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GIcon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: secondaryText(c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _chatTool(BuildContext c, GpixStore s, VoidCallback run) async {
  if (!s.supportsChatTools) {
    await gpixAlert(
      c,
      'Aggiorna il backend GPIX',
      'Questa opzione richiede la versione 2.24.15.',
    );
    return;
  }
  run();
}

Future<void> _editExpiry(BuildContext c, GpixStore s, String id) async {
  final choice = await open<int>(
    c,
    MessageExpiry(seconds: s.thread(id).number('messageTTL').toInt()),
  );
  if (choice == null || !c.mounted) return;
  await perform(c, () => s.act('messageExpiry', {'id': id, 'seconds': choice}));
}

class _ChatAppearance extends StatefulWidget {
  const _ChatAppearance({required this.id});
  final String id;

  @override
  State<_ChatAppearance> createState() => _ChatAppearanceState();
}

class _ChatAppearanceState extends State<_ChatAppearance> {
  ChatColors? selectedTheme;
  ChatFont? selectedFont;
  bool saving = false;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final style = s.thread(widget.id).obj('chatStyle');
    final colors = selectedTheme ?? ChatColors.fromName(style.str('theme'));
    final font = selectedFont ?? ChatFont.fromName(style.str('font'));
    return Scaffold(
      appBar: AppBar(title: pageTitle('Personalizza')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 25),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: chatComposerColor(c),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ChatBubble(
                    colors: colors,
                    child: Text(
                      'Ciao!',
                      style: TextStyle(
                        fontFamily: font.family,
                        fontWeight: font.weight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ChatBubble(
                    colors: colors,
                    own: true,
                    child: Text(
                      'Come va?',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: font.family,
                        fontWeight: font.weight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Tema',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final choice in ChatColors.values)
                ChoiceChip(
                  avatar: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: choice.gradient,
                    ),
                    child: const SizedBox.square(dimension: 16),
                  ),
                  label: Text(choice.label),
                  selected: colors == choice,
                  onSelected: (_) => setState(() => selectedTheme = choice),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Carattere',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final choice in ChatFont.values)
                ChoiceChip(
                  label: Text(
                    choice.label,
                    style: TextStyle(
                      fontFamily: choice.family,
                      fontWeight: choice.weight,
                    ),
                  ),
                  selected: font == choice,
                  onSelected: (_) => setState(() => selectedFont = choice),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving || selectedTheme == null && selectedFont == null
                ? null
                : () async {
                    setState(() => saving = true);
                    await perform(c, () async {
                      await s.act('chatAppearance', {
                        'id': widget.id,
                        if (selectedTheme != null) 'theme': colors.name,
                        if (selectedFont != null) 'font': font.name,
                      });
                      if (c.mounted) Navigator.pop(c);
                    });
                    if (mounted) setState(() => saving = false);
                  },
            child: const Text('Applica'),
          ),
        ],
      ),
    );
  }
}

class _ChatNicknames extends StatelessWidget {
  const _ChatNicknames({required this.id});
  final String id;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final t = s.thread(id);
    final nicknames = t.obj('chatStyle').obj('nicknames');
    return Scaffold(
      appBar: AppBar(title: pageTitle('Soprannomi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(5, 6, 5, 20),
        children: [
          for (final uid in t.ids('members'))
            PersonTile(
              uid,
              subtitle: nicknames.str(uid, 'Imposta soprannome'),
              trailing: const GIcon(CupertinoIcons.pencil, size: 19),
              onTap: () async {
                final name = await textDialog(
                  c,
                  'Soprannome',
                  nicknames.str(uid),
                );
                if (name == null || !c.mounted) return;
                await perform(
                  c,
                  () => s.act('chatNickname', {
                    'id': id,
                    'user': uid,
                    'text': name.trim(),
                  }),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChatPrivacy extends StatelessWidget {
  const _ChatPrivacy({required this.id});
  final String id;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final t = s.thread(id);
    final group = t.str('owner').isNotEmpty;
    final other = s.other(t);
    final restrictions = s.preferences.ids('restricted');
    final restricted = restrictions.contains(other);
    return Scaffold(
      appBar: AppBar(title: pageTitle('Privacy e sicurezza')),
      body: ListView(
        children: [
          _ThreadInfoRow(
            icon: CupertinoIcons.check_mark_circled,
            label: 'Conferme di lettura',
            subtitle: 'Impostazione dell’account',
            onTap: () =>
                open(c, const MessageToggleSetting(setting: 'readReceipts')),
          ),
          _ThreadInfoRow(
            icon: CupertinoIcons.photo,
            label: 'Protezione delle immagini',
            subtitle: 'Impostazione dell’account',
            onTap: () =>
                open(c, const MessageToggleSetting(setting: 'imageProtection')),
          ),
          if (t.isNotEmpty && !group) ...[
            _ThreadInfoRow(
              icon: CupertinoIcons.person_crop_circle,
              label: restricted ? 'Rimuovi restrizioni' : 'Limita account',
              onTap: () => perform(
                c,
                () => s.act('preferences', {
                  'key': 'restricted',
                  'value': restricted
                      ? (restrictions..remove(other))
                      : [...restrictions, other],
                }),
              ),
            ),
            _ThreadInfoRow(
              icon: CupertinoIcons.nosign,
              label: 'Blocca',
              destructive: true,
              onTap: () async {
                if (await gpixAlert(
                      c,
                      'Bloccare ${s.user(other).str('username')}?',
                      'L’account non potrà più contattarti su GPIX.',
                      confirm: 'Blocca',
                      destructive: true,
                      cancel: true,
                    ) &&
                    c.mounted) {
                  await perform(c, () async {
                    await s.act('block', {'user': other, 'enabled': true});
                    if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
                  });
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

String expiryLabel(int seconds) => switch (seconds) {
  -1 => 'la lettura',
  60 => '1 minuto',
  3600 => '1 ora',
  86400 => '24 ore',
  _ => 'mai',
};

class MessageExpiry extends StatefulWidget {
  final int seconds;
  const MessageExpiry({super.key, required this.seconds});
  @override
  State<MessageExpiry> createState() => _MessageExpiryState();
}

class _MessageExpiryState extends State<MessageExpiry> {
  late int value = widget.seconds;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: pageTitle('Messaggi a scadenza')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GIcon(CupertinoIcons.timer, size: 54, color: auraBlue),
        const SizedBox(height: 20),
        const Text(
          'Per quanto restano i nuovi messaggi?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'La scelta riguarda solo i nuovi messaggi. Le durate partono dall’invio; Dopo la lettura usa la conferma di apertura della chat. Le foto a visione limitata hanno una modalità separata scelta prima dell’invio.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5),
          ),
        ),
        for (final seconds in [0, -1, 60, 3600, 86400])
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 4,
            ),
            title: Text(
              seconds == 0
                  ? 'Disattivata'
                  : seconds == -1
                  ? 'Dopo la lettura'
                  : expiryLabel(seconds),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              seconds == 0
                  ? 'I nuovi messaggi restano nella chat'
                  : seconds == -1
                  ? 'Scompaiono 5 secondi dopo la lettura; nei gruppi, per il mittente dopo la lettura di tutti.'
                  : 'Eliminazione automatica ${seconds == 60
                        ? 'un minuto'
                        : seconds == 3600
                        ? 'un’ora'
                        : '24 ore'} dopo l’invio',
            ),
            trailing: GIcon(
              value == seconds
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: value == seconds ? auraBlue : muted,
            ),
            onTap: () => setState(() => value = seconds),
          ),
        const SizedBox(height: 24),
        PrimaryButton('Salva durata', onTap: () => Navigator.pop(c, value)),
      ],
    ),
  );
}

Future<String?> showSearchMessages(BuildContext c, String thread) =>
    open<String>(c, _ChatSearch(thread: thread));

class _ChatSearch extends StatefulWidget {
  const _ChatSearch({required this.thread});

  final String thread;

  @override
  State<_ChatSearch> createState() => _ChatSearchState();
}

class _ChatSearchState extends State<_ChatSearch> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final t = s.thread(widget.thread);
    final term = directSearchTerm(query);
    final messages = t
        .rows('messages')
        .reversed
        .where((m) => matchesDirectMessage(s, m, term))
        .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Cerca nella chat',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
            child: DirectSearchField(
              key: const ValueKey('thread-search'),
              controller: search,
              hint: 'Cerca nei messaggi',
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: term.isEmpty
                ? const SizedBox.shrink()
                : messages.isEmpty
                ? const Center(child: Text('Nessun risultato'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: messages.length,
                    itemBuilder: (c, index) {
                      final m = messages[index];
                      final author = m.str('author');
                      return DirectThreadRow(
                        key: ValueKey('thread-result-${m.str('id')}'),
                        portrait: Avatar(author, size: 46),
                        name: author == s.myId
                            ? 'Tu'
                            : _participantName(s, t, author),
                        preview: Text(m.str('text')),
                        time: directTimeAgo(m.number('created'), compact: true),
                        onTap: () {
                          FocusScope.of(c).unfocus();
                          Navigator.pop(c, m.str('id'));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ForwardRecipient extends StatefulWidget {
  const _ForwardRecipient();

  @override
  State<_ForwardRecipient> createState() => _ForwardRecipientState();
}

class _ForwardRecipientState extends State<_ForwardRecipient> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final term = directSearchTerm(query);
    final users = s.users
        .where(
          (u) =>
              u.str('id') != s.myId &&
              !s.blocked(u.str('id')) &&
              directSearchTerm(
                '${u.str('name')} ${u.str('username')}',
              ).contains(term),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Inoltra a',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
            child: DirectSearchField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              hint: 'Cerca persone',
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? const Center(child: Text('Nessun risultato'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: users.length,
                    itemBuilder: (c, i) {
                      final u = users[i];
                      return PersonTile(
                        u.str('id'),
                        subtitle: '@${u.str('username')}',
                        trailing: TextButton(
                          onPressed: () => Navigator.pop(c, u.str('id')),
                          child: const Text('Invia'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatPhoto extends StatelessWidget {
  const _ChatPhoto({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(15),
    child: ColoredBox(
      color: subdued(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 86, maxHeight: 268),
        child: MediaView(
          reference,
          width: 210,
          placeholderHeight: 165,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

class ProtectedChatImage extends StatefulWidget {
  final bool protected;
  final String reference;
  final double expiresAt;
  final Widget child;
  const ProtectedChatImage({
    super.key,
    required this.protected,
    required this.reference,
    this.expiresAt = 0,
    required this.child,
  });
  @override
  State<ProtectedChatImage> createState() => _ProtectedChatImageState();
}

class _ProtectedChatImageState extends State<ProtectedChatImage> {
  bool revealed = false;
  @override
  void didUpdateWidget(ProtectedChatImage old) {
    super.didUpdateWidget(old);
    if (old.protected != widget.protected) revealed = false;
  }

  @override
  Widget build(BuildContext c) {
    final hidden = widget.protected && !revealed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => hidden
          ? setState(() => revealed = true)
          : open(
              c,
              ImagePage(
                reference: widget.reference,
                expiresAt: widget.expiresAt,
              ),
            ),
      child: hidden
          ? Container(
              width: 210,
              height: 155,
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GIcon(CupertinoIcons.eye_slash, size: 26),
                  const SizedBox(height: 10),
                  const Text('Foto nascosta'),
                  const SizedBox(height: 5),
                  Text(
                    'Tocca per mostrare',
                    style: TextStyle(color: secondaryText(c), fontSize: 12),
                  ),
                ],
              ),
            )
          : widget.child,
    );
  }
}

String activityLabel(GpixStore s, String id) {
  if (!s.activityVisible) return '';
  if (s.online(id)) return 'Attivo/a ora';
  final seconds = s.user(id).number('lastActive');
  if (seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  final today = DateTime.now();
  final elapsed = today.difference(date);
  if (elapsed.inMinutes < 1) return 'Ultimo accesso poco fa';
  if (elapsed.inHours < 12) return 'Ultimo accesso ${directTimeAgo(seconds)}';
  final day = DateTime(date.year, date.month, date.day);
  final current = DateTime(today.year, today.month, today.day);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final hour = clock(seconds);
  if (day == current) return 'Ultimo accesso oggi alle $hour';
  if (day == yesterday) return 'Ultimo accesso ieri alle $hour';
  final month =
      '${date.day}/${date.month}${date.year == today.year ? '' : '/${date.year}'}';
  return 'Ultimo accesso $month alle $hour';
}

class ChatPresenceAvatar extends StatelessWidget {
  final String user;
  final double size;
  final bool ring;
  const ChatPresenceAvatar(
    this.user, {
    super.key,
    this.size = 42,
    this.ring = false,
  });
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Avatar(
            user,
            size: size,
            ring: ring,
            viewed: ring && !s.hasUnseenStories(user),
          ),
          if (s.online(user))
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                label: 'Attivo/a ora',
                child: Container(
                  key: ValueKey('online-$user'),
                  width: size < 45 ? 11 : 16,
                  height: size < 45 ? 11 : 16,
                  decoration: BoxDecoration(
                    color: const Color(0xff32cf69),
                    shape: BoxShape.circle,
                    border: Border.all(color: surface(c), width: 2.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatActivityLabel extends StatelessWidget {
  final J thread;
  final bool wrap;
  const ChatActivityLabel({super.key, required this.thread, this.wrap = false});
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), group = thread.str('owner').isNotEmpty;
    final text = group
        ? '${thread.ids('members').length} partecipanti'
        : activityLabel(s, s.other(thread));
    return Text(
      text.isEmpty
          ? (group ? '' : s.user(s.other(thread)).str('username'))
          : text,
      maxLines: wrap ? null : 1,
      overflow: wrap ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: !group && s.online(s.other(thread))
            ? const Color(0xff26ae55)
            : muted,
        fontSize: wrap ? 12 : 10,
      ),
    );
  }
}

class ConversationActivity extends StatelessWidget {
  final J thread;
  const ConversationActivity({super.key, required this.thread});

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final peers = s.typingPeers(thread.str('id'));
    if (peers.isEmpty) return const SizedBox.shrink();
    final recording = peers.where((peer) => peer.str('kind') == 'recording');
    final isRecording = recording.isNotEmpty;
    final peer = (isRecording ? recording.first : peers.first).str('user');
    final name = s.user(peer).str('name', s.user(peer).str('username'));
    final action = isRecording ? 'sta registrando un audio…' : 'sta scrivendo…';
    final text = thread.str('owner').isNotEmpty && name.isNotEmpty
        ? '$name $action'
        : 'S${action.substring(1)}';
    return Row(
      children: [
        if (isRecording)
          GIcon(CupertinoIcons.mic_fill, size: 13, color: accent(c))
        else if (!MediaQuery.disableAnimationsOf(c))
          const TypingDots(),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent(c),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
    animation: controller,
    builder: (c, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Opacity(
            opacity:
                .25 +
                .75 * (1 - ((controller.value - i / 3).abs() % 1)).clamp(0, 1),
            child: Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: const BoxDecoration(
                color: auraBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}
