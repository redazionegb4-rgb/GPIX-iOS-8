import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'stories.dart' show Composer;
import 'messages.dart' show Chat;
import 'social.dart' show Profile;
import 'features13.dart' show PrivacyTools;

enum StoryStickerTool {
  place('Luogo', CupertinoIcons.location, Color(0xff8447ff)),
  mention('Menzione', CupertinoIcons.at, Color(0xffee620c)),
  music('Musica', CupertinoIcons.music_note_2, Color(0xffd91566)),
  gif('GIF', CupertinoIcons.search, Color(0xff009d65)),
  prompt(
    'Tocca a te',
    CupertinoIcons.rectangle_on_rectangle,
    Color(0xffd91566),
  ),
  frame('Cornice', CupertinoIcons.photo, Color(0xff8447ff)),
  strip('Photostrip', CupertinoIcons.square_stack, Color(0xff8447ff)),
  photo('Foto', CupertinoIcons.photo_on_rectangle, Color(0xff009d65)),
  cutout('Ritagli', CupertinoIcons.scissors, Color(0xff009d65)),
  highlight('Metti in evidenza', CupertinoIcons.star_circle, Color(0xffd91566)),
  question('Domande', CupertinoIcons.question_circle, Color(0xffb521ac)),
  avatar('Avatar', CupertinoIcons.person_crop_circle, Color(0xffee620c)),
  emoji('Emoji', CupertinoIcons.smiley, Color(0xffee620c)),
  reaction('Reazione emoji', CupertinoIcons.heart_circle, Color(0xffee620c)),
  poll('Sondaggio', CupertinoIcons.chart_bar, Color(0xffb521ac)),
  slider('Slider emoji', CupertinoIcons.slider_horizontal_3, Color(0xffd91566)),
  link('Link', CupertinoIcons.link, Color(0xff0876e8)),
  hashtag('Hashtag', CupertinoIcons.number, Color(0xffb521ac)),
  donation('Donazione', CupertinoIcons.heart_circle, Color(0xff0876e8)),
  countdown('Countdown', CupertinoIcons.timer, Color(0xffb521ac)),
  rating('Valutazione', CupertinoIcons.star, Color(0xffb87800)),
  time('Ora', CupertinoIcons.clock, Color(0xff0876e8));

