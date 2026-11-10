#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${ANDROID_HOME:-}" && -d "$PROJECT_ROOT/.tools/android-sdk" ]]; then
  export ANDROID_HOME="$PROJECT_ROOT/.tools/android-sdk"
fi
SYMBOLS_DIR="$PROJECT_ROOT/.tools/build-symbols/$(date -u +%Y%m%dT%H%M%SZ)"
"$PROJECT_ROOT/scripts/flutterw" pub get
python3 "$PROJECT_ROOT/scripts/portable_flutter_build.py" --release --target-platform android-arm64 \
  --obfuscate --split-debug-info="$SYMBOLS_DIR" --extra-gen-snapshot-options=--strip "$@"
python3 "$PROJECT_ROOT/scripts/audit_apk.py" \
  "$PROJECT_ROOT/companion_flutter/build/app/outputs/flutter-apk/app-release.apk"
mkdir -p "$PROJECT_ROOT/dist"
cp "$PROJECT_ROOT/companion_flutter/build/app/outputs/flutter-apk/app-release.apk" "$PROJECT_ROOT/dist/RemindMe-Flutter-arm64.apk"
python3 - "$PROJECT_ROOT/dist/RemindMe-Flutter-arm64.apk" <<'PYHASH'
import hashlib
from pathlib import Path
import sys
apk = Path(sys.argv[1])
apk.with_suffix('.sha256').write_text(hashlib.sha256(apk.read_bytes()).hexdigest() + '  ' + apk.name + '\n')
PYHASH
echo "APK: $PROJECT_ROOT/dist/RemindMe-Flutter-arm64.apk"
echo "Keep debug symbols locally for crash reports: $SYMBOLS_DIR"
