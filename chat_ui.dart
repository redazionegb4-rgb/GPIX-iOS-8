import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/kit.dart';

enum ChatColors {
  violet('Classico', Color(0xffa437ca), Color(0xff5940ed)),
  blue('Blu', Color(0xff315bd8), Color(0xff1972d9)),
  rose('Rosa', Color(0xffca366e), Color(0xffa42879)),
  mint('Verde', Color(0xff218363), Color(0xff166b81)),
  pulse('Pulse', Color(0xff252525), Color(0xff161616));

  const ChatColors(this.label, this.top, this.bottom);

  final String label;
  final Color top, bottom;

  static ChatColors fromName(String name) =>
      values.firstWhere((theme) => theme.name == name, orElse: () => violet);

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [top, bottom],
  );
}

enum ChatFont {
  standard('Classico', null, FontWeight.w400),
  rounded('Medio', null, FontWeight.w500),
  mono('Monospazio', 'monospace', FontWeight.w400);

  const ChatFont(this.label, this.family, this.weight);

  final String label;
  final String? family;
  final FontWeight weight;

  static ChatFont fromName(String name) =>
      values.firstWhere((font) => font.name == name, orElse: () => standard);
}

Color chatReplyColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff26272c)
    : const Color(0xffeff0f3);

Color chatComposerColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xff1d1e22)
    : const Color(0xfff4f4f5);

class ChatGlassButton extends StatelessWidget {
  const ChatGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 44,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (dark ? Colors.black : Colors.white).withValues(alpha: .43),
          border: Border.all(
            color: (dark ? Colors.white : Colors.black).withValues(alpha: .14),
            width: .65,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .21 : .07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: IconButton(
            tooltip: label,
            onPressed: onTap,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(),
            icon: GIcon(icon, size: size * .54, color: foreground(context)),
          ),
        ),
      ),
    );
  }
}

class ChatBlurHeader extends StatelessWidget {
  const ChatBlurHeader({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final canvas = surface(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 13, sigmaY: 13),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                canvas.withValues(alpha: .88),
                canvas.withValues(alpha: .79),
                canvas.withValues(alpha: .70),
              ],
              stops: const [0, .58, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.input,
    required this.focus,
    required this.colors,
    required this.sending,
    required this.recording,
    required this.seconds,
    required this.onChanged,
    required this.onSend,
    required this.onCamera,
    required this.onVoice,
    required this.onCancelVoice,
    required this.onGallery,
    required this.onSticker,
    required this.onMore,
  });

  final TextEditingController input;
  final FocusNode focus;
  final ChatColors colors;
  final bool sending, recording;
  final int seconds;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend, onCamera, onVoice, onCancelVoice;
  final VoidCallback onGallery, onSticker, onMore;

