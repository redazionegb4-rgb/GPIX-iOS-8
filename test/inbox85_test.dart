import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/messages.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  testWidgets('Inbox opens account switcher and long-press actions', (t) async {
    final store = GpixStore()..startTestDemo();
    addTearDown(store.dispose);
    final thread = store.inboxThreads.first;
    await t.pumpWidget(
      GpixScope(
        store: store,
        child: MaterialApp(
          theme: gpixTheme(Brightness.light),
          home: const Inbox(),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(store.me['username'] as String),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Aggiungi account'), findsOneWidget);
    Navigator.of(t.element(find.text('Aggiungi account'))).pop();
    await t.pumpAndSettle();
    final row = find.text(store.threadName(thread)).last;
    await t.ensureVisible(row);
    await t.longPress(row);
    await t.pumpAndSettle();
    expect(find.text('Silenzia'), findsOneWidget);
    expect(find.text('Elimina'), findsOneWidget);
    await t.tap(find.text('Fissa'));
    await t.pumpAndSettle();
    expect(thread['chatSettings']['pinned'], true);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
