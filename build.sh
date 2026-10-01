#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP="build/DefaultBrowserSwitch.app"
ARCH="$(uname -m)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc \
  -O \
  -target "${ARCH}-apple-macosx14.0" \
  -swift-version 5 \
  -framework AppKit \
  -o "$APP/Contents/MacOS/DefaultBrowserSwitch" \
  Sources/main.swift

cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --sign - "$APP"
echo "Built $APP"
