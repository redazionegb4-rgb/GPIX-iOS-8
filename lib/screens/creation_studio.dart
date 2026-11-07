import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../ui/kit.dart';
import 'features13.dart';
import 'instants.dart';
import 'live.dart';
import 'stories.dart';
import 'post_composer.dart';

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
  bool visitedReel = false,
      startingLive = false,
      editingCapture = false,
      publishingPost = false;

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
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: Theme.of(c).canvasColor,
    resizeToAvoidBottomInset: false,
    body: Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: mode != 0,
          child: TickerMode(
            enabled: mode == 0,
            child: PostComposer(
              onPublishStepChanged: (value) {
                setState(() => publishingPost = value);
              },
            ),
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
        if (mode == 4) const LiveSetup(),
      ],
    ),
    bottomNavigationBar: Offstage(
      offstage:
          editingCapture ||
          mode == 1 ||
          mode == 4 ||
          (mode == 0 && publishingPost),
      child: Builder(
        builder: (c) => ColoredBox(
          color: Theme.of(c).canvasColor,
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
                                    ? accent(c)
                                    : secondaryText(c),
                                backgroundColor: mode == i ? subdued(c) : null,
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
  );
}
