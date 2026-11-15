import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'community.dart' show CloseFriends;
import 'messages.dart' show Chat;
import 'note_pickers.dart';

class NoteBubble extends StatelessWidget {
  const NoteBubble({
    super.key,
    required this.text,
    this.details = const {},
    this.placeholder = false,
    this.maxLines = 2,
    this.fitContents = false,
  });

  final String text;
  final J details;
  final bool placeholder, fitContents;
  final int maxLines;
  static const _fontSize = 11.5;

  @override
  Widget build(BuildContext context) {
    final caption = text.isEmpty ? _attachmentTitle(details) : text;
    final symbol = details.obj('music').isNotEmpty
        ? CupertinoIcons.waveform
        : details.str('place').isNotEmpty
        ? CupertinoIcons.placemark
        : null;
    final color = _noteInk(context, details, subtle: placeholder);
    final label = Text(
      caption,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: _fontSize, height: 1.06, color: color),
    );
    return _NoteCloud(
      details: details,
      fitContents: fitContents,
      child: symbol == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GIcon(symbol, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(child: label),
              ],
            ),
    );
  }
}

String _attachmentTitle(J details) {
  final track = details.obj('music');
  if (track.isNotEmpty) return track.str('title', 'Musica');
  if (details.str('place').isNotEmpty) return details.str('place');
  return details.str('gif').isNotEmpty ? 'GIF' : '';
}

Color _noteFill(BuildContext context, J details) {
  final value = int.tryParse(
    details.str('color').replaceFirst('#', ''),
    radix: 16,
  );
  return value == null
      ? (Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Theme.of(context).colorScheme.surfaceContainerHighest)
      : Color(0xff000000 | value);
}

Color _noteInk(BuildContext context, J details, {bool subtle = false}) {
  if (details.str('color').isEmpty)
    return subtle ? secondaryText(context) : foreground(context);
  final dark =
      ThemeData.estimateBrightnessForColor(_noteFill(context, details)) ==
      Brightness.dark;
  return dark
      ? (subtle ? Colors.white70 : Colors.white)
      : const Color(0xff151820);
}

class _NoteCloud extends StatelessWidget {
  const _NoteCloud({
    required this.details,
    required this.child,
    this.fullSize = false,
    this.fitContents = false,
  });

  final J details;
  final Widget child;
  final bool fullSize, fitContents;

  @override
  Widget build(BuildContext context) {
    final fill = _noteFill(context, details);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: const ValueKey('note-bubble-body'),
          constraints: BoxConstraints(
            minHeight: fullSize ? 56 : 40,
            minWidth: fitContents ? 44 : 0,
          ),
          padding: EdgeInsets.fromLTRB(
            9,
            fullSize ? 9 : 6,
            9,
            fullSize ? 22 : 17,
          ),
          decoration: ShapeDecoration(
            color: fill,
            shape: _NoteCloudShape(fullSize: fullSize),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.light
                      ? .11
                      : .26,
                ),
                blurRadius: fullSize ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Align(
            heightFactor: 1,
            widthFactor: fitContents ? 1 : null,
            child: child,
          ),
        ),
        if (details.str('emoji').isNotEmpty)
          Positioned(
            left: fullSize ? -7 : -4,
            top: fullSize ? -10 : -5,
            child: Transform.rotate(
              angle: -.15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _noteFill(context, const {}),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(color: Color(0x15000000), blurRadius: 7),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(fullSize ? 4 : 2),
                  child: Text(
                    details.str('emoji'),
                    style: TextStyle(
                      fontSize: fullSize ? 17 : 12,
                      height: 1.05,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoteCloudShape extends ShapeBorder {
  const _NoteCloudShape({required this.fullSize});

  final bool fullSize;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final tail = fullSize ? 13.0 : 11.0;
    final radius = fullSize ? 17.0 : 14.0;
    final body = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom - tail,
    );
    final x = rect.left + (fullSize ? 19 : 16);
    final joined = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius))),
      Path()..addOval(
        Rect.fromCenter(
          center: Offset(x, body.bottom - 1.5),
          width: fullSize ? 17 : 13,
          height: fullSize ? 14 : 12,
        ),
      ),
    );
    return joined..addOval(
      Rect.fromCircle(
        center: Offset(x + 4, rect.bottom - 2.5),
        radius: fullSize ? 3 : 2.6,
      ),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  ShapeBorder scale(double t) => this;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
}

class NotePortrait extends StatelessWidget {
  const NotePortrait(
    this.owner, {
    super.key,
    required this.size,
    this.details = const {},
  });

