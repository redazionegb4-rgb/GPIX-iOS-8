import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../ui/kit.dart';

Future<String> storyComposite(
  List<String> paths,
  String output, {
  bool boomerang = false,
}) => Isolate.run(() {
  final frames = paths
      .map(
        (p) => im.bakeOrientation(im.decodeImage(File(p).readAsBytesSync())!),
      )
      .toList();
  if (boomerang) {
    final order = [
      ...frames,
      ...frames.reversed.skip(1).take(math.max(0, frames.length - 2)),
    ];
    im.Image? animation;
    for (final frame in order) {
      final f = im.copyResize(frame, width: 480)..frameDuration = 100;
      if (animation == null) {
        animation = f;
      } else {
        animation.addFrame(f);
      }
    }
    File(output).writeAsBytesSync(im.encodeGif(animation!, repeat: 0));
  } else {
    final canvas = im.Image(width: 720, height: 1280);
    final cols = frames.length == 4 ? 2 : 1, rows = 2;
    final width = 720 ~/ cols, height = 1280 ~/ rows;
    for (var i = 0; i < frames.length; i++) {
      final src = frames[i],
          scale = math.max(width / src.width, height / src.height);
      final resized = im.copyResize(
        src,
        width: (src.width * scale).ceil(),
        height: (src.height * scale).ceil(),
      );
      final crop = im.copyCrop(
        resized,
        x: (resized.width - width) ~/ 2,
        y: (resized.height - height) ~/ 2,
        width: width,
        height: height,
      );
      im.compositeImage(
        canvas,
        crop,
        dstX: (i % cols) * width,
        dstY: (i ~/ cols) * height,
      );
    }
    File(output).writeAsBytesSync(im.encodeJpg(canvas, quality: 90));
  }
  return output;
});

class StoryCamera extends StatefulWidget {
  final ValueChanged<String> onMedia, onMode;
  final VoidCallback onCreate;
  const StoryCamera({
    super.key,
    required this.onMedia,
    required this.onMode,
    required this.onCreate,
  });
  @override
  State<StoryCamera> createState() => _StoryCameraState();
}

