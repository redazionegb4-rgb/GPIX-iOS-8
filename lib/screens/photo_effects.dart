import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as im;
import '../core/data.dart';

const photoFilters = <String, List<double>>{
  // saturation, contrast, warmth, fade, brightness
  'Originale': [1, 1, 0, 0, 1], 'Fade': [.85, .88, 0, .12, 1],
  'Fade warm': [.86, .9, .3, .1, 1.02], 'Fade cool': [.85, .9, -.3, .1, 1.02],
  'Simple warm': [1.05, 1.03, .35, 0, 1.03],
  'Simple cool': [1.04, 1.04, -.35, 0, 1.02],
  'Boost': [1.25, 1.12, 0, 0, 1.02], 'Boost warm': [1.2, 1.1, .25, 0, 1.03],
  'Caldo': [1.08, 1.05, .4, 0, 1], 'Vivido': [1.35, 1.12, 0, 0, 1],
  'Gritty': [.55, 1.35, 0, 0, .98], 'Halo': [.85, .88, .18, .15, 1.08],
  'Color leak': [1.15, .95, .55, .05, 1.05],
  'Soft light': [.9, .88, 0, .06, 1.1],
  'Jaipur': [.8, 1.07, .45, .04, 1.05], 'Cairo': [.72, 1.14, .3, .02, 1.04],
  'Tokyo': [0, 1.25, 0, 0, 1.04], 'Rio': [1.38, 1.08, .15, 0, 1.04],
  'Mono': [0, 1, 0, 0, 1], 'Noir': [0, 1.4, 0, 0, .95],
};
const photoAdjustments = [
  'Regola',
  'Lux',
  'Luminosità',
  'Contrasto',
  'Saturazione',
  'Colore',
  'Sfumatura',
  'Alte luci',
  'Ombre',
  'Vignettatura',
  'Tilt-Shift',
  'Nitidezza',
];

Future<Uint8List> processPhoto(J args) async {
  var image = im.bakeOrientation(
    im.decodeImage(await File(args.str('path')).readAsBytes())!,
  );
  final limit = args.number('limit', 1800).toInt();
  if (math.max(image.width, image.height) > limit)
    image = im.copyResize(
      image,
      width: image.width >= image.height ? limit : null,
      height: image.height > image.width ? limit : null,
    );
  final a = args.obj('adjustments');
  final angle = a.number('Regola') * .15;
  if (angle.abs() > .01) {
    image = im.copyRotate(
      image,
      angle: angle,
      interpolation: im.Interpolation.cubic,
    );
    // Crop the rotated frame to keep transparent corners outside the photo.
    final zoom =
        1 /
        (math.cos(angle.abs() * math.pi / 180) +
            math.sin(angle.abs() * math.pi / 180) *
                math.max(
                  image.width / image.height,
                  image.height / image.width,
                ));
    final w = (image.width * zoom).round(), h = (image.height * zoom).round();
    image = im.copyCrop(
      image,
      x: (image.width - w) ~/ 2,
      y: (image.height - h) ~/ 2,
      width: w,
      height: h,
    );
  }
  final ratio = args.number('aspect', 1);
  final w = image.width / image.height > ratio
      ? (image.height * ratio).round()
      : image.width;
  final h = image.width / image.height > ratio
      ? image.height
      : (image.width / ratio).round();
  image = im.copyCrop(
    image,
    x: (image.width - w) ~/ 2,
    y: (image.height - h) ~/ 2,
    width: math.max(1, w),
    height: math.max(1, h),
  );
  final preset = photoFilters[args.str('filter')] ?? photoFilters['Originale']!;
  final strength = args.number('intensity', 1);
  final saturation =
      (1 + (preset[0] - 1) * strength) * (1 + a.number('Saturazione') / 100);
  final contrast =
      (1 + (preset[1] - 1) * strength) *
      (1 + a.number('Contrasto') / 160 + a.number('Lux') / 400);
  final brightness =
      args.number('brightness', 1) *
      (1 + (preset[4] - 1) * strength) *
      (1 + a.number('Luminosità') / 200);
  image = im.adjustColor(
    image,
    saturation: saturation.clamp(0, 2.5),
    contrast: contrast.clamp(0, 2),
    brightness: brightness,
  );
  final warmth = preset[2] * strength + a.number('Colore') / 100;
  final fade = preset[3] * strength + a.number('Sfumatura') / 500;
  final highlights = a.number('Alte luci') / 100,
      shadows = a.number('Ombre') / 100,
      lux = a.number('Lux') / 100;
  for (final pixel in image) {
    final luminance =
        (pixel.r * .2126 + pixel.g * .7152 + pixel.b * .0722) / 255;
    final tone =
        highlights * luminance * luminance * 65 +
        shadows * (1 - luminance) * (1 - luminance) * 65 +
        lux * (.5 - luminance) * 25;
    pixel.r = (pixel.r * (1 + warmth * .12) * (1 - fade) + 255 * fade + tone)
        .clamp(0, 255);
    pixel.g = (pixel.g * (1 - fade) + 255 * fade + tone).clamp(0, 255);
    pixel.b = (pixel.b * (1 - warmth * .12) * (1 - fade) + 255 * fade + tone)
        .clamp(0, 255);
  }
  if (a.number('Nitidezza') > 0) {
    final amount = a.number('Nitidezza') / 100;
    image = im.convolution(
      image,
      filter: [0, -amount, 0, -amount, 1 + 4 * amount, -amount, 0, -amount, 0],
    );
  }
  if (a.number('Tilt-Shift') > 0) {
    final blurred = im.gaussianBlur(
      im.Image.from(image),
      radius: math.max(1, (image.width / 150).round()),
    );
    final power = a.number('Tilt-Shift') / 100;
    for (final pixel in image) {
      final blend =
          (((pixel.y / image.height - .5).abs() - .12) * 3).clamp(0, 1) * power;
      final other = blurred.getPixel(pixel.x, pixel.y);
      pixel.r = pixel.r * (1 - blend) + other.r * blend;
      pixel.g = pixel.g * (1 - blend) + other.g * blend;
      pixel.b = pixel.b * (1 - blend) + other.b * blend;
    }
  }
  if (a.number('Vignettatura') > 0)
    image = im.vignette(image, amount: a.number('Vignettatura') / 100);
  return Uint8List.fromList(
    im.encodeJpg(image, quality: args.flag('preview') ? 85 : 93),
  );
}
