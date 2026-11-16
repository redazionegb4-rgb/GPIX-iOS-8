import 'dart:ui';

import 'data.dart';

enum AvatarFeature {
  skin(23, 15),
  hair(5, 2),
  hairColor(9, 0),
  eyeColor(5, 0),
  face(3, 0),
  faceWidth(100, 50),
  cheeks(100, 50),
  jaw(100, 50),
  beard(2, 0),
  body(3, 1),
  shoulders(100, 50),
  waist(100, 50),
  height(100, 50),
  outfit(7, 0),
  glasses(1, 0);

  const AvatarFeature(this.max, this.initial);

  final int max;
  final int initial;
}

class AvatarStyle {
  const AvatarStyle() : _features = const {};
  AvatarStyle._(Map<AvatarFeature, int> features)
    : _features = Map.unmodifiable(features);

  factory AvatarStyle.fromJson(J data) => AvatarStyle._({
    for (final feature in AvatarFeature.values)
      if (data[feature.name] case final int value)
        feature: value.clamp(0, feature.max),
  });

  final Map<AvatarFeature, int> _features;

  int operator [](AvatarFeature feature) =>
      _features[feature] ?? feature.initial;

  AvatarStyle withFeature(AvatarFeature feature, int value) =>
      AvatarStyle._({..._features, feature: value.clamp(0, feature.max)});

  J toJson() => {
    for (final feature in AvatarFeature.values) feature.name: this[feature],
  };

  static const skinTones = [
    Color(0xff2e1a14),
    Color(0xff3d221b),
    Color(0xff4b2a1e),
    Color(0xff584031),
    Color(0xff663f2e),
    Color(0xff744939),
    Color(0xff754a30),
    Color(0xff865338),
    Color(0xff985d3b),
    Color(0xffa36949),
    Color(0xffb37d58),
    Color(0xffc18b68),
    Color(0xffcc986c),
    Color(0xffd8a17a),
    Color(0xffe4aa85),
    Color(0xffe9b38c),
    Color(0xffefc3a3),
    Color(0xfffad1b7),
    Color(0xff8c8d95),
    Color(0xff94bd9c),
    Color(0xff72b8c0),
    Color(0xff666ba7),
    Color(0xffaa79a5),
    Color(0xffbd677d),
  ];

  static const hairTones = [
    Color(0xff2b2321),
    Color(0xff402b24),
    Color(0xff62412d),
    Color(0xff8c5835),
    Color(0xffb28052),
    Color(0xffd9b77c),
    Color(0xffa5a0a5),
    Color(0xffac422d),
    Color(0xff77559f),
    Color(0xff527ea0),
  ];

  static const eyeTones = [
    Color(0xff643a26),
    Color(0xff906d43),
    Color(0xff628755),
    Color(0xff5488a8),
    Color(0xff7f8c91),
    Color(0xff594c72),
  ];

  static const outfitTones = [
    Color(0xff293447),
    Color(0xfff4e8e2),
    Color(0xffac3649),
    Color(0xff49614e),
    Color(0xff6479c0),
    Color(0xffd68e47),
    Color(0xff8b6293),
    Color(0xff509196),
  ];
}
