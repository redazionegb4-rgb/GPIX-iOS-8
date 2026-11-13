export 'icons.dart';
import 'icons.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import '../core/data.dart';
import '../core/store.dart';

const auraBlue = Color(0xff0866ff),
    ink = Color(0xff14151a),
    muted = Color(0xff62646e),
    soft = Color(0xfff1f2f5),
    line = Color(0xffe5e5e7),
    danger = Color(0xffe33958);

const auraAction = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [auraBlue, auraBlue],
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
    surface: canvas,
    onSurface: dark ? const Color(0xfffafafa) : ink,
    onSurfaceVariant: dark ? const Color(0xffbdbdbd) : muted,
    primary: dark ? const Color(0xff78abff) : auraBlue,
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
    borderRadius: BorderRadius.circular(12),
  );
  final field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: scheme,
    canvasColor: canvas,
    scaffoldBackgroundColor: canvas,
    splashFactory: InkRipple.splashFactory,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.5),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -.2),
      bodyMedium: TextStyle(height: 1.32),
    ),
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
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size.square(44),
      ),
    ),
    dividerColor: scheme.outlineVariant,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: auraBlue,
        foregroundColor: Colors.white,
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
        foregroundColor: scheme.onSurface,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
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
      iconColor: scheme.onSurface,
      minTileHeight: 52,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
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

final accountSheetProgress = ValueNotifier<double>(0);

class AccountSheetBackdrop extends StatelessWidget {
  const AccountSheetBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: accountSheetProgress,
    child: child,
    builder: (context, value, child) {
      return ColoredBox(
        color: Theme.of(context).canvasColor == Colors.black || value > 0
            ? Colors.black
            : Theme.of(context).canvasColor,
        child: Transform.translate(
          offset: Offset(0, 12 * value),
          child: Transform.scale(
            scale: 1 - .078 * value,
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24 * value),
              child: child,
            ),
          ),
        ),
      );
    },
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
      barrierColor: Colors.black54,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(c)
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 290),
              reverseDuration: Duration(milliseconds: 215),
            ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
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

Future<T?> anchoredMenu<T>(
  BuildContext context,
  List<PopupMenuEntry<T>> items, {
  required double width,
  required String label,
  bool alignRight = false,
}) async {
  final anchor = context.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (anchor is! RenderBox || overlay is! RenderBox || !anchor.hasSize) {
    return null;
  }
  final rect =
      anchor.localToGlobal(Offset.zero, ancestor: overlay) & anchor.size;
  final safe = MediaQuery.paddingOf(context);
  final minLeft = safe.left + 12;
  final maxRight = overlay.size.width - safe.right - 12;
  final menuWidth = width.clamp(0.0, (maxRight - minLeft).clamp(0.0, width));
  if (menuWidth == 0) return null;
  final left =
      (alignRight ? rect.right - menuWidth : rect.center.dx - menuWidth / 2)
          .clamp(minLeft, maxRight - menuWidth);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(
      left,
      rect.bottom + 6,
      overlay.size.width - left - menuWidth,
      0,
    ),
    items: items,
    semanticLabel: label,
    constraints: BoxConstraints.tightFor(width: menuWidth),
    color: dark ? const Color(0xff191a1c) : Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 10,
    shadowColor: Colors.black.withValues(alpha: dark ? .48 : .22),
    menuPadding: const EdgeInsets.all(5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(17),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    clipBehavior: Clip.antiAlias,
    popUpAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 215),
            reverseDuration: Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
  );
}

PopupMenuItem<T> dropdownRow<T>(
  BuildContext context,
  T value,
  String label,
  IconData icon, {
  bool selected = false,
  bool enabled = true,
}) {
  final color = !enabled
      ? secondaryText(context)
      : selected
      ? accent(context)
      : foreground(context);
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    padding: EdgeInsets.zero,
    height: 45,
    child: Container(
      constraints: const BoxConstraints(minHeight: 45),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? accent(context).withValues(alpha: .10) : null,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          GIcon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 7),
            GIcon(CupertinoIcons.check_mark, size: 15, color: color),
          ],
        ],
      ),
    ),
  );
}

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
    final radius = BorderRadius.circular(11);
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: secondary ? subdued(c) : accent(c),
          foregroundColor: secondary
              ? foreground(c)
              : Theme.of(c).colorScheme.onPrimary,
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
    );
  }
}

Future<void> openPhotoPreview(BuildContext context, String path) =>
    openPhotoGallery(context, [path]);

