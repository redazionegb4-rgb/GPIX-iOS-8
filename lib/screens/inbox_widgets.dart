import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ui/kit.dart';

class DirectSearchField extends StatelessWidget {
  const DirectSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? const Color(0xff242529) : const Color(0xffeff0f3);
    final hintColor = secondaryText(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(26),
      borderSide: BorderSide.none,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        style: TextStyle(fontSize: 15, color: foreground(context)),
        decoration: InputDecoration(
          filled: true,
          fillColor: fill,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 15, color: hintColor),
          prefixIcon: Icon(CupertinoIcons.search, size: 19, color: hintColor),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 43,
            minHeight: 43,
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Svuota ricerca',
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 17,
                    color: hintColor,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 12,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class DirectThreadRow extends StatelessWidget {
  const DirectThreadRow({
    super.key,
    required this.portrait,
    required this.name,
    required this.preview,
    required this.onTap,
    this.onPortrait,
    this.onLongPress,
    this.trailing,
    this.time = '',
    this.unread = false,
    this.pinned = false,
    this.silenced = false,
    this.temporary = false,
  });

  final Widget portrait;
  final String name;
  final String time;
  final Widget preview;
  final VoidCallback onTap;
  final VoidCallback? onPortrait, onLongPress;
  final Widget? trailing;
  final bool unread, pinned, silenced, temporary;

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryText(context);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 15, 5),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 63,
                child: Center(
                  child: onPortrait == null
                      ? portrait
                      : InkResponse(
                          onTap: onPortrait,
                          radius: 33,
                          child: portrait,
                        ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground(context),
                              fontSize: 14,
                              height: 1.18,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (pinned) ...[
                          const SizedBox(width: 5),
                          Icon(
                            CupertinoIcons.pin_fill,
                            size: 11,
                            color: secondary,
                          ),
                        ],
                        if (silenced) ...[
                          const SizedBox(width: 5),
                          Icon(
                            CupertinoIcons.bell_slash,
                            size: 12,
                            color: secondary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: DefaultTextStyle(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.18,
                              color: unread ? foreground(context) : secondary,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            child: preview,
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            ' · $time',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.18,
                              color: secondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (unread) ...[
                const SizedBox(width: 12),
                Semantics(
                  label: temporary
                      ? 'Messaggio temporaneo non letto'
                      : 'Non letto',
                  child: temporary
                      ? CustomPaint(
                          size: const Size.square(17),
                          painter: _TemporaryUnreadDot(accent(context)),
                        )
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent(context),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemporaryUnreadDot extends CustomPainter {
  const _TemporaryUnreadDot(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..color = color;
    canvas.drawCircle(center, 3.1, paint);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * 6.6,
        .85,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TemporaryUnreadDot oldDelegate) =>
      color != oldDelegate.color;
}

String directSearchTerm(String value) => value
    .trim()
    .toLowerCase()
    .replaceFirst(RegExp(r'^@'), '')
    .replaceAll(RegExp('[àáâãäå]'), 'a')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[òóôõö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u');

String directTimeAgo(num value, {bool compact = false}) {
  if (value <= 0) return '';
  final minutes =
      (DateTime.now().millisecondsSinceEpoch / 1000 - value).toInt() ~/ 60;
  if (minutes < 1) return compact ? 'Ora' : 'ora';
  if (minutes < 60) return compact ? '$minutes min' : '$minutes min fa';
  final hours = minutes ~/ 60;
  if (hours < 24)
    return compact ? '$hours h' : (hours == 1 ? '1 ora fa' : '$hours ore fa');
  final days = hours ~/ 24;
  if (days < 7)
    return compact
        ? '$days g'
        : (days == 1 ? '1 giorno fa' : '$days giorni fa');
  final date = DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
  return '${date.day}/${date.month}/${date.year}';
}
