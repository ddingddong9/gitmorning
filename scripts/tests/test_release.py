import base64
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


configure = load('configure_bundle', 'configure-bundle.py').configure
release = load('prepare_release', 'prepare-release.py')


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plist = self.root / 'Info.plist'
        self.plist.write_bytes((ROOT / 'Resources/Info.plist').read_bytes())
        self.key = base64.b64encode(b'k' * 32).decode()
        self.feed = 'https://github.com/example/homebrew-gitmorning/releases/latest/download/appcast.xml'

    def info(self):
        return plistlib.loads(self.plist.read_bytes())

    def test_release_rejects_missing_updater_or_signing_identity(self):
        for env in [dict(GITMORNING_RELEASE='1'),
                    dict(GITMORNING_RELEASE='1', GITMORNING_CORE_ONLY='1',
                         GITMORNING_UPDATE_FEED=self.feed, GITMORNING_UPDATE_PUBLIC_KEY=self.key)]:
            with self.assertRaises(ValueError):
                configure(self.plist, env)

    def test_bad_feed_or_missing_key_does_not_change_existing_plist(self):
        before = self.plist.read_bytes()
        for feed in ['http://example.com/feed', 'https://user:pass@example.com/feed', 'https://example.com/feed?token=x']:
            with self.assertRaises(ValueError):
                configure(self.plist, dict(GITMORNING_UPDATE_FEED=feed, GITMORNING_UPDATE_PUBLIC_KEY=self.key))
        with self.assertRaises(ValueError):
            configure(self.plist, dict(GITMORNING_UPDATE_FEED=self.feed))
        self.assertEqual(self.plist.read_bytes(), before)

    def test_production_settings_keep_user_install_choice_and_disable_profile(self):
        configure(self.plist, dict(GITMORNING_RELEASE='1', GITMORNING_VERSION='0.3.0', GITMORNING_BUILD='3',
                                  GITMORNING_UPDATE_FEED=self.feed, GITMORNING_UPDATE_PUBLIC_KEY=self.key))
        info = self.info()
        self.assertTrue(info['SUEnableAutomaticChecks'])
        self.assertFalse(info['SUAutomaticallyUpdate'])
        self.assertFalse(info['SUSendProfileInfo'])
        self.assertTrue(info['SUVerifyUpdateBeforeExtraction'])
        metadata = release.release_metadata(info, 'example/homebrew-gitmorning', self.key)
        self.assertEqual((metadata['version'], metadata['build']), ('0.3.0', '3'))
        with self.assertRaises(ValueError):
            release.release_metadata(info, 'example/different-repo', self.key)

    def test_cask_and_appcast_point_to_identical_versioned_archive(self):
        configure(self.plist, dict(GITMORNING_UPDATE_FEED=self.feed, GITMORNING_UPDATE_PUBLIC_KEY=self.key))
        metadata = release.release_metadata(self.info(), 'example/homebrew-gitmorning', self.key)
        archive = self.root / metadata['filename']
        archive.write_bytes(b'synthetic archive, not an app')
        signature = base64.b64encode(b's' * 64).decode()
        feed = ET.fromstring(release.appcast(metadata, archive, signature, '<new> & fixes'))
        item = feed.find('channel/item')
        enclosure = item.find('enclosure')
        self.assertEqual(enclosure.attrib['length'], str(archive.stat().st_size))
        self.assertEqual(enclosure.attrib[f'{{{release.SPARKLE}}}edSignature'], signature)
        self.assertTrue(enclosure.attrib['url'].endswith('/' + archive.name))
        self.assertEqual(item.find(f'{{{release.SPARKLE}}}hardwareRequirements').text, 'arm64')
        self.assertEqual(item.find('description').text, '<new> & fixes')
        cask = release.cask(metadata, 'a' * 64)
        self.assertIn('auto_updates true', cask)
        self.assertIn('strategy :sparkle', cask)
        self.assertIn('sha256 "' + 'a' * 64 + '"', cask)
        self.assertNotIn('sha256 :no_check', cask)
        self.assertNotIn('xattr', cask)
        with self.assertRaises(ValueError):
            release.cask(metadata, 'placeholder')

    def test_versions_and_signature_are_validated(self):
        for env in [dict(GITMORNING_BUILD='0'), dict(GITMORNING_VERSION='0.3.0;bad')]:
            with self.assertRaises(ValueError):
                configure(self.plist, env)
        archive = self.root / 'synthetic.zip'
        archive.write_bytes(b'test')
        with self.assertRaises(ValueError):
            release.appcast({}, archive, base64.b64encode(b'x').decode(), '')


if __name__ == '__main__':
    unittest.main()
