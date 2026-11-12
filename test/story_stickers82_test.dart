import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/stories.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/story_stickers.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  testWidgets(
    'Sticker search, poll publication and voting through story viewer',
    (t) async {
      t.view.physicalSize = const Size(320, 760);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      await t.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.dark),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => open(
                    context,
                    const Composer(kind: 'story', editStory: true),
                  ),
                  child: const Text('Editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Editor'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Sticker'));
      await t.pumpAndSettle();
      final picker = find.byType(StoryStickerPicker);
      expect(picker, findsOneWidget);
      await t.enterText(
        find.descendant(of: picker, matching: find.byType(TextField)),
        'sondaggio',
      );
      await t.pumpAndSettle();
      expect(find.text('Photostrip'), findsNothing);
      await t.tap(find.text('Sondaggio'));
      await t.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(PollEditor),
        matching: find.byType(TextField),
      );
      await t.enterText(fields.at(0), 'Mare o montagna?');
      await t.enterText(fields.at(1), 'Mare');
      await t.enterText(fields.at(2), 'Montagna');
      await t.pumpAndSettle();
      final add = find.widgetWithText(FilledButton, 'Aggiungi');
      await t.ensureVisible(add);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.text('Mare o montagna?'), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.tap(find.text('La tua storia'));
      await t.pumpAndSettle();
      final story = store.stories(store.myId).first;
      expect(story.obj('style').obj('poll').ids('options'), [
        'Mare',
        'Montagna',
      ]);
      expect(story.obj('style').flag('stickerOnly'), isTrue);
      final storyId = story.str('id');
      story['author'] = 'u0';
      await t.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(Brightness.dark),
            home: StoryViewer(user: 'u0', ids: [storyId]),
          ),
        ),
      );
      await t.pump();
      await t.tap(find.text('Mare o montagna?'));
      await t.pumpAndSettle();
      await t.tap(find.text('Montagna'));
      await t.pump(const Duration(milliseconds: 400));
      expect(store.post(storyId).obj('style').obj('poll').number('myVote'), 1);
      await t.pumpWidget(const SizedBox());
    },
  );
}
