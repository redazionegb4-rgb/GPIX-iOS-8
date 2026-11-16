import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/avatar_style.dart';

/// Draws the same avatar in the editor, in its thumbnail and in the photo export.
class AvatarPreview extends StatelessWidget {
  const AvatarPreview({
    super.key,
    required this.style,
    this.rotation = 0,
    this.fullBody = false,
    this.detail = true,
  });

  final AvatarStyle style;
  final double rotation;
  final bool fullBody, detail;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _AvatarPainter(style, rotation, fullBody, detail),
      child: const SizedBox.expand(),
    ),
  );

  static Future<Uint8List> profilePhoto(AvatarStyle style) async {
    const size = Size.square(576);
    final recorder = ui.PictureRecorder();
    _AvatarPainter(style, -.12, false, true).paint(Canvas(recorder), size);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('Impossibile creare la foto avatar.');
        return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }
}

class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.style, this.rotation, this.fullBody, this.detail);

  final AvatarStyle style;
  final double rotation;
  final bool fullBody, detail;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffb1a4ed), Color(0xffd0e4fa), Color(0xffeff8fc)],
          stops: [0, .56, 1],
        ).createShader(rect),
    );

    final scale = fullBody
        ? math.min(size.width / 2.35, size.height / 4.04)
        : math.min(size.width / 1.57, size.height / 1.89);
    final scene = _AvatarScene(
      origin: Offset(size.width / 2, size.height * (fullBody ? .515 : .48)),
      scale: scale,
      focusY: fullBody ? 1.92 : 2.93,
      rotation: rotation,
      detail: detail,
    );
    if (fullBody) {
      final shadow = Rect.fromCenter(
        center: scene.project(0, .04, 0),
        width: scale * 1.3,
        height: scale * .21,
      );
      canvas.drawOval(
        shadow,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x46424a76), Color(0x00424a76)],
          ).createShader(shadow),
      );
    }

    final skin = AvatarStyle.skinTones[style[AvatarFeature.skin]];
    final hair = AvatarStyle.hairTones[style[AvatarFeature.hairColor]];
    final iris = AvatarStyle.eyeTones[style[AvatarFeature.eyeColor]];
    final shirt = AvatarStyle.outfitTones[style[AvatarFeature.outfit]];
    final width = (style[AvatarFeature.faceWidth] - 50) / 450;
    final cheeks = (style[AvatarFeature.cheeks] - 50) / 520;
    final jaw = (style[AvatarFeature.jaw] - 50) / 410;
    final head = (style[AvatarFeature.face], .548 + width, cheeks, jaw);
    final headWidth = head.$2;
    final body = style[AvatarFeature.body];
    final bodyWidth = [.46, .52, .6, .67][body];
    final shoulders = bodyWidth + (style[AvatarFeature.shoulders] - 50) / 440;
    final waist = bodyWidth * .74 + (style[AvatarFeature.waist] - 50) / 440;
    final legLength = .55 + (style[AvatarFeature.height] - 50) / 440;
    final torso = fullBody ? 1.72 + (legLength - .55) * .55 : 1.72;
    final headY = torso + 1.19;
    final eyeY = headY + .10;
    final pants = Color.lerp(const Color(0xff273755), shirt, .12)!;
    final hairStyle = style[AvatarFeature.hair];

    if (fullBody) {
      for (final side in [-1.0, 1.0]) {
        scene.oval(
          side * waist * .49,
          .18,
          .055,
          .15,
          .09,
          .235,
          const Color(0xffece9ed),
        );
        scene.oval(
          side * waist * .49,
          .115,
          .07,
          .156,
          .039,
          .24,
          const Color(0xffafb8c9),
        );
        scene.oval(
          side * waist * .49,
          .25 + legLength * .74,
          0,
          .13 + waist * .08,
          legLength,
          .15,
          pants,
          roll: side * -.055,
        );
      }
      scene.oval(0, torso - .5, 0, waist, .255, .255, pants);
    }
    scene.layer = 3;
    scene.oval(0, torso - .03, 0, waist + .055, .54, .28, shirt);
    scene.oval(0, torso + .218, 0, shoulders, .34, .292, shirt);
    scene.layer = 4;
    scene.oval(0, torso + .51, .004, .224, .28, .21, skin);
    for (final side in [-1.0, 1.0]) {
      scene.layer = 2;
      scene.oval(
        side * shoulders * 1.03,
        torso + .116,
        0,
        .17,
        .245,
        .177,
        shirt,
        roll: side * .36,
      );
      scene.layer = 1;
      scene.oval(
        side * (shoulders + .138),
        torso - .22,
        .012,
        .11,
        .317,
        .114,
        skin,
        roll: side * .22,
      );
      if (fullBody) {
        scene.oval(
          side * (shoulders + .194),
          torso - .57,
          .025,
          .082,
          .145,
          .096,
          skin,
          roll: side * .15,
        );
        scene.oval(
          side * (shoulders + .12),
          torso - .53,
          .087,
          .035,
          .08,
          .043,
          skin,
          roll: side * -.47,
        );
      }
    }

    scene.layer = 4;
    if (hairStyle == 4) {
      scene.oval(0, headY - .25, -.235, headWidth + .095, .88, .34, hair);
      for (final side in [-1.0, 1.0]) {
        scene.oval(
          side * (headWidth - .015),
          headY - .37,
          .008,
          .15,
          .63,
          .173,
          hair,
          roll: side * .18,
        );
      }
    }
    if (hairStyle == 5) {
      scene.oval(.045, headY + .59, -.42, .255, .24, .225, hair);
    }
    scene.layer = 5;
    for (final side in [-1.0, 1.0]) {
      scene.oval(
        side * (headWidth - .018),
        headY - .005,
        -.012,
        .112,
        .175,
        .13,
        skin,
        roll: side * -.18,
      );
      scene.oval(
        side * (headWidth + .031),
        headY - .012,
        .057,
        .052,
        .099,
        .064,
        Color.lerp(skin, const Color(0xff9e433c), .23)!,
      );
    }
    scene.layer = 6;
    scene.oval(0, headY, 0, headWidth, .691, .533, skin, face: head);

    scene.layer = 12;
    scene.oval(0, headY - .029, .489, .079, .105, .122, skin);

    final eyeX = headWidth * .405;
    final lid = Color.lerp(skin, const Color(0xff402524), .53)!;
    for (final side in [-1.0, 1.0]) {
      final x = side * eyeX;
      scene.layer = 7;
      scene.oval(x, eyeY, .457, .117, .076, .079, lid, roll: side * -.11);
      scene.layer = 8;
      scene.oval(
        x,
        eyeY - .008,
        .477,
        .105,
        .060,
        .069,
        const Color(0xfff6eee8),
        roll: side * -.10,
      );
      scene.layer = 9;
      scene.oval(x - .007, eyeY - .007, .531, .051, .061, .034, iris);
      scene.layer = 10;
      scene.oval(
        x - .01,
        eyeY - .006,
        .553,
        .031,
        .043,
        .022,
        const Color(0xff251b20),
      );
      scene.layer = 11;
      scene.oval(x - .026, eyeY + .018, .568, .013, .014, .009, Colors.white);
      scene.oval(
        x + .006 * side,
        headY + .229,
        .471,
        .115,
        .026,
        .040,
        hair,
        roll: side * -.14,
      );
    }

    final lip = Color.lerp(skin, const Color(0xffb65b60), .34)!;
    final lipShadow = Color.lerp(lip, const Color(0xff6b302f), .45)!;
    scene.layer = 8;
    scene.oval(0, headY - .235, .483, .121, .035, .037, lip);
    scene.layer = 9;
    scene.oval(0, headY - .248, .511, .10, .009, .012, lipShadow);
    for (final side in [-1.0, 1.0]) {
      scene.oval(
        side * .105,
        headY - .240,
        .492,
        .019,
        .009,
        .012,
        lipShadow,
        roll: side * .32,
      );
    }

    scene.layer = 7;
    final beard = style[AvatarFeature.beard];
    if (beard > 0) {
      final facialHair = Color.lerp(hair, skin, beard == 1 ? .58 : .19)!;
      scene.oval(0, headY - .39, .41, headWidth * .51, .13, .078, facialHair);
      if (beard == 2) {
        for (final side in [-1.0, 1.0]) {
          scene.oval(
            side * headWidth * .51,
            headY - .29,
            .319,
            .139,
            .18,
            .108,
            facialHair,
            roll: side * -.51,
          );
          scene.oval(
            side * .075,
            headY - .172,
            .508,
            .089,
            .021,
            .024,
            facialHair,
            roll: side * -.20,
          );
        }
      }
    }
    scene.layer = 13;
    if (hairStyle > 0) {
      scene.oval(
        0,
        headY,
        0,
        headWidth * 1.062,
        .730,
        .583,
        hair,
        face: head,
        hairline: (angle) =>
            -.32 + .93 * math.pow(math.max(0, math.cos(angle)), 1.45),
      );
    }
    if (hairStyle == 2) {
      scene.layer = 14;
      scene.oval(
        -.119,
        headY + .549,
        .329,
        headWidth * .70,
        .154,
        .186,
        hair,
        roll: -.32,
      );
      scene.layer = 13;
      scene.oval(.227, headY + .508, .299, .223, .122, .162, hair, roll: .40);
    } else if (hairStyle == 3) {
      for (var i = 0; i < 16; i++) {
        final angle = i * math.pi / 8;
        final height = .48 + math.sin(i * 2.1) * .077;
        final radius = .153 + math.cos(i * 1.6) * .023;
        scene.oval(
          math.sin(angle) * headWidth * .70,
          headY + height,
          math.cos(angle) * .40,
          radius,
          radius,
          radius,
          hair,
        );
      }
      scene.oval(0, headY + .65, -.06, .36, .17, .36, hair);
    }

    scene.layer = 15;
    if (style[AvatarFeature.glasses] != 0) {
      const frame = Color(0xff323343);
      for (final side in [-1.0, 1.0]) {
        scene.ring(side * eyeX, eyeY - .011, .57, .157, .129, frame);
        scene.oval(
          side * (eyeX + .156),
          eyeY + .039,
          .471,
          .032,
          .018,
          .109,
          frame,
          roll: .06,
        );
      }
      scene.oval(0, eyeY + .014, .579, .081, .013, .013, frame);
    }
    scene.paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter previous) =>
      previous.style != style ||
      previous.rotation != rotation ||
      previous.fullBody != fullBody ||
      previous.detail != detail;
}

