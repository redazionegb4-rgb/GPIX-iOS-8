#!/bin/bash
set -euo pipefail
GPIX_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$GPIX_ROOT"
# Xcode Cloud runs this after cloning the Git repository.
if ! command -v flutter >/dev/null 2>&1 || ! flutter --version | grep -q 'Flutter 3.35.7'; then
  GPIX_FLUTTER_DIR="${CI_DERIVED_DATA_PATH:-$HOME/Library/Caches}/gpix-flutter-3.35.7"
  if [[ ! -x "$GPIX_FLUTTER_DIR/bin/flutter" ]]; then
    git clone --depth 1 --branch 3.35.7 https://github.com/flutter/flutter.git "$GPIX_FLUTTER_DIR"
  fi
  export PATH="$GPIX_FLUTTER_DIR/bin:$PATH"
fi
flutter config --no-analytics
flutter precache --ios
flutter pub get --enforce-lockfile
flutter build ios --config-only --no-codesign
command -v pod >/dev/null 2>&1 || { echo 'CocoaPods richiesto nel runner Xcode.'; exit 1; }
cd ios
pod install
