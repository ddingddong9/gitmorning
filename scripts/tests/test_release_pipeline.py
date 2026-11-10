import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


versions = load('release_version', 'release-version.py')
cask = load('update_cask', 'update-cask.py')

APPCAST = b'''<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0"><channel><title>GitMorning Updates</title>
<item><title>GitMorning 0.5.6</title><sparkle:version>11</sparkle:version><sparkle:shortVersionString>0.5.6</sparkle:shortVersionString>
<enclosure url="https://github.com/o/gitmorning/releases/download/v0.5.6/GitMorning-0.5.6-arm64.zip" length="1" type="application/octet-stream" sparkle:edSignature="x"/></item>
</channel></rss>'''


class ReleaseVersionTests(unittest.TestCase):
    def test_next_build_and_newer_version(self):
        self.assertEqual(versions.next_release('v0.5.7', APPCAST), ('0.5.7', 12))
        self.assertEqual(versions.next_release('v1.0.0', APPCAST), ('1.0.0', 12))
        self.assertEqual(versions.published(APPCAST), ('0.5.6', 11))

    def test_rejects_old_or_malformed_tags(self):
        for tag in ['v0.5.6', 'v0.5.5', 'v0.4.10', '0.5.7', 'v0.5', 'v0.5.7-beta', 'vx.y.z']:
            with self.assertRaises(ValueError, msg=tag):
                versions.next_release(tag, APPCAST)

    def test_rejects_appcasts_without_a_valid_item(self):
        for xml in [b'<rss><channel></channel></rss>', APPCAST.replace(b'<sparkle:version>11', b'<sparkle:version>0')]:
            with self.assertRaises(ValueError):
                versions.published(xml)


class UpdateCaskTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in ['Casks/gitmorning.rb', 'distribution/README.md', 'distribution/appcast.xml']:
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / path, self.root / path)

    def test_updates_cask_records_and_versions_line(self):
        sums = 'a' * 64 + '  GitMorning-0.5.6-arm64.zip\n'
        readme = self.root / 'distribution/README.md'
        readme.write_text('x\n\nPublished versions: 0.5.4, 0.5.5.\n')
        self.assertEqual(cask.update(self.root, APPCAST, sums, 'o/gitmorning'), ('0.5.6', 11, 'a' * 64))
        text = (self.root / 'Casks/gitmorning.rb').read_text()
        self.assertIn('version "0.5.6,11"', text)
        self.assertIn('sha256 "' + 'a' * 64 + '"', text)
        self.assertIn('url "https://github.com/o/gitmorning/releases/download/', text)
        self.assertEqual((self.root / 'distribution/appcast.xml').read_bytes(), APPCAST)
        self.assertIn('Published versions: 0.5.4, 0.5.5, 0.5.6.', readme.read_text())
        cask.update(self.root, APPCAST, sums, 'o/gitmorning')  # running twice does not repeat the version
        self.assertEqual(readme.read_text().count('0.5.6'), 1)

    def test_requires_the_archive_checksum(self):
        with self.assertRaises(ValueError):
            cask.update(self.root, APPCAST, 'b' * 64 + '  Other.zip\n', 'o/gitmorning')
        with self.assertRaises(ValueError):
            cask.checksum_for('not-a-sum  GitMorning-0.5.6-arm64.zip', 'GitMorning-0.5.6-arm64.zip')


if __name__ == '__main__':
    unittest.main()