typedef _Vertex = ({Offset point, double depth, int color});
typedef _Surface = ({_Vertex a, _Vertex b, _Vertex c, double depth, int layer});

/// Projects lit surfaces towards the camera and draws distant surfaces first.
class _AvatarScene {
  _AvatarScene({
    required this.origin,
    required this.scale,
    required this.focusY,
    required double rotation,
    required this.detail,
  }) : sine = math.sin(rotation),
       cosine = math.cos(rotation);

  final Offset origin;
  final double scale, focusY, sine, cosine;
  final bool detail;
  final _faces = <_Surface>[];
  int layer = 0;

  Offset project(double x, double y, double z) => Offset(
    origin.dx + (x * cosine + z * sine) * scale,
    origin.dy - (y - focusY) * scale,
  );

  _Vertex _vertex(
    double x,
    double y,
    double z,
    double nx,
    double ny,
    double nz,
    Color color,
  ) {
    final horizontal = nx * cosine + nz * sine;
    final forward = nz * cosine - nx * sine;
    final normal = math.sqrt(nx * nx + ny * ny + nz * nz);
    final light = (-.38 * horizontal + .66 * ny + .64 * forward) / normal;
    final lit = light > .35
        ? Color.lerp(color, const Color(0xfffff3ec), (light - .35) * .29)!
        : Color.lerp(color, const Color(0xff182742), (.35 - light) * .34)!;
    return (
      point: project(x, y, z),
      depth: z * cosine - x * sine,
      color: lit.toARGB32(),
    );
  }

