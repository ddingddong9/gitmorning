import re
import tempfile
import unittest
from pathlib import Path

from feed.landing import ASSETS, ROOT, build, released_version

APPCAST = """<?xml version="1.0"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
<item><sparkle:version>11</sparkle:version><sparkle:shortVersionString>0.5.6</sparkle:shortVersionString></item>
<item><sparkle:version>12</sparkle:version><sparkle:shortVersionString>0.5.7</sparkle:shortVersionString></item>
</channel></rss>"""


class LandingTests(unittest.TestCase):
    def test_newest_build_wins_regardless_of_order(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "appcast.xml"
            path.write_text(APPCAST)
            self.assertEqual(released_version(path), "0.5.7")

    def test_site_has_pages_assets_and_version(self):
        with tempfile.TemporaryDirectory() as tmp:
            version = build(tmp)
            html = (Path(tmp) / "index.html").read_text(encoding="utf-8")
            self.assertNotIn("{{VERSION}}", html)
            self.assertIn("v" + version, html)
            for name in ["style.css", "site.js"] + ["assets/" + n for n in ASSETS]:
                self.assertTrue((Path(tmp) / name).is_file(), name)
            # Every local file the page references exists in the built site (v1/ comes from the feed build).
            for ref in re.findall(r'(?:src|href|poster|data-ko-src|data-ko-poster)="([^"#:]+)"', html):
                if not ref.startswith("v1/"):
                    self.assertTrue((Path(tmp) / ref).is_file(), ref)

    def test_every_korean_key_matches_an_element_or_script_string(self):
        html = (ROOT / "web/index.html").read_text(encoding="utf-8")
        script = (ROOT / "web/site.js").read_text(encoding="utf-8")
        page_keys = set(re.findall(r'data-i18n="([^"]+)"', html))
        korean = script[script.index("const ko = {"):script.index("const en = {")]
        korean_keys = set(re.findall(r'^\s+"([^"]+)":', korean, re.M))
        self.assertEqual(page_keys - korean_keys, set(), "page text without Korean")
        used_in_script = set(re.findall(r'text\("([^"]+)"\)', script))
        self.assertEqual(korean_keys - page_keys - used_in_script, set(), "unused Korean keys")


if __name__ == "__main__":
    unittest.main()
