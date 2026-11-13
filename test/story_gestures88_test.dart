import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/screens/story_stickers.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  testWidgets(
    'Slow swipes change story and activity returns to the chosen story',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      store.state['posts'] = [
        for (final id in ['one', 'two'])
          {
            'id': id,
            'author': store.myId,
            'kind': 'story',
            'text': id,
            'expires': now + 100,
          },
      ];
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => open(context, StoryViewer(user: store.myId)),
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apri'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      final story = find.byType(StoryCanvas);
      String shown() => tester.widget<StoryCanvas>(story).story.str('id');
      expect(shown(), 'one');
      await tester.pump(const Duration(milliseconds: 250));
      final swipe = await tester.startGesture(tester.getCenter(story));
      await swipe.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 450));
      await swipe.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 450));
      await swipe.up();
      await tester.pump();
      expect(shown(), 'two');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.drag(story, const Offset(130, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown(), 'one');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.drag(story, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.byType(StoryActivityPanel), findsOneWidget);
      final thumbnails = find.byType(PageView);
      tester.widget<PageView>(thumbnails).controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(195, 465), const Offset(0, 105));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(StoryActivityPanel), findsNothing);
      expect(shown(), 'two');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
