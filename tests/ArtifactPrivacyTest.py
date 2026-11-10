"""Focused regression checks for the shared-APK privacy gate."""
import io
import json
import tempfile
from unittest.mock import patch
from pathlib import Path
import runpy
import unittest
import zipfile

AUDIT = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/audit_apk.py'))['audit']


def check(entries):
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w') as apk:
        for name, content in entries.items():
            apk.writestr(name, content)
    archive.seek(0)
    return AUDIT(archive)


class ArtifactPrivacyTest(unittest.TestCase):
    def test_allows_normal_resources_and_public_signing_certificate(self):
        self.assertEqual(check({'assets/message.txt': b'An example reminder',
                                'META-INF/CERT.RSA': b'-----BEGIN CERTIFICATE-----'}), [])

    def test_rejects_embedded_source_paths_without_printing_the_path(self):
        # Fictional test fixtures; these paths are never used to access files.
        for path in [b'/Users/example/project/source.dart',
                     b'/home/example/project/source.dart',
                     b'C:\\Users\\example\\project\\source.dart']:
            self.assertEqual(check({'lib/app.so': b'prefix\x00' + path}),
                             [('lib/app.so', 'developer home-folder path')])

    def test_rejects_private_configuration_and_key_material(self):
        self.assertIn(('assets/.env', 'private configuration filename'),
                      check({'assets/.env': b'placeholder'}))
        self.assertIn(('lib/app.so', 'private key'),
                      check({'lib/app.so': b'-----BEGIN PRIVATE KEY-----'}))

    def test_rejects_access_token_shapes_without_reporting_the_value(self):
        self.assertEqual(check({'assets/settings': b'ghp_' + b'a' * 36}),
                         [('assets/settings', 'access token')])


class PortableBuildTest(unittest.TestCase):
    def test_package_alias_is_temporary_for_success_failure_and_exception(self):
        builder = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'scripts/portable_flutter_build.py'))['build']
        for outcome in [0, 2, OSError('compiler unavailable')]:
            with self.subTest(outcome=str(outcome)), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                config = root / 'companion_flutter/.dart_tool/package_config.json'
                config.parent.mkdir(parents=True)
                original = json.dumps({'configVersion': 2, 'packages': [{
                    'name': 'remindme_companion', 'rootUri': '../',
                    'packageUri': 'lib/', 'languageVersion': '3.6'}]}).encode()
                config.write_bytes(original)

                def compiler(command):
                    alias = json.loads(config.read_text())['packages'][-1]
                    self.assertEqual(alias['name'], 'remindme_build_plugins')
                    self.assertEqual(alias['rootUri'], 'flutter_build/')
                    self.assertEqual(alias['packageUri'], '')
                    self.assertIn('--no-pub', command)
                    if isinstance(outcome, Exception):
                        raise outcome
                    from subprocess import CompletedProcess
                    return CompletedProcess(command, outcome)

                with patch('subprocess.run', side_effect=compiler):
                    if isinstance(outcome, Exception):
                        with self.assertRaises(OSError):
                            builder(root, ['--release'])
                    else:
                        self.assertEqual(builder(root, ['--release']), outcome)
                self.assertEqual(config.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
