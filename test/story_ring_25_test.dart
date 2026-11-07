import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  for (final page in ['inbox', 'profile', 'chat']) {
    testWidgets(
      '$page hides the story ring after viewing and restores it for a new story',
      (tester) async {
        final store = GpixStore()..startTestDemo();
        final thread = store.threads.first;
        final uid = store.other(thread);
        final original = store.stories(uid).first;
        final widget = page == 'inbox'
            ? const Inbox()
            : page == 'profile'
            ? Profile(user: uid)
            : Chat(id: thread.str('id'));
        await tester.pumpWidget(
          GpixScope(
            store: store,
            child: MaterialApp(home: widget),
          ),
        );
        await tester.pumpAndSettle();
        Iterable<Avatar> avatars() => tester
            .widgetList<Avatar>(find.byType(Avatar))
            .where(
              (a) =>
                  a.user == uid &&
                  a.size ==
                      (page == 'chat'
                          ? 38
                          : page == 'profile'
                          ? 80
                          : 56),
            );
        expect(avatars(), isNotEmpty);
        expect(avatars().first.ring, isTrue);
        for (final story in store.stories(uid)) {
          await store.act('see', {'id': story.str('id')});
        }
        await tester.pumpAndSettle();
        expect(avatars().first.ring, isFalse);
        store.state['posts'] = [
          ...store.allPosts,
          {
            ...original,
            'id': 'brand-new-story',
            'seenByMe': false,
            'viewers': <String>[],
          },
        ];
        store.notifyListeners();
        await tester.pumpAndSettle();
        expect(avatars().first.ring, isTrue);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }
  testWidgets(
    'A story seen on another screen has no ring when a profile opens',
    (tester) async {
      final store = GpixStore()..startTestDemo();
      store.post('s1')['seenByMe'] = true;
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: const MaterialApp(home: Profile(user: 'u1')),
        ),
      );
      await tester.pumpAndSettle();
      final avatar = tester
          .widgetList<Avatar>(find.byType(Avatar))
          .firstWhere((a) => a.user == 'u1' && a.size == 80);
      expect(avatar.ring, isFalse);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
