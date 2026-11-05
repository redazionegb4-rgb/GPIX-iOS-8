#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "Installa Flutter 3.38.9 e aggiungi flutter al PATH."; exit 1; }
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter pub get
media_kit_gradle="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/media_kit_libs_android_video-1.3.8/android/build.gradle"
# La beta include ARMv7, ARM64 e x86_64. Escludi il jar x86 a 32 bit.
if [[ -f "$media_kit_gradle" ]] && grep -Fq 'default-x86.jar' "$media_kit_gradle"; then
  original="$(mktemp)"
  cp "$media_kit_gradle" "$original"
  trap 'cat "$original" > "$media_kit_gradle"; rm -f "$original"' EXIT
  sed '/default-x86[.]jar/d' "$original" > "$media_kit_gradle"
fi
flutter build apk --release
printf '\nAPK build/app/outputs/flutter-apk/app-release.apk\n'