Future<void> openPhotoGallery(
  BuildContext context,
  List<String> photos, {
  int initial = 0,
}) async {
  if (photos.isEmpty) return;
  await open<void>(
    context,
    _PhotoGallery(photos: photos, initial: initial.clamp(0, photos.length - 1)),
  );
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photos, required this.initial});

  final List<String> photos;
  final int initial;

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final PageController pages = PageController(initialPage: widget.initial);
  late int selected = widget.initial;
  final transform = TransformationController();
  bool zoomed = false;

  @override
  void initState() {
    super.initState();
    transform.addListener(updateZoom);
  }

  void updateZoom() {
    final enlarged = transform.value.getMaxScaleOnAxis() > 1.01;
    if (enlarged != zoomed) setState(() => zoomed = enlarged);
  }

  @override
  void dispose() {
    transform.dispose();
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      centerTitle: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        tooltip: 'Chiudi anteprima',
        icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.photos.length == 1
            ? 'Anteprima foto'
            : '${selected + 1} / ${widget.photos.length}',
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    ),
    body: SafeArea(
      top: false,
      child: PageView.builder(
        controller: pages,
        physics: zoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.photos.length,
        onPageChanged: (index) {
          transform.value = Matrix4.identity();
          setState(() => selected = index);
        },
        itemBuilder: (context, index) {
          final image = Center(
            child: MediaView(widget.photos[index], fit: BoxFit.contain),
          );
          return index == selected
              ? InteractiveViewer(
                  transformationController: transform,
                  panEnabled: zoomed,
                  maxScale: 4,
                  child: image,
                )
              : image;
        },
      ),
    ),
  );
}

class MediaView extends StatelessWidget {
  final String reference;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width, height, placeholderHeight;
  const MediaView(
    this.reference, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.placeholderHeight,
    this.thumbnail = false,
    this.fallback,
  });
  final bool thumbnail;
  final Widget? fallback;

  @override
  Widget build(BuildContext c) {
    final s = GpixScope.of(c, listen: false);
    final path = s.url(reference);
    Widget placeholder() => SizedBox(
      width: width,
      height: placeholderHeight ?? height,
      child: ColoredBox(
        color: subdued(c),
        child: Center(
          child:
              fallback ??
              GIcon(CupertinoIcons.photo, color: secondaryText(c), size: 24),
        ),
      ),
    );
    final cacheWidth = thumbnail && width != null
        ? (width! * MediaQuery.devicePixelRatioOf(c)).ceil()
        : null;
    if (path.isEmpty)
      return SizedBox(width: width, height: height, child: placeholder());
    if (path.startsWith('https://'))
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        errorBuilder: (_, e, st) => placeholder(),
        loadingBuilder: (c, child, p) => p == null ? child : placeholder(),
      );
    if (path.startsWith('/'))
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        cacheWidth: cacheWidth,
        errorBuilder: (_, e, st) => placeholder(),
      );
    return Image.asset(
      'assets/media/$path',
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
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
    final profile = s.user(user);
    final username = profile.str('username').trim();
    final initial =
        username.isEmpty || profile.str('name') == 'Account non disponibile'
        ? ''
        : username.characters.first.toUpperCase();
    final imageView = MediaView(
      image ?? profile.str('avatar'),
      alignment: const Alignment(0, -.7),
      fallback: initial.isEmpty
          ? GIcon(
              CupertinoIcons.person_fill,
              size: size * .44,
              color: secondaryText(c),
            )
          : Text(
              initial,
              style: TextStyle(
                fontSize: size * .36,
                fontWeight: FontWeight.w700,
                color: secondaryText(c),
              ),
            ),
    );
    final picture = roundedSquare
        ? ClipRRect(borderRadius: BorderRadius.circular(14), child: imageView)
        : ClipOval(child: imageView);
    const ringWidth = 2.3, ringGap = 2.8;
    final diameter = size + (ring ? 2 * (ringWidth + ringGap) : 0);
    final closeStory = ring && s.closeStory(user);
    final shape = roundedSquare ? BoxShape.rectangle : BoxShape.circle;
    final framed = ring
        ? Container(
            padding: const EdgeInsets.all(ringWidth),
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: roundedSquare ? BorderRadius.circular(19) : null,
              gradient: roundedSquare || viewed || closeStory
                  ? null
                  : const SweepGradient(
                      colors: [
                        Color(0xffffa500),
                        Color(0xfff84b18),
                        Color(0xffe5008f),
                        Color(0xffa621cc),
                        Color(0xffffa500),
                      ],
                    ),
              color: closeStory
                  ? const Color(0xff25bd61)
                  : viewed
                  ? foreground(c).withValues(alpha: .15)
                  : roundedSquare
                  ? auraBlue
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(ringGap),
              decoration: BoxDecoration(
                shape: shape,
                borderRadius: roundedSquare ? BorderRadius.circular(17) : null,
                color: Theme.of(c).canvasColor,
              ),
              child: picture,
            ),
          )
        : picture;
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: diameter, maxHeight: diameter),
        child: AspectRatio(aspectRatio: 1, child: framed),
      ),
    );
  }
}

