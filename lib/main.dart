import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'core/store.dart';
import 'ui/kit.dart';
import 'ui/entrance.dart';
import 'rebuild/shell.dart';
import 'screens/calls.dart';
import 'screens/auth.dart';
import 'screens/features13.dart';
import 'core/push_service.dart';
export 'screens/auth.dart' show Welcome;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = GpixStore();
  PushService.instance.attach(store);
  runApp(
    GpixLaunch(
      store: store,
      builder: (loading, error, retry) => GpixApp(
        store: store,
        initializing: loading,
        launchError: error,
        retryLaunch: retry,
      ),
    ),
  );
}

class GpixApp extends StatelessWidget {
  static final _lightTheme = gpixTheme(Brightness.light);
  static final _darkTheme = gpixTheme(Brightness.dark);

  final GpixStore store;
  final bool initializing;
  final String launchError;
  final VoidCallback? retryLaunch;
  const GpixApp({
    super.key,
    required this.store,
    this.initializing = false,
    this.launchError = '',
    this.retryLaunch,
  });
  @override
  Widget build(BuildContext context) => GpixScope(
    store: store,
    child: AnimatedBuilder(
      animation: store,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'GPIX',
        navigatorKey: gpixNavigator,
        themeMode: store.appearance == 'dark'
            ? ThemeMode.dark
            : store.appearance == 'light'
            ? ThemeMode.light
            : ThemeMode.system,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        scrollBehavior: const _GpixScrollBehavior(),
        builder: (c, child) {
          final app = AuraBackdrop(
            child: Stack(
              fit: StackFit.expand,
              children: [child!, const IncomingCall()],
            ),
          );
          if (defaultTargetPlatform != TargetPlatform.iOS) return app;
          final media = MediaQuery.of(c);
          // Use the Android reference's text proportions at phone widths.
          final referenceScale = (media.size.shortestSide / 340).clamp(
            1.0,
            1.2,
          );
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: referenceScale,
              ),
            ),
            child: app,
          );
        },
        home: AnimatedBuilder(
          animation: store,
          builder: (c, _) => AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(c)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: initializing
                ? LaunchScreen(
                    key: const ValueKey('launch'),
                    error: launchError,
                    retry: retryLaunch,
                  )
                : store.signedIn
                ? store.me['emailVerified'] == false
                      ? AccountSecurity(
                          key: ValueKey('verify-${store.myId}'),
                          mode: 'verify',
                        )
                      : const SocialShell(key: ValueKey('signed-in-home'))
                : const Welcome(key: ValueKey('welcome')),
          ),
        ),
      ),
    ),
  );
}

class _GpixScrollBehavior extends MaterialScrollBehavior {
  const _GpixScrollBehavior();

  @override
  TargetPlatform getPlatform(BuildContext context) => defaultTargetPlatform;
}
