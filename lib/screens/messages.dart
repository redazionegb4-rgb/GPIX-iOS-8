import 'dart:async';
import 'dart:io';
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
import 'social.dart';
import 'features13.dart';
import 'sessions_instants.dart';
import 'stories.dart';
import 'calls.dart';
import 'emoji_picker.dart';
import 'chat_media.dart';
import 'giphy.dart';
import 'photo_send.dart';
import 'community.dart';

class Inbox extends StatefulWidget {
  const Inbox({super.key});
  @override
  State<Inbox> createState() => _InboxState();
}

class _InboxState extends State<Inbox> {
  String query = '';
  bool unreadOnly = false;
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        threads = s.inboxThreads
            .where(
              (t) =>
                  ('${s.threadName(t)} ${inboxPreview(s, t)}')
                      .toLowerCase()
                      .contains(query.toLowerCase()) &&
                  (!unreadOnly || s.chatHasUnread(t)),
            )
            .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                s.me.str('username'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (s.requestedThreads.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 7),
                child: Icon(CupertinoIcons.circle_fill, size: 7, color: danger),
              ),
          ],
        ),
        actions: [
          if (s.preferences.flag('hideInstantBubble'))
            IconButton(
              tooltip: 'Istantanee',
              onPressed: () => openInstants(c),
              icon: const GIcon(CupertinoIcons.photo_on_rectangle),
            ),
          IconButton(
            tooltip: 'Nuovo messaggio',
            onPressed: () => newConversation(c),
            icon: const GIcon(CupertinoIcons.square_pencil, size: 26),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 150),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 15),
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Cerca persone e messaggi',
                    prefixIcon: const GIcon(CupertinoIcons.search, size: 19),
                    filled: true,
                    fillColor: subdued(c),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const NotesTray(),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Messaggi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => open(c, const MessageRequests()),
                      style: TextButton.styleFrom(foregroundColor: muted),
                      child: Text(
                        s.requestedThreads.isEmpty
                            ? 'Richieste'
                            : 'Richieste (${s.requestedThreads.length})',
                      ),
                    ),
                  ],
                ),
              ),
              if (threads.isEmpty)
                const EmptyState(
                  CupertinoIcons.paperplane,
                  'Le tue conversazioni',
                  'Inizia a scrivere a qualcuno della community.',
                ),
              for (final t in threads)
                AuraPanel(
                  margin: const EdgeInsets.fromLTRB(12, 3, 12, 7),
                  child: InkWell(
                    onTap: () => open(c, Chat(id: t.str('id'))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          if (t.str('owner').isNotEmpty)
                            groupAvatar()
                          else
                            GestureDetector(
                              onTap: () => s.stories(s.other(t)).isNotEmpty
                                  ? open(c, StoryViewer(user: s.other(t)))
                                  : open(c, Profile(user: s.other(t))),
                              child: ChatPresenceAvatar(
                                s.other(t),
                                size: 64,
                                ring: s.hasUnseenStories(s.other(t)),
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.threadName(t),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: s.chatHasUnread(t)
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (s.typingPeers(t.str('id')).isNotEmpty)
                                  ConversationActivity(thread: t)
                                else
                                  Text(
                                    inboxPreview(s, t),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: s.chatHasUnread(t)
                                          ? foreground(c)
                                          : muted,
                                      fontWeight: s.chatHasUnread(t)
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (s.chatHasUnread(t))
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: violet,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!s.preferences.flag('hideInstantBubble'))
            const Positioned(right: 10, bottom: 110, child: InstantPile()),
        ],
      ),
    );
  }
}

class MessageRequests extends StatefulWidget {
  final bool hidden;
  const MessageRequests({super.key, this.hidden = false});
  @override
  State<MessageRequests> createState() => _MessageRequestsState();
}

