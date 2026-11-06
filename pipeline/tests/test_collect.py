import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from pipeline.collect import CollectionError, parse_trending, publish, readme, request, snapshot, trending_url

HTML = (Path(__file__).parent / "fixtures/trending.html").read_text()


class CollectorTests(unittest.TestCase):
    def test_heading_ignores_hidden_template_and_dialog(self):
        items = parse_trending(HTML)
        self.assertEqual(items[0]["id"], "example/alpha")
        self.assertEqual(items[0]["description"], "Documents & search")

    def test_rank_preserves_source_order_and_metrics(self):
        items = parse_trending(HTML)
        self.assertEqual([r["rank"] for r in items], [1, 2])
        self.assertEqual(items[0]["stars"], 12345)
        self.assertEqual(items[0]["periodStars"], 1234)
        self.assertEqual(items[0]["language"], "Python")

    def test_optional_values_remain_unknown(self):
        item = parse_trending(HTML)[1]
        self.assertEqual(item["description"], "")
        self.assertIsNone(item["language"])
        item = parse_trending(HTML.replace('href="/example/beta/stargazers"', 'href="/example/beta/forks"'))[1]
        self.assertIsNone(item["stars"])

    def test_weekly_values_are_not_daily_values(self):
        self.assertIsNone(parse_trending(HTML, "weekly")[0]["periodStars"])
        self.assertEqual(parse_trending(HTML.replace("stars today", "stars this week"), "weekly")[0]["periodStars"], 1234)

    def test_invalid_or_duplicate_rows_fail_entire_snapshot(self):
        for html in ["<h1>Sign in</h1>", HTML + HTML, HTML.replace('/example/beta"', '/example/beta/issues"')]:
            with self.subTest(html=html[:25]), self.assertRaises(CollectionError):
                parse_trending(html)

    def test_language_url_uses_path_and_period_query(self):
        self.assertEqual(trending_url("weekly", "Python"), "https://github.com/trending/python?since=weekly")
        with self.assertRaises(CollectionError):
            trending_url("daily", "../../private")

    def test_api_token_never_leaves_approved_origins(self):
        for url, api in [("https://evil.example/api", True), ("http://api.github.com/repos/x/y", True), ("https://github.com:444/trending", False)]:
            with self.assertRaises(CollectionError):
                request(url, api=api)

    def test_snapshot_atomic_write_and_previous_success_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            payload = snapshot(HTML, collected_at="2026-11-02T00:00:00+00:00")
            path = publish(payload, directory)
            before = path.read_bytes()
            self.assertEqual(json.loads(before)["repositories"][0]["id"], "example/alpha")
            with self.assertRaises(CollectionError):
                publish(snapshot("invalid page"), directory)
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(len(list(Path(directory).iterdir())), 1)

    def test_shared_parity_fixtures(self):
        # The same files are checked by scripts/check-parity.swift for the app parser.
        directory = Path(__file__).parent / "fixtures/parity"
        files = sorted(directory.glob("*.html"))
        self.assertTrue(files)
        for html in files:
            period = html.name.split(".")[1]
            with self.subTest(fixture=html.name):
                if ".reject." in html.name:
                    with self.assertRaises(CollectionError):
                        parse_trending(html.read_text(encoding="utf-8"), period)
                else:
                    expected = json.loads(html.with_suffix(".json").read_text(encoding="utf-8"))
                    self.assertEqual(parse_trending(html.read_text(encoding="utf-8"), period), expected)

    def test_unrecognized_metrics_are_unknown_not_errors(self):
        item = parse_trending(HTML.replace(">12,345<", ">12.3k<"))[0]
        self.assertIsNone(item["stars"])
        self.assertEqual(item["periodStars"], 1234)

    @patch("pipeline.collect.request")
    def test_readme_source_preserves_sha_and_text(self, mocked):
        mocked.return_value = json.dumps({"encoding": "base64", "size": 5, "content": "aGVsbG8=", "sha": "example-sha", "html_url": "https://github.com/example/alpha/blob/main/README.md"})
        data = readme("example/alpha")
        self.assertEqual(data["content"], "hello")
        self.assertEqual(data["summaryStatus"], "pending")


if __name__ == "__main__":
    unittest.main()
