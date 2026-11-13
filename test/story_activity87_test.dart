import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/story_stickers.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Story activity follows the carousel in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      final peer = store.users.firstWhere((u) => u.str('id') != store.myId);
      final peerId = peer.str('id');
      store.state['posts'] = [
        for (final id in ['one', 'two'])
          {
            'id': id,
            'author': store.myId,
            'kind': 'story',
            'text': id,
            'expires': now + 100,
            'viewers': id == 'two' ? [peerId] : <String>[],
            'stickerActivity': [
              if (id == 'two')
                {'user': peerId, 'kind': 'reaction', 'value': '🔥'},
            ],
          },
      ];
      store.state['threads'] = [
        {
          'id': 'thread',
          'members': [store.myId, peerId],
          'messages': [
            {
              'id': 'reply',
              'kind': 'story',
              'author': peerId,
              'text': 'Risposta di prova',
              'story': {'id': 'two'},
              'created': now,
            },
          ],
        },
      ];
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(brightness),
            home: const StoryActivityPanel(storyId: 'one'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Risposta di prova'), findsNothing);
      final panel = find.byType(StoryActivityPanel);
      final scaffold = find.descendant(
        of: panel,
        matching: find.byType(Scaffold),
      );
      expect(
        tester.widget<Scaffold>(scaffold).backgroundColor,
        brightness == Brightness.light ? Colors.white : Colors.black,
      );
      await tester.dragFrom(const Offset(240, 390), const Offset(-135, 0));
      await tester.pumpAndSettle();
      expect(find.text('Interazioni'), findsNothing);
      final viewer = find.widgetWithText(ListTile, 'Reazione · 🔥');
      expect(viewer, findsOneWidget);
      expect(
        find.descendant(of: viewer, matching: find.text(peer.str('username'))),
        findsOneWidget,
      );
      expect(find.text('Risposta di prova'), findsOneWidget);
      expect(find.text(peer.str('username')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
