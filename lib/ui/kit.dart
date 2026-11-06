export 'icons.dart';
import 'icons.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../core/data.dart';
import '../core/store.dart';

const auraBlue = Color(0xff2563eb),
    ink = Color(0xff101828),
    muted = Color(0xff767676),
    soft = Color(0xfff3f3f4),
    line = Color(0xffe5e5e7),
    danger = Color(0xffe33958);

const auraAction = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [auraBlue, Color(0xff1749b8)],
);

ThemeData gpixTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final fontFamily = defaultTargetPlatform == TargetPlatform.iOS
      ? null
      : 'Roboto';
  final canvas = dark ? Colors.black : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: auraBlue,
    brightness: brightness,
    surface: dark ? const Color(0xff161616) : Colors.white,
    onSurface: dark ? const Color(0xfffafafa) : ink,
    onSurfaceVariant: dark ? const Color(0xffbdbdbd) : muted,
    primary: dark ? const Color(0xffa9c7ff) : const Color(0xff1d54c5),
    onPrimary: dark ? ink : Colors.white,
    primaryContainer: dark ? const Color(0xff334c79) : const Color(0xffd5e7ff),
    onPrimaryContainer: dark
        ? const Color(0xffe6efff)
        : const Color(0xff113879),
    secondary: dark ? const Color(0xffa9c7ff) : auraBlue,
    tertiary: dark ? const Color(0xff8ed5ec) : const Color(0xff087b9b),
    onTertiary: dark ? ink : Colors.white,
    tertiaryContainer: dark ? const Color(0xff17475a) : const Color(0xffd5f1fa),
    onTertiaryContainer: dark
        ? const Color(0xffd5f1fa)
        : const Color(0xff0e4156),
    surfaceContainerLowest: canvas,
    surfaceContainerLow: dark
        ? const Color(0xff101010)
        : const Color(0xfffafafa),
    surfaceContainer: dark ? const Color(0xff161616) : const Color(0xfff7f7f7),
    surfaceContainerHigh: dark
        ? const Color(0xff1b1b1b)
        : const Color(0xfff5f5f5),
    surfaceContainerHighest: dark ? const Color(0xff212121) : soft,
    outlineVariant: dark ? const Color(0xff3b3b3b) : line,
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: scheme,
    canvasColor: canvas,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        color: scheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -.45,
      ),
    ),
    dividerColor: scheme.outlineVariant,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(48, 48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x22000000),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xffe6efff) : const Color(0xff203557),
      contentTextStyle: TextStyle(color: dark ? ink : Colors.white),
    ),
    listTileTheme: ListTileThemeData(
      shape: rounded,
      iconColor: scheme.onSurfaceVariant,
      selectedColor: scheme.primary,
      selectedTileColor: scheme.primaryContainer,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
  );
}

Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;
Color foreground(BuildContext c) => Theme.of(c).colorScheme.onSurface;
Color subdued(BuildContext c) =>
    Theme.of(c).colorScheme.surfaceContainerHighest;
Color accent(BuildContext c) => Theme.of(c).colorScheme.primary;
Color secondaryText(BuildContext c) => Theme.of(c).colorScheme.onSurfaceVariant;

InputDecoration mediaInputDecoration(BuildContext context, String hint) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: dark ? const Color(0xff626b7a) : const Color(0xffb0bac8),
    ),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: dark ? const Color(0xffc4cad4) : const Color(0xff465369),
    ),
    filled: true,
    fillColor: dark ? const Color(0xff222936) : const Color(0xfff5f7fb),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: accent(context), width: 1.5),
    ),
  );
}

class AuraBackdrop extends StatelessWidget {
  const AuraBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).canvasColor, child: child);
}

LinearGradient crystalGradient(BuildContext c, {bool translucent = false}) {
  final dark = Theme.of(c).brightness == Brightness.dark;
  final top = dark ? const Color(0xff333333) : Colors.white;
  final bottom = dark ? const Color(0xff181818) : const Color(0xffeeeeef);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: translucent
        ? [top.withValues(alpha: .86), bottom.withValues(alpha: .78)]
        : [top, bottom],
  );
}

