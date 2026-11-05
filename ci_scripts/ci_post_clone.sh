#!/bin/sh
set -eu
GPIX_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$GPIX_ROOT"
test -f GPIX.xcodeproj/project.pbxproj
test -f GPIX/Application.swift
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  case "$CI_BUILD_NUMBER" in *[!0-9]*|'') echo 'Numero build non valido' >&2; exit 1;; esac
  GPIX_VERSION=$((1000 + CI_BUILD_NUMBER))
  sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $GPIX_VERSION/" Config/App.xcconfig
fi
/usr/bin/plutil -lint GPIX/Info.plist
/usr/bin/plutil -lint GPIX.xcodeproj/project.pbxproj
xcrun swiftc -swift-version 5 GPIX/Domain.swift GPIX/DemoData.swift GPIX/Credentials.swift GPIX/Session.swift GPIX/DemoSession.swift QA/DomainChecks.swift -o "${TMPDIR:-/tmp}/gpix-domain-checks"
"${TMPDIR:-/tmp}/gpix-domain-checks"
echo 'GPIX: progetto UIKit pronto per Archive. Nessuna installazione necessaria.'
