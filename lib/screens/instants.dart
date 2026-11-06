import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart' as cam;
import 'package:image/image.dart' as im;
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';
import 'social.dart' show Profile;

Future<void> openInstants(BuildContext c) => Navigator.of(c).push(
  PageRouteBuilder<void>(
    transitionDuration: MediaQuery.disableAnimationsOf(c)
        ? Duration.zero
        : const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (c, animation, secondary) => const InstantsPage(),
    transitionsBuilder: (c, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: .78, end: 1).animate(curve),
          alignment: Alignment.bottomRight,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.08, .10),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        ),
      );
    },
  ),
);

class InstantPile extends StatefulWidget {
  const InstantPile({super.key});
  @override
  State<InstantPile> createState() => _InstantPileState();
}

class _InstantPileState extends State<InstantPile> {
  bool pressed = false, opening = false;
  Future<void> enter() async {
    if (opening) return;
    opening = true;
    setState(() => pressed = true);
    if (!MediaQuery.disableAnimationsOf(context))
      await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => pressed = false);
    await openInstants(context);
    if (mounted) setState(() => opening = false);
  }

  Future<void> pause(bool value) async {
    await perform(
      context,
      () => GpixScope.of(context, listen: false).snoozeInstants(value),
    );
  }

  void controls() {
    final s = GpixScope.of(context, listen: false);
    sheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActionRow(
            s.instantsPaused ? CupertinoIcons.play : CupertinoIcons.pause,
            s.instantsPaused ? 'Riprendi istantanee' : 'Pausa per 24 ore',
            () {
              Navigator.pop(context);
              pause(!s.instantsPaused);
            },
          ),
          ActionRow(CupertinoIcons.archivebox, 'Archivio privato', () {
            Navigator.pop(context);
            open(context, const InstantArchive());
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c), rows = s.instantPile, paused = s.instantsPaused;
    final count = s.demo
        ? rows.length
        : s.state.number('instantUnread', rows.length.toDouble()).toInt();
    return Semantics(
      label: paused ? 'Istantanee in pausa' : 'Istantanee: $count nuove',
      button: true,
      child: GestureDetector(
        onTap: enter,
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onLongPress: () {
          setState(() => pressed = false);
          controls();
        },
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0).abs() > 100)
            pause(d.primaryVelocity! > 0);
        },
        child: AnimatedScale(
          scale: pressed ? .92 : 1,
          duration: MediaQuery.disableAnimationsOf(c)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 104,
            height: 126,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (
                  var i = (rows.isEmpty ? 1 : rows.length.clamp(1, 3)) - 1;
                  i >= 0;
                  i--
                )
                  Transform.translate(
                    offset: Offset(i * 7.0, -i * 5.0),
                    child: Transform.rotate(
                      angle: i * .12 - .07,
                      child: Container(
                        width: 82,
                        height: 88,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: subdued(c),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: surface(c), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .18),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: rows.isEmpty
                            ? Center(
                                child: GIcon(
                                  paused
                                      ? CupertinoIcons.pause
                                      : CupertinoIcons.camera,
                                  size: 28,
                                ),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  InstantPreview(
                                    key: ValueKey('pile-${rows[i].str('id')}'),
                                    id: rows[i].str('id'),
                                  ),
                                  ColoredBox(
                                    color: Colors.black.withValues(alpha: .08),
                                  ),
                                  if (i == 0)
                                    const Center(
                                      child: Icon(
                                        CupertinoIcons.photo_on_rectangle,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: surface(c),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Theme.of(c).dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 0 && !paused) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: violet,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          paused
                              ? 'In pausa'
                              : count > 0
                              ? (count == 1 ? '1 nuova' : '$count nuove')
                              : 'Istantanee',
                          style: TextStyle(
                            color: foreground(c),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Inbox entry is the viewing deck, never the former marketing/grid hub.
class InstantsPage extends StatefulWidget {
  final bool autoCapture;
  const InstantsPage({super.key, this.autoCapture = false});
  @override
  State<InstantsPage> createState() => _InstantsPageState();
}

class _InstantsPageState extends State<InstantsPage> {
  List<J>? rows;
  String error = '';
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
      final list = (await GpixScope.of(
        context,
        listen: false,
      ).instantList()).rows('received');
      if (mounted) setState(() => rows = list);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Impossibile caricare le istantanee.');
    }
  }

  @override
  Widget build(BuildContext c) {
    if (rows?.isNotEmpty == true) return InstantViewer(items: rows!);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Chiudi istantanee',
          onPressed: () => Navigator.pop(c),
          icon: const GIcon(CupertinoIcons.xmark),
        ),
        actions: [
          IconButton(
            tooltip: 'Le tue istantanee',
            onPressed: () => open(c, const InstantArchive()),
            icon: const GIcon(CupertinoIcons.square_grid_2x2),
          ),
          IconButton(
            tooltip: 'Crea un’istantanea',
            onPressed: () async {
              await open(c, const InstantComposer(autoCapture: true));
              if (mounted) refresh();
            },
            icon: const GIcon(CupertinoIcons.camera),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GIcon(
                  CupertinoIcons.photo_on_rectangle,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  error.isNotEmpty
                      ? error
                      : rows == null
                      ? 'Caricamento…'
                      : 'Nessuna nuova istantanea',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'I nuovi scatti dei tuoi amici appariranno qui. Puoi condividere il tuo momento anche adesso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () async {
                    await open(c, const InstantComposer(autoCapture: true));
                    if (mounted) refresh();
                  },
                  icon: const GIcon(CupertinoIcons.camera),
                  label: const Text('Crea un’istantanea'),
                ),
                if (error.isNotEmpty)
                  TextButton(onPressed: refresh, child: const Text('Riprova')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InstantCollectionPage extends StatefulWidget {
  // Entry always opens the dashboard; camera belongs to the explicit Create action.
  final bool autoCapture;
  const InstantCollectionPage({super.key, this.autoCapture = false});
  @override
  State<InstantCollectionPage> createState() => _InstantCollectionPageState();
}

class _InstantCollectionPageState extends State<InstantCollectionPage> {
  J? data;
  String error = '', filter = 'all';
  bool loaded = false, busy = false;
  Timer? refreshTimer;
  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      refresh();
      refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) refresh();
      });
    }
  }

  Future<void> refresh() async {
    try {
      final value = await GpixScope.of(context, listen: false).instantList();
      if (mounted)
        setState(() {
          data = value;
          error = '';
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Non riesco a caricare le istantanee.');
    }
  }

  Future<void> create() async {
    await open(context, const InstantComposer(autoCapture: true));
    if (mounted) refresh();
  }

  Future<void> archive() async {
    await open(context, const InstantArchive());
    if (mounted) refresh();
  }

  Future<void> pause(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    await perform(context, () async {
      await GpixScope.of(context, listen: false).snoozeInstants(value);
      await refresh();
    });
    if (mounted) setState(() => busy = false);
  }

  Widget title(String text, String count) => Padding(
    padding: const EdgeInsets.only(top: 25, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
        ),
        Text(count, style: const TextStyle(color: muted)),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c),
        received = (data?.rows('received') ?? <J>[])
            .where((x) => x.number('expires') > now)
            .toList(),
        own = (data?.rows('active') ?? <J>[])
            .where((x) => x.number('expires') > now)
            .toList();
    final groups = <String, List<J>>{};
    for (final row in received) {
      groups.putIfAbsent(row.str('owner'), () => []).add(row);
    }
    final paused = data?.flag('paused') ?? s.instantsPaused;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Istantanee',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Archivio privato',
            onPressed: archive,
            icon: const GIcon(CupertinoIcons.archivebox),
          ),
          IconButton(
            tooltip: 'Opzioni istantanee',
            icon: const GIcon(CupertinoIcons.ellipsis_circle),
            onPressed: () => sheet(
              c,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionRow(
                    paused ? CupertinoIcons.play : CupertinoIcons.pause,
                    paused
                        ? 'Riprendi ricezione'
                        : 'Pausa ricezione per 24 ore',
                    () {
                      Navigator.pop(c);
                      pause(!paused);
                    },
                  ),
                  ActionRow(
                    CupertinoIcons.archivebox,
                    'Il tuo archivio privato',
                    () {
                      Navigator.pop(c);
                      archive();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
          children: [
            const Text(
              'Nuovi momenti',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Apri le card degli amici. Scatta e condividi le tue.',
              style: TextStyle(color: muted),
            ),
            if (s.demo)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Stai provando la demo',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 22),
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('instant-create'),
                onTap: create,
                borderRadius: BorderRadius.circular(26),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff6748f6), Color(0xffbd48c7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  padding: const EdgeInsets.all(21),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .17),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const GIcon(
                          CupertinoIcons.camera_fill,
                          color: Colors.white,
                          size: 29,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crea un’istantanea',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 19,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Scatta ora. Condividi il tuo momento.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const GIcon(
                        CupertinoIcons.plus,
                        color: Colors.white,
                        size: 25,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final choice in [
                    ('all', 'Tutte'),
                    ('new', 'Da aprire'),
                    ('mine', 'Le tue'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(choice.$2),
                        selected: filter == choice.$1,
                        onSelected: (_) => setState(() => filter = choice.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    Text(error, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: refresh,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            if (data == null && error.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (paused)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: subdued(c),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const GIcon(CupertinoIcons.pause_circle, color: muted),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ricezione in pausa',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => pause(false),
                      child: const Text('Riprendi'),
                    ),
                  ],
                ),
              ),
            if (filter != 'mine') ...[
              title(
                'Dai tuoi amici',
                '${received.length} ${received.length == 1 ? 'nuova' : 'nuove'}',
              ),
              if (data != null && groups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: subdued(c),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const GIcon(
                        CupertinoIcons.photo_on_rectangle,
                        size: 35,
                        color: muted,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        paused
                            ? 'Un momento di pausa'
                            : 'Nessuna nuova istantanea',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quando arrivano nuovi scatti, li trovi qui.\nIntanto puoi creare il tuo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              if (groups.isNotEmpty)
                LayoutBuilder(
                  builder: (c, box) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in groups.entries)
                        SizedBox(
                          width: (box.maxWidth - 12) / 2,
                          child: InstantFriendCard(
                            owner: entry.key,
                            items: entry.value,
                            onTap: () async {
                              await open(
                                c,
                                InstantViewer(
                                  items: received
                                      .skip(
                                        received.indexWhere(
                                          (x) =>
                                              x.str('id') ==
                                              entry.value.first.str('id'),
                                        ),
                                      )
                                      .toList(),
                                ),
                              );
                              if (mounted) refresh();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            if (filter != 'new') ...[
              title(
                'Le tue · 24 ore',
                '${own.length} ${own.length == 1 ? 'attiva' : 'attive'}',
              ),
              if (data != null && own.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(c).dividerColor),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Row(
                    children: [
                      const GIcon(
                        CupertinoIcons.camera,
                        size: 31,
                        color: muted,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Il prossimo istante è tuo.\nPuoi pubblicare anche senza amici.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              if (own.isNotEmpty)
                LayoutBuilder(
                  builder: (c, box) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final row in own)
                        SizedBox(
                          width: (box.maxWidth - 12) / 2,
                          child: InstantOwnCard(
                            item: row,
                            onTap: () async {
                              await open(
                                c,
                                InstantViewer(items: [row], archive: true),
                              );
                              if (mounted) refresh();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 28),
            Material(
              color: subdued(c),
              borderRadius: BorderRadius.circular(23),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                onTap: archive,
                leading: const GIcon(CupertinoIcons.archivebox, size: 28),
                title: const Text(
                  'Il tuo archivio',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Solo tuo. Rivedi, elimina o crea un riepilogo.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                trailing: const GIcon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstantFriendCard extends StatelessWidget {
  final String owner;
  final List<J> items;
  final VoidCallback onTap;
  const InstantFriendCard({
    super.key,
    required this.owner,
    required this.items,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            InstantPreview(
              key: ValueKey('friend-${items.first.str('id')}'),
              id: items.first.str('id'),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'nuova' : 'nuove'}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const Center(
              child: GIcon(
                CupertinoIcons.viewfinder,
                size: 35,
                color: Colors.white,
              ),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    items.first.str('username'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tocca per aprire',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label:
          '${items.first.str('username')}, ${items.length} istantanee da aprire',
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

class InstantOwnCard extends StatelessWidget {
  final J item;
  final VoidCallback onTap;
  const InstantOwnCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext c) {
    final left = (item.number('expires') - now).clamp(0, 86400).toInt();
    final time = left >= 3600
        ? '${(left / 3600).ceil()} h'
        : '${(left / 60).ceil()} min';
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ArchiveThumbnail(
              key: ValueKey('active-${item.str('id')}'),
              id: item.str('id'),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Scade tra $time',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            Positioned(
              left: 13,
              right: 13,
              bottom: 15,
              child: Text(
                item.str('caption').isEmpty
                    ? 'Il tuo istante'
                    : item.str('caption'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(onTap: onTap, child: card);
  }
}

class InstantComposer extends StatefulWidget {
  final List<String>
  eligible; // retained for source compatibility; the audience is a group
  final Future<XFile?> Function()? capture;
  final bool autoCapture;
  final J? replyTo;
  final ValueChanged<bool>? onPhotoChanged;
  const InstantComposer({
    super.key,
    this.eligible = const [],
    this.capture,
    this.autoCapture = false,
    this.replyTo,
    this.onPhotoChanged,
  });
  @override
  State<InstantComposer> createState() => _InstantComposerState();
}

class _InstantComposerState extends State<InstantComposer> {
  String photo = '',
      uploaded = '',
      key = newId(),
      audience = 'friends',
      error = '';
  J? data;
  final caption = TextEditingController();
  bool busy = false, capturing = false, loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      refresh();
      if (widget.autoCapture && widget.capture != null)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) capture();
        });
    }
  }

  Future<void> refresh() async {
    try {
      final value = await GpixScope.of(context, listen: false).instantList();
      if (mounted)
        setState(() {
          data = value;
          error = '';
        });
    } catch (e) {
      if (mounted)
        setState(() => error = 'Non è stato possibile caricare le istantanee.');
    }
  }

  @override
  void dispose() {
    caption.dispose();
    if (photo.isNotEmpty)
      unawaited(File(photo).delete().catchError((_) => File(photo)));
    super.dispose();
  }

  Future<void> takePhoto(XFile file) async {
    if (!mounted) return;
    final old = photo;
    setState(() {
      photo = file.path;
      uploaded = '';
      key = newId();
    });
    widget.onPhotoChanged?.call(true);
    if (old.isNotEmpty && old != photo)
      await File(old).delete().catchError((_) => File(old));
  }

  Future<void> capture() async {
    if (widget.capture == null) return;
    final file = await widget.capture!();
    if (file != null) await takePhoto(file);
  }

  Future<void> send() async {
    if (busy || photo.isEmpty) return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      uploaded = uploaded.isEmpty
          ? await s.upload(photo, 'image/jpeg')
          : uploaded;
      final id = await s.sendInstant(
        uploaded,
        const [],
        caption.text.trim(),
        requestKey: key,
        audience: widget.replyTo == null ? audience : '',
        replyTo: widget.replyTo?.str('id') ?? '',
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Istantanea pubblicata · disponibile per 24 ore'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Annulla',
            onPressed: () async {
              try {
                await s.deleteInstant(id);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Invio annullato')),
                );
              } catch (_) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Impossibile annullare. Riprova dall’archivio.',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    });
    if (mounted) setState(() => busy = false);
  }

  void audienceSheet(BuildContext c) => sheet(
    c,
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in [
          ('friends', 'Amici', CupertinoIcons.person_2),
          ('close', 'Amici più stretti', CupertinoIcons.star),
        ])
          ListTile(
            leading: GIcon(choice.$3),
            title: Text(choice.$2),
            trailing: audience == choice.$1
                ? const GIcon(CupertinoIcons.check_mark, color: violet)
                : null,
            onTap: () {
              setState(() => audience = choice.$1);
              Navigator.pop(c);
            },
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => Theme(
    data: ThemeData.dark(useMaterial3: true),
    child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Chiudi',
          onPressed: busy ? null : () => Navigator.pop(c),
          icon: const GIcon(CupertinoIcons.xmark),
        ),
        title: const Text(
          'Nuova istantanea',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Le tue istantanee',
            onPressed: () => open(c, const InstantArchive()),
            icon: const GIcon(CupertinoIcons.square_grid_2x2),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (c, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  children: [
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                    if (photo.isEmpty)
                      widget.capture != null
                          ? const AspectRatio(
                              aspectRatio: 1,
                              child: ColoredBox(
                                color: Color(0xff18191f),
                                child: Center(
                                  child: GIcon(
                                    CupertinoIcons.camera,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                          : LiveInstantCamera(onPhoto: takePhoto)
                    else ...[
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(38),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(File(photo), fit: BoxFit.cover),
                              if (caption.text.isNotEmpty)
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 20,
                                  child: Text(
                                    caption.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: caption,
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Aggiungi una didascalia…',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                final old = photo;
                                setState(() => photo = '');
                                widget.onPhotoChanged?.call(false);
                                unawaited(
                                  File(
                                    old,
                                  ).delete().catchError((_) => File(old)),
                                );
                              },
                        icon: const GIcon(CupertinoIcons.arrow_clockwise),
                        label: const Text('Scatta di nuovo'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (widget.replyTo != null)
                      Text(
                        'Risposta a @${widget.replyTo!.str('username')}',
                        style: const TextStyle(color: Colors.white70),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => audienceSheet(c),
                        icon: const GIcon(
                          CupertinoIcons.person_2,
                          color: Colors.white,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              audience == 'close'
                                  ? 'Amici più stretti'
                                  : 'Amici',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 5),
                            const GIcon(
                              CupertinoIcons.chevron_down,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    if (photo.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy || data == null ? null : send,
                          icon: const GIcon(CupertinoIcons.paperplane_fill),
                          label: Text(
                            busy ? 'Condivisione…' : 'Pubblica istantanea',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// The existing native camera plugin is already present in the Android host.
class LiveInstantCamera extends StatefulWidget {
  final Future<void> Function(XFile) onPhoto;
  const LiveInstantCamera({super.key, required this.onPhoto});
  @override
  State<LiveInstantCamera> createState() => _LiveInstantCameraState();
}

class _LiveInstantCameraState extends State<LiveInstantCamera>
    with WidgetsBindingObserver {
  cam.CameraController? controller;
  List<cam.CameraDescription> cameras = [];
  int selected = 0;
  bool busy = false, flash = false, starting = false;
  String error = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    start();
  }

  Future<void> start() async {
    if (starting || !mounted) return;
    starting = true;
    try {
      cameras = await cam.availableCameras().timeout(
        const Duration(seconds: 8),
      );
      if (cameras.isEmpty) throw Exception();
      final next = cam.CameraController(
        cameras[selected % cameras.length],
        cam.ResolutionPreset.high,
        enableAudio: false,
      );
      await next.initialize().timeout(const Duration(seconds: 20));
      await next.setFlashMode(cam.FlashMode.off);
      if (!mounted ||
          (WidgetsBinding.instance.lifecycleState != null &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed)) {
        await next.dispose();
        return;
      }
      setState(() => controller = next);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Consenti l’accesso alla fotocamera e riprova.');
    } finally {
      starting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      final old = controller;
      controller = null;
      if (old != null) unawaited(old.dispose());
    } else {
      start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> snap() async {
    final current = controller;
    if (current == null || !current.value.isInitialized || busy) return;
    setState(() => busy = true);
    try {
      final photo = await current.takePicture();
      final raw = await File(photo.path).readAsBytes();
      final source = im.decodeImage(raw);
      if (source != null) {
        final normal = im.bakeOrientation(source),
            side = normal.width < normal.height ? normal.width : normal.height;
        final crop = im.copyCrop(
          normal,
          x: (normal.width - side) ~/ 2,
          y: (normal.height - side) ~/ 2,
          width: side,
          height: side,
        );
        await File(photo.path).writeAsBytes(im.encodeJpg(crop, quality: 90));
      }
      if (mounted) await widget.onPhoto(photo);
    } catch (_) {
      if (mounted) setState(() => error = 'Non riesco a scattare. Riprova.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final current = controller;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: ColoredBox(
              color: const Color(0xff18191f),
              child: current?.value.isInitialized == true
                  ? LayoutBuilder(
                      builder: (c, b) {
                        final preview = current!.value.previewSize!;
                        return FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: preview.height,
                            height: preview.width,
                            child: cam.CameraPreview(current),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: error.isEmpty
                          ? const CircularProgressIndicator()
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    error,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: start,
                                    child: const Text('Riprova'),
                                  ),
                                ],
                              ),
                            ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: flash ? 'Disattiva flash' : 'Attiva flash',
              onPressed: current == null || busy
                  ? null
                  : () async {
                      try {
                        await current.setFlashMode(
                          flash ? cam.FlashMode.off : cam.FlashMode.always,
                        );
                        if (mounted) setState(() => flash = !flash);
                      } catch (_) {
                        if (mounted)
                          notice(
                            c,
                            'Flash non disponibile su questa fotocamera',
                          );
                      }
                    },
              icon: GIcon(
                flash ? CupertinoIcons.bolt : CupertinoIcons.bolt_slash,
                color: Colors.white,
              ),
            ),
            Semantics(
              button: true,
              label: 'Scatta istantanea',
              child: GestureDetector(
                onTap: busy ? null : snap,
                child: Container(
                  width: 78,
                  height: 78,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: busy ? Colors.white38 : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Cambia fotocamera',
              onPressed: cameras.length < 2 || busy || controller == null
                  ? null
                  : () async {
                      final old = controller;
                      setState(() {
                        controller = null;
                        selected = (selected + 1) % cameras.length;
                        flash = false;
                        error = '';
                      });
                      await old?.dispose();
                      await start();
                    },
              icon: const GIcon(
                CupertinoIcons.camera_rotate,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class InstantViewer extends StatefulWidget {
  final List<J> items;
  final bool archive;
  const InstantViewer({super.key, required this.items, this.archive = false});
  @override
  State<InstantViewer> createState() => _InstantViewerState();
}

class _InstantViewerState extends State<InstantViewer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool animating = false;
  double flyFrom = 0,
      flyTo = 0,
      flyFromX = 0,
      flyToX = 0,
      dragX = 0,
      cardExtent = 320;
  Curve settleCurve = Curves.easeInOutCubic;
  final previewKeys = <String, GlobalKey<_InstantPreviewState>>{};
  GlobalKey<_InstantPreviewState> previewKey(String id) =>
      previewKeys.putIfAbsent(id, () => GlobalKey<_InstantPreviewState>());
  double get turnProgress => (dragY.abs() / cardExtent).clamp(0.0, 1.0);
  late final AnimationController flight =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(() {
        if (mounted)
          setState(() {
            final t = settleCurve.transform(flight.value);
            dragY = flyFrom + (flyTo - flyFrom) * t;
            dragX = flyFromX + (flyToX - flyFromX) * t;
          });
      });
  @override
  void initState() {
    super.initState();
    flight;
  }

  Future<void> finishDrag(double velocity, {bool cancel = false}) async {
    if (busy || animating || bytes == null) return;
    final advance =
        !cancel &&
        (dragY.abs() > cardExtent * .18 ||
            dragX.abs() > cardExtent * .16 ||
            velocity.abs() > 450);
    flight.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(
            milliseconds: advance ? (velocity.abs() > 1200 ? 270 : 360) : 380,
          );
    settleCurve = advance ? Curves.easeInOutCubic : Curves.easeOutBack;
    flyFromX = dragX;
    flyToX = advance
        ? (dragX == 0 ? cardExtent * .16 : dragX.sign * cardExtent * .25)
        : 0;
    flyFrom = dragY;
    flyTo = advance
        ? (dragY < 0 || velocity < -450 || dragY.abs() < 10 ? -1 : 1) *
              (cardExtent * 1.35 + 50)
        : 0;
    animating = true;
    try {
      await flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    animating = false;
    if (advance) {
      next();
    } else {
      setState(() {
        dragY = 0;
        dragX = 0;
      });
    }
  }

  int index = 0;
  double dragY = 0;
  bool captureBlocked = false, secureReady = false;
  Uint8List? bytes;
  String error = '', reaction = '', replyKey = newId();
  bool loaded = false, busy = false, hidden = false;
  final reply = TextEditingController();
  J get item => widget.items[index];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      loaded = true;
      WidgetsBinding.instance.addObserver(this);
      load();
    }
  }

  void clear() {
    if (bytes != null) {
      MemoryImage(bytes!).evict();
      bytes!.fillRange(0, bytes!.length, 0);
      bytes = null;
    }
  }

  Future<void> load() async {
    try {
      try {
        const channel = MethodChannel('GPIX/privacy');
        channel.setMethodCallHandler((call) async {
          if (call.method == 'captured' && mounted) {
            clear();
            setState(() {
              captureBlocked = true;
              secureReady = false;
            });
          }
        });
        final allowed = await channel.invokeMethod('secure', true);
        if (allowed == false ||
            (defaultTargetPlatform == TargetPlatform.iOS && allowed != true)) {
          if (mounted)
            setState(() {
              captureBlocked = true;
              secureReady = false;
            });
          return;
        }
      } catch (_) {
        if (mounted)
          setState(() {
            captureBlocked = true;
            secureReady = false;
          });
        return;
      }
      if (!mounted || hidden || captureBlocked) return;
      if (!secureReady) setState(() => secureReady = true);
      final value = await GpixScope.of(
        context,
        listen: false,
      ).instantBytes(item.str('id'), archive: widget.archive);
      if (!mounted || hidden || captureBlocked) {
        value.fillRange(0, value.length, 0);
        return;
      }
      setState(() {
        bytes = value;
        error = '';
      });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Questa istantanea non è più disponibile.');
    }
  }

  void close() {
    if (hidden) return;
    hidden = true;
    clear();
    if (mounted && ModalRoute.of(context)?.isCurrent == true)
      Navigator.pop(context);
  }

  void next() {
    if (busy || animating || (bytes == null && error.isEmpty)) return;
    if (index + 1 >= widget.items.length) {
      if (widget.archive) {
        close();
        return;
      }
      clear();
      hidden = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const InstantComposer(autoCapture: true),
        ),
      );
      return;
    }
    clear();
    setState(() {
      index++;
      dragY = 0;
      dragX = 0;
      error = '';
      reaction = '';
      reply.clear();
      replyKey = newId();
    });
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) close();
  }

  @override
  void dispose() {
    flight.dispose();
    clear();
    reply.dispose();
    WidgetsBinding.instance.removeObserver(this);
    const channel = MethodChannel('GPIX/privacy');
    channel.setMethodCallHandler(null);
    channel.invokeMethod('secure', false).catchError((_) {});
    super.dispose();
  }

  Future<void> feedback(String kind, String text) async {
    if (busy || text.trim().isEmpty) return;
    setState(() => busy = true);
    await perform(context, () async {
      await GpixScope.of(context, listen: false).instantFeedback(
        item.str('id'),
        kind,
        text,
        kind == 'reaction' ? 'reaction-$text' : replyKey,
      );
      if (mounted) {
        setState(() {
          if (kind == 'reaction') {
            reaction = text;
          } else {
            reply.clear();
            replyKey = newId();
          }
        });
        notice(
          context,
          kind == 'reaction' ? 'Reazione inviata' : 'Risposta inviata',
        );
      }
    });
    if (mounted) setState(() => busy = false);
  }

  void photoReply(BuildContext c) {
    final row = Map<String, dynamic>.from(item);
    final nav = Navigator.of(c);
    close();
    nav.push(
      MaterialPageRoute(
        builder: (_) => InstantComposer(autoCapture: true, replyTo: row),
      ),
    );
  }

  Widget reactionButton(String emoji) => SizedBox(
    width: 44,
    height: 44,
    child: Material(
      color: reaction == emoji ? violet : Colors.white12,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy || reaction == emoji
            ? null
            : () => feedback('reaction', emoji),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 23))),
      ),
    ),
  );
  Widget protectedPhoto() => defaultTargetPlatform == TargetPlatform.iOS
      ? UiKitView(
          key: ValueKey('secure-${item.str('id')}'),
          viewType: 'GPIX/secure-photo',
          creationParams: {'bytes': bytes!},
          creationParamsCodec: const StandardMessageCodec(),
        )
      : Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: false);
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        tooltip: 'Chiudi istantanea',
        onPressed: close,
        icon: const GIcon(CupertinoIcons.xmark),
      ),
      actions: [
        IconButton(
          tooltip: 'Le tue istantanee',
          onPressed: () {
            if (widget.archive) {
              close();
              return;
            }
            clear();
            hidden = true;
            Navigator.pushReplacement(
              c,
              MaterialPageRoute(builder: (_) => const InstantArchive()),
            );
          },
          icon: const GIcon(CupertinoIcons.square_grid_2x2),
        ),
        if (!widget.archive)
          IconButton(
            tooltip: 'Crea un’istantanea',
            onPressed: () {
              final nav = Navigator.of(c);
              close();
              nav.push(
                MaterialPageRoute(
                  builder: (_) => const InstantComposer(autoCapture: true),
                ),
              );
            },
            icon: const GIcon(CupertinoIcons.camera),
          ),
        if (widget.archive)
          IconButton(
            tooltip: 'Elimina istantanea',
            icon: const GIcon(CupertinoIcons.trash),
            onPressed: () => perform(c, () async {
              if (await gpixAlert(
                c,
                'Eliminare l’istantanea?',
                'Sarà rimossa dall’archivio e ritirata a chi non l’ha aperta.',
                confirm: 'Elimina',
                cancel: true,
                destructive: true,
              )) {
                if (!c.mounted) return;
                await GpixScope.of(
                  c,
                  listen: false,
                ).deleteInstant(item.str('id'));
                close();
              }
            }),
          ),
      ],
    ),
    body: SafeArea(
      child: captureBlocked
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GIcon(
                      CupertinoIcons.lock_shield,
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Contenuto protetto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Interrompi la cattura dello schermo e riapri le istantanee.',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height:
                      (MediaQuery.sizeOf(c).height -
                              MediaQuery.viewInsetsOf(c).bottom -
                              390)
                          .clamp(60.0, MediaQuery.sizeOf(c).width) +
                      20,
                  child: LayoutBuilder(
                    builder: (c, box) {
                      final side = (box.maxWidth - 36)
                          .clamp(
                            0.0,
                            (box.maxHeight - 30).clamp(0.0, double.infinity),
                          )
                          .toDouble();
                      cardExtent = side > 0 ? side : 320;
                      return Center(
                        child: SizedBox(
                          width: side,
                          height: side + 20,
                          child: GestureDetector(
                            key: const ValueKey('instant-deck'),
                            onTap: bytes == null || busy || animating
                                ? null
                                : () => finishDrag(-650),
                            onPanUpdate: busy || animating || bytes == null
                                ? null
                                : (d) => setState(() {
                                    dragY = (dragY + d.delta.dy).clamp(
                                      -side,
                                      side,
                                    );
                                    dragX = (dragX + d.delta.dx * .5).clamp(
                                      -side * .5,
                                      side * .5,
                                    );
                                  }),
                            onPanEnd: (d) => finishDrag(
                              d.velocity.pixelsPerSecond.dy.abs() >
                                      d.velocity.pixelsPerSecond.dx.abs()
                                  ? d.velocity.pixelsPerSecond.dy
                                  : -d.velocity.pixelsPerSecond.dx.abs(),
                            ),
                            onPanCancel: () {
                              if (dragY.abs() + dragX.abs() > .1)
                                finishDrag(0, cancel: true);
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                if (secureReady)
                                  for (var n = 2; n >= 1; n--)
                                    if (index + n < widget.items.length)
                                      Positioned(
                                        top:
                                            (12 - n * 6) +
                                            (16 - (12 - n * 6)) * turnProgress,
                                        left: n * 9.0 * (1 - turnProgress),
                                        right: n * 9.0 * (1 - turnProgress),
                                        bottom:
                                            (16 + n * 5.0) +
                                            (4 - (16 + n * 5.0)) * turnProgress,
                                        child: Transform.rotate(
                                          key: ValueKey('instant-next-$n'),
                                          angle:
                                              (n.isEven ? -.045 : .045) *
                                              (1 - turnProgress),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              38,
                                            ),
                                            child: ColoredBox(
                                              color: Color(
                                                n == 1
                                                    ? 0xff41434b
                                                    : 0xff737580,
                                              ),
                                              child: InstantPreview(
                                                key: previewKey(
                                                  widget.items[index + n].str(
                                                    'id',
                                                  ),
                                                ),
                                                id: widget.items[index + n].str(
                                                  'id',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                Transform.translate(
                                  key: const ValueKey('instant-front-motion'),
                                  offset: Offset(dragX, dragY * .85),
                                  child: Transform(
                                    alignment: Alignment.bottomCenter,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .0008)
                                      ..rotateX(-dragY / cardExtent * .10)
                                      ..rotateZ(
                                        (dragX / cardExtent * .35 +
                                                dragY / cardExtent * .24)
                                            .clamp(-.45, .45),
                                      ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 16,
                                        bottom: 4,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(38),
                                        child: ColoredBox(
                                          color: const Color(0xff17171c),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (bytes != null && !hidden)
                                                protectedPhoto()
                                              else if (error.isEmpty)
                                                Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (secureReady)
                                                      InstantPreview(
                                                        key: previewKey(
                                                          item.str('id'),
                                                        ),
                                                        id: item.str('id'),
                                                      ),
                                                    const Center(
                                                      child: SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: Colors
                                                                  .white70,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              else
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          25,
                                                        ),
                                                    child: Text(
                                                      error,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (item
                                                  .str('caption')
                                                  .isNotEmpty)
                                                Positioned(
                                                  left: 20,
                                                  right: 20,
                                                  bottom: 20,
                                                  child: Text(
                                                    item.str('caption'),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 19,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black,
                                                          blurRadius: 12,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Avatar(item.str('owner'), size: 23),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${widget.archive ? 'Tu' : item.str('username')} · ${relative(item['created'])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        tooltip: 'Prossima istantanea',
                        onPressed: busy ? null : next,
                        icon: const GIcon(
                          CupertinoIcons.chevron_down,
                          size: 17,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.archive && bytes != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: 180,
                      height: 112,
                      child: Stack(
                        children: [
                          for (final spot in [
                            ('😂', 0.0, 20.0),
                            ('❤️', 60.0, 0.0),
                            ('😍', 30.0, 65.0),
                            ('🔥', 90.0, 65.0),
                          ])
                            Positioned(
                              left: spot.$2,
                              top: spot.$3,
                              child: reactionButton(spot.$1),
                            ),
                          Positioned(
                            left: 120,
                            top: 20,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Material(
                                color: Colors.white12,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Altre reazioni',
                                  onPressed: busy
                                      ? null
                                      : () => sheet(
                                          c,
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 12,
                                            children: [
                                              for (final emoji in [
                                                '❤️',
                                                '😂',
                                                '😍',
                                                '🔥',
                                                '😢',
                                                '👏',
                                              ])
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(c);
                                                    feedback('reaction', emoji);
                                                  },
                                                  child: Text(
                                                    emoji,
                                                    style: const TextStyle(
                                                      fontSize: 28,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                  icon: const GIcon(
                                    CupertinoIcons.plus,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 8, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: reply,
                            maxLength: 1000,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Rispondi a ${item.str('username')}…',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(26),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (v) => feedback('reply', v),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Invia risposta',
                          onPressed: busy
                              ? null
                              : () => feedback('reply', reply.text),
                          icon: const GIcon(
                            CupertinoIcons.paperplane,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rispondi con un’istantanea',
                          onPressed: busy ? null : () => photoReply(c),
                          icon: const GIcon(
                            CupertinoIcons.camera,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.archive || bytes == null)
                  TextButton(
                    onPressed: next,
                    child: const Text(
                      'Prossima',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
    ),
  );
}

class InstantPreview extends StatefulWidget {
  final String id;
  const InstantPreview({super.key, required this.id});
  @override
  State<InstantPreview> createState() => _InstantPreviewState();
}

class _InstantPreviewState extends State<InstantPreview> {
  Future<Uint8List>? future;
  Uint8List? data;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= GpixScope.of(context, listen: false)
        .instantPreview(widget.id)
        .then((v) {
          if (!mounted) {
            v.fillRange(0, v.length, 0);
          } else {
            data = v;
          }
          return v;
        });
  }

  @override
  void dispose() {
    if (data != null) {
      MemoryImage(data!).evict();
      data!.fillRange(0, data!.length, 0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Uint8List>(
    future: future,
    builder: (c, s) => s.hasData
        ? Image.memory(
            s.data!,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          )
        : const ColoredBox(
            color: Color(0xff3e3e4f),
            child: Center(
              child: GIcon(CupertinoIcons.viewfinder, color: Colors.white54),
            ),
          ),
  );
}

class InstantArchive extends StatefulWidget {
  const InstantArchive({super.key});
  @override
  State<InstantArchive> createState() => _InstantArchiveState();
}

class _InstantArchiveState extends State<InstantArchive> {
  List<J>? rows;
  String error = '', key = newId(), recapMedia = '', cursor = '';
  final selected = <String>{};
  bool busy = false, loaded = false, selecting = false, activeOnly = false;
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
      final page = await GpixScope.of(
        context,
        listen: false,
      ).instantArchivePage();
      final value = page.rows('items');
      cursor = page.str('nextCursor');
      if (mounted)
        setState(() {
          rows = value;
          error = '';
          selected.removeWhere((id) => !value.any((x) => x.str('id') == id));
        });
    } catch (_) {
      if (mounted) setState(() => error = 'Archivio non disponibile.');
    }
  }

  Future<void> more() async {
    if (busy || cursor.isEmpty) return;
    setState(() => busy = true);
    await perform(context, () async {
      final page = await GpixScope.of(
        context,
        listen: false,
      ).instantArchivePage(cursor: cursor);
      if (mounted)
        setState(() {
          final existing = rows!.map((x) => x.str('id')).toSet();
          rows = [
            ...rows!,
            ...page.rows('items').where((x) => !existing.contains(x.str('id'))),
          ];
          cursor = page.str('nextCursor');
        });
    });
    if (mounted) setState(() => busy = false);
  }

  void select(String id) {
    if (busy) return;
    setState(() {
      if (!selected.remove(id)) {
        if (selected.length >= 9) {
          notice(context, 'Massimo 9 istantanee');
          return;
        }
        selected.add(id);
      }
      key = newId();
      recapMedia = '';
    });
  }

  Future<void> recap() async {
    if (busy || selected.isEmpty) return;
    if (!await gpixAlert(
          context,
          'Condividere il riepilogo nelle Storie?',
          'Le foto selezionate diventeranno un collage visibile al pubblico delle tue Storie per 24 ore.',
          confirm: 'Pubblica',
          cancel: true,
        ) ||
        !mounted)
      return;
    setState(() => busy = true);
    await perform(context, () async {
      final s = GpixScope.of(context, listen: false);
      recapMedia = recapMedia.isEmpty
          ? await s.instantRecap(selected.toList(), key)
          : recapMedia;
      await s.act('post', {
        'kind': 'story',
        'text': 'I miei istanti',
        'media': recapMedia,
        'idempotencyKey': 'recap-$key',
      });
      if (mounted) {
        setState(() {
          selected.clear();
          key = newId();
          recapMedia = '';
        });
        notice(context, 'Riepilogo pubblicato nelle Storie');
      }
    });
    if (mounted) setState(() => busy = false);
  }

  IconButton audienceControl(BuildContext c) => IconButton(
    tooltip: 'Destinatari delle istantanee attive',
    icon: const GIcon(CupertinoIcons.person_2),
    onPressed: busy
        ? null
        : () => sheet(
            c,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Aggiorna il pubblico di tutte le tue istantanee ancora valide per 24 ore. Le foto già aperte non tornano visibili.',
                  ),
                ),
                for (final audience in [
                  ('friends', 'Amici'),
                  ('close', 'Amici più stretti'),
                ])
                  ActionRow(CupertinoIcons.person_2, audience.$2, () async {
                    Navigator.pop(c);
                    if (!await gpixAlert(
                          c,
                          'Aggiornare i destinatari?',
                          'Tutte le tue istantanee non scadute saranno disponibili anche ai nuovi membri di questo pubblico.',
                          confirm: 'Conferma',
                          cancel: true,
                        ) ||
                        !c.mounted)
                      return;
                    await perform(c, () async {
                      final s = GpixScope.of(c, listen: false);
                      for (final row in (await s.instantList()).rows(
                        'active',
                      )) {
                        if (s.demo) {
                          s.state
                                  .rows('demoInstants')
                                  .firstWhere(
                                    (x) => x.str('id') == row.str('id'),
                                  )['audience'] =
                              audience.$1;
                        } else {
                          await s.api(
                            '/instants/${row.str('id')}/audience',
                            payload: {'audience': audience.$1},
                          );
                        }
                      }
                      notice(c, 'Destinatari aggiornati');
                    });
                  }),
              ],
            ),
          ),
  );
  void archiveOptions(BuildContext c) => sheet(
    c,
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionRow(CupertinoIcons.arrow_clockwise, 'Aggiorna archivio', () {
          Navigator.pop(c);
          refresh();
        }),
        ActionRow(
          CupertinoIcons.checkmark_circle,
          'Seleziona foto per un riepilogo',
          () {
            Navigator.pop(c);
            setState(() => selecting = true);
          },
        ),
        ActionRow(
          CupertinoIcons.person_2,
          'Destinatari delle istantanee attive',
          () {
            Navigator.pop(c);
            audienceControl(c).onPressed?.call();
          },
        ),
      ],
    ),
  );
  Future<void> openPhoto(List<J> items, int i) async {
    await open(context, InstantViewer(items: items.sublist(i), archive: true));
    if (mounted) refresh();
  }

  void photoOptions(BuildContext c, J row) => sheet(
    c,
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionRow(CupertinoIcons.eye, 'Visualizzazioni', () async {
          Navigator.pop(c);
          await open(c, InstantViews(id: row.str('id')));
          if (mounted) refresh();
        }),
        ActionRow(CupertinoIcons.square_grid_2x2, 'Aggiungi al riepilogo', () {
          Navigator.pop(c);
          setState(() => selecting = true);
          select(row.str('id'));
        }),
        ActionRow(CupertinoIcons.trash, 'Elimina istantanea', () async {
          Navigator.pop(c);
          if (!await gpixAlert(
                c,
                'Eliminare l’istantanea?',
                'La foto verrà rimossa dal tuo archivio e non sarà più disponibile ai destinatari.',
                confirm: 'Elimina',
                destructive: true,
                cancel: true,
              ) ||
              !c.mounted)
            return;
          await perform(
            c,
            () => GpixScope.of(c, listen: false).deleteInstant(row.str('id')),
          );
          if (mounted) refresh();
        }, destructive: true),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) {
    final visible = (rows ?? <J>[])
        .where((r) => !activeOnly || r.number('expires') > now)
        .toList();
    final groups = <String, List<J>>{};
    const months = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];
    for (final row in visible) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        (row.number('created') * 1000).round(),
      );
      final name = '${months[d.month - 1]} ${d.year}';
      groups.putIfAbsent(name, () => []).add(row);
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          selecting ? '${selected.length} selezionate' : 'Le tue istantanee',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Indietro',
          onPressed: () => selecting
              ? setState(() {
                  selecting = false;
                  selected.clear();
                })
              : Navigator.maybePop(c),
          icon: const GIcon(CupertinoIcons.chevron_left),
        ),
        actions: [
          if (selecting)
            TextButton(
              onPressed: () => setState(() {
                selecting = false;
                selected.clear();
              }),
              child: const Text('Fine'),
            )
          else
            IconButton(
              tooltip: 'Opzioni archivio',
              onPressed: busy ? null : () => archiveOptions(c),
              icon: const GIcon(CupertinoIcons.ellipsis, size: 24),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: subdued(c),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const GIcon(
                    CupertinoIcons.lock_shield,
                    color: violet,
                    size: 23,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Solo tu puoi vedere le tue foto qui.\nConservate nel tuo archivio fino a un anno.',
                      style: TextStyle(fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (rows?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  ChoiceChip(
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(fontSize: 12),
                    label: const Text('Tutte'),
                    selected: !activeOnly,
                    onSelected: (_) => setState(() => activeOnly = false),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                    labelStyle: const TextStyle(fontSize: 12),
                    label: const Text('Ultime 24 ore'),
                    selected: activeOnly,
                    onSelected: (_) => setState(() => activeOnly = true),
                  ),
                  const Spacer(),
                  if (!selecting)
                    TextButton(
                      onPressed: () => setState(() => selecting = true),
                      child: const Text(
                        'Seleziona',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: error.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error),
                        TextButton(
                          onPressed: refresh,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  )
                : rows == null
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              gradient: const LinearGradient(
                                colors: [Color(0xff9d68f5), Color(0xffed75aa)],
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.square_grid_2x2,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            activeOnly
                                ? 'Nessuna istantanea nelle ultime 24 ore'
                                : 'Ancora nessuna istantanea qui',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Quando scatti e condividi le tue istantanee, le ritrovi qui.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              height: 1.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: CustomScrollView(
                      slivers: [
                        for (final group in groups.entries) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                17,
                                17,
                                17,
                                13,
                              ),
                              child: Text(
                                group.key[0].toUpperCase() +
                                    group.key.substring(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 3,
                                  crossAxisSpacing: 3,
                                  childAspectRatio: 1,
                                ),
                            delegate: SliverChildBuilderDelegate((c, i) {
                              final row = group.value[i],
                                  id = row.str('id'),
                                  d = DateTime.fromMillisecondsSinceEpoch(
                                    (row.number('created') * 1000).round(),
                                  );
                              return GestureDetector(
                                onTap: busy
                                    ? null
                                    : () => selecting
                                          ? select(id)
                                          : openPhoto(
                                              visible,
                                              visible.indexOf(row),
                                            ),
                                onLongPress: busy
                                    ? null
                                    : () => photoOptions(c, row),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ArchiveThumbnail(
                                      key: ValueKey('archive-$id'),
                                      id: id,
                                    ),
                                    Positioned(
                                      top: 7,
                                      left: 7,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${d.day}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (selecting)
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Icon(
                                          selected.contains(id)
                                              ? CupertinoIcons
                                                    .checkmark_circle_fill
                                              : CupertinoIcons.circle,
                                          color: selected.contains(id)
                                              ? violet
                                              : Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Material(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(18),
                                        child: InkWell(
                                          onTap: () async {
                                            await open(c, InstantViews(id: id));
                                            if (mounted) refresh();
                                          },
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 5,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  CupertinoIcons.eye,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${row.number('viewsCount').toInt()}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }, childCount: group.value.length),
                          ),
                        ],
                        if (cursor.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: TextButton(
                                onPressed: busy ? null : more,
                                child: Text(
                                  busy ? 'Caricamento…' : 'Carica altre',
                                ),
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: violet,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: busy
                ? null
                : selecting
                ? (selected.isEmpty ? null : recap)
                : () async {
                    await open(c, const InstantComposer(autoCapture: true));
                    if (mounted) refresh();
                  },
            icon: GIcon(
              selecting ? CupertinoIcons.sparkles : CupertinoIcons.camera,
              size: 20,
            ),
            label: Text(
              busy
                  ? 'Attendi…'
                  : selecting
                  ? 'Crea riepilogo · ${selected.length}/9'
                  : 'Crea istantanea',
            ),
          ),
        ),
      ),
    );
  }
}

class InstantViews extends StatefulWidget {
  final String id;
  const InstantViews({super.key, required this.id});
  @override
  State<InstantViews> createState() => _InstantViewsState();
}

class _InstantViewsState extends State<InstantViews> {
  final items = <J>[];
  int? next = 0;
  int total = 0;
  bool busy = false, started = false;
  String error = '';
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      fetch();
    }
  }

  Future<void> fetch({bool reset = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final page = await GpixScope.of(
        context,
        listen: false,
      ).instantViewers(widget.id, offset: reset ? 0 : next ?? 0);
      if (!mounted) return;
      setState(() {
        if (reset) items.clear();
        items.addAll(page.rows('items'));
        total = page.number('total').toInt();
        next = page['nextOffset'] is num
            ? (page['nextOffset'] as num).toInt()
            : null;
        error = '';
      });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Impossibile caricare le visualizzazioni.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: pageTitle('Visualizzazioni'),
      actions: [
        IconButton(
          tooltip: 'Aggiorna visualizzazioni',
          onPressed: busy ? null : () => fetch(reset: true),
          icon: const GIcon(CupertinoIcons.arrow_clockwise),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '$total ${total == 1 ? 'visualizzazione' : 'visualizzazioni'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(error),
                TextButton(
                  onPressed: () => fetch(reset: items.isEmpty),
                  child: const Text('Riprova'),
                ),
              ],
            ),
          ),
        if (busy && items.isEmpty)
          const Center(child: CircularProgressIndicator()),
        Expanded(
          child: items.isEmpty && !busy && error.isEmpty
              ? const EmptyState(
                  CupertinoIcons.eye,
                  'Nessuna visualizzazione',
                  'Qui vedrai chi ha aperto questa istantanea.',
                )
              : ListView(
                  children: [
                    for (final v in items)
                      ListTile(
                        leading: v.str('avatar').isEmpty
                            ? CircleAvatar(
                                backgroundColor: subdued(c),
                                child: const GIcon(CupertinoIcons.person),
                              )
                            : ClipOval(
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: MediaView(v.str('avatar')),
                                ),
                              ),
                        title: Text(
                          v.str('name', v.str('username')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Visualizzata ${relative(v['opened'])}'),
                        onTap: v.str('user').isEmpty
                            ? null
                            : () => open(c, Profile(user: v.str('user'))),
                      ),
                    if (next != null && error.isEmpty)
                      TextButton(
                        onPressed: busy ? null : fetch,
                        child: Text(busy ? 'Caricamento…' : 'Carica altre'),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}

class ArchiveThumbnail extends StatefulWidget {
  final String id;
  const ArchiveThumbnail({super.key, required this.id});
  @override
  State<ArchiveThumbnail> createState() => _ArchiveThumbnailState();
}

class _ArchiveThumbnailState extends State<ArchiveThumbnail> {
  Future<Uint8List>? future;
  Uint8List? bytes;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= GpixScope.of(context, listen: false)
        .instantBytes(widget.id, archive: true)
        .then((value) {
          if (!mounted) {
            value.fillRange(0, value.length, 0);
            return Uint8List(0);
          }
          bytes = value;
          return value;
        });
  }

  @override
  void dispose() {
    if (bytes != null) {
      MemoryImage(bytes!).evict();
      bytes!.fillRange(0, bytes!.length, 0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => FutureBuilder<Uint8List>(
    future: future,
    builder: (c, s) => s.hasData && s.data!.isNotEmpty
        ? Image.memory(s.data!, fit: BoxFit.cover)
        : ColoredBox(
            color: subdued(c),
            child: Center(
              child: s.hasError
                  ? const GIcon(CupertinoIcons.exclamationmark_circle)
                  : const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ),
  );
}