class _StoryCameraState extends State<StoryCamera> with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  int lens = 0, seconds = 0, cells = 2, generation = 0;
  String mode = 'Storia', error = '', status = '';
  bool busy = false,
      flash = false,
      grid = false,
      audio = true,
      hold = false,
      recording = false;
  Timer? timer;
  final captures = <String>[];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    final request = ++generation;
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Nessuna fotocamera disponibile.');
      await controller?.dispose();
      final next = CameraController(
        cameras[lens % cameras.length],
        ResolutionPreset.high,
        enableAudio: audio,
      );
      controller = next;
      await next.initialize();
      if (!mounted || request != generation) {
        await next.dispose();
        return;
      }
      setState(() => error = '');
    } catch (e) {
      if (mounted && request == generation)
        setState(
          () => error =
              'Fotocamera non disponibile. Consenti l’accesso nelle impostazioni oppure scegli un file dalla galleria.',
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      timer?.cancel();
      generation++;
      final previous = controller;
      if (recording) {
        unawaited(stop().whenComplete(() => previous?.dispose()));
      } else {
        previous?.dispose();
      }
      controller = null;
    } else if (state == AppLifecycleState.resumed) {
      initialize();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  Future<void> gallery() async {
    await perform(context, () async {
      final kind = await sheet<String>(
        context,
        Column(
          children: [
            ActionRow(
              CupertinoIcons.photo,
              'Foto',
              () => Navigator.pop(context, 'photo'),
            ),
            ActionRow(
              CupertinoIcons.video_camera,
              'Video',
              () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 15),
          ],
        ),
      );
      if (kind == null) return;
      final f = kind == 'video'
          ? await ImagePicker().pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 60),
            )
          : await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1800,
              imageQuality: 90,
            );
      if (f != null) widget.onMedia(f.path);
    });
  }

  Future<void> shoot() async {
    if (busy) return;
    if (recording) {
      await stop();
      return;
    }
    if (mode == 'Senza tenere premuto') {
      await record();
      return;
    }
    final c = controller;
    if (c == null || !c.value.isInitialized) {
      notice(
        context,
        'Scegli un file dalla galleria oppure abilita la fotocamera.',
      );
      return;
    }
    setState(() => busy = true);
    await perform(context, () async {
      if (mode == 'Boomerang') {
        final frames = <String>[];
        for (var i = 0; i < 6; i++) {
          if (!mounted) return;
          setState(() => status = '${i + 1}/6');
          frames.add((await c.takePicture()).path);
        }
        final dir = await getTemporaryDirectory();
        final path = await storyComposite(
          frames,
          '${dir.path}/gpix-boom-${DateTime.now().microsecondsSinceEpoch}.gif',
          boomerang: true,
        );
        if (mounted) widget.onMedia(path);
      } else {
        final path = (await c.takePicture()).path;
        if (mode == 'Layout') {
          captures.add(path);
          if (captures.length < cells) {
            setState(() => status = '${captures.length}/$cells');
            return;
          }
          final dir = await getTemporaryDirectory();
          final result = await storyComposite(
            List.of(captures),
            '${dir.path}/gpix-layout-${DateTime.now().microsecondsSinceEpoch}.jpg',
          );
          if (mounted) widget.onMedia(result);
        } else {
          widget.onMedia(path);
        }
      }
    });
    if (mounted)
      setState(() {
        busy = false;
        status = '';
      });
  }

  Future<void> record() async {
    final c = controller;
    if (c == null || !c.value.isInitialized || busy || recording) return;
    setState(() => busy = true);
    await perform(context, () async {
      await c.startVideoRecording();
      if (!mounted) return;
      setState(() {
        recording = true;
        seconds = 0;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => seconds++);
        if (seconds >= 60) stop();
      });
      if (mode != 'Senza tenere premuto' && !hold) await stop();
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> stop() async {
    if (!recording) return;
    timer?.cancel();
    setState(() => recording = false);
    await perform(context, () async {
      final f = await controller!.stopVideoRecording();
      if (mounted) widget.onMedia(f.path);
    });
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: const Color(0xff090d12),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (controller?.value.isInitialized == true)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller!.value.previewSize!.height,
                        height: controller!.value.previewSize!.width,
                        child: CameraPreview(controller!),
                      ),
                    )
                  else
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff26242b), Color(0xff0b111a)],
                        ),
                      ),
                    ),
                  if (grid || mode == 'Layout')
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _CameraGrid(mode == 'Layout' ? cells : 9),
                      ),
                    ),
                  Positioned(
                    top: 9,
                    left: 7,
                    right: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Chiudi fotocamera',
                          onPressed: () => Navigator.pop(c),
                          icon: const GIcon(
                            CupertinoIcons.xmark,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                        IconButton(
                          tooltip: flash ? 'Disattiva flash' : 'Attiva flash',
                          onPressed: () => perform(c, () async {
                            final next = !flash;
                            await controller?.setFlashMode(
                              next ? FlashMode.torch : FlashMode.off,
                            );
                            setState(() => flash = next);
                          }),
                          icon: GIcon(
                            flash
                                ? CupertinoIcons.bolt_fill
                                : CupertinoIcons.bolt_slash_fill,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Impostazioni fotocamera',
                          onPressed: () => sheet(
                            c,
                            StatefulBuilder(
                              builder: (c, update) => Column(
                                children: [
                                  const Text(
                                    'Fotocamera',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SwitchListTile(
                                    title: const Text('Griglia'),
                                    value: grid,
                                    onChanged: (v) {
                                      setState(() => grid = v);
                                      update(() {});
                                    },
                                  ),
                                  SwitchListTile(
                                    title: const Text('Audio nei video'),
                                    value: audio,
                                    onChanged: (v) {
                                      setState(() => audio = v);
                                      update(() {});
                                      initialize();
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                          icon: const GIcon(
                            CupertinoIcons.gear_alt,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: MediaQuery.sizeOf(c).height * .34,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tool(
                          CupertinoIcons.textformat,
                          'Crea',
                          widget.onCreate,
                        ),
                        tool(CupertinoIcons.infinite, 'Boomerang', () {
                          setState(() {
                            mode = mode == 'Boomerang' ? 'Storia' : 'Boomerang';
                            captures.clear();
                          });
                        }),
                        tool(CupertinoIcons.square_split_2x2, 'Layout', () {
                          setState(() {
                            mode = 'Layout';
                            cells = cells == 2 ? 4 : 2;
                            captures.clear();
                          });
                        }),
                        tool(
                          CupertinoIcons.stop_circle,
                          'Senza tenere premuto',
                          () {
                            setState(
                              () => mode = mode == 'Senza tenere premuto'
                                  ? 'Storia'
                                  : 'Senza tenere premuto',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (error.isNotEmpty)
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 150,
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 21,
                    child: Column(
                      children: [
                        if (status.isNotEmpty || mode != 'Storia')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: Text(
                              status.isNotEmpty
                                  ? status
                                  : mode == 'Layout'
                                  ? 'Layout · $cells foto'
                                  : mode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (recording)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '00:${seconds.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        GestureDetector(
                          onTap: shoot,
                          onLongPressStart: (_) {
                            hold = true;
                            record();
                          },
                          onLongPressEnd: (_) {
                            hold = false;
                            stop();
                          },
                          child: Semantics(
                            label: 'Scatta foto o registra video',
                            button: true,
                            child: Container(
                              width: 78,
                              height: 78,
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: recording
                                      ? danger
                                      : Colors.white.withValues(alpha: .85),
                                ),
                                child: busy
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: ink,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : recording
                                    ? const GIcon(
                                        CupertinoIcons.stop_fill,
                                        color: Colors.white,
                                        size: 30,
                                      )
                                    : null,
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
          ),
          SizedBox(
            height: 88,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Galleria',
                    onPressed: gallery,
                    icon: const GIcon(
                      CupertinoIcons.photo,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final item in ['POST', 'STORIA', 'REEL'])
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: item == 'STORIA'
                                ? null
                                : () => widget.onMode(
                                    item.toLowerCase() == 'post'
                                        ? 'post'
                                        : 'reel',
                                  ),
                            child: Text(
                              item,
                              style: TextStyle(
                                color: item == 'STORIA'
                                    ? Colors.white
                                    : Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cambia fotocamera',
                    onPressed: () {
                      lens++;
                      initialize();
                    },
                    icon: const GIcon(
                      CupertinoIcons.camera_rotate,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget tool(IconData icon, String label, VoidCallback tap) => InkWell(
    onTap: tap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GIcon(icon, color: Colors.white, size: 25),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              color: label == mode
                  ? Colors.white
                  : Colors.white.withValues(alpha: .88),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CameraGrid extends CustomPainter {
  final int count;
  _CameraGrid(this.count);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    final cols = count == 9
            ? 3
            : count == 4
            ? 2
            : 1,
        rows = count == 9 ? 3 : 2;
    for (var i = 1; i < cols; i++) {
      c.drawLine(
        Offset(s.width * i / cols, 0),
        Offset(s.width * i / cols, s.height),
        p,
      );
    }
    for (var i = 1; i < rows; i++) {
      c.drawLine(
        Offset(0, s.height * i / rows),
        Offset(s.width, s.height * i / rows),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_CameraGrid old) => old.count != count;
}
