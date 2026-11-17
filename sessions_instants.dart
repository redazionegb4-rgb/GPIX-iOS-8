import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
export 'instants.dart';

String sessionDate(dynamic value) {
  final seconds = value is num ? value.toInt() : 0;
  if (seconds <= 0) return 'Non disponibile';
  final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

class DeviceSessions extends StatefulWidget {
  const DeviceSessions({super.key});
  @override
  State<DeviceSessions> createState() => _DeviceSessionsState();
}

class _DeviceSessionsState extends State<DeviceSessions> {
  List<J>? rows;
  String error = '';
  bool busy = false;
  bool loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      refresh();
    }
  }

  Future<void> refresh() async {
    try {
      final s = GpixScope.of(context, listen: false);
      if (s.demo) {
        s.state['demoDeviceSessions'] ??= [
          {
            'id': 'demo-current',
            'device': 'Questo dispositivo (demo)',
            'current': true,
            'created': now,
            'lastSeen': now,
            'expires': now + 86400,
            'ip': '',
          },
          {
            'id': 'demo-other',
            'device': 'iPhone (esempio)',
            'current': false,
            'created': now - 86400,
            'lastSeen': now - 7200,
            'expires': now + 86400,
            'ip': '',
          },
        ];
        rows = s.state.rows('demoDeviceSessions');
      } else {
        rows = (await s.api('/sessions')).rows('sessions');
      }
      error = '';
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() {});
  }

  Future<void> revoke({J? row, bool others = false}) async {
    if (busy) return;
    final current = row?.flag('current') ?? false;
    if (!await gpixAlert(
      context,
      others
          ? 'Disconnettere gli altri dispositivi?'
          : current
          ? 'Uscire da questo dispositivo?'
          : 'Disconnettere questo dispositivo?',
      'Sarà necessario effettuare nuovamente l’accesso.',
      confirm: 'Disconnetti',
      cancel: true,
      destructive: true,
    ))
      return;
    if (!mounted) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      var logout = current;
      if (s.demo) {
        s.state['demoDeviceSessions'] = rows!
            .where(
              (x) => others ? x.flag('current') : x.str('id') != row!.str('id'),
            )
            .toList();
      } else {
        final r = await s.api(
          '/sessions/revoke',
          payload: others ? {'others': true} : {'id': row!['id']},
        );
        logout = r.flag('loggedOut');
      }
      if (logout) {
        await s.logout(remote: false);
        if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        await refresh();
      }
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivi collegati'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna sessioni',
            onPressed: busy ? null : refresh,
            icon: const GIcon(CupertinoIcons.arrow_clockwise),
          ),
        ],
      ),
      body: error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: refresh,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            )
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  s.demo
                      ? 'Esempi dimostrativi: non sono accessi reali.'
                      : 'Ogni voce rappresenta una sessione di accesso. Disconnetti quelle che non riconosci.',
                  style: const TextStyle(color: muted, height: 1.4),
                ),
                const SizedBox(height: 15),
                for (final row in rows!)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: const GIcon(
                              CupertinoIcons.device_phone_portrait,
                              size: 28,
                            ),
                            title: Text(row.str('device')),
                            subtitle: Text(
                              row.flag('current')
                                  ? 'Sessione attuale'
                                  : 'Altra sessione',
                            ),
                            trailing: row.flag('current')
                                ? const Icon(
                                    CupertinoIcons.checkmark_shield,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Accesso: ${sessionDate(row['created'])}\nUltima attività: ${sessionDate(row['lastSeen'])}${row.str('ip').isEmpty ? '' : '\nIP: ${row.str('ip')}'}',
                              style: const TextStyle(color: muted, height: 1.5),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : () => revoke(row: row),
                              child: Text(
                                row.flag('current')
                                    ? 'Esci da questo dispositivo'
                                    : 'Disconnetti',
                                style: const TextStyle(color: danger),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (rows!.any((x) => !x.flag('current')))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => revoke(others: true),
                      icon: const GIcon(
                        CupertinoIcons.square_arrow_left,
                        size: 19,
                      ),
                      label: const Text('Disconnetti tutti gli altri'),
                    ),
                  ),
              ],
            ),
    );
  }
}
