import 'dart:io';
import 'dart:async';
import '../core/drafts.dart';
import 'dart:convert';
import 'photo_effects.dart';
import 'music_picker.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/gallery.dart';
import 'social.dart' show textDialog;
import 'package:image/image.dart' as im;
import 'package:path_provider/path_provider.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

Future<String> renderPostPhoto(J args) async {
  var img = im.decodeImage(await processPhoto(args))!;
  final overlayPath = args.str('overlay');
  if (overlayPath.isNotEmpty) {
    final overlay = im.decodeImage(await File(overlayPath).readAsBytes());
    if (overlay != null) {
      final stamp = im.copyResize(
        im.bakeOrientation(overlay),
        width: (img.width * .28).round(),
      );
      img = im.compositeImage(
        img,
        stamp,
        dstX: img.width - stamp.width - (img.width * .03).round(),
        dstY: img.height - stamp.height - (img.width * .03).round(),
      );
    }
  }
  final captionPng = args.str('captionPng');
  if (captionPng.isNotEmpty) {
    final label = im.decodePng(base64Decode(captionPng))!;
    final stamp = im.copyResize(
      label,
      width: (img.width * args.number('textWidth', .8)).round(),
    );
    img = im.compositeImage(
      img,
      stamp,
      dstX: ((img.width - stamp.width) * args.number('textX', .5)).round(),
      dstY: ((img.height - stamp.height) * args.number('textY', .5)).round(),
    );
  }
  final out = args.str('output');
  await File(out).writeAsBytes(im.encodeJpg(img, quality: 91));
  return out;
}

