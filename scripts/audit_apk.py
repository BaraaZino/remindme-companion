#!/usr/bin/env python3
"""Reject APKs containing private keys, local configuration or home-folder paths.

This is a focused artifact check, not a substitute for a source/history secret scan.
Only archive entry names and finding categories are printed, never secret values.
"""
import argparse
from pathlib import Path
import re
import sys
import zipfile

PATTERNS = {
    'developer home-folder path': re.compile(
        rb'(?:/Users/|/home/)[A-Za-z0-9_.-]+/|[A-Za-z]:\\Users\\[A-Za-z0-9_.-]+\\'),
    'private key': re.compile(
        rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'credential-bearing URL': re.compile(rb'https?://[^\s/:@]+:[^\s/@]+@'),
    'access token': re.compile(
        rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|sk-(?:proj-)?[A-Za-z0-9_-]{30,}'),
}
SENSITIVE_FILE = re.compile(
    r'(^|/)(?:\.env(?:\..*)?|local\.properties|key\.properties|[^/]*\.(?:keystore|jks|p12|pfx)|id_rsa|id_ed25519)$',
    re.IGNORECASE)


def audit(path):
    findings = []
    with zipfile.ZipFile(path) as apk:
        for entry in apk.infolist():
            if entry.is_dir():
                continue
            if SENSITIVE_FILE.search(entry.filename):
                findings.append((entry.filename, 'private configuration filename'))
            content = apk.read(entry)
            for label, pattern in PATTERNS.items():
                if pattern.search(content):
                    findings.append((entry.filename, label))
    return findings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apks', type=Path, nargs='+')
    args = parser.parse_args()
    failed = False
    for path in args.apks:
        findings = audit(path)
        if findings:
            failed = True
            for entry, label in findings:
                print(f'{path.name}: {label} in {entry}', file=sys.stderr)
        else:
            print(f'{path.name}: artifact privacy checks passed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
