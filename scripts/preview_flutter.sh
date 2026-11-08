#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/flutterw" run -d web-server --web-hostname 127.0.0.1 --web-port 8942 --no-web-resources-cdn
