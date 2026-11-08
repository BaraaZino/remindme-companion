#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${ANDROID_HOME:-}" && -d "$PROJECT_ROOT/.tools/android-sdk" ]]; then
  export ANDROID_HOME="$PROJECT_ROOT/.tools/android-sdk"
fi
"$PROJECT_ROOT/scripts/flutterw" build apk --release --target-platform android-arm64 "$@"
mkdir -p "$PROJECT_ROOT/dist"
cp "$PROJECT_ROOT/companion_flutter/build/app/outputs/flutter-apk/app-release.apk" "$PROJECT_ROOT/dist/RemindMe-Flutter-arm64.apk"
echo "APK: $PROJECT_ROOT/dist/RemindMe-Flutter-arm64.apk"