  @override
  Widget build(BuildContext context) {
    final hasText = input.text.trim().isNotEmpty;
    final iconSize = MediaQuery.sizeOf(context).width < 350 ? 34.0 : 39.0;
    final textColor = foreground(context);
    return Material(
      key: const ValueKey('chat-composer-pill'),
      color: chatComposerColor(context),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 3, 6, 3),
        child: recording
            ? Row(
                children: [
                  _ComposerButton(
                    label: 'Scarta vocale',
                    icon: CupertinoIcons.trash,
                    color: danger,
                    onTap: onCancelVoice,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Registrazione  ·  ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                  ),
                  _ComposerButton(
                    label: 'Invia vocale',
                    icon: CupertinoIcons.paperplane_fill,
                    color: colors.bottom,
                    onTap: onVoice,
                  ),
                ],
              )
            : Row(
                children: [
                  _ComposerButton(
                    label: 'Fotocamera chat',
                    icon: CupertinoIcons.camera_fill,
                    color: Colors.white,
                    fill: colors.bottom,
                    size: 35,
                    onTap: onCamera,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-message-input'),
                      controller: input,
                      focusNode: focus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      cursorColor: colors.bottom,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: onChanged,
                      style: TextStyle(fontSize: 15, color: textColor),
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Messaggio…',
                        counterText: '',
                        hintStyle: TextStyle(
                          color: secondaryText(context),
                          fontSize: 15,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (hasText)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.bottom,
                        minimumSize: const Size(49, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: sending ? null : onSend,
                      child: const Text(
                        'Invia',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else ...[
                    _ComposerButton(
                      label: 'Registra vocale',
                      icon: CupertinoIcons.mic,
                      size: iconSize,
                      onTap: onVoice,
                    ),
                    _ComposerButton(
                      label: 'Foto',
                      icon: CupertinoIcons.photo,
                      size: iconSize,
                      onTap: onGallery,
                    ),
                    _ComposerButton(
                      label: 'Sticker',
                      icon: CupertinoIcons.smiley,
                      size: iconSize,
                      onTap: onSticker,
                    ),
                    _ComposerButton(
                      label: 'Allegati',
                      icon: CupertinoIcons.plus_circle,
                      size: iconSize,
                      onTap: onMore,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ComposerButton extends StatelessWidget {
  const _ComposerButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fill,
    this.color,
    this.size = 39,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? fill, color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: 38,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      style: IconButton.styleFrom(
        foregroundColor: color ?? foreground(context),
        backgroundColor: fill,
        shape: const CircleBorder(),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
      ),
      icon: icon == CupertinoIcons.smiley
          ? const ChatStickerIcon(size: 23)
          : Icon(icon, size: fill == null ? 23 : 21),
    ),
  );
}

class ChatStickerIcon extends StatelessWidget {
  const ChatStickerIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StickerPainter(color ?? foreground(context)),
  );
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shape = Path()
      ..moveTo(20.8, 14)
      ..lineTo(15, 20.7)
      ..quadraticBezierTo(14.2, 21.4, 12.7, 21.4)
      ..lineTo(7, 21.4)
      ..quadraticBezierTo(2.2, 21.4, 2.2, 16.7)
      ..lineTo(2.2, 7.4)
      ..quadraticBezierTo(2.2, 2.6, 7, 2.6)
      ..lineTo(16.8, 2.6)
      ..quadraticBezierTo(21.6, 2.6, 21.6, 7.4)
      ..lineTo(21.6, 11.7)
      ..quadraticBezierTo(21.6, 13.1, 20.8, 14)
      ..moveTo(14.2, 20.9)
      ..lineTo(14.2, 18.3)
      ..quadraticBezierTo(14.2, 14, 18.2, 13.8)
      ..lineTo(20.8, 13.8)
      ..moveTo(7.1, 14)
      ..quadraticBezierTo(9.7, 17.7, 13.4, 15);
    canvas.drawPath(shape, outline);
    final eyes = Paint()..color = color;
    canvas.drawCircle(const Offset(7.6, 10), 1.15, eyes);
    canvas.drawCircle(const Offset(14.8, 10), 1.15, eyes);
  }

  @override
  bool shouldRepaint(_StickerPainter oldDelegate) => color != oldDelegate.color;
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.child,
    required this.colors,
    this.own = false,
    this.joinAbove = false,
    this.joinBelow = false,
    this.expired = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  final Widget child;
  final ChatColors colors;
  final bool own, joinAbove, joinBelow, expired;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const round = Radius.circular(20), join = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: !own && joinAbove ? join : round,
      topRight: own && joinAbove ? join : round,
      bottomLeft: !own && joinBelow ? join : round,
      bottomRight: own && joinBelow ? join : round,
    );
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: expired
            ? const Color(0xff53505b)
            : own
            ? null
            : chatReplyColor(context),
        gradient: own && !expired ? colors.gradient : null,
        borderRadius: radius,
      ),
      child: child,
    );
  }
}

class ChatSwipeRow extends StatefulWidget {
  const ChatSwipeRow({
    super.key,
    required this.child,
    required this.time,
    required this.timeOffset,
    required this.onTimeDrag,
    required this.onTimeRelease,
    required this.onReply,
    required this.replyIndicatorLeft,
  });

  static const double timeWidth = 58;
  final Widget child;
  final String time;
  final ValueListenable<double> timeOffset;
  final ValueChanged<double> onTimeDrag;
  final VoidCallback onTimeRelease;
  final VoidCallback? onReply;
  final double replyIndicatorLeft;

  @override
  State<ChatSwipeRow> createState() => _ChatSwipeRowState();
}

class _ChatSwipeRowState extends State<ChatSwipeRow> {
  static const double replyThreshold = 48;
  double distance = 0;
  int direction = 0;
  bool dragging = false, passedThreshold = false;

  void _update(DragUpdateDetails details) {
    distance += details.delta.dx;
    if (direction == 0 && distance.abs() >= 6) {
      direction = distance.sign.toInt();
    }
    if (direction < 0) {
      widget.onTimeDrag((-distance * .92).clamp(0.0, ChatSwipeRow.timeWidth));
    } else if (direction > 0 && widget.onReply != null) {
      final crossed = distance >= replyThreshold;
      if (crossed && !passedThreshold) HapticFeedback.selectionClick();
      passedThreshold = crossed;
      setState(() {});
    }
  }

  void _end({required bool completed}) {
    if (direction < 0) widget.onTimeRelease();
    final reply = completed && direction > 0 && passedThreshold;
    setState(() {
      distance = 0;
      direction = 0;
      dragging = false;
      passedThreshold = false;
    });
    if (reply) widget.onReply?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final shift = dragging && direction > 0 && widget.onReply != null
        ? (distance * .79).clamp(0.0, 66.0)
        : 0.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => setState(() => dragging = true),
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: (_) => _end(completed: true),
      onHorizontalDragCancel: () => _end(completed: false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: shift),
        duration: dragging || reducedMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: widget.child,
        builder: (context, replyShift, child) => ValueListenableBuilder<double>(
          valueListenable: widget.timeOffset,
          child: child,
          builder: (context, clockShift, child) => Stack(
            alignment: Alignment.center,
            children: [
              if (replyShift > 0)
                Positioned(
                  left: widget.replyIndicatorLeft,
                  child: Opacity(
                    opacity: (replyShift / 36).clamp(0.0, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: chatReplyColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: GIcon(
                          CupertinoIcons.reply,
                          size: 16,
                          color: foreground(context),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(replyShift - clockShift, 0),
                child: child,
              ),
              if (clockShift > 0)
                Positioned(
                  right: clockShift - ChatSwipeRow.timeWidth,
                  child: Opacity(
                    opacity: (clockShift / 45).clamp(0.0, 1.0),
                    child: SizedBox(
                      width: ChatSwipeRow.timeWidth,
                      child: Text(
                        widget.time,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryText(context),
                          fontSize: 10,
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

class ChatMenuAction {
  const ChatMenuAction(
    this.value,
    this.icon,
    this.label, {
    this.dangerous = false,
  });

  final String value, label;
  final IconData icon;
  final bool dangerous;
}

Future<String?> showChatMessageMenu(
  BuildContext context, {
  required Rect anchor,
  required bool own,
  required String time,
  required String selection,
  required ChatColors colors,
  required List<ChatMenuAction> actions,
  required List<ChatMenuAction> moreActions,
  required bool reactionsAvailable,
  required String currentReaction,
}) => showGeneralDialog<String>(
  context: context,
  barrierLabel: 'Chiudi menu messaggio',
  barrierDismissible: true,
  barrierColor: Colors.transparent,
  requestFocus: false,
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 190),
  pageBuilder: (context, animation, _) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeTop = math.max(6.0, MediaQuery.paddingOf(context).top);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 23, sigmaY: 23),
            child: ColoredBox(
              color: (dark ? const Color(0xff111215) : const Color(0xffefeff2))
                  .withValues(alpha: dark ? .50 : .72),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(10, 6, 10, 12),
          child: CustomSingleChildLayout(
            delegate: _ChatMenuPosition(
              anchor.top - safeTop,
              reactionsAvailable,
            ),
            child: FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
              child: ScaleTransition(
                alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                scale: animation.drive(
                  Tween(
                    begin: .95,
                    end: 1.0,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: _ChatMenu(
                  own: own,
                  time: time,
                  selection: selection,
                  colors: colors,
                  actions: actions,
                  moreActions: moreActions,
                  reactionsAvailable: reactionsAvailable,
                  currentReaction: currentReaction,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  },
);

class _ChatMenuPosition extends SingleChildLayoutDelegate {
  const _ChatMenuPosition(this.anchor, this.reactionsAvailable);

  final double anchor;
  final bool reactionsAvailable;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(420, constraints.maxWidth),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (size.width - childSize.width) / 2,
    (anchor - (reactionsAvailable ? 68 : 0)).clamp(
      0.0,
      math.max(0.0, size.height - childSize.height),
    ),
  );

  @override
  bool shouldRelayout(_ChatMenuPosition oldDelegate) =>
      anchor != oldDelegate.anchor ||
      reactionsAvailable != oldDelegate.reactionsAvailable;
}

class _ChatMenu extends StatefulWidget {
  const _ChatMenu({
    required this.own,
    required this.time,
    required this.selection,
    required this.colors,
    required this.actions,
    required this.moreActions,
    required this.reactionsAvailable,
    required this.currentReaction,
  });

  final bool own, reactionsAvailable;
  final String time, selection, currentReaction;
  final ChatColors colors;
  final List<ChatMenuAction> actions, moreActions;

  @override
  State<_ChatMenu> createState() => _ChatMenuState();
}

class _ChatMenuState extends State<_ChatMenu> {
  bool showMore = false;

  void _choose(String value) {
    if (value == 'more') {
      setState(() => showMore = !showMore);
    } else {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = foreground(context);
    final width = math.min(420.0, MediaQuery.sizeOf(context).width - 20);
    final panelWidth = math.min(254.0, width * .79);
    final side = widget.own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final alignment = widget.own ? Alignment.bottomRight : Alignment.bottomLeft;
    return PopScope(
      canPop: !showMore,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showMore) setState(() => showMore = false);
      },
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: side,
              children: [
                if (widget.reactionsAvailable) ...[
                  Material(
                    color: dark ? const Color(0xff28292f) : Colors.white,
                    elevation: 7,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(32),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          for (final emoji in const [
                            '❤️',
                            '😂',
                            '😮',
                            '😢',
                            '😡',
                            '👍',
                          ])
                            Expanded(
                              child: Semantics(
                                selected: emoji == widget.currentReaction,
                                button: true,
                                child: InkResponse(
                                  radius: 24,
                                  onTap: () => _choose('reaction:$emoji'),
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: emoji == widget.currentReaction
                                          ? chatReplyColor(context)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: IconButton(
                              onPressed: () => _choose('reaction-picker'),
                              tooltip: 'Altre reazioni',
                              icon: GIcon(
                                CupertinoIcons.plus,
                                size: 23,
                                color: secondaryText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(310, width * .85),
                  ),
                  child: ChatBubble(
                    colors: widget.colors,
                    own: widget.own,
                    child: Text(
                      widget.selection,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.own ? Colors.white : ink,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Stack(
                  alignment: alignment,
                  children: [
                    ExcludeSemantics(
                      excluding: showMore,
                      child: IgnorePointer(
                        ignoring: showMore,
                        child: SizedBox(
                          width: panelWidth,
                          child: _GlassMenuPanel(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  10,
                                  14,
                                  4,
                                ),
                                child: Text(
                                  widget.time,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: secondaryText(context),
                                  ),
                                ),
                              ),
                              for (final item in widget.actions)
                                _item(context, item),
                              if (widget.moreActions.isNotEmpty)
                                _item(
                                  context,
                                  const ChatMenuAction(
                                    'more',
                                    CupertinoIcons.ellipsis,
                                    'Altro',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (showMore)
                      SizedBox(
                        width: math.min(185, panelWidth),
                        child: _GlassMenuPanel(
                          children: [
                            InkWell(
                              onTap: () => _choose('more'),
                              child: const Padding(
                                padding: EdgeInsets.fromLTRB(14, 13, 14, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Altro',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    GIcon(
                                      CupertinoIcons.chevron_down,
                                      size: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            for (final item in widget.moreActions)
                              _item(context, item),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, ChatMenuAction item) {
    final color = item.dangerous ? danger : foreground(context);
    return InkWell(
      onTap: () => _choose(item.value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 8, 14, 8),
          child: Row(
            children: [
              item.value == 'sticker'
                  ? ChatStickerIcon(size: 22, color: color)
                  : GIcon(item.icon, color: color, size: 21),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(fontSize: 15, color: color),
                ),
              ),
              if (item.value == 'more')
                GIcon(CupertinoIcons.chevron_right, size: 13, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassMenuPanel extends StatelessWidget {
  const _GlassMenuPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = BorderRadius.circular(21);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .45 : .19),
            offset: const Offset(0, 12),
            blurRadius: 23,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: (dark ? const Color(0xff303037) : Colors.white).withValues(
              alpha: .68,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: border,
              side: BorderSide(
                color: Colors.white.withValues(alpha: .60),
                width: .65,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
