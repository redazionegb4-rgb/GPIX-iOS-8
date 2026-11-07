import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/core/push_service.dart';
import 'package:gpix/main.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';

void main() {
  test(
    'Foreground previews redact only messages when recipient chooses privacy',
    () async {
      final s = GpixStore()..startTestDemo();
      expect(
        pushNotificationBody(s, 'message', 'Ci vediamo alle 20?'),
        'Ci vediamo alle 20?',
      );
      await s.setPreference('hideNotificationPreviews', true);
      expect(
        pushNotificationBody(s, 'message', 'TESTO PRIVATO'),
        'Apri GPIX per leggerlo.',
      );
      expect(
        pushNotificationBody(s, 'announcement', 'Novità GPIX'),
        'Novità GPIX',
      );
      await s.setPreference('hideNotificationPreviews', false);
      expect(pushNotificationBody(s, 'message', 'Ciao'), 'Ciao');
      expect(pushNotificationBody(s, 'message', null), 'Nuovo messaggio');
      s.dispose();
    },
  );
  test(
    'Foreground message headings distinguish messages from other notifications',
    () async {
      final s = GpixStore()..startTestDemo();
      expect(
        pushNotificationNotice(
          s,
          'message',
          'Nuovo messaggio · Andrea Rossi',
          'Ciao!',
        ),
        'Nuovo messaggio · Andrea Rossi\nCiao!',
      );
      expect(
        pushNotificationNotice(s, 'message', 'Andrea Rossi', 'Ciao!'),
        'Nuovo messaggio · Andrea Rossi\nCiao!',
      );
      expect(
        pushNotificationNotice(s, 'message', 'GPIX', 'Ciao!'),
        'Nuovo messaggio\nCiao!',
      );
      expect(
        pushNotificationNotice(s, 'announcement', 'GPIX', 'Novità'),
        'Novità',
      );
      await s.setPreference('hideNotificationPreviews', true);
      expect(
        pushNotificationNotice(
          s,
          'message',
          'Nuovo messaggio · Weekend',
          'TESTO PRIVATO',
        ),
        'Nuovo messaggio · Weekend\nApri GPIX per leggerlo.',
      );
      s.dispose();
    },
  );
  for (final appearance in ['light', 'dark']) {
    testWidgets(
      'Privacy notification toggle is distinct from inbox previews $appearance',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.appearance = appearance;
        await t.pumpWidget(GpixApp(store: s));
        await t.pumpAndSettle();
        gpixNavigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Settings()),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Privacy').first);
        await t.pumpAndSettle();
        await t.tap(find.text('Nascondi anteprima nelle notifiche'));
        await t.pumpAndSettle();
        final toggle = find.byType(SwitchListTile);
        expect(t.widget<SwitchListTile>(toggle).value, isFalse);
        final thread = s.inboxThreads.first;
        final before = inboxPreview(s, thread);
        await t.tap(toggle);
        await t.pumpAndSettle();
        expect(s.preferences['hideNotificationPreviews'], true);
        expect(t.widget<SwitchListTile>(toggle).value, isTrue);
        expect(inboxPreview(s, thread), before);
        expect(
          pushNotificationBody(s, 'message', 'PRIVATO'),
          'Apri GPIX per leggerlo.',
        );
        gpixNavigator.currentState!.pop();
        await t.pumpAndSettle();
        await t.tap(find.text('Nascondi anteprima nelle notifiche'));
        await t.pumpAndSettle();
        expect(t.widget<SwitchListTile>(toggle).value, isTrue);
        await t.tap(toggle);
        await t.pumpAndSettle();
        expect(s.preferences['hideNotificationPreviews'], false);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }
}
