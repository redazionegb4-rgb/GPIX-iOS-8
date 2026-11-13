import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/shell.dart';
import 'package:gpix/rebuild/surfaces.dart';
import 'package:gpix/ui/kit.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('New destinations are reachable in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = GpixStore()..startTestDemo();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        GpixScope(
          store: store,
          child: MaterialApp(
            theme: gpixTheme(brightness),
            home: const SocialShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TimelinePost), findsWidgets);
      for (final (label, screen) in [
        ('Messaggi', DirectHome),
        ('Cerca', DiscoverHome),
        ('Profilo', ProfileHome),
      ]) {
        await tester.tap(find.byTooltip(label).last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(screen).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
