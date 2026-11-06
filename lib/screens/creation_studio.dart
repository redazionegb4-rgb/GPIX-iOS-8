import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../ui/kit.dart';
import 'features13.dart';
import 'instants.dart';
import 'live.dart';
import 'stories.dart';

class CreationStudio extends StatefulWidget {
  const CreationStudio({super.key});

  @override
  State<CreationStudio> createState() => _CreationStudioState();
}

class _CreationStudioState extends State<CreationStudio> {
  static const modes = ['Post', 'Storia', 'Istantanee', 'Reel', 'Diretta'];
  final modeScroll = PageController(viewportFraction: .29);
  final title = TextEditingController();
  int mode = 0;
  bool visitedReel = false, startingLive = false, editingCapture = false;

  @override
  void dispose() {
    modeScroll.dispose();
    title.dispose();
    super.dispose();
  }

  void select(int index) {
    if (startingLive || index < 0 || index >= modes.length || index == mode) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      mode = index;
      if (mode == 3) visitedReel = true;
    });
  }

  @override
  Widget build(BuildContext c) => Theme(
    data: gpixTheme(Brightness.dark),
    child: Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: mode != 0,
            child: TickerMode(
              enabled: mode == 0,
              child: const Composer(kind: 'post'),
            ),
          ),
          if (visitedReel)
            Offstage(
              offstage: mode != 3,
              child: TickerMode(
                enabled: mode == 3,
                child: const Composer(kind: 'reel'),
              ),
            ),
          if (mode == 1)
            Composer(
              kind: 'story',
              studio: true,
              onEditorOpened: () => setState(() => editingCapture = true),
            ),
          if (mode == 2)
            InstantComposer(
              autoCapture: true,
              onPhotoChanged: (value) => setState(() => editingCapture = value),
            ),
          if (mode == 4)
            Scaffold(
              appBar: AppBar(
                title: const Text('Nuova diretta'),
                leading: IconButton(
                  tooltip: 'Chiudi',
                  onPressed: startingLive ? null : () => Navigator.pop(c),
                  icon: const GIcon(CupertinoIcons.xmark),
                ),
              ),
              body: SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 20),
                    const GIcon(
                      CupertinoIcons.dot_radiowaves_left_right,
                      size: 46,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Preparati alla diretta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppInput(title, 'Titolo della diretta'),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      'Avvia diretta',
                      busy: startingLive,
                      onTap: () async {
                        setState(() => startingLive = true);
                        try {
                          await createLive(c, initialTitle: title.text.trim());
                        } finally {
                          if (mounted) setState(() => startingLive = false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Offstage(
        offstage: editingCapture,
        child: Builder(
          builder: (c) => ColoredBox(
            color: const Color(0xff151519),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: (_) {
                          select(modeScroll.page?.round() ?? mode);
                          return false;
                        },
                        child: PageView.builder(
                          controller: modeScroll,
                          scrollDirection: Axis.horizontal,
                          physics: startingLive
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          itemCount: modes.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4,
                            ),
                            child: Semantics(
                              selected: mode == i,
                              child: TextButton(
                                onPressed: startingLive
                                    ? null
                                    : () => modeScroll.animateToPage(
                                        i,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        curve: Curves.easeOut,
                                      ),
                                style: TextButton.styleFrom(
                                  foregroundColor: mode == i
                                      ? Colors.white
                                      : Colors.white60,
                                  backgroundColor: mode == i
                                      ? Colors.white12
                                      : null,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  modes[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: mode == i
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bozze',
                      onPressed: startingLive
                          ? null
                          : () => open(c, const DraftList()),
                      icon: const GIcon(CupertinoIcons.doc_text, size: 19),
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