  const StoryStickerTool(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

Future<StoryStickerTool?> pickStorySticker(BuildContext context) =>
    showModalBottomSheet<StoryStickerTool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: ColoredBox(
              color: const Color(0xd91d1d20),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 16),
                  child: const StoryStickerPicker(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

class StoryStickerPicker extends StatefulWidget {
  const StoryStickerPicker({super.key});

  @override
  State<StoryStickerPicker> createState() => _StoryStickerPickerState();
}

class _StoryStickerPickerState extends State<StoryStickerPicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final tools = StoryStickerTool.values.where(
      (tool) => tool.label.toLowerCase().contains(query),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 4,
            margin: const EdgeInsets.only(bottom: 13),
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          TextField(
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Cerca',
              filled: true,
              fillColor: Colors.white24,
              prefixIcon: Icon(CupertinoIcons.search),
            ),
          ),
          const SizedBox(height: 22),
          if (tools.isEmpty) const Text('Nessuno sticker trovato'),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 9,
            runSpacing: 12,
            children: [
              for (final tool in tools)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xff16161c),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, tool),
                  icon: Icon(tool.icon, color: tool.color, size: 20),
                  label: Text(tool.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> storyStickerInput(
  BuildContext context,
  String title,
  String label, {
  int limit = 100,
  bool replying = false,
  String? Function(String)? validate,
}) async {
  var input = '';
  final form = GlobalKey<FormState>();
  return showGeneralDialog<String>(
    context: context,
    barrierColor: Colors.black54,
    pageBuilder: (context, _, _) => _StickerEditorOverlay(
      title: title,
      onDone: () {
        if (form.currentState!.validate()) Navigator.pop(context, input);
      },
      doneLabel: replying ? 'Invia' : 'Fine',
      child: Form(
        key: form,
        child: TextFormField(
          autofocus: true,
          maxLength: limit,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          decoration: _stickerField(label),
          onChanged: (value) => input = value.trim(),
          validator: (_) =>
              input.isEmpty ? 'Compila questo campo.' : validate?.call(input),
        ),
      ),
    ),
  );
}

Uri? storyStickerLink(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty)
    return null;
  return uri;
}

class StoryStickerFace extends StatelessWidget {
  const StoryStickerFace({
    super.key,
    required this.sticker,
    required this.post,
    required this.editing,
    this.onVote,
    this.maxWidth = 235,
  });

  final J sticker;
  final J post;
  final bool editing;
  final ValueChanged<int>? onVote;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tool = StoryStickerTool.values.asNameMap()[sticker.str('type')];
    final size = sticker.number('size', 52).clamp(28, 94).toDouble();
    final label = sticker.str('label');
    if (tool == null || tool == StoryStickerTool.emoji) {
      return Text(
        sticker.str('emoji'),
        style: TextStyle(fontSize: size, height: 1.1),
      );
    }
    if (tool == StoryStickerTool.reaction) {
      return Semantics(
        button: !editing,
        label: 'Reagisci con ${sticker.str('emoji')}',
        child: Container(
          width: size * 1.32,
          height: size * 1.32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            sticker.str('emoji'),
            style: TextStyle(fontSize: size * .72),
          ),
        ),
      );
    }
    if (tool == StoryStickerTool.avatar) {
      return Avatar(post.str('author'), size: size * 1.45, ring: true);
    }
    if (tool == StoryStickerTool.poll ||
        tool == StoryStickerTool.rating ||
        tool == StoryStickerTool.slider) {
      return SizedBox(
        width: (size * 4.5).clamp(150.0, maxWidth.clamp(150.0, 300.0)),
        child: StoryVoteSticker(
          key: ValueKey(post.str('id')),
          poll: post.obj('style').obj('poll'),
          type: tool,
          style: sticker.number('palette').toInt(),
          emoji: sticker.str('emoji', '😍'),
          onVote: editing ? null : onVote,
          showResults:
              !editing &&
              GpixScope.of(context, listen: false).myId == post.str('author'),
        ),
      );
    }
    final references = editing
        ? sticker.ids('files')
        : [
            for (final id in sticker.ids('mediaIds'))
              if (post.ids('mediaItems').contains(id))
                id
              else
                for (final media in post.rows('mediaItems'))
                  if (media.str('id') == id) media.str('url'),
          ];
    if (references.isNotEmpty) {
      final width = size * (tool == StoryStickerTool.strip ? 1.15 : 1.95);
      final photos = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reference in references)
            MediaView(reference, width: width, height: width * .77),
        ],
      );
      if (tool == StoryStickerTool.cutout) {
        return ClipOval(child: photos);
      }
      if (tool == StoryStickerTool.frame) {
        return _StoryFrame(photo: photos, editing: editing, width: width);
      }
      if (tool == StoryStickerTool.photo || tool == StoryStickerTool.gif) {
        return ClipRRect(borderRadius: BorderRadius.circular(9), child: photos);
      }
      return Container(
        padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
        color: Colors.white,
        child: photos,
      );
    }
    final darkHeader =
        tool == StoryStickerTool.question ||
        tool == StoryStickerTool.prompt ||
        tool == StoryStickerTool.countdown;
    final action = switch (tool) {
      StoryStickerTool.question => 'Scrivi qualcosa…',
      StoryStickerTool.prompt => 'Tocca a te',
      _ => '',
    };
    final display = label.isEmpty ? tool.label : label;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(darkHeader ? 14 : 8),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: darkHeader ? const Color(0xff24242a) : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!darkHeader &&
                        tool != StoryStickerTool.hashtag &&
                        tool != StoryStickerTool.time) ...[
                      Icon(tool.icon, size: 19, color: tool.color),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        display,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkHeader ? Colors.white : tool.color,
                          fontWeight: FontWeight.w800,
                          fontSize: (size * .33).clamp(12, 26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (action.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xffefeff2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      action,
                      style: const TextStyle(
                        color: Color(0xff202026),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (tool == StoryStickerTool.countdown)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: _StoryCountdown(end: sticker.number('end').toInt()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryFrame extends StatefulWidget {
  const _StoryFrame({
    required this.photo,
    required this.editing,
    required this.width,
  });
  final Widget photo;
  final bool editing;
  final double width;

  @override
  State<_StoryFrame> createState() => _StoryFrameState();
}

class _StoryFrameState extends State<_StoryFrame> {
  bool revealed = false;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xfffffdf3),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 18),
      child: widget.editing || revealed
          ? widget.photo
          : SizedBox(
              width: widget.width,
              height: widget.width * .77,
              child: InkWell(
                onTap: () => setState(() => revealed = true),
                child: const ColoredBox(
                  color: Color(0xff303036),
                  child: Center(
                    child: Text(
                      'Tocca per svelare',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
}

class _StoryCountdown extends StatefulWidget {
  const _StoryCountdown({required this.end});
  final int end;
  @override
  State<_StoryCountdown> createState() => _StoryCountdownState();
}

class _StoryCountdownState extends State<_StoryCountdown> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
      if (remaining.isNegative) timer.cancel();
    });
  }

  Duration get remaining => DateTime.fromMillisecondsSinceEpoch(
    widget.end,
  ).difference(DateTime.now());

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = remaining;
    String two(int value) => value.toString().padLeft(2, '0');
    return Text(
      left.isNegative
          ? 'Terminato'
          : '${left.inDays > 0 ? "${left.inDays}g " : ""}${two(left.inHours % 24)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
      style: const TextStyle(
        color: Color(0xff16161c),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

const interactiveStoryStickers = {
  'place',
  'mention',
  'prompt',
  'question',
  'reaction',
  'link',
  'hashtag',
  'donation',
};

const _pollColors = [
  Color(0xff25252d),
  Color(0xff9c2964),
  Color(0xff364daa),
  Color(0xff087568),
];

InputDecoration _stickerField(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xff64646c)),
  filled: true,
  fillColor: const Color(0xfff0f0f2),
  counterText: '',
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: BorderSide.none,
  ),
);

class _StickerEditorOverlay extends StatelessWidget {
  const _StickerEditorOverlay({
    required this.title,
    required this.child,
    required this.onDone,
    this.doneLabel = 'Fine',
  });
  final String title;
  final Widget child;
  final VoidCallback onDone;
  final String doneLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Annulla',
        icon: const Icon(CupertinoIcons.xmark),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        TextButton(
          onPressed: onDone,
          child: Text(
            doneLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: child,
        ),
      ),
    ),
  );
}

Future<J?> editStoryVote(BuildContext context, StoryStickerTool tool) =>
    showGeneralDialog<J>(
      context: context,
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => _StoryVoteEditor(tool: tool),
    );

class _StoryVoteEditor extends StatefulWidget {
  const _StoryVoteEditor({required this.tool});
  final StoryStickerTool tool;
  @override
  State<_StoryVoteEditor> createState() => _StoryVoteEditorState();
}

class _StoryVoteEditorState extends State<_StoryVoteEditor> {
  final form = GlobalKey<FormState>();
  final question = TextEditingController();
  final options = [
    TextEditingController(text: 'Sì'),
    TextEditingController(text: 'No'),
  ];
  int palette = 0;
  String emoji = '😍';

  @override
  void dispose() {
    question.dispose();
    for (final option in options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.tool == StoryStickerTool.poll;
    final slider = widget.tool == StoryStickerTool.slider;
    return _StickerEditorOverlay(
      title: widget.tool.label,
      onDone: () {
        if (!form.currentState!.validate()) return;
        final values = poll
            ? options.map((option) => option.text.trim()).toList()
            : slider
            ? ['Poco', 'Abbastanza', 'Molto', 'Al massimo']
            : ['★', '★★', '★★★', '★★★★'];
        if (values.map((value) => value.toLowerCase()).toSet().length !=
            values.length) {
          notice(context, 'Inserisci risposte diverse.');
          return;
        }
        Navigator.pop(context, {
          'question': question.text.trim(),
          'options': values,
          'palette': palette,
          'emoji': emoji,
        });
      },
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: _pollColors[palette],
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: TextFormField(
                    controller: question,
                    autofocus: true,
                    maxLength: 120,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: _stickerField('Fai una domanda…'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Scrivi una domanda.' : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    if (poll) ...[
                      for (var index = 0; index < options.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TextFormField(
                            controller: options[index],
                            maxLength: 60,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _stickerField('Opzione ${index + 1}'),
                            validator: (value) => value!.trim().isEmpty
                                ? 'Inserisci una risposta.'
                                : null,
                          ),
                        ),
                      if (options.length < 4)
                        TextButton(
                          onPressed: () => setState(
                            () => options.add(TextEditingController()),
                          ),
                          child: const Text('Aggiungi un’opzione'),
                        ),
                    ] else if (slider)
                      Wrap(
                        children: [
                          for (final value in ['😍', '🔥', '😂', '❤️', '👏'])
                            ChoiceChip(
                              selected: emoji == value,
                              label: Text(value),
                              onSelected: (_) => setState(() => emoji = value),
                            ),
                        ],
                      )
                    else
                      const Text(
                        '★ ★ ★ ★',
                        style: TextStyle(
                          color: Color(0xffb87800),
                          fontSize: 26,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Cambia colore',
                      onPressed: () => setState(
                        () => palette = (palette + 1) % _pollColors.length,
                      ),
                      icon: Icon(
                        CupertinoIcons.circle_fill,
                        color: _pollColors[palette],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoryVoteSticker extends StatefulWidget {
  const StoryVoteSticker({
    super.key,
    required this.poll,
    required this.type,
    required this.style,
    required this.emoji,
    required this.showResults,
    this.onVote,
  });

  final J poll;
  final StoryStickerTool type;
  final int style;
  final String emoji;
  final bool showResults;
  final ValueChanged<int>? onVote;

  @override
  State<StoryVoteSticker> createState() => _StoryVoteStickerState();
}

class _StoryVoteStickerState extends State<StoryVoteSticker> {
  double level = 0;
  int bump = 0;

  @override
  Widget build(BuildContext context) {
    final options = widget.poll.ids('options');
    final mine = widget.poll.number('myVote', -1).toInt();
    final counts = widget.poll['counts'] as List? ?? const [];
    int votes(int i) =>
        i < counts.length && counts[i] is num ? (counts[i] as num).toInt() : 0;
    final total = List.generate(options.length, votes).fold(0, (a, b) => a + b);
    final results = widget.showResults || mine >= 0;
    final onVote = results ? null : widget.onVote;
    final color = _pollColors[widget.style % _pollColors.length];
    final slider = widget.type == StoryStickerTool.slider;
    final rating = widget.type == StoryStickerTool.rating;
    final max = (options.length - 1).clamp(1, 3).toDouble();
    final average = total == 0
        ? 0.0
        : List.generate(
                options.length,
                (i) => votes(i) * i,
              ).fold(0, (a, b) => a + b) /
              total;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: color,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Text(
                widget.poll.str('question'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (slider && options.length >= 2)
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6,
                    thumbShape: _EmojiThumb(widget.emoji),
                  ),
                  child: Slider(
                    min: 0,
                    max: max,
                    divisions: max.toInt(),
                    value: (results ? average : level).clamp(0, max),
                    activeColor: color,
                    label: widget.emoji,
                    onChanged: onVote == null
                        ? null
                        : (value) => setState(() => level = value),
                    onChangeEnd: onVote == null
                        ? null
                        : (value) {
                            setState(() {
                              level = value;
                              bump++;
                            });
                            onVote(value.round());
                          },
                  ),
                ),
                if (bump > 0)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(bump),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 690),
                        builder: (_, t, child) => Align(
                          alignment: Alignment(level / max * 2 - 1, 0),
                          child: Opacity(
                            opacity: (1 - t).clamp(0, 1),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                -38 * Curves.easeOut.transform(t),
                              ),
                              child: Transform.scale(
                                scale:
                                    1 + .65 * Curves.easeOutBack.transform(t),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          else if (rating)
            Row(
              children: [
                for (var i = 0; i < options.length; i++)
                  Expanded(
                    child: IconButton(
                      tooltip: '${i + 1} stelle',
                      onPressed: onVote == null ? null : () => onVote(i),
                      icon: Icon(
                        i <= mine
                            ? CupertinoIcons.star_fill
                            : CupertinoIcons.star,
                        color: const Color(0xffb87800),
                        size: 20,
                      ),
                    ),
                  ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  for (var i = 0; i < options.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Material(
                        color: const Color(0xffefeff2),
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onVote == null ? null : () => onVote(i),
                          child: Stack(
                            children: [
                              if (results)
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: total == 0
                                          ? 0
                                          : votes(i) / total,
                                      heightFactor: 1,
                                      child: ColoredBox(
                                        color: color.withValues(
                                          alpha: i == mine ? .28 : .13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          options[i],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xff16161c),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (results)
                                        Text(
                                          '${total == 0 ? 0 : (votes(i) * 100 / total).round()}%',
                                          style: const TextStyle(
                                            color: Color(0xff16161c),
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
                      ),
                    ),
                ],
              ),
            ),
          if (rating && results && total > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${(average + 1).toStringAsFixed(1)} / ${options.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmojiThumb extends SliderComponentShape {
  const _EmojiThumb(this.emoji);
  final String emoji;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(32, 32);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: emoji, style: const TextStyle(fontSize: 25)),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      context.canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }
}

class StoryEmojiBurst extends StatelessWidget {
  const StoryEmojiBurst({super.key, required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: LayoutBuilder(
        builder: (_, box) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1750),
          builder: (_, time, __) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (var i = 0; i < 26; i++)
                if (time > (i % 9) * .032) _emojiParticle(box.biggest, time, i),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _emojiParticle(Size area, double time, int index) {
    final t = ((time - (index % 9) * .032) / .71).clamp(0.0, 1.0);
    final size = 21.0 + (index * 17 % 28);
    final drift = (index.isEven ? 1 : -1) * (12 + index % 5 * 6) * t;
    return Positioned(
      left: (area.width - size) * ((index * 37 % 101) / 100) + drift,
      top: -size + (area.height + size) * Curves.easeIn.transform(t),
      child: Opacity(
        opacity:
            (t * 10).clamp(0.0, 1.0) * (1 - ((t - .72) / .28).clamp(0.0, 1.0)),
        child: Transform.rotate(
          angle: (index.isEven ? 1 : -1) * (.2 + t * .8),
          child: Transform.scale(
            scale:
                .7 +
                .35 * Curves.easeOutBack.transform((t * 5).clamp(0.0, 1.0)),
            child: Text(emoji, style: TextStyle(fontSize: size, height: 1)),
          ),
        ),
      ),
    );
  }
}

class StoryActivityPanel extends StatefulWidget {
  const StoryActivityPanel({super.key, required this.storyId});
  final String storyId;

  @override
  State<StoryActivityPanel> createState() => _StoryActivityPanelState();
}

class _StoryActivityPanelState extends State<StoryActivityPanel> {
  String query = '';
  final _viewersScroll = ScrollController();
  int? _returnPointer;
  Offset _returnOrigin = Offset.zero;

  void _trackReturn(PointerDownEvent event) {
    if (_returnPointer != null ||
        !_viewersScroll.hasClients ||
        _viewersScroll.position.extentBefore > 0)
      return;
    _returnPointer = event.pointer;
    _returnOrigin = event.position;
  }

  void _finishReturn(PointerUpEvent event) {
    if (_returnPointer != event.pointer) return;
    _returnPointer = null;
    final movement = event.position - _returnOrigin;
    if (movement.dy >= 55 &&
        movement.dy > movement.dx.abs() * 1.4 &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.pop(context, selectedId);
    }
  }

  late String selectedId = widget.storyId;
  PageController? _pages;

  @override
  void dispose() {
    _viewersScroll.dispose();
    _pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final story = store.post(selectedId);
    final stories = store.stories(store.myId);
    final replies = story.rows('stickerActivity');
    final page = stories.indexWhere((item) => item.str('id') == selectedId);
    final pages = _pages ??= PageController(
      initialPage: page < 0 ? 0 : page,
      viewportFraction: .17,
    );
    final messages = <(String, J)>[
      for (final thread in store.threads)
        for (final message in thread.rows('messages'))
          if (message.obj('story').str('id') == selectedId &&
              message.str('author') != store.myId &&
              message.str('text').isNotEmpty)
            (thread.str('id'), message),
    ];
    final allViewers = store.viewers(story);
    final activityByUser = <String, List<J>>{};
    for (final reply in replies) {
      final userId = reply.str('user');
      if (userId.isNotEmpty) (activityByUser[userId] ??= []).add(reply);
    }
    final viewers =
        {...allViewers, ...story.ids('likes'), ...activityByUser.keys}.where((
          id,
        ) {
          final user = store.user(id);
          return "${user.str('username')} ${user.str('name')}"
              .toLowerCase()
              .contains(query.trim().toLowerCase());
        }).toList();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Colors.black : Colors.white;
    final header = Theme.of(context).colorScheme.surfaceContainerLow;
    final textColor = dark ? Colors.white : const Color(0xff13161b);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: header,
        title: const Text('Attività della storia'),
        centerTitle: true,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Impostazioni',
          onPressed: () => open(context, const PrivacyTools()),
          icon: const Icon(CupertinoIcons.gear_alt),
        ),
        actions: [
          IconButton(
            tooltip: 'Chiudi',
            onPressed: () => Navigator.pop(context, selectedId),
            icon: const Icon(CupertinoIcons.xmark),
          ),
        ],
      ),
      body: SectionSwipe(
        onStep: (step) {
          final target = (page < 0 ? 0 : page) + step;
          if (target < 0 || target >= stories.length || !pages.hasClients)
            return;
          if (MediaQuery.disableAnimationsOf(context)) {
            pages.jumpToPage(target);
          } else {
            pages.animateToPage(
              target,
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
            );
          }
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _trackReturn,
          onPointerUp: _finishReturn,
          onPointerCancel: (event) {
            if (_returnPointer == event.pointer) _returnPointer = null;
          },
          child: ListView(
            controller: _viewersScroll,
            children: [
              ColoredBox(
                color: header,
                child: Column(
                  children: [
                    SizedBox(
                      height: 131,
                      child: PageView(
                        controller: pages,
                        onPageChanged: (index) {
                          if (index < stories.length) {
                            setState(
                              () => selectedId = stories[index].str('id'),
                            );
                          }
                        },
                        children: [
                          for (final item in stories)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () =>
                                      Navigator.pop(context, item.str('id')),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 190),
                                    width: item.str('id') == selectedId
                                        ? 72
                                        : 56,
                                    height: item.str('id') == selectedId
                                        ? 128
                                        : 99,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (item.str('media').isNotEmpty)
                                          MediaView(item.str('media'))
                                        else
                                          Center(
                                            child: Text(
                                              item.str('text'),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          left: 4,
                                          bottom: 4,
                                          child: Text(
                                            '◉ ${store.viewers(item).length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 5,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Center(
                            child: InkWell(
                              onTap: () =>
                                  open(context, const Composer(kind: 'story')),
                              child: Container(
                                width: 56,
                                height: 99,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  CupertinoIcons.camera,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.person_2, size: 16),
                          const SizedBox(width: 5),
                          Text('${allViewers.length}'),
                          const SizedBox(width: 15),
                          const Icon(CupertinoIcons.sparkles, size: 16),
                          const SizedBox(width: 5),
                          Text('${replies.length}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(CupertinoIcons.person_2, color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Visualizzazioni',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Elimina storia',
                    icon: const Icon(CupertinoIcons.trash),
                    onPressed: () async {
                      if (await gpixAlert(
                            context,
                            'Eliminare la storia?',
                            'La storia verrà rimossa.',
                            confirm: 'Elimina',
                            destructive: true,
                            cancel: true,
                          ) &&
                          context.mounted) {
                        await perform(context, () async {
                          await store.act('deletePost', {'id': selectedId});
                          if (context.mounted) Navigator.pop(context);
                        });
                      }
                    },
                  ),
                ],
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: InputDecoration(
                    hintText: 'Cerca account',
                    hintStyle: TextStyle(
                      color: dark ? Colors.white70 : const Color(0xff555c67),
                    ),
                    prefixIcon: const Icon(CupertinoIcons.search, size: 19),
                    filled: true,
                    fillColor: subdued(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              if (messages.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Text(
                    'Risposte alla storia',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                for (final (threadId, message) in messages)
                  ListTile(
                    leading: Avatar(message.str('author'), size: 44),
                    title: Text(
                      store.user(message.str('author')).str('username'),
                    ),
                    subtitle: Text(
                      message.str('text'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(CupertinoIcons.paperplane),
                    onTap: () => open(context, Chat(id: threadId)),
                  ),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Text(
                  'Chi ha visualizzato questa storia',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (viewers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 16,
                  ),
                  child: Center(
                    child: Text(
                      query.trim().isEmpty
                          ? 'Ancora nessuna visualizzazione'
                          : 'Nessun account trovato',
                      style: TextStyle(color: textColor),
                    ),
                  ),
                ),
              for (final id in viewers)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Avatar(id, size: 44),
                      if (story.ids('likes').contains(id))
                        Positioned(
                          right: -4,
                          bottom: -2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: surface(context),
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(3),
                              child: Icon(
                                CupertinoIcons.heart_fill,
                                color: Color(0xffed4956),
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    store.user(id).str('username'),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: activityByUser[id] == null
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final reply in activityByUser[id]!)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '${_interactionLabel(reply)} · ${reply.str('value')}',
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                          ],
                        ),
                  trailing: IconButton(
                    tooltip: 'Apri profilo',
                    icon: const Icon(CupertinoIcons.ellipsis),
                    onPressed: () => open(context, Profile(user: id)),
                  ),
                ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _interactionLabel(J reply) => switch (reply.str('kind')) {
    'reaction' => 'Reazione',
    'question' => 'Risposta',
    'slider' => 'Slider emoji',
    'rating' => 'Valutazione',
    _ => 'Sondaggio',
  };
}
