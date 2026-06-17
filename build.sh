#!/usr/bin/env bash
set -euo pipefail

VERSION=$(date +"%Y%m%d-%H%M")
APK_DIR=build/app/outputs/flutter-apk

flutter build apk --dart-define=APP_VERSION="$VERSION"

cp "$APK_DIR/app-release.apk" "$APK_DIR/kbannerguider-$VERSION.apk"

flutter install -d 23191JEGR03752

# Install on any running emulators
while IFS= read -r line; do
  EMU_ID=$(echo "$line" | awk -F'•' '{print $2}' | tr -d ' ')
  if [[ -n "$EMU_ID" ]]; then
    echo "Installing on emulator $EMU_ID..."
    flutter install -d "$EMU_ID" || true
  fi
done < <(flutter devices 2>/dev/null | grep '(emulator)')

echo "Built: $APK_DIR/kbannerguider-$VERSION.apk"
