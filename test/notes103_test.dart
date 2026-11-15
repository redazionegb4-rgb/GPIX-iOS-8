import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/rebuild/surfaces.dart';
import 'package:gpix/screens/notes.dart';
import 'package:gpix/ui/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesStore extends GpixStore {
  @override
  Future<List<J>> musicTracks() async => [
    {
      'id': 'original-1',
      'title': 'Riflessi',
      'artist': 'GPIX',
      'audio': '/music/audio/original-1',
      'duration': 28,
      'original': true,
      'reels': 1,
    },
  ];
}

Future<GpixStore> showNotes(
  WidgetTester tester, {
  double width = 402,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  Widget? page,
}) async {
  final store = NotesStore()..startTestDemo();
  SharedPreferences.setMockInitialValues({});
  store.prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = Size(width, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 54, bottom: 31);
  addTearDown(tester.view.reset);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    GpixScope(
      store: store,
      child: MaterialApp(
        theme: gpixTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: page ?? ProfileHome(user: store.myId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profile shows its real sections and opens the note editor', (
    tester,
  ) async {
    await showNotes(
      tester,
      width: 320,
      textScale: 1.20,
      brightness: Brightness.dark,
    );
    expect(find.text('Modifica'), findsOneWidget);
    expect(find.byTooltip('Crea'), findsOneWidget);
    expect(find.byTooltip('Impostazioni e attività'), findsOneWidget);
    expect(find.byTooltip('Threads'), findsNothing);
    expect(find.byTooltip('Richieste di seguirti'), findsNothing);
    expect(find.text('Persone suggerite'), findsOneWidget);
    expect(find.text('Nuova'), findsOneWidget);
    final photo = tester.getRect(find.byKey(const ValueKey('profile-avatar')));
    final bubble = tester.getRect(
      find.byKey(const ValueKey('note-bubble-body')),
    );
    expect(bubble.top, lessThan(photo.top));
    expect(bubble.bottom, lessThan(photo.center.dy + 12));
    await tap(tester, find.byTooltip('La tua nota'));
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Condividi'),
    );
    expect(submit.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final (brightness, width, scale) in [
    (Brightness.light, 402.0, 1.0),
    (Brightness.dark, 320.0, 1.4),
  ]) {
    testWidgets(
      'The inbox note leaves the portrait visible in ${brightness.name}',
      (tester) async {
        final store = await showNotes(
          tester,
          width: width,
          textScale: scale,
          brightness: brightness,
          page: const DirectHome(),
        );
        final tray = find.byType(NotesTray);
        final body = find.descendant(
          of: tray,
          matching: find.byKey(const ValueKey('note-bubble-body')),
        );
        final portrait = find.descendant(
          of: tray,
          matching: find.byType(NotePortrait),
        );

        void checkLayout() {
          final bubbleRect = tester.getRect(body);
          final portraitRect = tester.getRect(portrait);
          expect(bubbleRect.height, lessThan(portraitRect.height));
          expect(bubbleRect.bottom, closeTo(portraitRect.top + 3, 0.1));
          expect(
            bubbleRect.top,
            greaterThanOrEqualTo(tester.getTopLeft(tray).dy),
          );
        }

        expect(find.text('Lascia una nota…'), findsOneWidget);
        checkLayout();
        await store.act('note', {
          'text': 'Ciao a tutti',
          'details': {'color': '#420dac', 'place': 'Reggio Calabria'},
        });
        await tester.pumpAndSettle();
        expect(find.text('Ciao a tutti'), findsOneWidget);
        checkLayout();
        await tap(tester, find.text('Ciao a tutti'));
        expect(find.text('Lascia una nuova nota'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Color, emoji and close-friends choice survive publishing', (
    tester,
  ) async {
    final store = await showNotes(tester);
    await tap(tester, find.byTooltip('La tua nota'));
    final field = find.byKey(const ValueKey('note-text'));
    await tester.enterText(field, 'Pausa caffè');
    await tap(tester, find.byTooltip('Personalizza la bolla'));
    expect(find.text('Bubble Editor'), findsOneWidget);
    await tap(tester, find.text('Prova'));
    await tap(tester, find.byKey(const ValueKey('note-color-3')));
    await tap(tester, find.byTooltip('Scegli emoji'));
    await tap(tester, find.text('✨'));
    await tap(tester, find.text('Applica'));
    expect(tester.widget<TextField>(field).controller!.text, 'Pausa caffè');
    await tap(tester, find.text('Condividi con gli amici'));
    await tap(tester, find.text('Amici più stretti'));
    await tap(tester, find.text('Condividi'));
    final note = store.notes.first;
    expect(note.str('text'), 'Pausa caffè');
    expect(note.str('audience'), 'close');
    expect(note.obj('details'), {'color': '#420dac', 'emoji': '✨'});
    expect(find.text('Pausa caffè'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'GIF and music previews show actual items and can be shared without a caption',
    (tester) async {
      final store = await showNotes(tester);
      await tap(tester, find.byTooltip('La tua nota'));
      await tap(tester, find.byTooltip('GIF'));
      expect(find.text('Cerca GIPHY'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('gif-demo-0')));
      expect(find.byTooltip('Rimuovi allegato'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Condividi'), findsOneWidget);
      await tap(tester, find.byTooltip('Rimuovi allegato'));
      await tap(tester, find.byTooltip('Musica'));
      expect(find.text('Condividi da Spotify'), findsOneWidget);
      await tap(tester, find.byTooltip('Salva brano'));
      await tap(tester, find.text('Salvato'));
      await tap(tester, find.text('Riflessi'));
      expect(find.text('Riflessi'), findsOneWidget);
      await tap(tester, find.text('Condividi'));
      expect(store.notes.single.str('text'), '');
      expect(
        store.notes.single.obj('details').obj('music').str('id'),
        'original-1',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Composer keeps the text and share actions usable with the keyboard',
    (tester) async {
      await showNotes(tester, width: 320);
      await tap(tester, find.byTooltip('La tua nota'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 351);
      await tester.pumpAndSettle();
      final textbox = tester.getRect(find.byKey(const ValueKey('note-text')));
      final submit = tester.getRect(find.text('Condividi'));
      expect(textbox.bottom, lessThan(submit.top));
      expect(submit.bottom, lessThan(874 - 351));
      await tap(tester, find.byTooltip('Luogo'));
      await tester.enterText(find.byType(TextField).last, 'Reggio Calabria');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Usa questo luogo'));
      expect(find.text('Reggio Calabria'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
