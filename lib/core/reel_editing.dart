import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'data.dart';
import 'store.dart';

const reelMaxDurationMs = 90000;
const reelMinimumClipMs = 350;
const reelFrameWidth = 540;
const reelFrameHeight = 960;

class ReelClip {
  const ReelClip({
    required this.id,
    required this.path,
    required this.photo,
    required this.originalMs,
    required this.startMs,
    required this.endMs,
    this.thumbnail,
  });

  final String id, path;
  final bool photo;
  final int originalMs, startMs, endMs;
  final Uint8List? thumbnail;

  int get durationMs => endMs - startMs;

  ReelClip trim(int start, int end) {
    final minDuration = math.min(reelMinimumClipMs, originalMs);
    final first = start.clamp(0, originalMs - minDuration);
    return ReelClip(
      id: id,
      path: path,
      photo: photo,
      originalMs: originalMs,
      startMs: first,
      endMs: end.clamp(first + minDuration, originalMs),
      thumbnail: thumbnail,
    );
  }

  J toJson() => {
    'id': id,
    'path': path,
    'photo': photo,
    'originalMs': originalMs,
    'startMs': startMs,
    'endMs': endMs,
  };
}

class ReelText {
  const ReelText({
    this.text = '',
    this.x = .5,
    this.y = .45,
    this.color = 0xffffffff,
    this.background = false,
  });

  factory ReelText.fromJson(J json) => ReelText(
    text: json.str('text'),
    x: json.number('x', .5).clamp(.08, .92).toDouble(),
    y: json.number('y', .45).clamp(.07, .93).toDouble(),
    color: json.number('color', 0xffffffff).toInt(),
    background: json.flag('background'),
  );

  final String text;
  final double x, y;
  final int color;
  final bool background;

  ReelText move(double left, double top) => ReelText(
    text: text,
    x: left.clamp(.08, .92),
    y: top.clamp(.07, .93),
    color: color,
    background: background,
  );

  J toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'color': color,
    'background': background,
  };

  void draw(Canvas canvas, Size size, {required TextDirection direction}) {
    if (text.trim().isEmpty) return;
    final scale = size.width / reelFrameWidth;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 37 * scale,
          height: 1.15,
          color: Color(color),
          fontWeight: FontWeight.w700,
          shadows: background
              ? null
              : [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 8 * scale,
                    offset: Offset(0, 2 * scale),
                  ),
                ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: direction,
      maxLines: 5,
      ellipsis: '…',
    )..layout(maxWidth: size.width * .86);
    final center = Offset(
      (size.width * x).clamp(
        painter.width / 2 + 9 * scale,
        size.width - painter.width / 2 - 9 * scale,
      ),
      (size.height * y).clamp(
        painter.height / 2 + 9 * scale,
        size.height - painter.height / 2 - 9 * scale,
      ),
    );
    final bounds = Rect.fromCenter(
      center: center,
      width: painter.width,
      height: painter.height,
    );
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds.inflate(9 * scale),
          Radius.circular(12 * scale),
        ),
        Paint()
          ..color = color == 0xff101115
              ? Colors.white
              : const Color(0xd919191c),
      );
    }
    painter.paint(canvas, bounds.topLeft);
    painter.dispose();
  }

  Future<String> rasterize(Directory folder, TextDirection direction) async {
    final recorder = ui.PictureRecorder();
    const frame = Size(540, 960);
    draw(Canvas(recorder), frame, direction: direction);
    final picture = recorder.endRecording();
    final image = await picture.toImage(reelFrameWidth, reelFrameHeight);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      return (await File('${folder.path}/overlay.png').writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      )).path;
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

class ReelMedia {
  static const channel = MethodChannel('GPIX/reelEditing');

  static Future<ReelClip> prepare(
    String path, {
    int photoDuration = 3000,
    J? saved,
  }) async {
    final meta =
        await channel.invokeMapMethod<String, dynamic>('inspect', {
          'path': path,
        }) ??
        {};
    final photo = meta.flag('photo');
    final original = photo
        ? (saved?.number('originalMs', photoDuration.toDouble()) ??
                  photoDuration)
              .toInt()
              .clamp(1000, 10000)
        : meta.number('durationMs').toInt();
    if (original < 1) throw Exception('Impossibile leggere questa clip.');
    final clip = ReelClip(
      id: saved?.str('id', newId()) ?? newId(),
      path: path,
      photo: photo,
      originalMs: original,
      startMs: 0,
      endMs: math.min(original, reelMaxDurationMs),
      thumbnail: meta['thumbnail'] as Uint8List?,
    );
    return saved == null
        ? clip
        : clip.trim(
            saved.number('startMs').toInt(),
            saved.number('endMs', clip.endMs.toDouble()).toInt(),
          );
  }

  static Future<List<Uint8List>> frames(
    ReelClip clip,
    List<int> positions,
  ) async {
    return (await channel.invokeListMethod<Uint8List>('frames', {
          'path': clip.path,
          'photo': clip.photo,
          'positions': positions,
          'size': 175,
        })) ??
        [];
  }

  static Future<String> cover({
    required String path,
    required bool photo,
    required int positionMs,
    required Directory folder,
  }) async => (await channel.invokeMethod<String>('cover', {
    'path': path,
    'photo': photo,
    'positionMs': positionMs,
    'output': '${folder.path}/cover.jpg',
  }))!;

  static Future<String> export({
    required List<ReelClip> clips,
    required bool originalAudio,
    required Directory folder,
    String? overlay,
    String? music,
    int musicStartMs = 0,
    int musicLengthMs = 15000,
  }) async {
    final result = await channel.invokeMethod<String>('export', {
      'clips': [for (final clip in clips) clip.toJson()],
      'originalAudio': originalAudio,
      'overlay': overlay,
      'music': music,
      'musicStartMs': musicStartMs,
      'musicLengthMs': musicLengthMs,
      'output': '${folder.path}/reel.mp4',
    });
    if (result == null || !await File(result).exists()) {
      throw Exception('Il video non è stato esportato. Riprova.');
    }
    return result;
  }
}

/// Imports only this account's signed GPIX media (or the bundled demo assets).
Future<String> reelImport(
  GpixStore store,
  String reference, {
  required String extension,
  required Directory folder,
  required String name,
}) async {
  final source = store.url(reference);
  final uri = Uri.parse(source);
  final file = File('${folder.path}/$name.$extension');
  if (store.demo && !uri.hasScheme) {
    if (source.startsWith('/'))
      return (await File(source).copy(file.path)).path;
    final data = await rootBundle.load('assets/media/$source');
    return (await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    )).path;
  }
  final server = Uri.parse(store.server);
  if (uri.scheme != 'https' ||
      uri.host != server.host ||
      uri.port != server.port ||
      !(uri.path.startsWith('/media/') ||
          uri.path.startsWith('/music/audio/'))) {
    throw Exception('Contenuto GPIX non disponibile.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 25));
    if (response.statusCode != HttpStatus.ok) {
      throw Exception('Contenuto multimediale non disponibile. Riprova.');
    }
    await response.timeout(const Duration(seconds: 30)).pipe(file.openWrite());
    if (await file.length() == 0) throw Exception('Il file è vuoto.');
    return file.path;
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  } finally {
    client.close(force: true);
  }
}

Future<Directory> reelWorkingDirectory() async =>
    (await getTemporaryDirectory()).createTemp('gpix-editor-reel-');
