import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../screens/creation_studio.dart';
import '../screens/social.dart' show Activity;
import '../screens/video.dart';
import '../ui/kit.dart';
import 'surfaces.dart';

class SocialShell extends StatefulWidget {
  const SocialShell({super.key});

  @override
  State<SocialShell> createState() => _SocialShellState();
}

class _SocialShellState extends State<SocialShell> {
  final _controller = PageController();
  final _feed = ScrollController();
  final _homeRefresh = GlobalKey<RefreshIndicatorState>();
  int _selected = 0;
  bool _compact = false;
  String? _reelCoverAccount;

  static const _labels = ['Home', 'Reel', 'Messaggi', 'Cerca', 'Profilo'];
  static const _icons = [
    CupertinoIcons.house,
    CupertinoIcons.play_rectangle,
    CupertinoIcons.paperplane,
    CupertinoIcons.search,
    CupertinoIcons.person_crop_circle,
  ];
  static const _selectedIcons = [
    CupertinoIcons.house_fill,
    CupertinoIcons.play_rectangle_fill,
    CupertinoIcons.paperplane_fill,
    CupertinoIcons.search,
    CupertinoIcons.person_crop_circle_fill,
  ];

  @override
  void dispose() {
    _controller.dispose();
    _feed.dispose();
    super.dispose();
  }

  void _openTab(int index) {
    if (!_controller.hasClients || index < 0 || index >= _labels.length) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (index == _selected && index == 0 && _feed.hasClients) {
      if (_feed.offset <= _feed.position.minScrollExtent + 1) {
        _homeRefresh.currentState?.show();
      } else if (reduced) {
        _feed.jumpTo(0);
      } else {
        _feed.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (reduced || (index - _selected).abs() > 1) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 270),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _swipeTab(int step) => _openTab(_selected + step);

  Widget _scrollAware(int index, Widget child) =>
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (_selected == index &&
              notification.metrics.axis == Axis.vertical &&
              (notification.scrollDelta ?? 0).abs() >= 1) {
            final compact =
                notification.metrics.pixels > 42 &&
                (notification.scrollDelta ?? 0) > 0;
            if (compact != _compact) setState(() => _compact = compact);
          }
          return false;
        },
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final store = GpixScope.of(context);
    final dark =
        Theme.of(context).brightness == Brightness.dark || _selected == 1;
    final ink = dark ? Colors.white : const Color(0xff14151a);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 210);
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final reel = _selected == 1;
    final compactDock = _compact;
    final profile = _selected == 4;
    final covered = reel && _reelCoverAccount == store.myId;
    final dockBottom = reel ? reelDockBottom(inset) : inset + 8;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AccountSheetBackdrop(
        child: Scaffold(
          body: Stack(
            children: [
              PageView(
                key: const ValueKey('gpix-destinations'),
                controller: _controller,
                physics: covered || _selected == 4
                    ? const NeverScrollableScrollPhysics()
                    : null,
                onPageChanged: (index) => setState(() {
                  _selected = index;
                  _compact = false;
                }),
                children: [
                  _KeepPage(
                    key: ValueKey(('home', store.myId)),
                    child: _scrollAware(
                      0,
                      HomeTimeline(
                        controller: _feed,
                        refreshKey: _homeRefresh,
                        active: _selected == 0,
                        onCreate: () => open(
                          context,
                          const CreationStudio(initial: CreationMode.story),
                        ),
                        onActivity: () => open(context, const Activity()),
                        onBoundarySwipe: _swipeTab,
                      ),
                    ),
                  ),
                  _KeepPage(
                    key: ValueKey(('reel', store.myId)),
                    child: Reels(
                      active: reel,
                      bottomOverlay: reelDockBottom(inset) + reelDockHeight,
                      onCoverDock: (cover) {
                        final account = cover ? store.myId : null;
                        if (_reelCoverAccount != account) {
                          setState(() => _reelCoverAccount = account);
                        }
                      },
                    ),
                  ),
                  _KeepPage(
                    key: ValueKey(('inbox', store.myId)),
                    child: _scrollAware(2, const DirectHome()),
                  ),
                  _KeepPage(
                    key: ValueKey(('discover', store.myId)),
                    child: _scrollAware(
                      3,
                      DiscoverHome(onBoundarySwipe: _swipeTab),
                    ),
                  ),
                  _KeepPage(
                    key: ValueKey(('profile', store.myId)),
                    child: _scrollAware(4, ProfileHome(user: store.myId)),
                  ),
                ],
              ),
              if (!covered && MediaQuery.viewInsetsOf(context).bottom == 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: dockBottom,
                  child: Center(
                    child: SectionSwipe(
                      animateDrag: true,
                      onStep: _swipeTab,
                      child: AnimatedContainer(
                        key: const ValueKey('floating-dock'),
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        width: reel
                            ? (MediaQuery.sizeOf(context).width * .755).clamp(
                                224.0,
                                355.0,
                              )
                            : profile
                            ? (MediaQuery.sizeOf(context).width *
                                      (compactDock ? .75 : .895))
                                  .clamp(224.0, 430.0)
                            : (MediaQuery.sizeOf(context).width -
                                      (compactDock ? 100 : 38))
                                  .clamp(224.0, 430.0),
                        height: reel
                            ? reelDockHeight
                            : profile
                            ? (compactDock ? 50 : 59)
                            : (compactDock ? 45 : 57),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                color: reel
                                    ? const Color(0xad202024)
                                    : dark
                                    ? const Color(0xc9232327)
                                    : const Color(0xe9ffffff),
                                border: Border.all(
                                  color: ink.withValues(
                                    alpha: reel ? .25 : .12,
                                  ),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _labels.length;
                                      index++
                                    )
                                      Expanded(
                                        child: Semantics(
                                          selected: _selected == index,
                                          button: true,
                                          child: Tooltip(
                                            message: _labels[index],
                                            child: InkWell(
                                              customBorder:
                                                  const StadiumBorder(),
                                              onTap: () => _openTab(index),
                                              child: AnimatedContainer(
                                                duration: duration,
                                                curve: Curves.easeOutCubic,
                                                margin: const EdgeInsets.all(4),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: ink.withValues(
                                                    alpha: _selected == index
                                                        ? (reel ? .16 : .09)
                                                        : 0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(40),
                                                ),
                                                child: AnimatedScale(
                                                  scale: _selected == index
                                                      ? 1.12
                                                      : 1,
                                                  duration: duration,
                                                  child: Badge(
                                                    backgroundColor:
                                                        const Color(0xffff0035),
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    offset: const Offset(2, 2),
                                                    isLabelVisible:
                                                        index == 2 &&
                                                        store.inboxThreads.any(
                                                          store.chatHasUnread,
                                                        ),
                                                    child: index == 4
                                                        ? Avatar(
                                                            store.myId,
                                                            size: 24,
                                                          )
                                                        : GIcon(
                                                            _selected == index
                                                                ? _selectedIcons[index]
                                                                : _icons[index],
                                                            color: ink,
                                                            size: 25,
                                                            dock: true,
                                                          ),
                                                  ),
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
  }
}

class _KeepPage extends StatefulWidget {
  const _KeepPage({super.key, required this.child});
  final Widget child;

  @override
  State<_KeepPage> createState() => _KeepPageState();
}

class _KeepPageState extends State<_KeepPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
