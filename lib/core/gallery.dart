import 'package:flutter/services.dart';

class GalleryPhoto {
  final String id;
  final Uint8List thumbnail;
  const GalleryPhoto(this.id, this.thumbnail);
}

class DeviceGallery {
  static const channel = MethodChannel('GPIX/gallery');
  static Future<List<GalleryPhoto>> recent() async {
    final values = await channel.invokeMethod<List<dynamic>>('recent');
    return (values ?? [])
        .map(
          (v) => GalleryPhoto(v['id'] as String, v['thumbnail'] as Uint8List),
        )
        .toList();
  }

  static Future<String> copy(String id) async =>
      (await channel.invokeMethod<String>('copy', {'id': id}))!;
}