BoxDecoration auraPanelDecoration(
  BuildContext context, {
  double radius = 22,
  bool translucent = false,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: crystalGradient(context, translucent: translucent),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark ? Theme.of(context).dividerColor : Colors.white,
    ),
    boxShadow: [
      BoxShadow(
        color: dark ? const Color(0x4d000000) : const Color(0x14000000),
        blurRadius: 15,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class AuraPanel extends StatelessWidget {
  const AuraPanel({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.radius = 22,
    this.frosted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final double radius;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final decoration = auraPanelDecoration(
      context,
      radius: radius,
      translucent: true,
    );
    final borderRadius = BorderRadius.circular(radius);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: decoration.border,
      ),
      position: DecorationPosition.foreground,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: decoration.gradient),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: decoration.boxShadow,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: frosted
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}

Future<void> perform(BuildContext c, Future<void> Function() work) async {
  try {
    await work();
  } catch (e) {
    if (c.mounted)
      await gpixAlert(
        c,
        'Operazione non riuscita',
        e.toString().replaceFirst('Exception: ', ''),
      );
  }
}

Future<bool> gpixAlert(
  BuildContext c,
  String title,
  String message, {
  String confirm = 'OK',
  bool destructive = false,
  bool cancel = false,
}) async =>
    await showDialog<bool>(
      context: c,
      builder: (context) => Dialog(
        backgroundColor: surface(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 27, 24, 23),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Row(
                children: [
                  if (cancel) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          foregroundColor: foreground(context),
                          backgroundColor: subdued(context),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Annulla',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        backgroundColor: destructive ? danger : auraBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        confirm,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ) ??
    false;
void notice(BuildContext c, String text) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Future<T?> sheet<T>(BuildContext c, Widget child, {bool scroll = true}) =>
    showModalBottomSheet<T>(
      context: c,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          decoration: BoxDecoration(
            gradient: crystalGradient(context),
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foreground(context).withValues(alpha: .24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: scroll ? SingleChildScrollView(child: child) : child,
                ),
              ],
            ),
          ),
        ),
      ),
    );

class ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final String? subtitle;
  const ActionRow(
    this.icon,
    this.label,
    this.onTap, {
    super.key,
    this.destructive = false,
    this.subtitle,
  });
  @override
  Widget build(BuildContext c) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 55),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Row(
          children: [
            GIcon(icon, size: 24, color: destructive ? danger : foreground(c)),
            const SizedBox(width: 17),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: destructive ? danger : foreground(c),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy, secondary;
  const PrimaryButton(
    this.label, {
    super.key,
    this.onTap,
    this.busy = false,
    this.secondary = false,
  });
  @override
  Widget build(BuildContext c) {
    final enabled = !busy && onTap != null;
    final radius = BorderRadius.circular(16);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: secondary || !enabled ? null : auraAction,
          borderRadius: radius,
          boxShadow: secondary || !enabled
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x442563eb),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: secondary ? subdued(c) : Colors.transparent,
            foregroundColor: secondary ? foreground(c) : Colors.white,
            disabledBackgroundColor: subdued(c),
            shape: RoundedRectangleBorder(borderRadius: radius),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: busy
              ? SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent(c),
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

Future<void> openPhotoPreview(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Anteprima foto'),
          leading: const CloseButton(),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 4,
            child: MediaView(path, fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

class MediaView extends StatelessWidget {
  final String reference;
  final BoxFit fit;
  final double? width, height, placeholderHeight;
  const MediaView(
    this.reference, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholderHeight,
  });
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c, listen: false);
    final path = s.url(reference);
    Widget placeholder() => SizedBox(
      height: placeholderHeight,
      child: ColoredBox(
        color: subdued(c),
        child: const Center(
          child: GIcon(CupertinoIcons.photo, color: muted, size: 24),
        ),
      ),
    );
    if (path.isEmpty)
      return SizedBox(width: width, height: height, child: placeholder());
    if (path.startsWith('https://'))
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, e, st) => placeholder(),
        loadingBuilder: (c, child, p) => p == null ? child : placeholder(),
      );
    if (path.startsWith('/'))
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, e, st) => placeholder(),
      );
    return Image.asset(
      'assets/media/$path',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, e, st) => placeholder(),
    );
  }
}

