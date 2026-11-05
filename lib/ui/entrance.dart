import 'package:flutter/material.dart';
import '../core/store.dart';
import 'kit.dart';

/// One finite entrance; stage changes restart it without duplicating forms.
class EntranceMotion extends StatefulWidget {
  final Widget child;
  final Object stage;
  const EntranceMotion({
    super.key,
    required this.child,
    this.stage = 'initial',
  });
  @override
  State<EntranceMotion> createState() => _EntranceMotionState();
}

class _EntranceMotionState extends State<EntranceMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> ease = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(EntranceMotion old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      if (MediaQuery.disableAnimationsOf(context)) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => FadeTransition(
    opacity: ease,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .035),
        end: Offset.zero,
      ).animate(ease),
      child: widget.child,
    ),
  );
}

class GpixLaunch extends StatefulWidget {
  final GpixStore store;
  final Widget Function(bool loading, String error, VoidCallback retry) builder;
  const GpixLaunch({super.key, required this.store, required this.builder});
  @override
  State<GpixLaunch> createState() => _GpixLaunchState();
}

class _GpixLaunchState extends State<GpixLaunch> {
  bool loading = true;
  String error = '';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = '';
      });
    try {
      await Future.wait([
        widget.store.init(),
        Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted)
        setState(() => error = 'Non è stato possibile aprire GPIX. Riprova.');
    }
  }

  @override
  Widget build(BuildContext c) => widget.builder(loading, error, load);
}

class LaunchScreen extends StatelessWidget {
  final String error;
  final VoidCallback? retry;
  const LaunchScreen({super.key, this.error = '', this.retry});
  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: Center(
        child: EntranceMotion(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(width: 240),
                const SizedBox(height: 32),
                if (error.isEmpty)
                  const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  Text(error, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: retry, child: const Text('Riprova')),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
