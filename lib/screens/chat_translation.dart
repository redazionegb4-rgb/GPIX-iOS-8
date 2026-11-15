import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/kit.dart';

Future<void> translateChatText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      final opened = await const MethodChannel(
        'GPIX/translation',
      ).invokeMethod<bool>('present', {'text': text});
      if (opened == true) return;
    } on MissingPluginException {
      // The native translation view is optional on older Apple SDKs.
    } on PlatformException {
      // Show the platform availability below.
    }
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    final system = DefaultProcessTextService();
    final actions = (await system.queryTextActions()).where((action) {
      final name = '${action.id} ${action.label}'.toLowerCase();
      return name.contains('translat') ||
          name.contains('traduc') ||
          name.contains('tradutt') ||
          name.contains('übersetz') ||
          name.contains('traduire');
    }).toList();
    if (!context.mounted) return;
    if (actions.isNotEmpty) {
      final choice = await sheet<ProcessTextAction>(
        context,
        Builder(
          builder: (menu) => Column(
            children: [
              const Text(
                'Traduci con',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final action in actions)
                ListTile(
                  leading: const GIcon(CupertinoIcons.globe, size: 22),
                  title: Text(action.label),
                  subtitle: const Text('Il testo verrà aperto in questa app'),
                  onTap: () => Navigator.pop(menu, action),
                ),
            ],
          ),
        ),
      );
      if (choice == null || !context.mounted) return;
      await perform(context, () async {
        final translated = await system.processTextAction(
          choice.id,
          text,
          true,
        );
        if (translated == null || translated.trim().isEmpty || !context.mounted)
          return;
        await sheet(
          context,
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Traduzione',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                SelectableText(translated),
              ],
            ),
          ),
        );
      });
      return;
    }
  }
  if (!context.mounted) return;
  await gpixAlert(
    context,
    'Traduzione non disponibile',
    defaultTargetPlatform == TargetPlatform.android
        ? 'Per usare Traduci, installa un’app di traduzione compatibile con il menu di testo di Android.'
        : 'La traduzione di sistema richiede iOS 17.4 o una versione successiva.',
  );
}