class Avatar extends StatelessWidget {
  final String user;
  final double size;
  final bool ring, viewed, roundedSquare;
  final String? image;
  const Avatar(
    this.user, {
    super.key,
    this.size = 42,
    this.ring = false,
    this.viewed = false,
    this.roundedSquare = false,
    this.image,
  });
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final imageView = SizedBox.square(
      dimension: size,
      child: MediaView(image ?? s.user(user).str('avatar')),
    );
    final picture = roundedSquare
        ? ClipRRect(borderRadius: BorderRadius.circular(14), child: imageView)
        : ClipOval(child: imageView);
    if (!ring) return picture;
    return Container(
      padding: const EdgeInsets.all(2.3),
      decoration: BoxDecoration(
        shape: roundedSquare ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: roundedSquare ? BorderRadius.circular(19) : null,
        gradient: roundedSquare || viewed || s.closeStory(user)
            ? null
            : const SweepGradient(
                colors: [
                  auraBlue,
                  Color(0xff3b82f6),
                  Color(0xff67e8f9),
                  Color(0xff7dd3fc),
                  auraBlue,
                ],
              ),
        color: s.closeStory(user)
            ? const Color(0xff25bd61)
            : viewed
            ? foreground(c).withValues(alpha: .15)
            : roundedSquare
            ? auraBlue
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2.8),
        decoration: BoxDecoration(
          shape: roundedSquare ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: roundedSquare ? BorderRadius.circular(17) : null,
          color: Theme.of(c).canvasColor,
        ),
        child: picture,
      ),
    );
  }
}

class PersonTile extends StatelessWidget {
  final String user;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const PersonTile(
    this.user, {
    super.key,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c);
    final u = s.user(user);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Avatar(user, size: 47),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.str('username'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? u.str('name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, detail;
  final Widget? action;
  const EmptyState(
    this.icon,
    this.title,
    this.detail, {
    super.key,
    this.action,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 42),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: auraPanelDecoration(c, radius: 40),
            child: GIcon(icon, size: 33, color: accent(c)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: muted, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

class AppInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final int lines;
  final TextInputType? keyboard;
  const AppInput(
    this.controller,
    this.hint, {
    super.key,
    this.obscure = false,
    this.lines = 1,
    this.keyboard,
  });
  @override
  Widget build(BuildContext c) => TextField(
    controller: controller,
    obscureText: obscure,
    maxLines: lines,
    keyboardType: keyboard,
    style: const TextStyle(fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
  );
}

Widget pageTitle(String title) => Text(
  title,
  style: const TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: -.45,
  ),
);
Future<T?> open<T>(BuildContext c, Widget page) => Navigator.of(c).push<T>(
  Theme.of(c).platform == TargetPlatform.iOS
      ? CupertinoPageRoute<T>(builder: (_) => AuraBackdrop(child: page))
      : MaterialPageRoute<T>(builder: (_) => AuraBackdrop(child: page)),
);

class BrandLogo extends StatelessWidget {
  final double width;
  const BrandLogo({super.key, this.width = 112});
  @override
  Widget build(BuildContext c) => Image.asset(
    Theme.of(c).brightness == Brightness.dark
        ? 'assets/brand/logo_dark.png'
        : 'assets/brand/logo_light.png',
    width: width,
    fit: BoxFit.contain,
    semanticLabel: 'GPIX',
  );
}