  final String owner;
  final double size;
  final J details;

  @override
  Widget build(BuildContext context) {
    final gif = details.str('gif');
    return gif.isEmpty
        ? Avatar(owner, size: size)
        : ClipRRect(
            borderRadius: BorderRadius.circular(size * .18),
            child: SizedBox.square(
              dimension: size,
              child: MediaView(
                gif,
                fallback: const GIcon(CupertinoIcons.photo),
              ),
            ),
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
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final notes = store.notes;
    final own = notes
        .where((note) => note.str('owner') == store.myId)
        .firstOrNull;
    final scaler = MediaQuery.textScalerOf(context);
    final textSize = scaler.scale(12.5);
    final bubbleTextSize = scaler.scale(NoteBubble._fontSize);
    final portraitTop = 17 + 3.32 * bubbleTextSize;
    return SizedBox(
      height: portraitTop + 96 + textSize * 1.25,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(3, 4, 8, 6),
        children: [
          _NoteTile(
            owner: store.myId,
            note: own,
            own: true,
            portraitTop: portraitTop,
          ),
          for (final note in notes)
            if (note.str('owner') != store.myId)
              _NoteTile(
                owner: note.str('owner'),
                note: note,
                portraitTop: portraitTop,
              ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.owner,
    required this.note,
    required this.portraitTop,
    this.own = false,
  });

  final String owner;
  final J? note;
  final double portraitTop;
  final bool own;
  static const _portraitSize = 77.0;
  static const _tailOverlap = 3.0;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final details = note?.obj('details') ?? const <String, dynamic>{};
    final person = store.user(owner);
    return SizedBox(
      width: 109,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => own ? manageOwnNote(context) : replyNote(context, note!),
        onDoubleTap: own || note == null
            ? null
            : () => perform(
                context,
                () => store.act('noteReact', {
                  'user': owner,
                  'created': note!['created'],
                  'enabled': true,
                }),
              ),
        child: Column(
          children: [
            SizedBox(
              width: 91,
              height: portraitTop + _portraitSize,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: portraitTop,
                    child: NotePortrait(
                      owner,
                      size: _portraitSize,
                      details: details,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _portraitSize - _tailOverlap,
                    child: Center(
                      child: NoteBubble(
                        text: note?.str('text') ?? 'Lascia una nota…',
                        details: details,
                        placeholder: note == null,
                        fitContents: true,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  if (note?.flag('likedByMe') == true ||
                      own && (note?.number('likesCount') ?? 0) > 0)
                    Positioned(
                      right: 7,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: surface(context),
                        child: const GIcon(
                          CupertinoIcons.heart_fill,
                          color: danger,
                          size: 14,
                        ),
                      ),
                    ),
                  if (note?.str('audience') == 'close')
                    const Positioned(
                      left: 7,
                      bottom: 0,
                      child: GIcon(
                        CupertinoIcons.star_circle_fill,
                        color: Color(0xff25bd61),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              own ? 'La tua nota' : person.str('name', person.str('username')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.15,
                color: own ? secondaryText(context) : foreground(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> manageOwnNote(BuildContext context) async {
  final store = GpixScope.of(context, listen: false);
  final note = store.notes
      .where((entry) => entry.str('owner') == store.myId)
      .firstOrNull;
  if (note == null) {
    await editNote(context);
    return;
  }

  final action = await noteSheet<String>(
    context,
    Builder(
      builder: (menu) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PublishedNote(note: note),
            const SizedBox(height: 9),
            Text(
              '${note.str('audience') == 'close' ? 'Condivisa con gli amici più stretti' : 'Condivisa con gli amici'} · ${relative(note['created'])}',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText(menu), fontSize: 12),
            ),
            const SizedBox(height: 19),
            FilledButton(
              style: _noteButton(radius: 12, height: 44),
              onPressed: () => Navigator.pop(menu, 'new'),
              child: const Text('Lascia una nuova nota'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(menu, 'delete'),
              style: TextButton.styleFrom(foregroundColor: danger),
              child: const Text('Elimina nota'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'new') await editNote(context);
  if (action == 'delete') {
    await perform(context, () => store.act('note', {'delete': true}));
  }
}

Future<void> editNote(BuildContext context) =>
    open(context, const _NoteEditor());

class _NoteEditor extends StatefulWidget {
  const _NoteEditor();

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  final text = TextEditingController();
  final focus = FocusNode();

  String audience = 'mutual';
  J details = {};
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> pickStyle() async {
    focus.unfocus();
    final style = await open<J>(
      context,
      _BubbleEditor(caption: text.text.trim(), details: details),
    );
    if (!mounted) return;
    if (style != null) {
      setState(() {
        details.remove('color');
        details.remove('emoji');
        details.addAll(style);
      });
    }
    focus.requestFocus();
  }

  Future<void> pickAttachment(String kind) async {
    focus.unfocus();
    final Object? attachment = switch (kind) {
      'gif' => await pickNoteGif(context),
      'music' => await pickNoteMusic(context),
      _ => await pickNotePlace(context, details.str('place')),
    };
    if (!mounted) return;
    if (attachment != null) {
      setState(() {
        details
          ..remove('gif')
          ..remove('music')
          ..remove('place')
          ..[kind] = attachment;
      });
    }
    focus.requestFocus();
  }

  Future<void> pickAudience(GpixStore store) async {
    focus.unfocus();
    final result = await noteSheet<String>(
      context,
      Builder(
        builder: (menu) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Condividi con',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              for (final (value, title, description, icon) in [
                (
                  'mutual',
                  'Amici',
                  'Follower che segui a tua volta',
                  CupertinoIcons.person_2_fill,
                ),
                (
                  'close',
                  'Amici più stretti',
                  '${store.state.ids('closeFriends').length} persone',
                  CupertinoIcons.star_fill,
                ),
              ])
                ListTile(
                  leading: GIcon(
                    icon,
                    color: value == 'close'
                        ? const Color(0xff25bd61)
                        : foreground(menu),
                  ),
                  title: Text(title),
                  subtitle: Text(description),
                  trailing: GIcon(
                    value == audience
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    color: value == audience ? noteAccent : secondaryText(menu),
                  ),
                  onTap: () => Navigator.pop(menu, value),
                ),
              TextButton(
                onPressed: () => Navigator.pop(menu, 'edit'),
                child: const Text('Modifica amici più stretti'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (result == 'edit') {
      await open(context, const CloseFriends());
    } else if (result != null) {
      setState(() => audience = result);
    }
    if (mounted) focus.requestFocus();
  }

  Future<void> publish(GpixStore store) => perform(context, () async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final track = details.obj('music');
      await store.act('note', {
        'text': text.text.trim(),
        'audience': audience,
        if (details.isNotEmpty)
          'details': {
            ...details,
            if (!store.demo && track.isNotEmpty && track.str('spotify').isEmpty)
              'music': {'id': track.str('id')},
          },
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  });

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final attachment = _attachmentTitle(details);
    final hasGif = details.str('gif').isNotEmpty;
    final hasMusic = details.obj('music').isNotEmpty;
    final canShare =
        !busy && (text.text.trim().isNotEmpty || attachment.isNotEmpty);
    return Scaffold(
      appBar: _noteHeader(context, close: true),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: const Alignment(0, .055),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NoteStage(
                        owner: store.myId,
                        details: details,
                        width: hasMusic ? 120 : 110,
                        editor: TextField(
                          key: const ValueKey('note-text'),
                          controller: text,
                          focusNode: focus,
                          autofocus: true,
                          maxLength: 60,
                          minLines: 1,
                          maxLines: 3,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: noteAccent,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.03,
                            color: _noteInk(context, details),
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration:
                              InputDecoration.collapsed(
                                hintText: 'Non riesco a\ndecidere…',
                                hintStyle: TextStyle(
                                  color: _noteInk(
                                    context,
                                    details,
                                    subtle: true,
                                  ),
                                ),
                              ).copyWith(
                                counterText: '',
                                filled: false,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                              ),
                        ),
                        onStyle: hasGif ? null : pickStyle,
                        onRemove: attachment.isEmpty
                            ? null
                            : () => setState(() {
                                details
                                  ..remove('gif')
                                  ..remove('place')
                                  ..remove('music');
                              }),
                      ),
                      if (attachment.isEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NoteTool(
                              label: 'Musica',
                              icon: CupertinoIcons.music_note_2,
                              color: const Color(0xffed2867),
                              onTap: () => pickAttachment('music'),
                            ),
                            const SizedBox(width: 16),
                            _NoteTool(
                              label: 'Luogo',
                              icon: CupertinoIcons.placemark,
                              color: const Color(0xff7838f4),
                              onTap: () => pickAttachment('place'),
                            ),
                            const SizedBox(width: 16),
                            _NoteTool(
                              label: 'GIF',
                              color: const Color(0xff4bcf6f),
                              onTap: () => pickAttachment('gif'),
                            ),
                          ],
                        ),
                      ] else
                        SizedBox(height: hasMusic ? 57 : 43),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: busy ? null : () => pickAudience(store),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GIcon(
                              audience == 'close'
                                  ? CupertinoIcons.star_fill
                                  : CupertinoIcons.person_2_fill,
                              size: 14,
                              color: audience == 'close'
                                  ? const Color(0xff25bd61)
                                  : foreground(context),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                audience == 'close'
                                    ? 'Amici più stretti'
                                    : 'Condividi con gli amici',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const GIcon(CupertinoIcons.chevron_right, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: canShare ? () => publish(store) : null,
                    style: _noteButton(radius: 24, height: 40).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(88, 40)),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 15),
                      ),
                    ),
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

ButtonStyle _noteButton({required double radius, required double height}) =>
    FilledButton.styleFrom(
      backgroundColor: noteAccent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xffa2b9f7),
      disabledForegroundColor: const Color(0xffdae3ff),
      minimumSize: Size(0, height),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

PreferredSizeWidget _noteHeader(BuildContext context, {bool close = false}) =>
    AppBar(
      toolbarHeight: 58,
      leadingWidth: 72,
      centerTitle: true,
      title: close
          ? null
          : const Text(
              'Bubble Editor',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
      leading: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton(
            tooltip: close ? 'Chiudi nota' : 'Indietro',
            onPressed: () => Navigator.maybePop(context),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(45),
              side: BorderSide(
                color: Theme.of(context).dividerColor,
                width: .6,
              ),
              backgroundColor: surface(context),
              shadowColor: Colors.black12,
              elevation: 2,
              shape: const CircleBorder(),
            ),
            icon: GIcon(
              close ? CupertinoIcons.xmark : CupertinoIcons.chevron_left,
              size: close ? 25 : 23,
            ),
          ),
        ),
      ),
    );

class _NoteStage extends StatelessWidget {
  const _NoteStage({
    required this.owner,
    required this.details,
    required this.editor,
    this.width = 110,
    this.mutedPhoto = false,
    this.onStyle,
    this.onRemove,
    this.onEmoji,
  });

  final String owner;
  final J details;
  final Widget editor;
  final double width;
  final bool mutedPhoto;
  final VoidCallback? onStyle, onRemove, onEmoji;

  @override
  Widget build(BuildContext context) {
    final track = details.obj('music');
    final place = details.str('place');
    final title = track.isNotEmpty ? track.str('title') : place;
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: mutedPhoto ? .44 : 1,
                  child: NotePortrait(
                    owner,
                    size: details.str('gif').isEmpty ? 96 : 94,
                    details: details,
                  ),
                ),
                if (onStyle != null)
                  Positioned(
                    right: 0,
                    bottom: 1,
                    child: _StageButton(
                      label: 'Personalizza la bolla',
                      size: 27,
                      onTap: onStyle!,
                      child: const _PaletteGlyph(size: 19),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NoteCloud(
                details: onEmoji == null
                    ? details
                    : (Map<String, dynamic>.of(details)..remove('emoji')),
                fullSize: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty) ...[
                      Row(
                        children: [
                          const SizedBox(width: 1),
                          GIcon(
                            track.isNotEmpty
                                ? CupertinoIcons.waveform
                                : CupertinoIcons.placemark,
                            size: 13,
                            color: _noteInk(context, details),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: _noteInk(context, details),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (track.str('artist').isNotEmpty)
                        Text(
                          track.str('artist'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: _noteInk(context, details, subtle: true),
                          ),
                        ),
                      const SizedBox(height: 3),
                    ],
                    editor,
                  ],
                ),
              ),
              const SizedBox(height: 81),
            ],
          ),
          if (onRemove != null)
            Positioned(
              right: -4,
              top: -4,
              child: _StageButton(
                label: 'Rimuovi allegato',
                size: 18,
                dark: true,
                onTap: onRemove!,
                child: GIcon(
                  CupertinoIcons.xmark,
                  size: 11,
                  color: surface(context),
                ),
              ),
            ),
          if (onEmoji != null)
            Positioned(
              left: -10,
              top: -14,
              child: Transform.rotate(
                angle: -.16,
                child: _StageButton(
                  label: 'Scegli emoji',
                  size: 36,
                  onTap: onEmoji!,
                  child: details.str('emoji').isEmpty
                      ? const GIcon(
                          CupertinoIcons.smiley,
                          size: 19,
                          color: Color(0xffed2867),
                        )
                      : Text(
                          details.str('emoji'),
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.label,
    required this.size,
    required this.onTap,
    required this.child,
    this.dark = false,
  });

  final String label;
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      child: Material(
        color: dark ? foreground(context) : surface(context),
        elevation: dark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size * .40),
          side: BorderSide(
            color: dark ? Colors.transparent : Theme.of(context).dividerColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );
}

class _NoteTool extends StatelessWidget {
  const _NoteTool({
    required this.label,
    required this.color,
    this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(36, 29),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: icon != null
          ? GIcon(icon!, color: color, size: 19)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 1.6, vertical: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: color, width: 1.7),
              ),
              child: Text(
                'GIF',
                style: TextStyle(
                  color: color,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
    ),
  );
}

class _BubbleEditor extends StatefulWidget {
  const _BubbleEditor({required this.caption, required this.details});

  final String caption;
  final J details;

  @override
  State<_BubbleEditor> createState() => _BubbleEditorState();
}

class _BubbleEditorState extends State<_BubbleEditor> {
  static const pages = [
    [0xffb993f6, 0xff7338ee, 0xff420dac, 0xffeb83dd, 0xffd129b5, 0xff8b1b79],
    [0xfff4a0b5, 0xffff6797, 0xffda315c, 0xfffd8453, 0xffe44c33, 0xff9b2223],
    [0xffffe591, 0xffffbe43, 0xfff78525, 0xffb97a3b, 0xff815236, 0xff533728],
    [0xffb9ebae, 0xff6be097, 0xff159a55, 0xff17ad91, 0xff178272, 0xff144f44],
    [0xffb6ddfb, 0xff65b8fc, 0xff157dec, 0xff144baf, 0xff283660, 0xff242729],
  ];
  late String color = widget.details.str('color');
  late String emoji = widget.details.str('emoji');
  int page = 0;
  final colors = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) introduction();
    });
  }

  Future<void> introduction() async {
    final store = GpixScope.of(context, listen: false);
    final key = 'gpix.noteColorIntro.${store.myId}';
    if (store.prefs?.getBool(key) == true) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi introduzione',
      barrierColor: const Color(0x6e0b1115),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      pageBuilder: (dialog, _, _) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 422),
              child: Material(
                color: surface(dialog),
                borderRadius: BorderRadius.circular(33),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 30, 32, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CustomPaint(
                          size: const Size(136, 92),
                          painter: _NoteIntroArt(foreground(dialog)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Esprimiti con una\nnota colorata',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Ora puoi dare un tocco di stile alla tua nota aggiungendo un colore e un'emoji.",
                        style: TextStyle(fontSize: 13, height: 1.2),
                      ),
                      const SizedBox(height: 26),
                      FilledButton(
                        style: _noteButton(radius: 13, height: 42),
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Prova'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await store.prefs?.setBool(key, true);
  }

  Future<void> pickEmoji() async {
    final result = await noteSheet<String>(
      context,
      Builder(
        builder: (menu) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scegli emoji',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final symbol in const [
                    '😀',
                    '😂',
                    '🥹',
                    '🥰',
                    '😍',
                    '😎',
                    '😴',
                    '🫠',
                    '🤍',
                    '❤️',
                    '🩵',
                    '💜',
                    '✨',
                    '⭐',
                    '🔥',
                    '🎉',
                    '🌈',
                    '🎵',
                    '🍀',
                    '🌙',
                    '☀️',
                    '🫶',
                    '💭',
                    '👀',
                    '🦋',
                    '🌹',
                    '💅',
                    '💋',
                    '🙃',
                    '😏',
                    '😈',
                    '🐻',
                  ])
                    TextButton(
                      onPressed: () => Navigator.pop(menu, symbol),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(43),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(symbol, style: const TextStyle(fontSize: 23)),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pop(menu, ''),
                child: const Text('Rimuovi emoji'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => emoji = result);
  }

  @override
  void dispose() {
    colors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final preview = {...widget.details, 'color': color, 'emoji': emoji};
    return Scaffold(
      appBar: _noteHeader(context),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 22),
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: const Alignment(0, .22),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  child: _NoteStage(
                    owner: store.myId,
                    details: preview,
                    mutedPhoto: true,
                    onEmoji: pickEmoji,
                    editor: Text(
                      widget.caption.isEmpty
                          ? 'Non riesco a\ndecidere…'
                          : widget.caption,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.05,
                        color: _noteInk(
                          context,
                          preview,
                          subtle: widget.caption.isEmpty,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: PageView.builder(
                controller: colors,
                itemCount: pages.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (context, index) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 276),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final (swatch, value) in pages[index].indexed)
                          _ColorSwatch(
                            index: index * 6 + swatch + 1,
                            value: Color(value),
                            selected:
                                color ==
                                '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0')}',
                            onTap: () => setState(() {
                              color =
                                  '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0')}';
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < pages.length; index++)
                  GestureDetector(
                    onTap: () => colors.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 225),
                      curve: Curves.easeOutCubic,
                    ),
                    child: Semantics(
                      selected: index == page,
                      label: 'Palette ${index + 1}',
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 8,
                        ),
                        child: CircleAvatar(
                          radius: 3.5,
                          backgroundColor: index == page
                              ? secondaryText(context)
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: _noteButton(radius: 13, height: 44),
                  onPressed: () => Navigator.pop(context, <String, dynamic>{
                    if (color.isNotEmpty) 'color': color,
                    if (emoji.isNotEmpty) 'emoji': emoji,
                  }),
                  child: const Text('Applica'),
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    Theme.of(context).brightness == Brightness.light
                    ? noteAccent
                    : accent(context),
              ),
              onPressed: () => setState(() {
                color = '';
                emoji = '';
              }),
              child: const Text(
                'Cancella',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.index,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Color value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Colore $index',
    selected: selected,
    button: true,
    child: InkWell(
      key: ValueKey('note-color-$index'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 42,
        child: Center(
          child: Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: value,
              border: Border.all(
                color: Colors.white,
                width: selected ? 3 : 1.7,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2a000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaletteGlyph extends StatelessWidget {
  const _PaletteGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _PalettePainter());
}

void _drawPalette(Canvas canvas, Rect bounds) {
  final x = bounds.left, y = bounds.top, w = bounds.width, h = bounds.height;
  Offset at(double a, double b) => Offset(x + a * w, y + b * h);
  final pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * .075
    ..strokeJoin = StrokeJoin.round
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xffffbd55), Color(0xffef4468), Color(0xff9426d0)],
    ).createShader(bounds);
  final outline = Path()..moveTo(at(.86, .65).dx, at(.86, .65).dy);
  outline
    ..cubicTo(x + w, y + .62 * h, x + w, y + .39 * h, x + .88 * w, y + .23 * h)
    ..cubicTo(x + .67 * w, y - .08 * h, x + .1 * w, y, x + .06 * w, y + .38 * h)
    ..cubicTo(
      x - .02 * w,
      y + .65 * h,
      x + .20 * w,
      y + .95 * h,
      x + .52 * w,
      y + .96 * h,
    )
    ..cubicTo(
      x + .72 * w,
      y + .96 * h,
      x + .62 * w,
      y + .84 * h,
      x + .62 * w,
      y + .77 * h,
    )
    ..cubicTo(
      x + .62 * w,
      y + .68 * h,
      x + .72 * w,
      y + .66 * h,
      x + .86 * w,
      y + .65 * h,
    );
  canvas.drawPath(outline, pen);
  pen.style = PaintingStyle.fill;
  for (final (a, b) in const [
    (.25, .32),
    (.46, .22),
    (.69, .29),
    (.77, .46),
    (.24, .56),
  ]) {
    canvas.drawCircle(at(a, b), w * .063, pen);
  }
}

class _PalettePainter extends CustomPainter {
  const _PalettePainter();

  @override
  void paint(Canvas canvas, Size size) =>
      _drawPalette(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(covariant _PalettePainter oldDelegate) => false;
}

class _NoteIntroArt extends CustomPainter {
  const _NoteIntroArt(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 136, size.height / 92);
    final pen = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final body = Path.combine(
      PathOperation.union,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(28, 23, 80, 39),
          const Radius.circular(16),
        ),
      ),
      Path()..addOval(const Rect.fromLTWH(43, 42, 27, 29)),
    );
    canvas.drawPath(body, pen);
    canvas.drawCircle(const Offset(66, 84), 6.5, pen);
    pen.color = ink.withValues(alpha: .26);
    canvas.drawLine(const Offset(68, 2), const Offset(68, 7), pen);
    canvas.drawLine(const Offset(46, 9), const Offset(49, 13), pen);
    canvas.drawLine(const Offset(90, 9), const Offset(87, 13), pen);
    final wave = Path()..moveTo(46, 40);
    for (var i = 0; i < 6; i++) {
      final a = 46.0 + 7.5 * i;
      wave.quadraticBezierTo(a + 3.75, i.isEven ? 48 : 32, a + 7.5, 40);
    }
    canvas.drawPath(wave, pen);
    final brush = Path()
      ..moveTo(34, 42)
      ..cubicTo(24, 40, 22, 49, 22, 50)
      ..lineTo(3, 69)
      ..quadraticBezierTo(-2, 76, 4, 76)
      ..quadraticBezierTo(6, 76, 10, 72)
      ..lineTo(27, 56)
      ..cubicTo(34, 54, 35, 48, 34, 42)
      ..close();
    pen.color = Colors.white;
    pen.shader = const LinearGradient(
      colors: [Color(0xffffdc68), Color(0xffe3476e), Color(0xff7338ef)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(const Rect.fromLTWH(0, 40, 36, 38));
    canvas.drawPath(brush, pen);
    canvas.drawLine(const Offset(19, 53), const Offset(25, 59), pen);
    canvas.drawLine(const Offset(23, 49), const Offset(29, 55), pen);
    _drawPalette(canvas, const Rect.fromLTWH(94, 43, 42, 43));
  }

  @override
  bool shouldRepaint(covariant _NoteIntroArt oldDelegate) =>
      oldDelegate.ink != ink;
}

class _PublishedNote extends StatelessWidget {
  const _PublishedNote({required this.note});

  final J note;

  @override
  Widget build(BuildContext context) {
    final details = note.obj('details');
    final track = details.obj('music');
    final spotify = track.str('spotify');
    final place = details.str('place');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NoteStage(
          owner: note.str('owner'),
          details: details,
          width: 142,
          editor: Text(
            note.str('text'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _noteInk(context, details),
              fontSize: 13,
              height: 1.1,
            ),
          ),
        ),
        if (track.str('audio').isNotEmpty) NotePlayback(track: track),
        if (spotify.isNotEmpty)
          TextButton(
            onPressed: () => _openUrl(context, Uri.parse(spotify)),
            child: const Text('Apri in Spotify'),
          ),
        if (place.isNotEmpty)
          TextButton(
            onPressed: () => _openUrl(
              context,
              Uri.https('www.google.com', '/maps/search/', {
                'api': '1',
                'query': place,
              }),
            ),
            child: const Text('Apri la mappa'),
          ),
      ],
    );
  }
}

Future<void> _openUrl(BuildContext context, Uri uri) =>
    perform(context, () async {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Impossibile aprire il collegamento.');
      }
    });

Future<void> replyNote(BuildContext context, J note) async {
  final store = GpixScope.of(context, listen: false);
  final owner = note.str('owner');
  final reply = await noteSheet<String>(context, _ReplyToNote(note: note));
  if (reply == null || reply.isEmpty || !context.mounted) return;
  await perform(context, () async {
    final thread = await store.openThread(owner);
    final quote = note.str('text').isNotEmpty
        ? note.str('text')
        : _attachmentTitle(note.obj('details'));
    await store.send(thread, '↪ $quote\n$reply');
    if (context.mounted) open(context, Chat(id: thread));
  });
}

class _ReplyToNote extends StatefulWidget {
  const _ReplyToNote({required this.note});

  final J note;

  @override
  State<_ReplyToNote> createState() => _ReplyToNoteState();
}

class _ReplyToNoteState extends State<_ReplyToNote> {
  String reply = '';
  bool reacting = false;

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final original = widget.note;
    final owner = original.str('owner');
    final current = store.notes
        .where(
          (note) =>
              note.str('owner') == owner &&
              note['created'] == original['created'],
        )
        .firstOrNull;
    final liked = current?.flag('likedByMe') ?? original.flag('likedByMe');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 3, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PublishedNote(note: current ?? original),
          const SizedBox(height: 8),
          Text(
            store.user(owner).str('username'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => reply = value.trim()),
                  onSubmitted: (_) {
                    if (reply.isNotEmpty) Navigator.pop(context, reply);
                  },
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Rispondi alla nota…',
                  ),
                ),
              ),
              IconButton(
                tooltip: liked ? 'Rimuovi Mi piace' : 'Mi piace',
                onPressed: reacting || current == null
                    ? null
                    : () => perform(context, () async {
                        setState(() => reacting = true);
                        try {
                          await store.act('noteReact', {
                            'user': owner,
                            'created': original['created'],
                            'enabled': !liked,
                          });
                        } finally {
                          if (mounted) setState(() => reacting = false);
                        }
                      }),
                icon: GIcon(
                  liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: liked ? danger : foreground(context),
                ),
              ),
              if (reply.isNotEmpty)
                IconButton(
                  tooltip: 'Invia risposta',
                  onPressed: () => Navigator.pop(context, reply),
                  icon: const GIcon(
                    CupertinoIcons.paperplane_fill,
                    color: noteAccent,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
