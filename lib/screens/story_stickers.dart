import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../ui/kit.dart';

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
          TextField(
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Cerca sticker',
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
  String? Function(String)? validate,
}) async {
  var input = '';
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          autofocus: true,
          maxLength: limit,
          decoration: InputDecoration(labelText: label),
          onChanged: (value) => input = value.trim(),
          validator: (_) =>
              input.isEmpty ? 'Compila questo campo.' : validate?.call(input),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(context, input);
          },
          child: const Text('Continua'),
        ),
      ],
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
  });

  final J sticker;
  final J post;
  final bool editing;

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
    if (tool == StoryStickerTool.avatar) {
      return Avatar(post.str('author'), size: size * 1.45, ring: true);
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
      if (tool == StoryStickerTool.cutout) return ClipOval(child: photos);
      if (tool == StoryStickerTool.photo || tool == StoryStickerTool.gif) {
        return ClipRRect(borderRadius: BorderRadius.circular(9), child: photos);
      }
      return Container(
        padding: EdgeInsets.fromLTRB(
          5,
          5,
          5,
          tool == StoryStickerTool.frame ? 16 : 5,
        ),
        color: Colors.white,
        child: photos,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 216),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tool.icon, size: 17, color: tool.color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      tool.label,
                      style: TextStyle(
                        color: tool.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xff16161c),
                    fontWeight: FontWeight.w700,
                    fontSize: (size * .3).clamp(12, 23),
                  ),
                ),
              if (tool == StoryStickerTool.countdown)
                _StoryCountdown(end: sticker.number('end').toInt()),
              if (['poll', 'slider', 'rating'].contains(tool.name))
                _VotePreview(post: post),
            ],
          ),
        ),
      ),
    );
  }
}

class _VotePreview extends StatelessWidget {
  const _VotePreview({required this.post});
  final J post;

  @override
  Widget build(BuildContext context) {
    final poll = post.obj('style').obj('poll');
    final mine = poll.number('myVote', -1).toInt();
    final options = poll.ids('options');
    return Text(
      mine >= 0 && mine < options.length
          ? 'Hai scelto ${options[mine]}'
          : options.join('  ·  '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xff353544), fontSize: 12),
    );
  }
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
  'poll',
  'slider',
  'link',
  'hashtag',
  'donation',
  'rating',
};

class StoryVoteSheet extends StatefulWidget {
  const StoryVoteSheet({
    super.key,
    required this.poll,
    required this.type,
    required this.own,
  });

  final J poll;
  final String type;
  final bool own;

  @override
  State<StoryVoteSheet> createState() => _StoryVoteSheetState();
}

class _StoryVoteSheetState extends State<StoryVoteSheet> {
  late double level = widget.poll
      .number('myVote', -1)
      .clamp(0, (widget.poll.ids('options').length - 1).clamp(0, 3))
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final options = widget.poll.ids('options');
    final mine = widget.poll.number('myVote', -1).toInt();
    final counts = widget.poll['counts'] as List? ?? const [];
    int votes(int i) =>
        i < counts.length && counts[i] is num ? (counts[i] as num).toInt() : 0;
    final total = List.generate(options.length, votes).fold(0, (a, b) => a + b);
    final showResults = widget.own || mine >= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.poll.str('question'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (widget.type == 'slider' &&
              options.length >= 2 &&
              !widget.own) ...[
            Text(
              options[level.round()],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 35),
            ),
            Slider(
              value: level,
              max: (options.length - 1).toDouble(),
              divisions: options.length - 1,
              label: options[level.round()],
              onChanged: (value) => setState(() => level = value),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, level.round()),
              child: const Text('Vota'),
            ),
          ],
          for (var i = 0; i < options.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(options[i]),
              selected: mine == i,
              trailing: showResults
                  ? Text(
                      total == 0
                          ? '0%'
                          : '${(votes(i) * 100 / total).round()}%',
                    )
                  : null,
              onTap: widget.own || widget.type == 'slider'
                  ? null
                  : () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
  }
}
