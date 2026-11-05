import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'data.dart';

class Drafts {
  static Future<Directory> root(String account) async {
    final path = (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(
      '$path/gpix-drafts/${base64Url.encode(utf8.encode(account)).replaceAll('=', '')}',
    );
    return dir.create(recursive: true);
  }

  static Future<List<J>> list(String account) async {
    final dir = await root(account);
    final result = <J>[];
    await for (final item in dir.list()) {
      if (item is! Directory) continue;
      try {
        final value = object(
          jsonDecode(await File('${item.path}/draft.json').readAsString()),
        );
        value['files'] = value
            .ids('files')
            .where((p) => File(p).existsSync())
            .toList();
        result.add(value);
      } catch (_) {}
    }
    result.sort((a, b) => b.number('updated').compareTo(a.number('updated')));
    return result;
  }

  static Future<J> save(String account, J value) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value.str('id')))
      throw Exception('Bozza non valida');
    final dir = Directory('${(await root(account)).path}/${value.str('id')}');
    await dir.create(recursive: true);
    final files = <String>[];
    for (var i = 0; i < value.ids('files').length; i++) {
      final src = File(value.ids('files')[i]);
      if (!await src.exists()) continue;
      if (src.path.startsWith('${dir.path}/')) {
        files.add(src.path);
        continue;
      }
      final ext = src.path.split('.').last.toLowerCase();
      final target =
          '${dir.path}/media-$i-${src.path.hashCode}.${RegExp(r'^[a-z0-9]{1,6}$').hasMatch(ext) ? ext : 'bin'}';
      if (!await File(target).exists()) await src.copy(target);
      files.add(target);
    }
    var assetIndex = 0;
    Future<dynamic> preserve(dynamic node) async {
      if (node is Map)
        return {for (final e in node.entries) e.key: await preserve(e.value)};
      if (node is List) return [for (final item in node) await preserve(item)];
      if (node is String &&
          node.startsWith('/') &&
          await File(node).exists() &&
          !node.startsWith('${dir.path}/')) {
        final ext = node.split('.').last;
        final target =
            '${dir.path}/asset-${assetIndex++}-${node.hashCode}.${RegExp(r"^[a-zA-Z0-9]{1,6}$").hasMatch(ext) ? ext : 'bin'}';
        if (!await File(target).exists()) await File(node).copy(target);
        return target;
      }
      return node;
    }

    final metadata = await preserve(value) as Map;
    final next = <String, dynamic>{
      ...Map<String, dynamic>.from(metadata),
      'files': files,
      'updated': DateTime.now().millisecondsSinceEpoch,
    };
    final temp = File('${dir.path}/draft.tmp');
    await temp.writeAsString(jsonEncode(next), flush: true);
    await temp.rename('${dir.path}/draft.json');
    return next;
  }

  static Future<void> delete(String account, String id) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id))
      throw Exception('Bozza non valida');
    final dir = Directory('${(await root(account)).path}/$id');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
