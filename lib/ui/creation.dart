import 'package:flutter/material.dart';
import 'kit.dart';

/// Media overlays remain readable over both bright and dark photographs.
class MediaToolButton extends StatelessWidget {
  const MediaToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: const Color(0xcc111111),
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white54,
      disabledBackgroundColor: const Color(0xaa111111),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.all(11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: const BorderSide(color: Color(0x33ffffff)),
    ),
    icon: GIcon(
      icon,
      color: onPressed == null ? Colors.white54 : Colors.white,
      size: 22,
    ),
  );
}

class CreationEmpty extends StatelessWidget {
  const CreationEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.onPressed,
  });

  final IconData icon;
  final String title, description;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: LayoutBuilder(
      builder: (context, box) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: auraBlue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: GIcon(icon, size: 34, color: accent(context)),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground(context),
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText(context),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (action != null && onPressed != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