class SavedAccountTile extends StatelessWidget {
  const SavedAccountTile({
    super.key,
    required this.account,
    required this.trailing,
    this.active = false,
    this.onTap,
  });

  final J account;
  final Widget trailing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext c) {
    final theme = Theme.of(c);
    final username = account.str('username');
    final name = account.str('name');
    final avatar = account.str('avatar');
    final label = name.isEmpty ? username : name;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(
        color: active
            ? accent(c).withValues(alpha: .35)
            : theme.colorScheme.outlineVariant,
      ),
    );
    return Material(
      color: active
          ? Color.alphaBlend(accent(c).withValues(alpha: .09), surface(c))
          : theme.colorScheme.surfaceContainerLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: avatar.isEmpty
            ? CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(label.characters.take(1).toString().toUpperCase()),
              )
            : Avatar(account.str('id'), image: avatar, size: 48),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          active ? '@$username · Account attivo' : '@$username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
        trailing: trailing,
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
      : PageRouteBuilder<T>(
          pageBuilder: (_, _, _) => AuraBackdrop(child: page),
          transitionDuration: MediaQuery.disableAnimationsOf(c)
              ? Duration.zero
              : const Duration(milliseconds: 265),
          reverseTransitionDuration: MediaQuery.disableAnimationsOf(c)
              ? Duration.zero
              : const Duration(milliseconds: 205),
          transitionsBuilder: (_, animation, _, child) {
            final eased = animation.drive(
              CurveTween(curve: Curves.easeOutCubic),
            );
            return SlideTransition(
              position: eased.drive(
                Tween(begin: const Offset(.075, 0), end: Offset.zero),
              ),
              child: FadeTransition(
                opacity: eased.drive(Tween(begin: .55, end: 1.0)),
                child: child,
              ),
            );
          },
        ),
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

/// Adds horizontal navigation to sections with a vertically scrolling body.
class SectionSwipe extends StatefulWidget {
  const SectionSwipe({
    super.key,
    required this.onStep,
    required this.child,
    this.enabled = true,
    this.onDrag,
    this.section,
    this.animateDrag = false,
  });

  final bool enabled;
  final ValueChanged<double>? onDrag;

  /// When supplied, slides the content towards the new section after selection.
  final int? section;

  /// Also follow the drag when the action does not change sections.
  final bool animateDrag;

  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<SectionSwipe> createState() => _SectionSwipeState();
}

class _SectionSwipeState extends State<SectionSwipe>
    with SingleTickerProviderStateMixin {
  double _distance = 0;
  bool _dragging = false;
  AnimationController? _offset;

  AnimationController get _motion =>
      _offset ??= AnimationController.unbounded(vsync: this);

  bool get _animate =>
      (widget.section != null || widget.animateDrag) &&
      !MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(SectionSwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.section;
    final next = widget.section;
    if (widget.enabled &&
        previous != null &&
        next != null &&
        previous != next &&
        _animate) {
      final motion = _motion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.enabled ||
            widget.section != next ||
            !_animate ||
            _dragging)
          return;
        motion.value = next > previous ? 46 : -46;
        _settle(const Duration(milliseconds: 255));
      });
    }
  }

  void _settle([Duration duration = const Duration(milliseconds: 170)]) {
    if (_animate) {
      _motion.animateTo(0, duration: duration, curve: Curves.easeOutCubic);
    }
    widget.onDrag?.call(0);
  }

  @override
  void dispose() {
    _offset?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        _distance = 0;
        _dragging = true;
        _offset?.stop();
      },
      onHorizontalDragUpdate: (details) {
        _distance += details.primaryDelta ?? 0;
        if (_animate) _motion.value = (_distance * .25).clamp(-32.0, 32.0);
        widget.onDrag?.call(_distance);
      },
      onHorizontalDragCancel: () {
        _dragging = false;
        _settle();
      },
      onHorizontalDragEnd: (details) {
        _dragging = false;
        final velocity = details.primaryVelocity ?? 0;
        final movement = _distance.abs() >= 42
            ? _distance
            : velocity.abs() >= 480
            ? velocity
            : 0;
        _settle();
        if (movement != 0) widget.onStep(movement < 0 ? 1 : -1);
      },
      child: _animate
          ? AnimatedBuilder(
              animation: _motion,
              child: widget.child,
              builder: (context, child) => Transform.translate(
                offset: Offset(_motion.value, 0),
                child: child,
              ),
            )
          : widget.child,
    );
  }
}