  void _triangle(_Vertex a, _Vertex b, _Vertex c) {
    final u = b.point - a.point;
    final v = c.point - a.point;
    if (u.dx * v.dy - u.dy * v.dx <= .0001) return;
    _faces.add((
      a: a,
      b: b,
      c: c,
      depth: (a.depth + b.depth + c.depth) / 3,
      layer: layer,
    ));
  }

  void oval(
    double x,
    double y,
    double z,
    double rx,
    double ry,
    double rz,
    Color color, {
    double roll = 0,
    (int, double, double, double)? face,
    double Function(double angle)? hairline,
  }) {
    final fine = detail && (rx > .25 || ry > .25);
    final rings = fine ? 27 : 12;
    final sides = fine ? 39 : 18;
    final rc = math.cos(roll), rs = math.sin(roll);
    final vertices = <_Vertex>[];
    for (var row = 0; row <= rings; row++) {
      for (var col = 0; col <= sides; col++) {
        final angle = (col / sides * 2 - 1) * math.pi;
        final start = hairline?.call(angle) ?? -math.pi / 2;
        final latitude = start + (math.pi / 2 - start) * row / rings;
        final ny = math.sin(latitude);
        final nx = math.sin(angle) * math.cos(latitude);
        final nz = math.cos(angle) * math.cos(latitude);
        var faceWidth = rx;
        if (face != null) {
          final lower = math.max(0.0, -ny);
          final jawShape = [0.0, .13, .31, -.22][face.$1];
          final cheekCurve = math.exp(-math.pow((ny + .28) * 4, 2));
          faceWidth *= 1 + (jawShape + face.$4) * lower + face.$3 * cheekCurve;
        }
        final px = nx * faceWidth;
        final py = ny * ry;
        vertices.add(
          _vertex(
            x + px * rc - py * rs,
            y + px * rs + py * rc,
            z + nz * rz,
            nx / faceWidth * rc - ny / ry * rs,
            nx / faceWidth * rs + ny / ry * rc,
            nz / rz,
            color,
          ),
        );
      }
    }
    for (var row = 0; row < rings; row++) {
      for (var col = 0; col < sides; col++) {
        final i = row * (sides + 1) + col;
        final j = i + sides + 1;
        _triangle(vertices[i], vertices[j], vertices[j + 1]);
        _triangle(vertices[i], vertices[j + 1], vertices[i + 1]);
      }
    }
  }

