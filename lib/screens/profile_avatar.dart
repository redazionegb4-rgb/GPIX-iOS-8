import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/avatar_style.dart';
import '../core/store.dart';
import '../ui/avatar_preview.dart';
import '../ui/kit.dart';

class ProfileAvatarEditor extends StatefulWidget {
  const ProfileAvatarEditor({super.key});

  @override
  State<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends State<ProfileAvatarEditor> {
  static const labels = [
    'Carnagione',
    'Acconciature',
    'Forma del viso',
    'Corpo',
    'Stile',
  ];
  final rotation = ValueNotifier<double>(-.1);
  late AvatarStyle style;
  int? step;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (step != null) return;
    final saved = GpixScope.of(context, listen: false).avatarModel;
    style = AvatarStyle.fromJson(saved);
    step = saved.isEmpty ? -1 : 0;
  }

  @override
  void dispose() {
    rotation.dispose();
    super.dispose();
  }

  void change(AvatarFeature feature, int value) =>
      setState(() => style = style.withFeature(feature, value));

  void previous() {
    if (step! > 0) {
      setState(() => step = step! - 1);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> next() async {
    if (step! < labels.length - 1) {
      setState(() => step = step! + 1);
      return;
    }
    setState(() => saving = true);
    try {
      final store = GpixScope.of(context, listen: false);
      await perform(context, () async {
        await store.saveAvatarModel(style.toJson());
        if (mounted) Navigator.pop(context, true);
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = step!;
    final introduction = current < 0;
    final last = current == labels.length - 1;
    return PopScope(
      canPop: !saving && current <= 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving && current > 0) previous();
      },
      child: Scaffold(
        backgroundColor: surface(context),
        body: Column(
          children: [
            Expanded(
              flex: introduction ? 7 : 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    label: 'Ruota l’avatar',
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) => rotation.value =
                          (rotation.value + details.delta.dx / 140).clamp(
                            -.90,
                            .90,
                          ),
                      child: ValueListenableBuilder<double>(
                        valueListenable: rotation,
                        builder: (context, angle, _) => AvatarPreview(
                          key: const ValueKey('profile-avatar-preview'),
                          style: style,
                          rotation: angle,
                          fullBody: introduction || current == 3 || last,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 8,
                    child: SafeArea(
                      bottom: false,
                      child: IconButton(
                        tooltip: 'Indietro',
                        onPressed: saving ? null : previous,
                        style: IconButton.styleFrom(
                          backgroundColor: surface(
                            context,
                          ).withValues(alpha: .9),
                          foregroundColor: foreground(context),
                        ),
                        icon: const GIcon(
                          CupertinoIcons.chevron_back,
                          size: 23,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: introduction ? 3 : 5,
              child: ListView(
                key: ValueKey(current),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  Text(
                    introduction ? 'Crea il tuo avatar' : labels[current],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: introduction ? 22 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (introduction)
                    const Text(
                      'Personalizza carnagione, capelli, viso, corpo e abbigliamento.',
                      textAlign: TextAlign.center,
                    )
                  else
                    ...options(current),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!introduction)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (var index = 0; index < labels.length; index++)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: index <= current
                                  ? foreground(context)
                                  : subdued(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : next,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(45),
                  ),
                  child: Text(
                    saving
                        ? 'Salvataggio…'
                        : introduction
                        ? 'Crea il tuo avatar'
                        : last
                        ? 'Salva avatar'
                        : 'Avanti',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> options(int current) => switch (current) {
    0 => [swatches('Carnagione', AvatarFeature.skin, AvatarStyle.skinTones)],
    1 => [
      swatches(
        'Colore dei capelli',
        AvatarFeature.hairColor,
        AvatarStyle.hairTones,
      ),
      presets(AvatarFeature.hair, [
        'Rasati',
        'Corti',
        'Ciuffo',
        'Ricci',
        'Lunghi',
        'Raccolti',
      ]),
    ],
    2 => [
      presets(AvatarFeature.face, ['Ovale', 'Rotondo', 'Squadrato', 'A cuore']),
      swatches(
        'Colore degli occhi',
        AvatarFeature.eyeColor,
        AvatarStyle.eyeTones,
      ),
      slider('Larghezza del viso', AvatarFeature.faceWidth),
      slider('Rotondità delle guance', AvatarFeature.cheeks),
      slider('Larghezza della mandibola', AvatarFeature.jaw),
    ],
    3 => [
      presets(AvatarFeature.body, [
        'Snello',
        'Regolare',
        'Atletico',
        'Robusto',
      ], fullBody: true),
      slider('Spalle', AvatarFeature.shoulders),
      slider('Vita', AvatarFeature.waist),
      slider('Altezza', AvatarFeature.height),
    ],
    _ => [
      const Text(
        'Colore della maglia',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      swatches(
        'Colore della maglia',
        AvatarFeature.outfit,
        AvatarStyle.outfitTones,
      ),
      const SizedBox(height: 12),
      const Text('Barba', style: TextStyle(fontWeight: FontWeight.w600)),
      Wrap(
        spacing: 7,
        children: [
          for (final (value, label) in const [
            'Senza barba',
            'Corta',
            'Piena',
          ].indexed)
            ChoiceChip(
              label: Text(label),
              selected: style[AvatarFeature.beard] == value,
              onSelected: (_) => change(AvatarFeature.beard, value),
            ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Occhiali'),
        value: style[AvatarFeature.glasses] == 1,
        onChanged: (value) => change(AvatarFeature.glasses, value ? 1 : 0),
      ),
    ],
  };

  Widget swatches(
    String label,
    AvatarFeature feature,
    List<Color> colors,
  ) => GridView.builder(
    primary: false,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisSpacing: 5,
      crossAxisSpacing: 6,
      mainAxisExtent: 40,
    ),
    itemCount: colors.length,
    itemBuilder: (context, index) {
      final color = colors[index];
      final selected = index == style[feature];
      return Semantics(
        button: true,
        selected: selected,
        label: '$label ${index + 1}',
        child: InkWell(
          key: ValueKey(('avatar-swatch', feature.name, index)),
          customBorder: const CircleBorder(),
          onTap: () => change(feature, index),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? foreground(context) : Colors.transparent,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget presets(
    AvatarFeature feature,
    List<String> names, {
    bool fullBody = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: GridView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: fullBody ? 4 : 3,
        mainAxisSpacing: 7,
        crossAxisSpacing: 7,
        mainAxisExtent: fullBody ? 115 : 87,
      ),
      itemCount: names.length,
      itemBuilder: (context, index) => Semantics(
        button: true,
        selected: style[feature] == index,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => change(feature, index),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: subdued(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: style[feature] == index
                    ? accent(context)
                    : Theme.of(context).dividerColor,
                width: style[feature] == index ? 1.8 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AvatarPreview(
                        style: style.withFeature(feature, index),
                        rotation: -.11,
                        fullBody: fullBody,
                        detail: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    names[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget slider(String label, AvatarFeature feature) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: style[feature].toDouble(),
          max: 100,
          onChanged: (value) => change(feature, value.round()),
          semanticFormatterCallback: (value) => '$label ${value.round()}',
        ),
      ],
    ),
  );
}
