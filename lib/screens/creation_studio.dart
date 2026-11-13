import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/kit.dart';
import 'instants.dart';
import 'live.dart';
import 'post_composer.dart';
import 'stories.dart';

enum CreationMode {
  post('Post', CupertinoIcons.square_grid_2x2),
  story('Storia', CupertinoIcons.camera),
  reel('Reel', CupertinoIcons.play_rectangle),
  live('Diretta', CupertinoIcons.dot_radiowaves_left_right),
  instant('Istantanea', CupertinoIcons.photo_on_rectangle);

  const CreationMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CreationStudio extends StatefulWidget {
  const CreationStudio({super.key, required this.initial});

  final CreationMode initial;

  @override
  State<CreationStudio> createState() => _CreationStudioState();
}

class _CreationStudioState extends State<CreationStudio> {
  late CreationMode mode = widget.initial;
  late final visited = {widget.initial};
  bool publishingPost = false;
  bool hasInstantPhoto = false;

  void select(CreationMode next) {
    if (mode == next) return;
    FocusScope.of(context).unfocus();
    setState(() {
      mode = next;
      visited.add(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rail = _ModeRail(mode: mode, onSelected: select);
    final showRail =
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        switch (mode) {
          CreationMode.post => !publishingPost,
          CreationMode.reel => true,
          CreationMode.instant => !hasInstantPhoto,
          _ => false,
        };
    return Scaffold(
      backgroundColor: surface(context),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (visited.contains(CreationMode.post))
            _RetainedEditor(
              key: const ValueKey(CreationMode.post),
              active: mode == CreationMode.post,
              child: PostComposer(
                onPublishStepChanged: (value) {
                  setState(() => publishingPost = value);
                },
              ),
            ),
          if (visited.contains(CreationMode.reel))
            _RetainedEditor(
              key: const ValueKey(CreationMode.reel),
              active: mode == CreationMode.reel,
              child: const Composer(kind: 'reel'),
            ),
          if (mode == CreationMode.story)
            Composer(kind: 'story', modePicker: rail),
          if (mode == CreationMode.live) LiveSetup(modePicker: rail),
          if (mode == CreationMode.instant)
            InstantComposer(
              autoCapture: true,
              onPhotoChanged: (value) =>
                  setState(() => hasInstantPhoto = value),
            ),
        ],
      ),
      bottomNavigationBar: showRail
          ? SafeArea(
              top: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: rail,
              ),
            )
          : null,
    );
  }
}

class _RetainedEditor extends StatelessWidget {
  const _RetainedEditor({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !active,
    child: TickerMode(enabled: active, child: child),
  );
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.mode, required this.onSelected});

  final CreationMode mode;
  final ValueChanged<CreationMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = CreationMode.values;
    return SectionSwipe(
      animateDrag: true,
      onStep: (step) {
        final next = mode.index + step;
        if (next >= 0 && next < options.length) onSelected(options[next]);
      },
      child: SizedBox(
        height: 49,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final offset in [-1, 0, 1])
              Expanded(
                child: switch (mode.index + offset) {
                  final index when index >= 0 && index < options.length =>
                    Semantics(
                      selected: offset == 0,
                      child: InkWell(
                        onTap: () => onSelected(options[index]),
                        borderRadius: BorderRadius.circular(22),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                options[index].label,
                                style: TextStyle(
                                  color: offset == 0
                                      ? foreground(context)
                                      : secondaryText(context),
                                  fontSize: 13,
                                  fontWeight: offset == 0
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
          ],
        ),
      ),
    );
  }
}
