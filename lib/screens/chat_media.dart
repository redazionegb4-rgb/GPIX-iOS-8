import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/data.dart';
import '../core/store.dart';
import '../ui/kit.dart';

class OncePhoto extends StatefulWidget {
  final String id;
  final Future<Uint8List> Function()? loader;
  final String? title;
  const OncePhoto({super.key, required this.id, this.loader, this.title});
  @override
  State<OncePhoto> createState() => _OncePhotoState();
}

class _OncePhotoState extends State<OncePhoto> with WidgetsBindingObserver {
  Uint8List? bytes;
  String error = '';
  Timer? timer;
  int left = 15;
  bool initialized = false, hidden = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      WidgetsBinding.instance.addObserver(this);
      load();
    }
  }

  Future<void> load() async {
    try {
      try {
        await const MethodChannel('GPIX/privacy').invokeMethod('secure', true);
      } catch (_) {}
      final data =
          await (widget.loader?.call() ??
              GpixScope.of(context, listen: false).openOnce(widget.id));
      if (!mounted || hidden) {
        data.fillRange(0, data.length, 0);
        return;
      }
      setState(() => bytes = data);
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (left <= 1) {
          close();
        } else {
          setState(() => left--);
        }
      });
    } catch (e) {
      if (mounted)
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void close() {
    if (hidden) return;
    timer?.cancel();
    if (mounted) {
      setState(() => hidden = true);
      Navigator.pop(context);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) close();
  }

  @override
  void dispose() {
    timer?.cancel();
    if (bytes != null) {
      MemoryImage(bytes!).evict();
      bytes!.fillRange(0, bytes!.length, 0);
    }
    WidgetsBinding.instance.removeObserver(this);
    const MethodChannel(
      'GPIX/privacy',
    ).invokeMethod('secure', false).catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        widget.title ??
            (GpixScope.of(c).message(widget.id).number('maxOpens', 1) == 2
                ? 'Foto con replay'
                : 'Visualizza una volta'),
        style: const TextStyle(fontSize: 16),
      ),
      leading: IconButton(
        tooltip: 'Chiudi foto',
        onPressed: close,
        icon: const GIcon(CupertinoIcons.xmark),
      ),
      actions: [
        if (bytes != null)
          Padding(
            padding: const EdgeInsets.all(17),
            child: Text(
              '${left}s',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
      ],
    ),
    body: Center(
      child: bytes != null && !hidden
          ? Image.memory(bytes!, fit: BoxFit.contain, gaplessPlayback: false)
          : error.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : const CircularProgressIndicator(color: Colors.white),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          GpixScope.of(c).message(widget.id).number('maxOpens', 1) == 2
              ? 'La foto si chiude dopo 15 secondi. Sono consentite due aperture totali.'
              : 'La foto si chiude dopo 15 secondi e non può essere riaperta.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ),
    ),
  );
}

class GifGallery extends StatelessWidget {
  final ValueChanged<String> onSelected;
  final VoidCallback onImport;
  const GifGallery({
    super.key,
    required this.onSelected,
    required this.onImport,
  });
  @override
  Widget build(BuildContext c) => Column(
    children: [
      const Text(
        'GIF',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: PrimaryButton(
          'Scegli un file GIF',
          secondary: true,
          onTap: onImport,
        ),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        itemCount: 6,
        itemBuilder: (c, i) => InkWell(
          onTap: () => onSelected('gif$i.gif'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: MediaView('gif$i.gif'),
          ),
        ),
      ),
    ],
  );
}

Future<void> messageInfo(BuildContext c, J message, J thread) => sheet(
  c,
  Builder(
    builder: (c) {
      final s = GpixScope.of(c);
      return Column(
        children: [
          const Text(
            'Informazioni sul messaggio',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 17),
          if (!s.readReceipts)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Le conferme di lettura sono disattivate.'),
            )
          else
            for (final id
                in thread
                    .ids('members')
                    .where((id) => id != message.str('author')))
              PersonTile(
                id,
                subtitle: message.ids('openedBy').contains(id)
                    ? 'Foto aperta'
                    : message.ids('readBy').contains(id)
                    ? 'Visualizzato${message.obj('readAt').number(id) > 0 ? ' · ${clock(message.obj('readAt')[id])}' : ''}'
                    : 'Non ancora visualizzato',
                trailing: GIcon(
                  message.ids('readBy').contains(id)
                      ? CupertinoIcons.checkmark_seal_fill
                      : CupertinoIcons.check_mark,
                  color: message.ids('readBy').contains(id) ? violet : muted,
                  size: 20,
                ),
              ),
          if (message.number('expires') > 0)
            Padding(
              padding: const EdgeInsets.all(17),
              child: Text(
                s.expired(message)
                    ? 'Messaggio scaduto'
                    : 'Scade alle ${clock(message['expires'])}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 17),
        ],
      );
    },
  ),
);
