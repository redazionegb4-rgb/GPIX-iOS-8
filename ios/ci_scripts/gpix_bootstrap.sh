#!/bin/bash
set -euo pipefail
GPIX_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# Always run project commands from the directory containing pubspec.yaml.
if [[ ! -f "$GPIX_ROOT/pubspec.yaml" && -n "${CI_PRIMARY_REPOSITORY_PATH:-}" && -f "$CI_PRIMARY_REPOSITORY_PATH/pubspec.yaml" ]]; then
  GPIX_ROOT="$CI_PRIMARY_REPOSITORY_PATH"
fi
trap 'echo "GPIX: errore alla riga $LINENO (cartella: $PWD)" >&2' ERR
cd "$GPIX_ROOT"
[[ "$(uname -s)" == Darwin ]] || { echo 'GPIX: iOS richiede il runner macOS di Xcode Cloud.' >&2; exit 1; }
for item in pubspec.yaml pubspec.lock lib/main.dart ios/Podfile ios/Runner.xcodeproj/project.pbxproj; do
  [[ -f "$item" ]] || { echo "GPIX: manca $item. Carica tutto GPIX su GitHub, non solo ios." >&2; exit 1; }
done
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1
unset BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_BIN_PATH BUNDLE_FORCE_RUBY_PLATFORM RUBYOPT RUBYLIB || true
GPIX_FLUTTER_DIR="${CI_DERIVED_DATA_PATH:-$HOME/Library/Caches}/gpix-flutter-3.38.9"
if [[ ! -x "$GPIX_FLUTTER_DIR/bin/flutter" ]]; then
  git clone --depth 1 --branch 3.38.9 https://github.com/flutter/flutter.git "$GPIX_FLUTTER_DIR"
fi
export PATH="$GPIX_FLUTTER_DIR/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
echo 'GPIX: preparazione automatica Flutter 3.38.9'
flutter --version
flutter precache --ios
(cd "$GPIX_ROOT" && flutter pub get --enforce-lockfile)
if ! command -v pod >/dev/null 2>&1 || ! pod --version >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || { echo 'GPIX: Homebrew assente sul runner Cloud. Scegli un ambiente macOS/Xcode Cloud recente.' >&2; exit 1; }
  echo 'GPIX: installazione CocoaPods sul runner Cloud'
  brew install cocoapods
fi
pod --version
(cd "$GPIX_ROOT/ios" && pod install)
GPIX_BUILD_NUMBER="${CI_BUILD_NUMBER:-49}"
[[ "$GPIX_BUILD_NUMBER" =~ ^[0-9]+$ ]] || { echo 'GPIX: numero build Cloud non valido.' >&2; exit 1; }
(cd "$GPIX_ROOT" && flutter build ios --config-only --release --no-codesign --build-number "$GPIX_BUILD_NUMBER" --dart-define=GPIX_NATIVE_PUSH=false)
[[ -s ios/Flutter/Generated.xcconfig && -d ios/Pods/Pods.xcodeproj ]] || { echo 'GPIX: preparazione incompleta.' >&2; exit 1; }
echo "GPIX: preparazione completata. Xcode Cloud può archiviare la build $GPIX_BUILD_NUMBER."
