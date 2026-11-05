import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GIcon extends StatelessWidget {
  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final List<Shadow>? shadows;
  const GIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.shadows,
  });
  @override
  Widget build(BuildContext c) {
    final name = names[icon];
    final resolvedColor = color == const Color(0xff15151b)
        ? Theme.of(c).colorScheme.onSurface
        : color;
    if (name == null || shadows != null)
      return Icon(
        icon,
        size: size,
        color: resolvedColor,
        semanticLabel: semanticLabel,
      );
    final theme = IconTheme.of(c);
    return Semantics(
      label: semanticLabel,
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: size ?? theme.size ?? 24,
          child: CustomPaint(
            painter: _LineIcon(
              name,
              resolvedColor ?? theme.color ?? Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  static final names = {
    CupertinoIcons.house: 'home',
    CupertinoIcons.house_fill: 'homeFill',
    CupertinoIcons.heart: 'heart',
    CupertinoIcons.heart_fill: 'heartFill',
    CupertinoIcons.paperplane: 'send',
    CupertinoIcons.paperplane_fill: 'sendFill',
    CupertinoIcons.chat_bubble: 'chat',
    CupertinoIcons.chat_bubble_fill: 'chatFill',
    CupertinoIcons.chat_bubble_2: 'messages',
    CupertinoIcons.chat_bubble_2_fill: 'messagesFill',
    CupertinoIcons.square_grid_2x2: 'grid',
    CupertinoIcons.search: 'search',
    CupertinoIcons.bookmark: 'save',
    CupertinoIcons.bookmark_fill: 'saveFill',
    CupertinoIcons.plus_app: 'plus',
    CupertinoIcons.play_rectangle: 'reel',
    CupertinoIcons.play_rectangle_fill: 'reelFill',
    CupertinoIcons.repeat: 'repeat',
    CupertinoIcons.camera: 'camera',
    CupertinoIcons.camera_fill: 'camera',
    CupertinoIcons.ellipsis: 'more',
    CupertinoIcons.placemark: 'pin',
    CupertinoIcons.person_crop_rectangle: 'tagPerson',
  };
}

class _LineIcon extends CustomPainter {
  final String kind;
  final Color color;
  _LineIcon(this.kind, this.color);
  @override
  void paint(Canvas c, Size size) {
    final side = size.shortestSide;
    c.translate((size.width - side) / 2, (size.height - side) / 2);
    c.scale(side / 24, side / 24);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = kind.endsWith('Fill')
          ? PaintingStyle.fill
          : PaintingStyle.stroke;
    final path = Path();
    switch (kind.replaceAll('Fill', '')) {
      case 'home':
        path.moveTo(3, 10);
        path.lineTo(12, 2.8);
        path.lineTo(21, 10);
        path.lineTo(21, 20);
        path.quadraticBezierTo(21, 21, 20, 21);
        path.lineTo(15.4, 21);
        path.lineTo(15.4, 14);
        path.lineTo(8.6, 14);
        path.lineTo(8.6, 21);
        path.lineTo(4, 21);
        path.quadraticBezierTo(3, 21, 3, 20);
        path.close();
        break;
      case 'heart':
        path.moveTo(12, 21);
        path.cubicTo(8, 18, 2.3, 13.5, 2.3, 8);
        path.cubicTo(2.3, 2.5, 9, 1.8, 12, 6);
        path.cubicTo(15, 1.8, 21.7, 2.5, 21.7, 8);
        path.cubicTo(21.7, 13.5, 16, 18, 12, 21);
        path.close();
        break;
      case 'send':
        paint.style = kind.endsWith('Fill')
            ? PaintingStyle.fill
            : PaintingStyle.stroke;
        path.moveTo(3, 9.2);
        path.quadraticBezierTo(2.1, 9.5, 3.2, 10.1);
        path.lineTo(10.2, 13.5);
        path.lineTo(13.9, 20.8);
        path.quadraticBezierTo(14.4, 21.8, 15, 20.6);
        path.lineTo(21.5, 3.3);
        path.quadraticBezierTo(22, 2, 20.7, 2.5);
        path.lineTo(3, 9.2);
        path.close();
        path.moveTo(10.2, 13.5);
        path.lineTo(20.9, 3.2);
        break;
      case 'chat':
      case 'messages':
        final bubble = Path()
          ..moveTo(12, 2.8)
          ..cubicTo(6.6, 2.8, 2.4, 6.6, 2.4, 11.6)
          ..cubicTo(2.4, 16.6, 6.6, 20.4, 12, 20.4)
          ..quadraticBezierTo(14.8, 20.4, 17, 19)
          ..lineTo(21.3, 21.1)
          ..lineTo(20.1, 16.2)
          ..cubicTo(24, 10.1, 19.4, 2.8, 12, 2.8)
          ..close();
        c.drawPath(bubble, paint);
        if (kind.startsWith('messages')) {
          final bolt = Path()
            ..moveTo(6.8, 14.7)
            ..lineTo(10.7, 9)
            ..lineTo(13.7, 11.5)
            ..lineTo(17.5, 8.5)
            ..lineTo(13.5, 14.4)
            ..lineTo(10.5, 12)
            ..close();
          c.drawPath(
            bolt,
            Paint()
              ..color = kind.endsWith('Fill')
                  ? (color.computeLuminance() > .5
                        ? Colors.black
                        : Colors.white)
                  : color,
          );
        }
        return;
      case 'grid':
        paint.strokeWidth = 1.55;
        paint.style = PaintingStyle.stroke;
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 3; col++) {
            c.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(3 + col * 6.5, 3 + row * 6.5, 4.7, 4.7),
                const Radius.circular(.7),
              ),
              paint,
            );
          }
        return;
      case 'search':
        c.drawCircle(const Offset(10.5, 10.5), 7.7, paint);
        path.moveTo(16, 16);
        path.lineTo(22, 22);
        break;
      case 'save':
        path.moveTo(5, 3);
        path.lineTo(19, 3);
        path.lineTo(19, 22);
        path.lineTo(12, 16.5);
        path.lineTo(5, 22);
        path.close();
        break;
      case 'plus':
        path.moveTo(12, 3);
        path.lineTo(12, 21);
        path.moveTo(3, 12);
        path.lineTo(21, 12);
        break;
      case 'reel':
        paint.style = PaintingStyle.stroke;
        final rect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(2.8, 2.8, 18.4, 18.4),
          const Radius.circular(4),
        );
        c.drawRRect(rect, paint);
        if (kind.endsWith('Fill')) {
          c.drawRRect(rect, Paint()..color = color);
          paint.color = color.computeLuminance() > .5
              ? Colors.black
              : Colors.white;
        }
        final bars = Path()
          ..moveTo(3, 8.5)
          ..lineTo(21, 8.5)
          ..moveTo(7.4, 3)
          ..lineTo(10.7, 8.5)
          ..moveTo(14.3, 3)
          ..lineTo(17.6, 8.5);
        c.drawPath(bars, paint);
        final play = Path()
          ..moveTo(10, 11.1)
          ..lineTo(16, 14.7)
          ..lineTo(10, 18.1)
          ..close();
        c.drawPath(play, Paint()..color = paint.color);
        return;
      case 'repeat':
        paint.style = PaintingStyle.stroke;
        path.moveTo(4.4, 10);
        path.lineTo(4.4, 7.5);
        path.quadraticBezierTo(4.4, 4.8, 7.2, 4.8);
        path.lineTo(19.6, 4.8);
        path.moveTo(16.2, 1.8);
        path.lineTo(19.6, 4.8);
        path.lineTo(16.2, 8.1);
        path.moveTo(19.6, 14);
        path.lineTo(19.6, 16.5);
        path.quadraticBezierTo(19.6, 19.2, 16.8, 19.2);
        path.lineTo(4.4, 19.2);
        path.moveTo(7.8, 15.9);
        path.lineTo(4.4, 19.2);
        path.lineTo(7.8, 22.2);
        break;
      case 'pin':
        paint.style = PaintingStyle.stroke;
        path.moveTo(12, 22);
        path.cubicTo(7, 16, 3.8, 12.5, 3.8, 8.8);
        path.cubicTo(3.8, -.3, 20.2, -.3, 20.2, 8.8);
        path.cubicTo(20.2, 12.5, 17, 16, 12, 22);
        path.close();
        c.drawCircle(const Offset(12, 8.7), 3, paint);
        break;
      case 'tagPerson':
        paint.style = PaintingStyle.stroke;
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2.5, 2.5, 19, 19),
            const Radius.circular(4),
          ),
          paint,
        );
        c.drawCircle(const Offset(12, 8), 2.9, paint);
        path.moveTo(6.2, 18.2);
        path.cubicTo(7.2, 12.6, 16.8, 12.6, 17.8, 18.2);
        break;
      case 'camera':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 5, 20, 16),
            const Radius.circular(4),
          ),
          paint,
        );
        c.drawCircle(const Offset(12, 13), 4, paint);
        path.moveTo(8, 5);
        path.lineTo(9, 2.5);
        path.lineTo(15, 2.5);
        path.lineTo(16, 5);
        break;
      case 'more':
        for (final x in [4.0, 12.0, 20.0])
          c.drawCircle(Offset(x, 12), 1.5, Paint()..color = color);
        return;
    }
    c.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineIcon old) => old.kind != kind || old.color != color;
}
