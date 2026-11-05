import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../ui/kit.dart';

class PhotoSend extends StatefulWidget {
  final String path;
  final String recipient;
  const PhotoSend({super.key, required this.path, required this.recipient});
  @override
  State<PhotoSend> createState() => _PhotoSendState();
}

class _PhotoSendState extends State<PhotoSend> {
  int mode = 0;
  static const labels = [
    'Conserva nella chat',
    'Visualizza una volta',
    'Consenti di riprodurre di nuovo',
  ];
  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Annulla foto',
                  onPressed: () => Navigator.pop(c),
                  icon: const GIcon(CupertinoIcons.xmark, color: Colors.white),
                ),
                const Spacer(),
                const Text(
                  'Invia foto',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MediaView(widget.path, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              mode == 0
                  ? 'La foto resta visibile nella conversazione.'
                  : mode == 1
                  ? 'Una sola apertura. Si chiude dopo 15 secondi.'
                  : 'Due aperture in totale per ogni destinatario.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 20),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const ValueKey('photo-mode'),
                    onPressed: () => setState(() => mode = (mode + 1) % 3),
                    icon: GIcon(
                      mode == 0
                          ? CupertinoIcons.checkmark_circle
                          : mode == 1
                          ? CupertinoIcons.circle
                          : CupertinoIcons.play_circle,
                      color: Colors.white,
                    ),
                    label: Text(
                      labels[mode],
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, mode),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Invia'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
