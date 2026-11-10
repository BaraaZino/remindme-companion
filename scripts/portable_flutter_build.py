#!/usr/bin/env python3
"""Compile with a portable package URI for Flutter's generated plugin registrant.

Flutter places this generated Dart file outside lib/. Giving that build directory
an ephemeral package alias prevents its absolute filename from entering the AOT
snapshot. The generated package configuration is restored even if compilation fails.
Run flutter pub get first. This script never modifies the Flutter SDK.
"""
import json
from pathlib import Path
import subprocess
import sys


def build(root, arguments):
    config = root / 'companion_flutter/.dart_tool/package_config.json'
    original = config.read_bytes()
    data = json.loads(original)
    alias = 'remindme_build_plugins'
    if any(package['name'] == alias for package in data['packages']):
        raise SystemExit('Build package alias is already in use.')
    project = next(p for p in data['packages'] if p['name'] == 'remindme_companion')
    data['packages'].append({
        'name': alias,
        'rootUri': 'flutter_build/',
        'packageUri': '',
        'languageVersion': project['languageVersion'],
    })
    try:
        config.write_text(json.dumps(data, indent=2) + '\n')
        return subprocess.run([str(root / 'scripts/flutterw'), 'build', 'apk',
                               '--no-pub', *arguments]).returncode
    finally:
        config.write_bytes(original)


if __name__ == '__main__':
    sys.exit(build(Path(__file__).resolve().parents[1], sys.argv[1:]))
