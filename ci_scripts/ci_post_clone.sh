#!/bin/sh
set -eu
GPIX_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
exec /bin/bash "$GPIX_ROOT/ios/ci_scripts/gpix_bootstrap.sh"
