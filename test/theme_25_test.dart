import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpix/main.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/calls.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/messages.dart';
import 'dart:ui' as ui;
void main() {
  setUpAll(() async {
    await (FontLoader('Roboto')..addFont(File('test/fonts/Roboto-Regular.ttf').readAsBytes().then((b) => ByteData.sublistView(b)))).load();
    await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
  });
  testWidgets('Appearance persists and changes the actual app theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store=GpixStore()..startTestDemo();
    store.prefs=await SharedPreferences.getInstance();
    await tester.pumpWidget(GpixApp(store:store));await tester.pumpAndSettle();
    await store.setAppearance('dark');await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(HomeShell))).brightness, Brightness.dark);
    expect(store.prefs!.getString('gpix.appearance'), 'dark');
    await store.setAppearance('light');await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(HomeShell))).brightness, Brightness.light);
    await tester.pumpWidget(const SizedBox());store.dispose();
  });
  for (final width in [320.0,390.0,430.0]) {
    testWidgets('Dark screens fit at $width', (tester) async {
      tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final store=GpixStore()..startTestDemo();store.appearance='dark';
      final boundary=GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key:boundary,child:GpixApp(store:store)));await tester.pumpAndSettle();
      final pages=<String,Widget>{'profile':Profile(user:store.myId),'inbox':const Inbox(),'settings':const Settings(),'appearance':const AppearancePage(),'share':Scaffold(body:SingleChildScrollView(child:SharePanel(post:store.posts.first)))};
      for(final page in pages.entries) {
        gpixNavigator.currentState!.push(MaterialPageRoute(builder:(_) => page.value));await tester.pumpAndSettle();
        expect(tester.takeException(),isNull,reason:page.key);
        if(width==390) {
          final render=boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image=await render.toImage();final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
            await Directory('QA/dark25').create(recursive:true);
            await File('QA/dark25/${page.key}.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();
          });
        }
        gpixNavigator.currentState!.pop();await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());store.dispose();
    });
  }
}