class _MessageRequestsState extends State<MessageRequests> {
  bool showAll = false, editing = false, busy = false;
  final selected = <String>{};
  Future<void> decide(List<String> ids, String decision) async {
    if (busy) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      for (final id in ids) {
        await s.act('messageRequest', {'id': id, 'decision': decision});
      }
      if (mounted)
        setState(() {
          selected.clear();
          editing = false;
        });
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        all = widget.hidden ? s.hiddenRequests : s.requestedThreads;
    final requests = all
        .where(
          (t) =>
              widget.hidden ||
              showAll ||
              t.rows('messages').isEmpty ||
              t.rows('messages').last.number('created') >= now - 30 * 86400,
        )
        .toList();
    selected.removeWhere((id) => !requests.any((t) => t.str('id') == id));
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.hidden ? 'Richieste nascoste' : 'Richieste di messaggi',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: requests.isEmpty || busy
                ? null
                : () => setState(() {
                    editing = !editing;
                    selected.clear();
                  }),
            child: Text(editing ? 'Fine' : 'Modifica'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.hidden)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: const GIcon(CupertinoIcons.eye_slash, size: 30),
              title: const Text(
                'Richieste nascoste',
                style: TextStyle(fontSize: 17),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${s.hiddenRequests.length}',
                    style: const TextStyle(color: muted, fontSize: 16),
                  ),
                  const SizedBox(width: 14),
                  const GIcon(
                    CupertinoIcons.chevron_right,
                    color: muted,
                    size: 20,
                  ),
                ],
              ),
              onTap: () => open(c, const MessageRequests(hidden: true)),
            ),
          Expanded(
            child: requests.isEmpty
                ? LayoutBuilder(
                    builder: (c, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 80),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: foreground(c),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: GIcon(
                                    widget.hidden
                                        ? CupertinoIcons.eye_slash
                                        : CupertinoIcons.paperplane,
                                    size: 54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              Text(
                                widget.hidden
                                    ? 'Nessuna richiesta nascosta'
                                    : showAll
                                    ? 'Nessuna richiesta di messaggi'
                                    : 'Nessuna richiesta di messaggi recente',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 27,
                                  height: 1.16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                widget.hidden
                                    ? 'Le richieste che nascondi appariranno qui. Puoi accettarle in qualsiasi momento.'
                                    : showAll
                                    ? 'Le nuove richieste appariranno qui.'
                                    : 'Le richieste più vecchie di 30 giorni non sono visibili.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              if (!widget.hidden && !showAll)
                                Padding(
                                  padding: const EdgeInsets.only(top: 27),
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => showAll = true),
                                    child: const Text(
                                      'Mostra tutto',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    children: [
                      if (widget.hidden)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Queste richieste rimangono separate dalle conversazioni finché non le accetti.',
                            style: TextStyle(color: muted, height: 1.4),
                          ),
                        ),
                      for (final t in requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: editing
                                    ? Checkbox(
                                        value: selected.contains(t.str('id')),
                                        onChanged: busy
                                            ? null
                                            : (v) => setState(() {
                                                if (v == true) {
                                                  selected.add(t.str('id'));
                                                } else {
                                                  selected.remove(t.str('id'));
                                                }
                                              }),
                                      )
                                    : Avatar(
                                        s.other(t),
                                        size: 58,
                                        ring: s.hasUnseenStories(s.other(t)),
                                      ),
                                title: Text(
                                  s.threadName(t),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  inboxPreview(s, t),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: editing
                                    ? () => setState(() {
                                        if (!selected.add(t.str('id')))
                                          selected.remove(t.str('id'));
                                      })
                                    : () => open(c, Chat(id: t.str('id'))),
                              ),
                              if (!editing)
                                Row(
                                  children: [
                                    if (!widget.hidden) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(
                                            CupertinoIcons.eye_slash,
                                            size: 17,
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(0, 46),
                                            foregroundColor: foreground(c),
                                            backgroundColor: subdued(c),
                                            side: BorderSide.none,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onPressed: busy
                                              ? null
                                              : () => decide([
                                                  t.str('id'),
                                                ], 'hidden'),
                                          label: const Text('Nascondi'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: FilledButton.icon(
                                        icon: const Icon(
                                          CupertinoIcons.check_mark,
                                          size: 17,
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 46),
                                          backgroundColor: violet,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => decide([
                                                t.str('id'),
                                              ], 'accepted'),
                                        label: const Text('Accetta'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      if (!widget.hidden && !showAll)
                        TextButton(
                          onPressed: () => setState(() => showAll = true),
                          child: const Text('Mostra tutto'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: editing
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: busy || selected.isEmpty
                      ? null
                      : () => decide(
                          selected.toList(),
                          widget.hidden ? 'accepted' : 'hidden',
                        ),
                  child: Text(
                    busy
                        ? 'Attendi…'
                        : widget.hidden
                        ? 'Accetta selezionate (${selected.length})'
                        : 'Nascondi selezionate (${selected.length})',
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
    color: Color(0xffeee8fd),
  ),
  child: const GIcon(CupertinoIcons.person_2_fill, color: violet, size: 25),
);
String inboxPreview(GpixStore s, J t) {
  final messages = t
      .rows('messages')
      .where((m) => !m.flag('afterRead') || !s.expired(m))
      .toList();
  final composing = s.typingPeers(t.str('id'));
  if (composing.isNotEmpty)
    return composing.any((x) => x.str('kind') == 'recording')
        ? 'Sta registrando un audio…'
        : 'Sta scrivendo…';
  final reactions = s.chatReactions(t);
  if (reactions.isNotEmpty &&
      (messages.isEmpty ||
          reactions.first.number('created') >=
              messages.last.number('created'))) {
    final n = reactions.first;
    return s.preferences['messagePreviews'] == false
        ? 'Nuova reazione · ${relative(n['created'])}'
        : '${s.user(n.str('actor')).str('username')} ha reagito a un tuo messaggio · ${relative(n['created'])}';
  }
  if (messages.isEmpty) return 'Inizia la conversazione';
  final m = messages.last, unread = s.unread(t);
  if (s.preferences['messagePreviews'] == false)
    return '${s.chatHasUnread(t) ? 'Nuovo messaggio' : 'Messaggio'} · ${relative(m['created'])}';
  if (unread > 1) return '$unread nuovi messaggi · ${relative(m['created'])}';
  if (m.str('author') == s.myId &&
      s.readReceipts &&
      m.ids('readBy').any((id) => id != s.myId))
    return 'Visualizzato · ${relative(m['created'])}';
  return '${m.str('author') == s.myId ? 'Tu: ' : ''}${preview(m)} · ${relative(m['created'])}';
}

String preview(J m) =>
    (m.flag('expired') ||
        (m.number('expires') > 0 && m.number('expires') <= now))
    ? 'Messaggio scaduto'
    : switch (m.str('kind')) {
        'image' => '📷 Foto',
        'audio' => '🎙 Messaggio vocale',
        'story' => '↩ ${m.str('text')}',
        'post' => 'Post condiviso',
        _ => m.str('text'),
      };
Future<void> newConversation(BuildContext c) =>
    sheet(c, const NewConversation());

class NewConversation extends StatefulWidget {
  const NewConversation({super.key});
  @override
  State<NewConversation> createState() => _NewConversationState();
}

class _NewConversationState extends State<NewConversation> {
  String query = '';
  bool group = false;
  Set<String> selected = {};
  final title = TextEditingController();
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        users = s.users.where(
          (u) =>
              u.str('id') != s.myId &&
              !s.blocked(u.str('id')) &&
              '${u['name']} ${u['username']}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group ? 'Nuovo gruppo' : 'Nuovo messaggio',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => group = !group),
                child: Text(group ? 'Messaggio' : 'Gruppo'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Cerca persone',
              prefixIcon: GIcon(CupertinoIcons.search, size: 19),
              border: InputBorder.none,
            ),
          ),
        ),
        if (group)
          Padding(
            padding: const EdgeInsets.all(18),
            child: AppInput(title, 'Nome del gruppo'),
          ),
        for (final u in users)
          PersonTile(
            u.str('id'),
            onTap: group
                ? () => setState(
                    () => selected.contains(u.str('id'))
                        ? selected.remove(u.str('id'))
                        : selected.add(u.str('id')),
                  )
                : () => perform(c, () async {
                    final id = await s.openThread(u.str('id'));
                    if (c.mounted) {
                      Navigator.pop(c);
                      open(c, Chat(id: id));
                    }
                  }),
            trailing: group
                ? GIcon(
                    selected.contains(u.str('id'))
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: selected.contains(u.str('id')) ? violet : muted,
                  )
                : null,
          ),
        if (group)
          Padding(
            padding: const EdgeInsets.all(20),
            child: PrimaryButton(
              'Crea gruppo (${selected.length})',
              onTap: selected.length < 2
                  ? null
                  : () => perform(c, () async {
                      if (title.text.trim().isEmpty)
                        throw Exception('Inserisci un nome per il gruppo.');
                      await s.act('group', {
                        'title': title.text.trim(),
                        'users': selected.toList(),
                      });
                      final t = s.threads.firstWhere(
                        (t) =>
                            t.str('title') == title.text.trim() &&
                            t.str('owner') == s.myId,
                      );
                      if (c.mounted) {
                        Navigator.pop(c);
                        open(c, Chat(id: t.str('id')));
                      }
                    }),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class Chat extends StatefulWidget {
  final String id;
  final bool openCamera;
  const Chat({super.key, required this.id, this.openCamera = false});
  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  Timer? presenceTimer;
  double lastEdit = 0;
  bool wasTyping = false;
  void signalTyping(bool active, {String kind = 'typing'}) {
    final s = store;
    if (s == null) return;
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

  final input = TextEditingController(), scroll = ScrollController();
  final focus = FocusNode();
  AudioRecorder? _recorder;
  AudioRecorder get recorder => _recorder ??= AudioRecorder();
  String replyId = '', editId = '';
  String searchQuery = '';
  final Map<String, double> dragOffsets = {};
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
        if (active) {
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
        if (mounted) unawaited(s.threadPresence(widget.id).catchError((_) {}));
      });
      if (widget.openCamera)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) photo(camera: true);
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
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => perform(context, () => s.markRead(widget.id)),
      );
    }
  }

  void changed() {
    if (mounted && store!.chatHasUnread(store!.thread(widget.id))) {
      store!.markRead(widget.id);
    }
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
    super.dispose();
  }

  Future<void> send() async {
    if (input.text.trim().isEmpty || sending) return;
    signalTyping(false);
    setState(() => sending = true);
    await perform(context, () async {
      final s = store!;
      if (editId.isNotEmpty) {
        await s.act('editMessage', {'id': editId, 'text': input.text.trim()});
      } else {
        await s.send(
          widget.id,
          input.text.trim(),
          reply: replyId,
          expiresIn: expiresIn,
        );
      }
      input.clear();
      setState(() {
        replyId = '';
        editId = '';
      });
      if (scroll.hasClients)
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
    });
    if (mounted) setState(() => sending = false);
  }

  Future<void> photo({bool camera = false}) async {
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
        reply: replyId,
        viewOnce: mode != 0,
        maxOpens: mode == 2 ? 2 : 1,
        expiresIn: mode != 0 ? 86400 : expiresIn,
      );
      setState(() => replyId = '');
    });
  }

  void attachments() => sheet(
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
          sheet(
            context,
            EmojiPicker(
              title: 'Invia uno sticker',
              onSelected: (emoji) {
                Navigator.pop(context);
                perform(
                  context,
                  () => store!.send(
                    widget.id,
                    emoji,
                    kind: 'sticker',
                    expiresIn: expiresIn,
                  ),
                );
              },
            ),
            scroll: false,
          );
        }),
        ActionRow(CupertinoIcons.clock, 'Messaggi a scadenza', () {
          Navigator.pop(context);
          expirySettings();
        }),
        const SizedBox(height: 15),
      ],
    ),
  );
  Future<void> expirySettings() async {
    final result = await open<int>(context, MessageExpiry(seconds: expiresIn));
    if (result == null || !mounted) return;
    await perform(context, () async {
      await store!.act('messageExpiry', {'id': widget.id, 'seconds': result});
      setState(() => expiresIn = result);
    });
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
    final s = GpixScope.of(c),
        t = s.thread(widget.id),
        messages = t
            .rows('messages')
            .where((m) => !m.flag('afterRead') || !s.expired(m))
            .toList(),
        group = t.str('owner').isNotEmpty;
    expiresIn = t.number('messageTTL').toInt();
    if (t.isEmpty)
      return Scaffold(
        appBar: AppBar(title: pageTitle('Conversazione')),
        body: const EmptyState(
          CupertinoIcons.chat_bubble,
          'Conversazione non disponibile',
          'Potrebbe essere stata rimossa o l’account bloccato.',
        ),
      );
    final quote = messages.firstWhere(
      (m) => m.str('id') == replyId || m.str('id') == editId,
      orElse: () => {},
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => open(c, ThreadInfo(id: widget.id)),
          child: Row(
            children: [
              if (group)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: FittedBox(child: groupAvatar()),
                )
              else
                GestureDetector(
                  onTap: () => s.stories(s.other(t)).isNotEmpty
                      ? open(c, StoryViewer(user: s.other(t)))
                      : open(c, Profile(user: s.other(t))),
                  child: ChatPresenceAvatar(
                    s.other(t),
                    size: 38,
                    ring: s.hasUnseenStories(s.other(t)),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.threadName(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group) ChatActivityLabel(thread: t),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerca nei messaggi',
            icon: const GIcon(CupertinoIcons.search),
            onPressed: () => showSearchMessages(context, widget.id),
          ),

          if (!group) ...[
            IconButton(
              tooltip: 'Chiamata vocale',
              onPressed: () => launchCall(c, widget.id, false),
              icon: const GIcon(CupertinoIcons.phone, size: 22),
            ),
            IconButton(
              tooltip: 'Videochiamata',
              onPressed: () => launchCall(c, widget.id, true),
              icon: const GIcon(CupertinoIcons.video_camera, size: 25),
            ),
          ],

          IconButton(
            tooltip: 'Impostazioni messaggi',
            onPressed: expirySettings,
            icon: const GIcon(CupertinoIcons.timer, size: 22),
          ),
          if (group)
            IconButton(
              tooltip: 'Dettagli chat',
              onPressed: () => open(c, ThreadInfo(id: widget.id)),
              icon: const GIcon(CupertinoIcons.info, size: 23),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!group && activityLabel(s, s.other(t)).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: ChatActivityLabel(thread: t, wrap: true),
            ),
          const Divider(height: 1, thickness: .5),
          if (expiresIn != 0)
            InkWell(
              onTap: expirySettings,
              child: Container(
                width: double.infinity,
                color: subdued(c),
                padding: const EdgeInsets.all(10),
                child: Text(
                  'Nuovi messaggi: eliminazione dopo ${expiryLabel(expiresIn)} · Modifica',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: violet),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(13, 20, 13, 15),
              itemCount: messages.length + 1,
              itemBuilder: (c, i) {
                if (i == messages.length)
                  return Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 35),
                    child: Column(
                      children: [
                        if (group)
                          groupAvatar()
                        else
                          Avatar(s.other(t), size: 75),
                        const SizedBox(height: 14),
                        Text(
                          s.threadName(t),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          group
                              ? 'Un posto per le vostre conversazioni'
                              : '@${s.user(s.other(t)).str('username')}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 16),
                        if (!group)
                          OutlinedButton(
                            onPressed: () => open(c, Profile(user: s.other(t))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: line),
                            ),
                            child: const Text(
                              'Visualizza profilo',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  );
                final m = messages[messages.length - 1 - i];
                return message(c, m, messages, i, group);
              },
            ),
          ),
          if (s.typingPeers(widget.id).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: ConversationActivity(thread: t),
            ),
          if (quote.isNotEmpty)
            Container(
              color: subdued(c),
              padding: const EdgeInsets.only(left: 18),
              child: Row(
                children: [
                  Container(width: 2, height: 32, color: violet),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editId.isNotEmpty
                              ? 'Modifica messaggio'
                              : 'Rispondi a ${s.user(quote.str('author')).str('username')}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview(quote),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      replyId = '';
                      editId = '';
                      input.clear();
                    }),
                    icon: const GIcon(CupertinoIcons.xmark, size: 17),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
              child: Container(
                key: const ValueKey('chat-composer-pill'),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  gradient: crystalGradient(c),
                  border: Border.all(color: Theme.of(c).dividerColor),
                  borderRadius: BorderRadius.circular(29),
                ),
                child: recording
                    ? Row(
                        children: [
                          IconButton(
                            tooltip: 'Scarta vocale',
                            onPressed: () => voice(cancel: true),
                            icon: const GIcon(
                              CupertinoIcons.trash,
                              color: danger,
                              size: 22,
                            ),
                          ),
                          const GIcon(
                            CupertinoIcons.mic_fill,
                            color: danger,
                            size: 18,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Registrazione · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Invia vocale',
                            onPressed: voice,
                            icon: const GIcon(
                              CupertinoIcons.paperplane_fill,
                              color: violet,
                              size: 23,
                            ),
                          ),
                        ],
                      )
                    : IconButtonTheme(
                        data: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 42),
                            maximumSize: const Size(38, 48),
                            padding: const EdgeInsets.all(5),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Fotocamera chat',
                              onPressed: () => photo(camera: true),
                              style: IconButton.styleFrom(
                                backgroundColor: violet,
                                foregroundColor: Colors.white,
                                fixedSize: const Size(38, 38),
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(
                                CupertinoIcons.camera,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: input,
                                focusNode: focus,
                                minLines: 1,
                                maxLines: 5,
                                onChanged: (_) => edited(),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: foreground(c),
                                ),
                                decoration: InputDecoration(
                                  filled: false,
                                  hintText: expiresIn != 0
                                      ? 'Scrivi a scadenza…'
                                      : 'Scrivi…',
                                  hintStyle: TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (input.text.trim().isEmpty) ...[
                              IconButton(
                                tooltip: 'Foto',
                                onPressed: photo,
                                icon: const GIcon(
                                  CupertinoIcons.photo,
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Registra vocale',
                                onPressed: voice,
                                icon: const GIcon(CupertinoIcons.mic, size: 23),
                              ),
                              IconButton(
                                tooltip: 'Allegati',
                                onPressed: attachments,
                                icon: const GIcon(
                                  CupertinoIcons.plus_circle,
                                  size: 25,
                                ),
                              ),
                            ] else
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: violet,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(54, 36),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: sending ? null : send,
                                child: const Text(
                                  'Invia',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget message(
    BuildContext c,
    J m,
    List<J> all,
    int reverseIndex,
    bool group,
  ) {
    final s = GpixScope.of(c),
        own = m.str('author') == s.myId,
        quote = all.firstWhere(
          (x) => x.str('id') == m.str('reply'),
          orElse: () => {},
        ),
        reactions = m.obj('reactions');
    final emojiOnly =
        m.str('kind') == 'text' &&
        m.str('text').trim().isNotEmpty &&
        m.str('text').runes.length <= 24 &&
        m
            .str('text')
            .runes
            .every(
              (r) =>
                  (r >= 0x1f000 && r <= 0x1faff) ||
                  (r >= 0x2600 && r <= 0x27bf) ||
                  [0xfe0f, 0xfe0e, 0x200d, 32].contains(r),
            );
    final story = m.obj('story');
    final gone = s.expired(m), once = m.flag('viewOnce');
    final sharedId = m.str('post', story.str('postId'));
    final shared = s.post(sharedId);
    final showTime =
        reverseIndex == all.length - 1 ||
        ((m.number('created') -
                    all[all.length - 2 - reverseIndex].number('created'))
                .abs() >
            900);
    return Column(
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              '${relative(m['created'])} · ${clock(m['created'])}',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(
            left: own ? 48 : 0,
            right: own ? 0 : 48,
            bottom: reactions.isEmpty ? 9 : 22,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: own
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!own) ...[
                Avatar(m.str('author'), size: 25),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    dragOffsets[m.str('id')] =
                        (dragOffsets[m.str('id')] ?? 0) + d.delta.dx;
                  },
                  onHorizontalDragCancel: () => dragOffsets.remove(m.str('id')),
                  onHorizontalDragEnd: (d) {
                    final distance = dragOffsets.remove(m.str('id')) ?? 0;
                    if (distance.abs() > 48 ||
                        (d.primaryVelocity ?? 0).abs() > 120) {
                      setState(() {
                        replyId = m.str('id');
                        editId = '';
                      });
                      focus.requestFocus();
                    }
                  },
                  onDoubleTap: () => perform(
                    c,
                    () => s.act('react', {
                      'id': m['id'],
                      'emoji': reactions.str(s.myId) == '❤️' ? '' : '❤️',
                    }),
                  ),
                  onLongPress: () => options(c, m),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        crossAxisAlignment: own
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (group && !own)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 10,
                                bottom: 4,
                              ),
                              child: Text(
                                s.user(m.str('author')).str('username'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            ),
                          if (quote.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                              decoration: BoxDecoration(
                                color: subdued(c),
                                borderRadius: BorderRadius.circular(9),
                                border: const Border(
                                  left: BorderSide(color: violet, width: 2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.user(quote.str('author')).str('username'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    preview(quote),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (sharedId.isNotEmpty)
                            InkWell(
                              onTap: shared.isEmpty
                                  ? null
                                  : () => open(c, PostPage(id: sharedId)),
                              child: Container(
                                width: 195,
                                margin: const EdgeInsets.only(bottom: 5),
                                decoration: BoxDecoration(
                                  color: subdued(c),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (shared.isNotEmpty) ...[
                                      MediaView(
                                        shared.str('media'),
                                        width: 195,
                                        height: 195,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Text(
                                          '${s.user(shared.str('author')).str('username')} · ${shared.str('text')}',
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const Padding(
                                        padding: EdgeInsets.all(18),
                                        child: Text(
                                          'Questo post non è disponibile.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: muted,
                                          ),
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
                              margin: const EdgeInsets.only(bottom: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    StoryCanvas(story: story),
                                    const Positioned(
                                      top: 10,
                                      left: 10,
                                      right: 10,
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
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: m.str('kind') == 'image' ? 3 : 14,
                              vertical: m.str('kind') == 'image' ? 3 : 11,
                            ),
                            decoration: BoxDecoration(
                              color: m.str('kind') == 'sticker' || emojiOnly
                                  ? Colors.transparent
                                  : own
                                  ? violet
                                  : subdued(c),
                              gradient:
                                  own &&
                                      m.str('kind') != 'sticker' &&
                                      !emojiOnly
                                  ? auraAction
                                  : m.str('kind') == 'sticker' || emojiOnly
                                  ? null
                                  : crystalGradient(c),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: const Radius.circular(24),
                                bottomRight: const Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (gone)
                                  const Text(
                                    'Messaggio scaduto',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: muted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else if (once)
                                  InkWell(
                                    onTap:
                                        own ||
                                            m.ids('openedBy').contains(s.myId)
                                        ? null
                                        : () => open(
                                            c,
                                            OncePhoto(id: m.str('id')),
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 13,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GIcon(
                                            (own
                                                    ? m
                                                          .ids('openedBy')
                                                          .isNotEmpty
                                                    : m
                                                          .ids('openedBy')
                                                          .contains(s.myId))
                                                ? CupertinoIcons
                                                      .check_mark_circled
                                                : CupertinoIcons.timer,
                                            color: own
                                                ? Colors.white
                                                : foreground(c),
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              (own
                                                      ? m
                                                            .ids('openedBy')
                                                            .isNotEmpty
                                                      : m
                                                            .ids('openedBy')
                                                            .contains(s.myId))
                                                  ? 'Foto aperta'
                                                  : m.number('maxOpens', 1) == 2
                                                  ? (m
                                                                .obj(
                                                                  'openCounts',
                                                                )
                                                                .number(
                                                                  s.myId,
                                                                ) >
                                                            0
                                                        ? 'Riproduci di nuovo'
                                                        : 'Foto · consenti replay')
                                                  : own
                                                  ? 'Foto · una visualizzazione'
                                                  : 'Tocca per aprire · una volta',
                                              style: TextStyle(
                                                color: own
                                                    ? Colors.white
                                                    : foreground(c),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (m.str('kind') == 'sticker' ||
                                    emojiOnly)
                                  Text(
                                    m.str('text'),
                                    style: const TextStyle(
                                      fontSize: 55,
                                      height: 1.2,
                                    ),
                                  )
                                else if (m.str('kind') == 'image' ||
                                    m.str('kind') == 'gif')
                                  ProtectedChatImage(
                                    key: ValueKey('protected-${m.str('id')}'),
                                    protected:
                                        !own &&
                                        s.preferences.flag('imageProtection'),
                                    reference: m.str('media'),
                                    expiresAt: m.number('readExpiresAt'),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: MediaView(
                                        m.str('media'),
                                        width: 210,
                                        height: 240,
                                      ),
                                    ),
                                  )
                                else if (m.str('kind') == 'audio')
                                  AudioBubble(
                                    key: ValueKey(m.str('id')),
                                    reference: m.str('media'),
                                    own: own,
                                  )
                                else
                                  Text(
                                    m.str('text'),
                                    style: TextStyle(
                                      color: own ? Colors.white : foreground(c),
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                if (m.flag('edited'))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'modificato',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: own ? Colors.white70 : muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (reactions.isNotEmpty)
                        Positioned(
                          bottom: -13,
                          right: own ? 7 : null,
                          left: own ? null : 7,
                          child: GestureDetector(
                            onTap: () => sheet(
                              c,
                              Column(
                                children: [
                                  const Text(
                                    'Reazioni',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  for (final e in reactions.entries)
                                    PersonTile(
                                      e.key,
                                      trailing: Text(
                                        '${e.value}',
                                        style: const TextStyle(fontSize: 23),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: subdued(c),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                reactions.values.join(' '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (own &&
            (reverseIndex == 0 ||
                all.lastWhere((x) => x.str('author') == s.myId).str('id') ==
                    m.str('id')))
          Padding(
            padding: const EdgeInsets.only(right: 7, top: 2, bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => messageInfo(c, m, s.thread(widget.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    !s.readReceipts
                        ? 'Conferme disattivate'
                        : (own
                              ? m.ids('openedBy').isNotEmpty
                              : m.ids('openedBy').contains(s.myId))
                        ? 'Foto aperta'
                        : m.ids('readBy').any((id) => id != s.myId)
                        ? 'Visualizzato'
                        : 'Inviato',
                    style: TextStyle(
                      fontSize: 10,
                      color: m.ids('readBy').any((id) => id != s.myId)
                          ? violet
                          : muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> options(BuildContext c, J m) => sheet(
    c,
    Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final emoji in ['❤️', '🔥', '😂', '😍', '👏', '🌈'])
                GestureDetector(
                  onTap: () {
                    Navigator.pop(c);
                    perform(
                      c,
                      () => store!.act('react', {
                        'id': m['id'],
                        'emoji': m.obj('reactions').str(store!.myId) == emoji
                            ? ''
                            : emoji,
                      }),
                    );
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        ActionRow(CupertinoIcons.info, 'Informazioni', () {
          Navigator.pop(c);
          messageInfo(c, m, store!.thread(widget.id));
        }),
        ActionRow(CupertinoIcons.reply, 'Rispondi', () {
          Navigator.pop(c);
          setState(() {
            replyId = m.str('id');
            editId = '';
          });
          focus.requestFocus();
        }),
        ActionRow(CupertinoIcons.arrowshape_turn_up_right, 'Inoltra', () {
          Navigator.pop(c);
          if (m.flag('viewOnce') ||
              m.number('expires') > 0 ||
              m.flag('afterRead')) {
            notice(c, 'Questo contenuto non può essere inoltrato.');
            return;
          }
          sheet(
            c,
            Column(
              children: [
                const Text(
                  'Inoltra a',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                for (final u in store!.users.where(
                  (u) =>
                      u.str('id') != store!.myId &&
                      !store!.blocked(u.str('id')),
                ))
                  PersonTile(
                    u.str('id'),
                    onTap: () => perform(c, () async {
                      await store!.act('forward', {
                        'id': m['id'],
                        'user': u['id'],
                      });
                      if (c.mounted) {
                        Navigator.pop(c);
                        notice(c, 'Messaggio inoltrato');
                      }
                    }),
                  ),
              ],
            ),
          );
        }),
        if (m.str('author') == store!.myId) ...[
          if (m.str('kind') == 'text')
            ActionRow(CupertinoIcons.pencil, 'Modifica', () {
              Navigator.pop(c);
              setState(() {
                editId = m.str('id');
                replyId = '';
                input.text = m.str('text');
              });
              focus.requestFocus();
            }),
          ActionRow(CupertinoIcons.trash, 'Annulla invio', () async {
            Navigator.pop(c);
            if (await gpixAlert(
                  c,
                  'Annullare l’invio?',
                  'Il messaggio verrà rimosso dalla conversazione.',
                  confirm: 'Annulla invio',
                  destructive: true,
                  cancel: true,
                ) &&
                c.mounted)
              perform(c, () => store!.act('deleteMessage', {'id': m['id']}));
          }, destructive: true),
        ],
        const SizedBox(height: 17),
      ],
    ),
  );
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
    final s = GpixScope.of(c),
        t = s.thread(id),
        group = t.str('owner').isNotEmpty,
        admin = t.str('owner') == s.myId;
    return Scaffold(
      appBar: AppBar(title: pageTitle('Dettagli chat')),
      body: ListView(
        children: [
          ListTile(
            leading: const GIcon(CupertinoIcons.photo),
            title: const Text('Contenuti condivisi'),
            onTap: () => open(c, SharedMedia(thread: id)),
          ),
          const SizedBox(height: 25),
          Center(child: group ? groupAvatar() : Avatar(s.other(t), size: 80)),
          const SizedBox(height: 15),
          Text(
            s.threadName(t),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 25),
          if (group && admin)
            ActionRow(CupertinoIcons.pencil, 'Cambia nome', () async {
              final text = await textDialog(
                c,
                'Nome del gruppo',
                t.str('title'),
              );
              if (text != null && text.isNotEmpty && c.mounted)
                perform(
                  c,
                  () => s.act('renameGroup', {'id': id, 'title': text}),
                );
            }),
          if (group && admin)
            ActionRow(
              CupertinoIcons.person_add,
              'Aggiungi partecipanti',
              () => sheet(
                c,
                Column(
                  children: [
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
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Partecipanti',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
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
                            c.mounted)
                          perform(
                            c,
                            () =>
                                s.act('removeMember', {'id': id, 'user': uid}),
                          );
                      },
                      icon: const GIcon(
                        CupertinoIcons.minus_circled,
                        color: danger,
                        size: 22,
                      ),
                    )
                  : null,
            ),
          if (group)
            ActionRow(
              CupertinoIcons.square_arrow_left,
              'Abbandona gruppo',
              () async {
                if (await gpixAlert(
                      c,
                      'Abbandonare il gruppo?',
                      'Non riceverai più i messaggi di questo gruppo.',
                      confirm: 'Abbandona',
                      cancel: true,
                      destructive: true,
                    ) &&
                    c.mounted)
                  perform(c, () async {
                    await s.act('leaveGroup', {'id': id});
                    if (c.mounted) Navigator.popUntil(c, (r) => r.isFirst);
                  });
              },
              destructive: true,
            ),
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
        const GIcon(CupertinoIcons.timer, size: 54, color: violet),
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
              color: value == seconds ? violet : muted,
            ),
            onTap: () => setState(() => value = seconds),
          ),
        const SizedBox(height: 24),
        PrimaryButton('Salva durata', onTap: () => Navigator.pop(c, value)),
      ],
    ),
  );
}

Future<void> showSearchMessages(BuildContext c, String thread) => sheet(
  c,
  StatefulBuilder(
    builder: (menu, update) {
      return _ChatSearch(thread: thread);
    },
  ),
);

class _ChatSearch extends StatefulWidget {
  final String thread;
  const _ChatSearch({required this.thread});
  @override
  State<_ChatSearch> createState() => _ChatSearchState();
}

class _ChatSearchState extends State<_ChatSearch> {
  String query = '';
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final messages = s
        .thread(widget.thread)
        .rows('messages')
        .where(
          (m) =>
              !m.flag('viewOnce') &&
              !m.flag('afterRead') &&
              (m.number('expires') == 0 ||
                  m.number('expires') >
                      DateTime.now().millisecondsSinceEpoch / 1000) &&
              query.trim().isNotEmpty &&
              m.str('text').toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.viewInsetsOf(c).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Cerca nei messaggi',
              prefixIcon: Icon(CupertinoIcons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          SizedBox(
            height: 300,
            child: ListView(
              children: [
                if (query.isNotEmpty && messages.isEmpty)
                  const ListTile(title: Text('Nessun risultato')),
                for (final m in messages)
                  ListTile(
                    title: Text(m.str('text')),
                    subtitle: Text(
                      '${s.user(m.str('author')).str('username')} · ${relative(m['created'])}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
              height: 240,
              decoration: BoxDecoration(
                color: surface(c),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GIcon(CupertinoIcons.eye_slash, size: 32),
                  SizedBox(height: 12),
                  Text('Foto nascosta'),
                  SizedBox(height: 8),
                  Text(
                    'Tocca per mostrare',
                    style: TextStyle(color: muted, fontSize: 12),
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
  if (s.online(id)) return 'Online';
  final seconds = s.user(id).number('lastActive');
  if (seconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(
        (seconds * 1000).toInt(),
      ).toLocal(),
      today = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final clock = '${two(date.hour)}:${two(date.minute)}';
  final day = DateTime(date.year, date.month, date.day),
      current = DateTime(today.year, today.month, today.day);
  if (day == current) return 'Ultimo accesso oggi alle $clock';
  if (day == current.subtract(const Duration(days: 1)))
    return 'Ultimo accesso ieri alle $clock';
  return 'Ultimo accesso ${two(date.day)}/${two(date.month)}/${date.year} alle $clock';
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Avatar(user, size: size, ring: ring),
        if (s.online(user))
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              label: 'Online',
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
                color: violet,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}
