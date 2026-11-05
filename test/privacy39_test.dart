import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/instants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(
          File(
            'test/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  testWidgets(
    'Android native privacy success with null still opens the photo',
    (t) async {
      final s = GpixStore()..startTestDemo();
      final rows = (await s.instantList()).rows('received');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('GPIX/privacy'),
            (c) async => null,
          );
      await t.pumpWidget(
        GpixScope(
          store: s,
          child: MaterialApp(home: InstantViewer(items: rows)),
        ),
      );
      await t.pumpAndSettle();
      expect(rows.first.flag('opened'), true);
      expect(find.text('Contenuto protetto'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      s.dispose();
    },
  );
  testWidgets('Message settings save preferences and hide inbox text', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(
          home: MessageToggleSetting(setting: 'messagePreviews'),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    expect(s.preferences['messagePreviews'], false);
    final thread = s.threads.first;
    if (thread.rows('messages').isNotEmpty)
      expect(
        inboxPreview(s, thread),
        isNot(contains(thread.rows('messages').last.str('text'))),
      );
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: MessageAudienceSetting(story: true)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Nessuno'));
    await t.pumpAndSettle();
    expect(s.preferences.str('storyReplies'), 'none');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  testWidgets(
    'Protected image requires explicit reveal and resets for a different message',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProtectedChatImage(
              key: ValueKey('one'),
              protected: true,
              reference: '',
              child: Text('original'),
            ),
          ),
        ),
      );
      expect(find.text('original'), findsNothing);
      await t.tap(find.text('Tocca per mostrare'));
      await t.pump();
      expect(find.text('original'), findsOneWidget);
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProtectedChatImage(
              key: ValueKey('two'),
              protected: true,
              reference: '',
              child: Text('other'),
            ),
          ),
        ),
      );
      expect(find.text('other'), findsNothing);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'Deck vertical gesture opens exactly the next instant at $width',
      (t) async {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('GPIX/privacy'),
              (c) async => true,
            );
        final s = GpixStore()..startTestDemo();
        s.seedInstants();
        final first = s.state.rows('demoInstants').first;
        final second = {...first, 'id': 'second39', 'caption': 'Seconda foto'};
        s.state['demoInstants'] = [first, second];
        final rows = (await s.instantList()).rows('received');
        await t.pumpWidget(
          GpixScope(
            store: s,
            child: MaterialApp(home: InstantViewer(items: rows)),
          ),
        );
        await t.pumpAndSettle();
        expect(first.flag('opened'), true);
        expect(second.flag('opened'), false);
        expect(t.takeException(), isNull);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await t.pump();
        if (width == 390)
          await t.runAsync(() async {
            final boundary = t.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('QA/instants39').create(recursive: true);
            await File(
              'QA/instants39/viewer.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        await t.drag(
          find.byKey(const ValueKey('instant-deck')),
          const Offset(0, -180),
        );
        await t.pumpAndSettle();
        expect(second.flag('opened'), true);
        expect(find.text('Seconda foto'), findsOneWidget);
        expect(t.takeException(), isNull);
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        t.view.resetViewInsets();
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }
}
