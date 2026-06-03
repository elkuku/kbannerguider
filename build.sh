#!/usr/bin/env bash
set -euo pipefail

VERSION=$(date +"%Y%m%d-%H%M")
APK_DIR=build/app/outputs/flutter-apk

flutter build apk --dart-define=APP_VERSION="$VERSION"

cp "$APK_DIR/app-release.apk" "$APK_DIR/kbannerguider-$VERSION.apk"

flutter install -d 23191JEGR03752

echo "Built: $APK_DIR/kbannerguider-$VERSION.apk"
