import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/shell.dart';
import 'package:gpix/screens/profile_avatar.dart';
import 'package:gpix/screens/social.dart';

import 'release_flows_test.dart' show mount;

void main() {
  testWidgets('Activity bubble points at the heart and is tappable', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    store.state['notifications'] = [
      {
        'id': 'new-like',
        'actor': store.users.first.str('id'),
        'type': 'like',
        'created': now,
        'seen': false,
      },
    ];
    await mount(tester, store, const SocialShell());
    final heart = tester.getRect(find.byKey(const ValueKey('activity-heart')));
    final bubble = find.byKey(const ValueKey('activity-bubble'));
    final popup = tester.getRect(bubble);
    expect(popup.center.dx, closeTo(heart.center.dx, .5));
    expect(popup.top, closeTo(heart.bottom - 3, .5));
    await tester.tap(bubble);
    await tester.pumpAndSettle();
    expect(find.byType(Activity), findsOneWidget);
    expect(store.hasActivity, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Only the profile grid switches on horizontal drag', (
    tester,
  ) async {
    final store = GpixStore()..startTestDemo();
    store.state['posts'] = [
      for (final kind in ['post', 'reel'])
        for (var index = 0; index < 9; index++)
          {
            'id': '$kind-$index',
            'author': store.myId,
            'created': now - index,
            'kind': kind,
            'media': 'post0.jpg',
            'style': {'cover': 'post0.jpg'},
            'viewCount': 322,
          },
    ];
    await mount(tester, store, const SocialShell());
    await tester.tap(find.byTooltip('Profilo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Persone suggerite'));
    await tester.pumpAndSettle();
    final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    final avatar = find.byKey(const ValueKey('profile-avatar'));
    final portrait = tester.getTopLeft(avatar);
    await tester.dragFrom(
      portrait + const Offset(25, 25),
      const Offset(160, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(avatar), portrait);
    expect(tabs.index, 0);

    final grid = find.byKey(const ValueKey('profile-grid-pages'));
    final tabBar = find.byType(TabBar);
    final header = tester.getRect(tabBar);
    final bounds = tester.getRect(grid);
    final gesture = await tester.startGesture(
      Offset(bounds.right - 44, header.bottom + 35),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-46, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getTopLeft(avatar), portrait);
    expect(tester.getRect(tabBar), header);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tabs.index, 1);
    expect(find.text('322'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Avatar options persist in Modifica profilo', (tester) async {
    final store = GpixStore()..startTestDemo();
    await mount(tester, store, const EditProfile());
    await tester.tap(find.byTooltip('Crea avatar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Crea avatar'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileAvatarEditor), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Crea il tuo avatar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(('avatar-swatch', 'skin', 3))));
    await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ricci'));
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Avanti'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Salva avatar'));
    await tester.pumpAndSettle();
    expect(store.avatarModel['skin'], 3);
    expect(store.avatarModel['hair'], 3);
    expect(find.byType(EditProfile), findsOneWidget);
    await tester.tap(find.byTooltip('Modifica avatar'));
    await tester.pumpAndSettle();
    expect(find.text('Usa come immagine del profilo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
