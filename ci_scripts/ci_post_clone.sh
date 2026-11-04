#!/bin/sh
set -eu
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"
echo 'GPIX Swift build 52: controllo sorgenti con il compilatore del runner.'
xcrun swiftc -frontend -parse -swift-version 5 GPIX/*.swift
echo 'Sintassi Swift verificata. Xcode eseguira compilazione e firma.'
