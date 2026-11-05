import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:gpix/screens/features13.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:gpix/core/drafts.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/push_service.dart';

class Paths extends PathProviderPlatform {
  final String root;
  Paths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Draft survives deletion of temp sources including overlay and audio, scoped per account',
    () async {
      final temp = await Directory.systemTemp.createTemp('gpix-draft33');
      PathProviderPlatform.instance = Paths(temp.path);
      final image = File('${temp.path}/image.jpg'),
          audio = File('${temp.path}/clip.m4a'),
          overlay = File('${temp.path}/text.png');
      await image.writeAsBytes([1, 2, 3]);
      await audio.writeAsBytes([4, 5]);
      await overlay.writeAsBytes([6, 7]);
      await Drafts.save('accountA', {
        'id': 'draft33',
        'kind': 'post',
        'files': [image.path],
        'text': 'Caption',
        'textX': .97,
        'textY': .02,
        'overlay': overlay.path,
        'style': {'audio': audio.path},
        'adjustments': {'contrast': .4},
      });
      await image.delete();
      await audio.delete();
      await overlay.delete();
      final drafts = await Drafts.list('accountA');
      expect(drafts, hasLength(1));
      final d = drafts.single;
      expect(await File((d['files'] as List).single).readAsBytes(), [1, 2, 3]);
      expect(await File(d['overlay']).readAsBytes(), [6, 7]);
      expect(await File(d['style']['audio']).readAsBytes(), [4, 5]);
      expect(d['textX'], .97);
      expect(d['adjustments']['contrast'], .4);
      expect(await Drafts.list('accountB'), isEmpty);
      await expectLater(
        Drafts.save('accountA', {'id': '../escape'}),
        throwsException,
      );
      await Drafts.delete('accountA', 'draft33');
      expect(await Drafts.list('accountA'), isEmpty);
      await temp.delete(recursive: true);
    },
  );
  test(
    'Upload streams all bytes, preserves error for retry, and reports progress',
    () async {
      final file = await File(
        '${Directory.systemTemp.path}/gpix-upload33',
      ).writeAsBytes(List.generate(90000, (i) => i % 256));
      var calls = 0;
      final s = GpixStore(
        client: MockClient((request) async {
          calls++;
          expect(request.headers['Authorization'], 'Bearer session33');
          final data = jsonDecode(request.body);
          expect(base64Decode(data['data']), await file.readAsBytes());
          return calls == 1
              ? http.Response('{"detail":"Temporary failure"}', 503)
              : http.Response('{"id":"m33","url":"/media/m33"}', 200);
        }),
      )..token = 'session33';
      final progress = <double>[];
      s.uploadProgress.addListener(() => progress.add(s.uploadProgress.value));
      await expectLater(s.upload(file.path, 'image/jpeg'), throwsException);
      expect(await file.exists(), isTrue);
      expect(await s.upload(file.path, 'image/jpeg'), 'm33');
      expect(progress.any((v) => v > 0 && v < 1), isTrue);
      expect(progress.last, 1);
      expect(calls, 2);
      await file.delete();
      s.dispose();
    },
  );
  test('APK without native push reports limitation without native or network calls', () async {
    if (PushService.nativePushAvailable) return;
    final s = GpixStore(client: MockClient((_) async => throw StateError('Unexpected network call')))..token = 'test-session';
    final result = await PushService.instance.enable(s);
    expect(result, contains('non sono incluse'));s.dispose();
  });
  test('Transport error fails promptly without deleting local media', () async {
    final file = await File(
      '${Directory.systemTemp.path}/gpix-error33',
    ).writeAsBytes([1, 2, 3]);
    final s = GpixStore(
      client: MockClient((_) async => throw http.ClientException('Offline')),
    )..token = 'session33';
    await expectLater(
      s.upload(file.path, 'image/jpeg').timeout(const Duration(seconds: 2)),
      throwsA(isA<http.ClientException>()),
    );
    expect(await file.exists(), isTrue);
    await file.delete();
    s.dispose();
  });
  for (final width in [320.0, 390.0]) {
    for (final dark in [false, true]) {
      testWidgets('New feature layouts $width dark=$dark', (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        final pages = <Widget>[
          const AccountSecurity(),
          const ProfileLinks(),
          const GridOrder(),
          const PrivacyTools(),
          const PushSettings(),
          SharedMedia(thread: s.threads.first['id']),
        ];
        for (final page in pages) {
          await t.pumpWidget(
            GpixScope(
              store: s,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: page,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            t.takeException(),
            isNull,
            reason: page.runtimeType.toString(),
          );
          await t.pumpWidget(const SizedBox());
        }
        s.dispose();
      });
    }
  }
}
