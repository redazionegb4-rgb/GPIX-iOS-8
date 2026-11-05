import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/core/data.dart';
import 'package:gpix/core/store.dart';
import 'package:gpix/screens/sessions_instants.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Instant send keeps the request key on retry and authenticates binary opens',
    () async {
      final calls = <String>[];
      final s = GpixStore(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer session36');
          calls.add(r.url.path);
          if (r.url.path == '/instants/send') {
            expect(jsonDecode(r.body)['requestKey'], 'retry36');
            return http.Response('{"ok":true}', 200);
          }
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      )..token = 'session36';
      await s.sendInstant(
        'media36',
        ['friend'],
        'caption',
        requestKey: 'retry36',
      );
      expect(await s.openInstant('i36'), [1, 2, 3]);
      expect(calls, ['/instants/send', '/instants/i36/open']);
      s.dispose();
    },
  );
  test('Demo instant is consumed once and expired photos disappear', () async {
    final s = GpixStore()..startTestDemo();
    final first = await s.instantList();
    final row = first.rows('received').single;
    expect(await s.openInstant(row.str('id')), isNotEmpty);
    expect((await s.instantList()).rows('received'), isEmpty);
    await expectLater(s.openInstant(row.str('id')), throwsException);
    s.state['demoInstants'] = [
      {'id': 'expired', 'owner': 'other', 'expires': now - 1},
    ];
    expect((await s.instantList()).rows('received'), isEmpty);
    s.dispose();
  });
  for (final width in [320.0, 390.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Sessions and instants layout $width $brightness', (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final s = GpixStore()..startTestDemo();
        Widget wrap(Widget child) => GpixScope(
          store: s,
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: child,
          ),
        );
        await t.pumpWidget(wrap(const DeviceSessions()));
        await t.pumpAndSettle();
        expect(find.text('Dispositivi collegati'), findsOneWidget);
        expect(find.text('Sessione attuale'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(
          wrap(const InstantCollectionPage(autoCapture: false)),
        );
        await t.pumpAndSettle();
        expect(find.text('Dai tuoi amici'), findsOneWidget);
        expect(find.text('Le tue'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(wrap(const InstantComposer(eligible: [])));
        await t.pumpAndSettle();
        expect(find.byType(LiveInstantCamera), findsOneWidget);
        expect(find.text('Galleria'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        s.dispose();
      });
    }
  }
  testWidgets('Device revoke requests only the selected public session id', (
    t,
  ) async {
    var revoked = false;
    final s = GpixStore(
      client: MockClient((r) async {
        if (r.url.path == '/sessions/revoke') {
          expect(jsonDecode(r.body), {'id': 'public-id'});
          revoked = true;
          return http.Response('{"ok":true,"loggedOut":false}', 200);
        }
        return http.Response(
          jsonEncode({
            'sessions': [
              if (!revoked)
                {
                  'id': 'public-id',
                  'device': 'iPhone test',
                  'current': false,
                  'created': now,
                  'lastSeen': now,
                },
            ],
          }),
          200,
        );
      }),
    )..token = 'session36';
    await t.pumpWidget(
      GpixScope(
        store: s,
        child: MaterialApp(home: const DeviceSessions()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Disconnetti').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Disconnetti').last);
    await t.pumpAndSettle();
    expect(revoked, isTrue);
    expect(find.text('iPhone test'), findsNothing);
    s.dispose();
  });
}
