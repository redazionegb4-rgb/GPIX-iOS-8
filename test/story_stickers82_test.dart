import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/stories.dart';
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
        of: find.byType(Form),
        matching: find.byType(TextField),
      );
      await t.enterText(fields.at(0), 'Mare o montagna?');
      await t.enterText(fields.at(1), 'Mare');
      await t.enterText(fields.at(2), 'Montagna');
      await t.pumpAndSettle();
      final add = find.widgetWithText(TextButton, 'Fine');
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
      await t.tap(find.text('Montagna'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('100%'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(store.post(storyId).obj('style').obj('poll').number('myVote'), 1);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Emoji slider sends the selected level on release', (t) async {
    int? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 230,
              child: StoryVoteSticker(
                poll: {
                  'question': 'Quanto?',
                  'options': ['1', '2', '3', '4'],
                },
                type: StoryStickerTool.slider,
                style: 1,
                emoji: '🔥',
                showResults: false,
                onVote: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    final rect = t.getRect(find.byType(Slider));
    await t.tapAt(Offset(rect.right - 18, rect.center.dy));
    await t.pump();
    expect(selected, 3);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Stars submit their rating inline', (t) async {
    int? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 230,
              child: StoryVoteSticker(
                poll: {
                  'question': 'Ti piace?',
                  'options': ['★', '★★', '★★★', '★★★★'],
                },
                type: StoryStickerTool.rating,
                style: 0,
                emoji: '😍',
                showResults: false,
                onVote: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byTooltip('3 stelle'));
    expect(selected, 2);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Sticker can be dragged to the lower right edge', (t) async {
    final sticker = <String, dynamic>{
      'emoji': '🔥',
      'x': .2,
      'y': .2,
      'size': 40,
    };
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 560,
              child: StatefulBuilder(
                builder: (_, update) => StoryCanvas(
                  story: {
                    'style': {
                      'stickers': [sticker],
                    },
                  },
                  editing: true,
                  onStickerMove: (_, delta) => update(() {
                    sticker['x'] = sticker.number('x') + delta.dx;
                    sticker['y'] = sticker.number('y') + delta.dy;
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.drag(find.text('🔥'), const Offset(400, 600));
    await t.pump();
    final canvas = t.getRect(find.byType(StoryCanvas));
    final face = t.getRect(find.text('🔥'));
    expect(face.right, closeTo(canvas.right, 1));
    expect(face.bottom, closeTo(canvas.bottom, 1));
    expect(t.takeException(), isNull);
  });
}
