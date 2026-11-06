import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:gpix/core/drafts.dart';
import 'package:gpix/core/profile_links.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/profile_links.dart';
import 'package:gpix/screens/social.dart';
import 'package:gpix/screens/post_composer.dart';
import 'package:gpix/screens/stories.dart';
import 'package:image/image.dart' as im;

class Paths extends PathProviderPlatform {
  final String root;
  Paths(this.root);
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

class Launcher extends UrlLauncherPlatform {
  @override
  get linkDelegate => null;
  Uri? launched;
  LaunchOptions? options;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched = Uri.parse(url);
    this.options = options;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('GPIX/gallery'),
          (call) async => [],
        );
    await (FontLoader('Roboto')..addFont(
          File(
            'test/fonts/Roboto-Regular.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader('packages/font_awesome_flutter/FontAwesomeBrands')
          ..addFont(
            rootBundle.load(
              'packages/font_awesome_flutter/lib/fonts/fa-brands-400.ttf',
            ),
          ))
        .load();
  });
  test('Social profile normalization, validation and WhatsApp targets', () {
    expect(
      socialLink('instagram', '@demix.87', '')['url'],
      'https://www.instagram.com/demix.87/',
    );
    final site = socialLink('website', 'https://gpix.cc/about', '');
    expect(site['title'], 'gpix.cc');
    expect(site['url'], 'https://gpix.cc/about');
    expect(
      () => socialLink('website', 'javascript:alert(1)', ''),
      throwsFormatException,
    );
    final w = socialLink('whatsapp', '+39 333 1234567', 'Scrivimi');
    expect(w['value'], '393331234567');
    expect(profileAppUri(w).scheme, 'whatsapp');
    expect(
      () => socialLink('instagram', 'https://evil.test', ''),
      throwsFormatException,
    );
    expect(() => socialLink('whatsapp', 'abc', ''), throwsFormatException);
    expect(
      resolveSocialLink({
        'url': 'https://www.instagram.com/demix.87/',
        'title': 'Demix',
      })['type'],
      'instagram',
    );
    expect(
      resolveSocialLink({
        'url': 'https://example.test/demix',
        'title': 'Unknown',
      })['type'],
      'website',
    );
  });
  testWidgets('Social links open the profile app, never an in-app web page', (
    t,
  ) async {
    final launcher = Launcher();
    UrlLauncherPlatform.instance = launcher;
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: Scaffold(
            body: ProfileLinkChips(
              links: [socialLink('threads', 'demix.87', 'demix.87')],
              own: false,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('demix.87'));
    await t.pump();
    expect(
      launcher.options!.mode,
      PreferredLaunchMode.externalNonBrowserApplication,
    );
    expect(launcher.launched!.host, 'www.threads.com');
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'Centered requests, unique settings, profile pin and social platform tiles dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        s.state['requests'] = [];
        s.me['links'] = [
          socialLink('threads', 'demix.87', 'demix.87'),
          socialLink('facebook', 'demetrio.barreca', 'Demetrio Barreca'),
        ];
        final post = s.allPosts.firstWhere(
          (p) => p['author'] == s.myId && p['kind'] == 'post',
        );
        await s.act('pinPost', {'id': post['id']});
        final key = GlobalKey();
        Future<void> mount(Widget page) async {
          await t.pumpWidget(
            GpixScope(
              store: s,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: RepaintBoundary(key: key, child: page),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }

        Future<void> shot(String name) async {
          await t.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1.5);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('QA/corrections34').create(recursive: true);
            await File(
              'QA/corrections34/$name-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }

        await mount(const Requests());
        final title = t.getCenter(find.text('Nessuna richiesta'));
        expect((title.dx - 195).abs(), lessThan(2));
        expect(title.dy, greaterThan(350));
        expect(title.dy, lessThan(650));
        await shot('requests');
        await mount(const Settings());
        await shot('settings');
        await t.tap(find.text('I tuoi contenuti'));
        await t.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Archivio'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('settings-search')),
          'Archivio',
        );
        await t.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Archivio'), findsOneWidget);
        expect(find.text('Centro sulla privacy'), findsNothing);
        expect(find.text('Informazioni'), findsNothing);
        await mount(Profile(user: s.myId));
        expect(find.byKey(ValueKey('pinned-${post['id']}')), findsOneWidget);
        expect(find.text('demix.87'), findsOneWidget);
        await shot('profile');
        await mount(const SocialLinkEditor());
        await t.tap(find.byKey(const ValueKey('social-platform-whatsapp')));
        await t.pumpAndSettle();
        expect(find.text('Numero WhatsApp'), findsOneWidget);
        await t.enterText(
          find.byKey(const ValueKey('social-handle')),
          '+39 333 1234567',
        );
        await t.pumpAndSettle();
        expect(find.text('Anteprima sul profilo'), findsOneWidget);
        expect(find.text('+393331234567'), findsOneWidget);
        await shot('social-editor');
        await t.pumpWidget(const SizedBox());
        s.dispose();
      },
    );
  }
  testWidgets('Manual post draft saves while composer remains open', (t) async {
    final root = (await t.runAsync(
      () => Directory.systemTemp.createTemp('gpix34'),
    ))!;
    PathProviderPlatform.instance = Paths(root.path);
    final file = File('${root.path}/photo.png');
    await t.runAsync(
      () => file.writeAsBytes(im.encodePng(im.Image(width: 20, height: 20))),
    );
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(
          home: PostComposer(
            initialDraft: {
              'id': 'manual34',
              'files': [file.path],
              'text': 'Caption saved',
              'textX': .9,
              'textY': .1,
            },
          ),
        ),
      ),
    );
    await t.pump();
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('save-post-draft')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await t.pump();
    final saved = await t.runAsync(() => Drafts.list('${s.server}|${s.myId}'));
    expect(saved!.single['text'], 'Caption saved');
    expect(saved.single['textX'], .9);
    expect(find.byType(PostComposer), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    s.dispose();
    await t.runAsync(() => root.delete(recursive: true));
  });
  testWidgets('Reel composer exposes explicit draft action before closing', (
    t,
  ) async {
    final s = GpixStore()..startTestDemo();
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: const MaterialApp(home: Composer(kind: 'reel')),
      ),
    );
    await t.pump();
    expect(find.byKey(const ValueKey('save-reel-draft')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('save-reel-draft')));
    await t.pump();
    expect(
      find.text('Aggiungi un video prima di salvare la bozza.'),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    s.dispose();
  });
}