  void ring(
    double x,
    double y,
    double z,
    double width,
    double height,
    Color color,
  ) {
    const segments = 20;
    const thickness = .014;
    final outside = <_Vertex>[];
    final inside = <_Vertex>[];
    for (var i = 0; i <= segments; i++) {
      final angle = 2 * math.pi * i / segments;
      final dx = math.cos(angle), dy = math.sin(angle);
      final depth = z - dx.abs() * .027;
      outside.add(
        _vertex(x + dx * width, y + dy * height, depth, dx, dy, 1, color),
      );
      inside.add(
        _vertex(
          x + dx * (width - thickness),
          y + dy * (height - thickness),
          depth,
          -dx,
          -dy,
          1,
          color,
        ),
      );
    }
    for (var i = 0; i < segments; i++) {
      _triangle(outside[i], inside[i + 1], outside[i + 1]);
      _triangle(outside[i], inside[i], inside[i + 1]);
    }
  }

  void paint(Canvas canvas) {
    _faces.sort((a, b) {
      final order = a.layer.compareTo(b.layer);
      return order == 0 ? a.depth.compareTo(b.depth) : order;
    });
    final xy = Float32List(_faces.length * 6);
    final colors = Int32List(_faces.length * 3);
    var index = 0;
    void write(_Vertex vertex) {
      xy[index * 2] = vertex.point.dx;
      xy[index * 2 + 1] = vertex.point.dy;
      colors[index++] = vertex.color;
    }

    for (final face in _faces) {
      write(face.a);
      write(face.b);
      write(face.c);
    }
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      xy,
      colors: colors,
    );
    canvas.drawVertices(
      vertices,
      BlendMode.modulate,
      Paint()..color = Colors.white,
    );
  }
}
