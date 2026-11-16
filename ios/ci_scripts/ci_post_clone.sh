#!/bin/sh
set -eu
exec /bin/bash "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/gpix_bootstrap.sh"
