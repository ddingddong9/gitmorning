import unittest
from unittest.mock import patch

from datetime import datetime, timezone

from pipeline.canary import check, check_feed
from pipeline.collect import CollectionError

ROW = '<article class="Box-row"><h2><a href="/o/r{n}">r</a></h2><span itemprop="programmingLanguage">Go</span><a href="/o/r{n}/stargazers">1,000</a><span>5 stars today</span></article>'


class CanaryTests(unittest.TestCase):
    @patch("pipeline.canary.request")
    def test_healthy_page_passes(self, mocked):
        mocked.return_value = "".join(ROW.format(n=n) for n in range(6))
        self.assertEqual(check("daily"), "daily: 6 rows OK")

    @patch("pipeline.canary.request")
    def test_too_few_rows_fail(self, mocked):
        mocked.return_value = ROW.format(n=1)
        with self.assertRaises(CollectionError):
            check("daily")

    @patch("pipeline.canary.request")
    def test_lost_metrics_fail(self, mocked):
        mocked.return_value = "".join(ROW.format(n=n).replace("1,000", "1k") for n in range(6))
        with self.assertRaisesRegex(CollectionError, "stars recognized for only 0/6"):
            check("daily")


    def test_feed_freshness(self):
        now = datetime(2026, 11, 4, 3, 0, tzinfo=timezone.utc)
        fresh = {f"f{n}.json": {"collectedAt": "2026-11-04T02:07:00+00:00"} for n in range(14)}
        self.assertEqual(check_feed({"files": fresh}, now), "shared feed: 14 files fresh")
        stale = dict(fresh, **{"f0.json": {"collectedAt": "2026-11-03T18:07:00+00:00"}})
        with self.assertRaisesRegex(CollectionError, "f0.json"):
            check_feed({"files": stale}, now)
        with self.assertRaisesRegex(CollectionError, "13/14"):
            check_feed({"files": dict(list(fresh.items())[:13])}, now)


if __name__ == "__main__":
    unittest.main()