List<double> postMatrix(String filter, double brightness) {
  if (filter == 'Mono')
    return [
      .2126 * brightness,
      .7152 * brightness,
      .0722 * brightness,
      0,
      0,
      .2126 * brightness,
      .7152 * brightness,
      .0722 * brightness,
      0,
      0,
      .2126 * brightness,
      .7152 * brightness,
      .0722 * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  if (filter == 'Vivido') {
    const sat = 1.35, contrast = 1.12;
    final a = (1 - sat) * .2126,
        b = (1 - sat) * .7152,
        c = (1 - sat) * .0722,
        v = contrast * brightness;
    const offset = 128 * (1 - contrast);
    return [
      (a + sat) * v,
      b * v,
      c * v,
      0,
      offset,
      a * v,
      (b + sat) * v,
      c * v,
      0,
      offset,
      a * v,
      b * v,
      (c + sat) * v,
      0,
      offset,
      0,
      0,
      0,
      1,
      0,
    ];
  }
  return [
    brightness * (filter == 'Caldo' ? 1.1 : 1),
    0,
    0,
    0,
    0,
    0,
    brightness,
    0,
    0,
    0,
    0,
    0,
    brightness * (filter == 'Caldo' ? 0.9 : 1),
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

class PostComposer extends StatefulWidget {
  final List<String> initialFiles;
  final J? initialDraft;
  const PostComposer({
    super.key,
    this.initialFiles = const [],
    this.initialDraft,
  });
  @override
  State<PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<PostComposer> {
  late List<String> files = [...widget.initialFiles];
  int step = 0, index = 0;
  late String draftId;
  Timer? draftTimer;
  bool savingDraft = false;
  String lastDraft = '';
  J draftData() => {
    'id': draftId,
    'kind': 'post',
    'files': files,
    'text': caption.text,
    'location': location.text,
    'aspect': aspect,
    'filter': filter,
    'brightness': brightness,
    'intensity': intensity,
    'adjustments': adjustments,
    'overlayText': overlayText,
    'overlay': overlay,
    'poll': poll,
    'aiLabel': aiLabel,
    'topic': topic,
    'textX': textX,
    'textY': textY,
    'textSize': textSize,
    'textColor': textColor.toARGB32(),
    'textAlign': textAlign.index,
    'audience': audience,
    'tagged': tagged.toList(),
    'music': music,
    'audioName': audioName,
    'commentsOff': commentsOff,
    'hideLikes': hideLikes,
  };
  Future<void> saveDraft({bool feedback = false}) async {
    if (files.isEmpty) {
      if (feedback)
        notice(context, 'Aggiungi una foto prima di salvare la bozza.');
      return;
    }
    if (savingDraft) {
      if (!feedback) return;
      while (savingDraft && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (mounted) await saveDraft(feedback: true);
      return;
    }
    if (busy) return;
    final data = draftData(), encoded = jsonEncode(draftData());
    if (!feedback && encoded == lastDraft) return;
    savingDraft = true;
    try {
      final s = GpixScope.of(context, listen: false);
      await Drafts.save('${s.server}|${s.myId}', data);
      lastDraft = encoded;
      if (feedback && mounted) notice(context, 'Bozza salvata');
    } catch (e) {
      if (feedback && mounted) notice(context, 'Bozza non salvata: $e');
    } finally {
      savingDraft = false;
    }
  }

  double aspect = 1, brightness = 1;
  String filter = 'Originale';
  String overlayText = '',
      overlay = '',
      audio = '',
      audioName = '',
      topic = '',
      audience = 'all';
  J? poll, music;
  final J adjustments = {};
  double intensity = 1, textX = .5, textY = .7, textSize = 24;
  Color textColor = Colors.white;
  TextAlign textAlign = TextAlign.center;
  final Map<String, Future<Uint8List>> previews = {};
  Future<Uint8List> photoBytes(String path, {String? preset, int limit = 650}) {
    final args = <String, dynamic>{
      'path': path,
      'aspect': aspect,
      'filter': preset ?? filter,
      'brightness': brightness,
      'intensity': intensity,
      'adjustments': Map<String, dynamic>.from(adjustments),
      'limit': limit,
      'preview': true,
    };
    final key = jsonEncode(args);
    if (previews.length > 60) previews.clear();
    return previews.putIfAbsent(key, () => compute(processPhoto, args));
  }

  Widget processed(String path, {String? preset, int limit = 650}) =>
      FutureBuilder<Uint8List>(
        future: photoBytes(path, preset: preset, limit: limit),
        builder: (c, snapshot) => snapshot.hasData
            ? Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : MediaView(path, fit: BoxFit.cover),
      );
  TextStyle get captionStyle => TextStyle(
    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
    color: textColor,
    fontSize: textSize,
    fontWeight: FontWeight.w700,
    shadows: const [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2)),
    ],
  );
  double exportedTextWidth = .5;
  Future<String> captionImage() async {
    if (overlayText.trim().isEmpty) return '';
    final painter = TextPainter(
      text: TextSpan(
        text: overlayText,
        style: captionStyle.copyWith(fontSize: textSize * 3),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 6,
    )..layout(maxWidth: 1053);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Offset(8, 8));
    final picture = recorder.endRecording();
    final labelWidth = (painter.width + 16).ceil();
    exportedTextWidth = labelWidth / 1170;
    final image = await picture.toImage(
      labelWidth,
      (painter.height + 16).ceil(),
    );
    picture.dispose();
    painter.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return base64Encode(data!.buffer.asUint8List());
  }

  bool aiLabel = false,
      multiple = false,
      loadingGallery = true,
      copying = false;
  List<GalleryPhoto> recent = [];
  final copied = <String, String>{};
  final tagged = <String>{};
  final photos = PageController(keepPage: false);
  void positionPreview() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && photos.hasClients) photos.jumpToPage(index);
    });
  }

  bool busy = false, commentsOff = false, hideLikes = false;
  final overlayInput = TextEditingController();
  final caption = TextEditingController(), location = TextEditingController();
  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    draftId = d?.str('id') ?? newId();
    if (d != null) {
      files = d.ids('files');
      caption.text = d.str('text');
      location.text = d.str('location');
      aspect = d.number('aspect', 1).toDouble();
      filter = d.str('filter', 'Originale');
      brightness = d.number('brightness', 1).toDouble();
      intensity = d.number('intensity', 1).toDouble();
      adjustments.addAll(d.obj('adjustments'));
      overlayText = d.str('overlayText');
      overlay = d.str('overlay');
      poll = d['poll'] == null ? null : d.obj('poll');
      aiLabel = d.flag('aiLabel');
      topic = d.str('topic');
      overlayInput.text = overlayText;
      textX = d.number('textX', .5).toDouble();
      textY = d.number('textY', .7).toDouble();
      textSize = d.number('textSize', 24).toDouble();
      textColor = Color(d.number('textColor', 0xffffffff).toInt());
      textAlign =
          TextAlign.values[d
              .number('textAlign', 2)
              .toInt()
              .clamp(0, TextAlign.values.length - 1)];
      audience = d.str('audience', 'all');
      tagged.addAll(d.ids('tagged'));
      music = d['music'] == null ? null : d.obj('music');
      audioName = d.str('audioName');
      commentsOff = d.flag('commentsOff');
      hideLikes = d.flag('hideLikes');
      step = files.isEmpty ? 0 : 1;
    }
    draftTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) saveDraft();
    });
    loadGallery();
  }

  Future<void> loadGallery() async {
    try {
      final values = await DeviceGallery.recent();
      if (mounted) {
        setState(() => recent = values);
        if (files.isEmpty && values.isNotEmpty) await selectPhoto(values.first);
      }
    } catch (_) {}
    if (mounted) setState(() => loadingGallery = false);
  }

  Future<void> originalRatio(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ratio = (descriptor.width / descriptor.height).clamp(.5, 1.91);
      descriptor.dispose();
      buffer.dispose();
      if (mounted) setState(() => aspect = ratio);
    } catch (_) {}
  }

  Future<void> selectPhoto(GalleryPhoto photo) async {
    if (copying) return;
    setState(() => copying = true);
    await perform(context, () async {
      final path = copied[photo.id] ?? await DeviceGallery.copy(photo.id);
      copied[photo.id] = path;
      if (!mounted) return;
      setState(() {
        if (!multiple) {
          files = [path];
          index = 0;
        } else if (files.contains(path)) {
          files.remove(path);
          index = index.clamp(0, math.max(0, files.length - 1));
        } else if (files.length < 10) {
          files.add(path);
          index = files.length - 1;
        }
      });
      if (files.length == 1) await originalRatio(path);
    });
    if (mounted) {
      setState(() => copying = false);
      positionPreview();
    }
  }

  @override
  void dispose() {
    draftTimer?.cancel();
    photos.dispose();
    overlayInput.dispose();
    caption.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> pick({bool camera = false}) async {
    await perform(context, () async {
      final picker = ImagePicker();
      final chosen = camera
          ? [
              await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 94,
              ),
            ]
          : await picker.pickMultiImage(limit: 10, imageQuality: 94);
      final list = chosen.whereType<XFile>().map((f) => f.path).toList();
      if (mounted && list.isNotEmpty)
        setState(() {
          files = list;
          index = 0;
        });
    });
  }

  Future<void> publish() async {
    await saveDraft();
    if (!mounted) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false),
          root = await getTemporaryDirectory();
      final media = <String>[];
      final label = await captionImage();
      for (final f in files) {
        final path = await compute(renderPostPhoto, {
          'path': f,
          'output': '${root.path}/gpix-post-${newId()}.jpg',
          'aspect': aspect,
          'filter': filter,
          'brightness': brightness,
          'captionPng': label,
          'textX': textX,
          'textY': textY,
          'textWidth': exportedTextWidth,
          'intensity': intensity,
          'adjustments': Map<String, dynamic>.from(adjustments),
          'overlay': overlay,
        });
        try {
          media.add(await s.upload(path, 'image/jpeg'));
        } finally {
          await File(path).delete();
        }
      }
      final track = music?.str('audio') ?? '';
      await s.act('post', {
        'kind': 'post',
        'idempotencyKey': draftId,
        'text': caption.text.trim(),
        'location': location.text.trim(),
        'media': media.first,
        'mediaItems': media,
        'audience': audience,
        'style': {
          'aspect': aspect,
          'draftKey': draftId,
          'audio': track,
          'audioName': audioName,
          if (music != null) 'music': music,
          'taggedUsers': tagged.toList(),
          'aiLabel': aiLabel,
          'topic': topic,
          if (poll != null) 'poll': poll,
        },
      });
      final post = s.posts.firstWhere(
        (p) =>
            p.str('author') == s.myId &&
            p.obj('style').str('draftKey') == draftId,
      );
      if (commentsOff || hideLikes)
        await s.act('postOptions', {
          'id': post['id'],
          'commentsOff': commentsOff,
          'hideLikes': hideLikes,
        });
      if (mounted) {
        Navigator.pop(context);
        unawaited(Drafts.delete('${s.server}|${s.myId}', draftId));
        notice(context, 'Post condiviso');
      }
    });
    if (mounted) setState(() => busy = false);
  }

  List<double> get matrix => postMatrix(filter, brightness);

  static const blue = Color(0xff4d5cff);
  Widget preview({bool finalStep = false}) {
    if (files.isEmpty)
      return const Center(
        child: GIcon(CupertinoIcons.photo, color: Colors.white38, size: 45),
      );
    return PageView.builder(
      key: ValueKey(files.join('|')),
      controller: photos,
      itemCount: files.length,
      onPageChanged: (i) => setState(() => index = i),
      itemBuilder: (c, i) => Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(
            builder: (c, box) => Stack(
              fit: StackFit.expand,
              children: [
                processed(files[i]),
                if (overlayText.isNotEmpty) movableCaption(box),
                if (overlay.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    width: box.maxWidth * .28,
                    child: MediaView(overlay),
                  ),
                if (files.length > 1)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${i + 1}/${files.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget movableCaption(BoxConstraints box) {
    final scale = box.maxWidth / 390;
    final style = captionStyle.copyWith(fontSize: textSize * scale);
    final padding = 8 / 3 * scale;
    final measure = TextPainter(
      text: TextSpan(text: overlayText, style: style),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 6,
    )..layout(maxWidth: box.maxWidth * .9);
    final width = (measure.width + padding * 2)
            .ceilToDouble()
            .clamp(1.0, box.maxWidth)
            .toDouble(),
        height = (measure.height + padding * 2)
            .ceilToDouble()
            .clamp(1.0, box.maxHeight)
            .toDouble();
    measure.dispose();
    final travelX = (box.maxWidth - width).clamp(1, double.infinity),
        travelY = (box.maxHeight - height).clamp(1, double.infinity);
    return Positioned(
      left: textX * travelX,
      top: textY * travelY,
      width: width,
      height: height,
      child: GestureDetector(
        key: const ValueKey('post-draggable-text'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: step == 1
            ? (details) => setState(() {
                textX = (textX + details.delta.dx / travelX).clamp(0, 1);
                textY = (textY + details.delta.dy / travelY).clamp(0, 1);
              })
            : null,
        onDoubleTap: step == 1 ? editText : null,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: RichText(
            text: TextSpan(text: overlayText, style: style),
            textAlign: textAlign,
            textDirection: TextDirection.ltr,
            maxLines: 6,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  Widget circle(IconData icon, VoidCallback action, {String? label}) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon: GIcon(icon, color: Colors.white, size: 22),
      );
  @override
  Widget build(BuildContext c) {
    final dark = step < 2;
    return Scaffold(
      backgroundColor: dark ? const Color(0xff0b0f15) : surface(c),
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xff0b0f15) : surface(c),
        foregroundColor: dark ? Colors.white : foreground(c),
        centerTitle: true,
        leading: IconButton(
          tooltip: step == 0 ? 'Annulla' : 'Indietro',
          onPressed: busy
              ? null
              : () {
                  if (step > 0) {
                    setState(() => step--);
                    positionPreview();
                  } else {
                    Navigator.pop(c);
                  }
                },
          icon: GIcon(
            step == 0 ? CupertinoIcons.xmark : CupertinoIcons.chevron_left,
            color: dark ? Colors.white : foreground(c),
          ),
        ),
        title: Text(
          step == 1 ? 'Modifica post' : 'Nuovo post',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            key: const ValueKey('save-post-draft'),
            onPressed: busy ? null : () => saveDraft(feedback: true),
            icon: GIcon(
              CupertinoIcons.doc_text,
              size: 18,
              color: dark ? Colors.white : foreground(c),
            ),
            label: Text(
              'Bozza',
              style: TextStyle(color: dark ? Colors.white : foreground(c)),
            ),
          ),
          if (step == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: files.isEmpty
                    ? null
                    : () {
                        setState(() => step++);
                        positionPreview();
                      },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: const Color(0xff9ebaff),
                  disabledForegroundColor: Colors.white30,
                ),
                child: const Text(
                  'Avanti',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: step == 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: busy ? null : publish,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      busy ? 'Pubblico…' : 'Condividi',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButton: busy
          ? ValueListenableBuilder<double>(
              valueListenable: GpixScope.of(c).uploadProgress,
              builder: (c, v, _) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface(c),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  v < 1
                      ? 'Caricamento ${(v * 100).round()}%'
                      : 'Pubblicazione…',
                ),
              ),
            )
          : null,
      body: step == 0
          ? selectPage(c)
          : step == 1
          ? editPage(c)
          : share(c),
    );
  }

  Widget selectPage(BuildContext c) => LayoutBuilder(
    builder: (c, box) => Column(
      children: [
        SizedBox(
          height: math.min(
            box.maxHeight * .56,
            MediaQuery.sizeOf(c).width * 1.1,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              preview(),
              Positioned(
                left: 12,
                bottom: 12,
                child: circle(
                  CupertinoIcons.arrow_up_left_arrow_down_right,
                  () => setState(() => aspect = aspect == 1 ? .8 : 1),
                  label: 'Proporzioni',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              TextButton(
                onPressed: () => pick(),
                child: const Row(
                  children: [
                    Text(
                      'Recenti',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 6),
                    GIcon(
                      CupertinoIcons.chevron_down,
                      color: Colors.white,
                      size: 15,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  multiple = !multiple;
                  if (!multiple && files.length > 1) {
                    files = [files[index]];
                    index = 0;
                  }
                }),
                style: TextButton.styleFrom(
                  backgroundColor: multiple ? blue : Colors.white10,
                  foregroundColor: Colors.white,
                ),
                icon: const GIcon(
                  CupertinoIcons.square_on_square,
                  color: Colors.white,
                  size: 19,
                ),
                label: Text(multiple ? 'Multipla' : 'Seleziona'),
              ),
            ],
          ),
        ),
        Expanded(
          child: loadingGallery
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : recent.isEmpty
              ? fallbackGallery(c)
              : GridView.builder(
                  key: const ValueKey('recent-photo-grid'),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: recent.length + 1,
                  itemBuilder: (c, i) {
                    if (i == 0)
                      return InkWell(
                        onTap: () => pick(camera: true),
                        child: const ColoredBox(
                          color: Color(0xff24262b),
                          child: Center(
                            child: GIcon(
                              CupertinoIcons.camera_fill,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      );
                    final photo = recent[i - 1],
                        path = copied[photo.id],
                        number = path == null ? 0 : files.indexOf(path) + 1;
                    return GestureDetector(
                      key: ValueKey('gallery-photo-${photo.id}'),
                      onTap: () => selectPhoto(photo),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(photo.thumbnail, fit: BoxFit.cover),
                          if (number > 0) ColoredBox(color: Colors.black26),
                          if (multiple || number > 0)
                            Positioned(
                              top: 7,
                              right: 7,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: number > 0 ? blue : Colors.black26,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                child: number > 0
                                    ? Center(
                                        child: Text(
                                          '$number',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    : null,
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
  );
  Widget fallbackGallery(BuildContext c) => ListView(
    children: [
      if (files.isNotEmpty)
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final path in files)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: SizedBox(width: 90, child: MediaView(path)),
                ),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed: pick,
          icon: const GIcon(
            CupertinoIcons.photo_on_rectangle,
            color: Colors.white,
          ),
          label: const Text('Apri galleria di sistema'),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 26),
        child: Text(
          'Consenti l’accesso alle foto per vedere qui la griglia dei recenti.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    ],
  );
  Future<void> chooseAudio() async {
    final chosen = await Navigator.of(
      context,
    ).push<J>(MaterialPageRoute(builder: (_) => const MusicPicker()));
    if (chosen != null && mounted)
      setState(() {
        music = chosen;
        audio = chosen.str('audio');
        audioName = '${chosen.str('artist')} · ${chosen.str('title')}';
      });
  }

  Future<void> editText() async {
    final input = overlayInput;
    input.text = overlayText;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1c1f24),
      builder: (c) => StatefulBuilder(
        builder: (c, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(c).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Testo sulla foto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Fine'),
                  ),
                ],
              ),
              TextField(
                controller: input,
                autofocus: true,
                maxLength: 160,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Scrivi qualcosa…',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onChanged: (value) => setState(() => overlayText = value),
              ),
              Row(
                children: [
                  const Text(
                    'Dimensione',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Expanded(
                    child: Slider(
                      value: textSize,
                      min: 14,
                      max: 48,
                      onChanged: (v) {
                        setState(() => textSize = v);
                        update(() {});
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(
                        () => textAlign = textAlign == TextAlign.center
                            ? TextAlign.left
                            : textAlign == TextAlign.left
                            ? TextAlign.right
                            : TextAlign.center,
                      );
                      update(() {});
                    },
                    icon: const Icon(
                      Icons.format_align_center,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final color in [
                    Colors.white,
                    Colors.black,
                    Colors.yellow,
                    Colors.red,
                    Colors.pink,
                    Colors.cyan,
                  ])
                    InkWell(
                      onTap: () {
                        setState(() => textColor = color);
                        update(() {});
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textColor == color
                                ? Colors.white
                                : Colors.white24,
                            width: textColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Trascina il testo sulla foto per spostarlo. Toccalo due volte per modificarlo.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget editPage(BuildContext c) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: chooseAudio,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                ),
                icon: const GIcon(
                  CupertinoIcons.music_note_2,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  audioName.isEmpty ? 'Aggiungi musica' : audioName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (audio.isNotEmpty)
              IconButton(
                onPressed: () => setState(() {
                  audio = '';
                  audioName = '';
                  music = null;
                }),
                icon: const GIcon(
                  CupertinoIcons.xmark,
                  color: Colors.white,
                  size: 17,
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: Center(
          child: AspectRatio(aspectRatio: aspect, child: preview()),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 93,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            tool(CupertinoIcons.textformat, 'Testo', editText),
            tool(CupertinoIcons.square_on_square, 'Overlay', () async {
              final value = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
              );
              if (value != null && mounted)
                setState(() => overlay = value.path);
            }),
            tool(
              CupertinoIcons.color_filter,
              'Filtri',
              () => adjust(c, filters: true),
            ),
            tool(
              CupertinoIcons.slider_horizontal_3,
              'Modifica',
              () => adjust(c, filters: false),
            ),
            tool(CupertinoIcons.crop, 'Proporzioni', () => ratios(c)),
            tool(
              CupertinoIcons.arrow_counterclockwise,
              'Ripristina',
              () => setState(() {
                filter = 'Originale';
                brightness = 1;
                adjustments.clear();
                intensity = 1;
                textX = .5;
                textY = .7;
                textSize = 24;
                overlay = '';
                overlayText = '';
                aspect = 1;
              }),
            ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < files.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => index = i);
                              positionPreview();
                            },
                            child: Container(
                              width: 42,
                              height: 52,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: index == i
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: MediaView(files[i]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  setState(() => step = 2);
                  positionPreview();
                },
                style: FilledButton.styleFrom(backgroundColor: blue),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Avanti'),
                    SizedBox(width: 7),
                    GIcon(
                      CupertinoIcons.arrow_right,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget tool(IconData icon, String title, VoidCallback action) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: InkWell(
      onTap: action,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 74,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GIcon(icon, color: Colors.white, size: 25),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> adjust(BuildContext c, {required bool filters}) async {
    final oldFilter = filter,
        oldIntensity = intensity,
        oldValues = Map<String, dynamic>.from(adjustments);
    var selected = filters ? filter : 'Luminosità', committed = false;
    await showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1c1f24),
      builder: (c) => StatefulBuilder(
        builder: (c, update) => SafeArea(
          child: SizedBox(
            height: filters ? 300 : 330,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Annulla'),
                      ),
                      Expanded(
                        child: Text(
                          filters ? 'Filtri' : 'Modifica',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          committed = true;
                          Navigator.pop(c);
                        },
                        child: const Text('Fine'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      if (filters)
                        for (final name in photoFilters.keys)
                          InkWell(
                            onTap: () {
                              setState(() => filter = name);
                              update(() => selected = name);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: filter == name
                                          ? Colors.white
                                          : Colors.white60,
                                      fontWeight: filter == name
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: 86,
                                    height: 90,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: filter == name
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: processed(
                                      files[index],
                                      preset: name,
                                      limit: 150,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                      else
                        for (var i = 0; i < photoAdjustments.length; i++)
                          InkWell(
                            onTap: () =>
                                update(() => selected = photoAdjustments[i]),
                            child: SizedBox(
                              width: 100,
                              child: Column(
                                children: [
                                  Text(
                                    photoAdjustments[i],
                                    style: TextStyle(
                                      color: selected == photoAdjustments[i]
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: 70,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected == photoAdjustments[i]
                                            ? blue
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: Icon(
                                      [
                                        Icons.rotate_right,
                                        Icons.auto_fix_high,
                                        Icons.wb_sunny_outlined,
                                        Icons.contrast,
                                        Icons.water_drop_outlined,
                                        Icons.color_lens_outlined,
                                        Icons.cloud_outlined,
                                        Icons.light_mode_outlined,
                                        Icons.tonality,
                                        Icons.vignette,
                                        Icons.blur_linear,
                                        Icons.details_outlined,
                                      ][i],
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                Text(
                  filters
                      ? 'Intensità · ${(intensity * 100).round()}'
                      : '$selected · ${adjustments.number(selected).round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Slider(
                  value: filters ? intensity : adjustments.number(selected),
                  min: filters
                      ? 0
                      : [
                          'Regola',
                          'Luminosità',
                          'Contrasto',
                          'Saturazione',
                          'Colore',
                          'Alte luci',
                          'Ombre',
                        ].contains(selected)
                      ? -100
                      : 0,
                  max: filters ? 1 : 100,
                  onChanged: (v) {
                    setState(() {
                      if (filters)
                        intensity = v;
                      else
                        adjustments[selected] = v;
                    });
                    update(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!committed && mounted)
      setState(() {
        filter = oldFilter;
        intensity = oldIntensity;
        adjustments
          ..clear()
          ..addAll(oldValues);
      });
  }

  Future<void> ratios(BuildContext c) => sheet(
    c,
    Column(
      children: [
        for (final entry in {
          1.0: 'Quadrato · 1:1',
          .8: 'Verticale · 4:5',
          .75: 'Ritratto · 3:4',
          1.91: 'Orizzontale',
        }.entries)
          ActionRow(CupertinoIcons.crop, entry.value, () {
            setState(() => aspect = entry.key);
            Navigator.pop(c);
          }),
      ],
    ),
  );
  Future<void> tagPeople(BuildContext c) => sheet(
    c,
    StatefulBuilder(
      builder: (c, update) {
        final store = GpixScope.of(c);
        return Column(
          children: [
            const Text(
              'Tagga persone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            for (final u in store.users.where(
              (u) => u.str('id') != store.myId && !store.blocked(u.str('id')),
            ))
              CheckboxListTile(
                value: tagged.contains(u.str('id')),
                title: Text(u.str('username')),
                secondary: Avatar(u.str('id'), size: 34),
                onChanged: (value) {
                  setState(
                    () => value == true
                        ? tagged.add(u.str('id'))
                        : tagged.remove(u.str('id')),
                  );
                  update(() {});
                },
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: PrimaryButton('Fine', onTap: () => Navigator.pop(c)),
            ),
          ],
        );
      },
    ),
  );
  Widget share(BuildContext c) {
    final store = GpixScope.of(c);
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        const SizedBox(height: 12),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 180,
              height: 240,
              child: preview(finalStep: true),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          child: TextField(
            controller: caption,
            maxLength: 2200,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Aggiungi una didascalia…',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 10,
            children: [
              ActionChip(
                avatar: const GIcon(CupertinoIcons.list_bullet, size: 18),
                label: Text(poll == null ? 'Sondaggio' : 'Sondaggio aggiunto'),
                onPressed: () async {
                  final value = await showDialog<J>(
                    context: c,
                    builder: (_) => PollEditor(initial: poll),
                  );
                  if (value != null && mounted)
                    setState(() => poll = value.isEmpty ? null : value);
                },
              ),
              ActionChip(
                avatar: const GIcon(CupertinoIcons.chat_bubble, size: 18),
                label: Text(topic.isEmpty ? 'Tema' : topic),
                onPressed: () async {
                  final value = await textDialog(c, 'Tema del post', topic);
                  if (value != null && mounted)
                    setState(() => topic = value.trim());
                },
              ),
            ],
          ),
        ),
        row(
          c,
          CupertinoIcons.music_note_2,
          'Aggiungi musica',
          audioName.isEmpty ? null : audioName,
          chooseAudio,
        ),
        row(
          c,
          CupertinoIcons.person_crop_rectangle,
          'Tagga persone',
          tagged.isEmpty ? null : '${tagged.length} persone',
          () => tagPeople(c),
        ),
        row(
          c,
          CupertinoIcons.placemark,
          'Aggiungi luogo',
          location.text.isEmpty ? null : location.text,
          () async {
            final value = await textDialog(c, 'Aggiungi luogo', location.text);
            if (value != null && mounted) setState(() => location.text = value);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(
            spacing: 7,
            children: [
              for (final place in ['Roma', 'Milano', 'Reggio di Calabria'])
                ActionChip(
                  label: Text(place),
                  onPressed: () => setState(() => location.text = place),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Divider(thickness: 6, height: 18),
        SwitchListTile.adaptive(
          secondary: const GIcon(CupertinoIcons.sparkles),
          title: const Text(
            'Aggiungi etichetta IA',
            style: TextStyle(fontSize: 15),
          ),
          subtitle: const Text(
            'Segnala contenuti realistici creati o modificati con l’IA.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          value: aiLabel,
          onChanged: (value) => setState(() => aiLabel = value),
        ),
        row(
          c,
          CupertinoIcons.person_2,
          'Pubblico',
          audience == 'close'
              ? 'Amici più stretti'
              : store.me.flag('private')
              ? 'Follower'
              : 'Come il tuo profilo',
          () => sheet(
            c,
            Column(
              children: [
                ActionRow(CupertinoIcons.person_2, 'Come il tuo profilo', () {
                  setState(() => audience = 'all');
                  Navigator.pop(c);
                }),
                ActionRow(CupertinoIcons.star_circle, 'Amici più stretti', () {
                  setState(() => audience = 'close');
                  Navigator.pop(c);
                }),
              ],
            ),
          ),
        ),
        const Divider(thickness: 6, height: 18),
        row(
          c,
          CupertinoIcons.ellipsis,
          'Altre opzioni',
          null,
          () => sheet(
            c,
            StatefulBuilder(
              builder: (c, update) => Column(
                children: [
                  SwitchListTile(
                    title: const Text('Disattiva commenti'),
                    value: commentsOff,
                    onChanged: (v) {
                      setState(() => commentsOff = v);
                      update(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Nascondi numero di Mi piace'),
                    value: hideLikes,
                    onChanged: (v) {
                      setState(() => hideLikes = v);
                      update(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: PrimaryButton('Fine', onTap: () => Navigator.pop(c)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget row(
    BuildContext c,
    IconData icon,
    String label,
    String? detail,
    VoidCallback action,
  ) => ListTile(
    minVerticalPadding: 16,
    leading: GIcon(icon, size: 26),
    title: Text(label, style: const TextStyle(fontSize: 15)),
    subtitle: detail == null
        ? null
        : Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
    trailing: const GIcon(CupertinoIcons.chevron_right, size: 17, color: muted),
    onTap: action,
  );
}

class PollEditor extends StatefulWidget {
  final J? initial;
  const PollEditor({super.key, this.initial});
  @override
  State<PollEditor> createState() => _PollEditorState();
}

class _PollEditorState extends State<PollEditor> {
  late final question = TextEditingController(
    text: widget.initial?.str('question') ?? '',
  );
  late final a = TextEditingController(
    text: widget.initial?.ids('options').firstOrNull ?? '',
  );
  late final b = TextEditingController(
    text: (widget.initial?.ids('options').length ?? 0) > 1
        ? widget.initial!.ids('options')[1]
        : '',
  );
  @override
  void dispose() {
    question.dispose();
    a.dispose();
    b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('Sondaggio'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: question,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Domanda'),
          ),
          TextField(
            controller: a,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Opzione 1'),
          ),
          TextField(
            controller: b,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Opzione 2'),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.initial != null)
        TextButton(
          onPressed: () => Navigator.pop(c, <String, dynamic>{}),
          child: const Text('Rimuovi'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const Text('Annulla'),
      ),
      FilledButton(
        onPressed: () {
          if (question.text.trim().isNotEmpty &&
              a.text.trim().isNotEmpty &&
              b.text.trim().isNotEmpty)
            Navigator.pop(c, {
              'question': question.text.trim(),
              'options': [a.text.trim(), b.text.trim()],
            });
        },
        child: const Text('Aggiungi'),
      ),
    ],
  );
}
