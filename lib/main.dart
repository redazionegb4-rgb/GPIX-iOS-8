import 'package:flutter/material.dart';
import 'core/store.dart';
import 'ui/kit.dart';
import 'ui/entrance.dart';
import 'screens/social.dart';
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
        theme: gpixTheme(Brightness.light),
        darkTheme: gpixTheme(Brightness.dark),
        builder: (c, child) => Stack(children: [child!, const IncomingCall()]),
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
                      ? const AccountSecurity(
                          key: ValueKey('verify'),
                          mode: 'verify',
                        )
                      : const HomeShell(key: ValueKey('home'))
                : const Welcome(key: ValueKey('welcome')),
          ),
        ),
      ),
    ),
  );
}
