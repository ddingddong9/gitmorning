import unittest
from pipeline.history import HISTORY_DAYS, history_name, merge


def daily(collected_at, ids, language="all"):
    return {"schemaVersion": 1, "period": "daily", "languageFilter": language, "collectedAt": collected_at,
            "repositories": [{"id": i, "rank": n + 1} for n, i in enumerate(ids)]}


class HistoryTests(unittest.TestCase):
    def test_first_run_starts_a_history(self):
        h = merge(None, daily("2026-11-05T08:30:00+00:00", ["a/one", "b/two"]))
        self.assertEqual(h["days"], [{"date": "2026-11-05", "collectedAt": "2026-11-05T08:30:00+00:00", "ranks": {"a/one": 1, "b/two": 2}}])
        self.assertEqual((h["period"], h["languageFilter"], h["updatedAt"]), ("daily", "all", "2026-11-05T08:30:00+00:00"))
        self.assertEqual(history_name("Python"), "history-daily-python.json")

    def test_same_day_is_replaced_and_new_day_appended(self):
        h = merge(None, daily("2026-11-05T08:30:00+00:00", ["a/one"]))
        h = merge(h, daily("2026-11-05T16:50:00+00:00", ["b/two", "a/one"]))
        self.assertEqual([d["date"] for d in h["days"]], ["2026-11-05"])
        self.assertEqual(h["days"][0]["ranks"], {"b/two": 1, "a/one": 2})
        h = merge(h, daily("2026-11-06T00:10:00Z", ["a/one"]))
        self.assertEqual([d["date"] for d in h["days"]], ["2026-11-05", "2026-11-06"])

    def test_keeps_only_recent_days(self):
        h = None
        for day in range(1, 21):
            h = merge(h, daily(f"2026-11-{day:02d}T12:00:00+00:00", ["a/one"]))
        self.assertEqual(len(h["days"]), HISTORY_DAYS)
        self.assertEqual(h["days"][0]["date"], "2026-11-07")
        self.assertEqual(h["days"][-1]["date"], "2026-11-20")

    def test_an_older_kept_list_does_not_drop_a_newer_day(self):
        h = merge(None, daily("2026-11-06T08:00:00+00:00", ["a/one"]))
        h = merge(h, daily("2026-11-05T08:00:00+00:00", ["b/two"]))  # collection failed, previous list kept
        self.assertEqual([d["date"] for d in h["days"]], ["2026-11-05", "2026-11-06"])
        self.assertEqual(h["updatedAt"], "2026-11-06T08:00:00+00:00")

    def test_invalid_or_foreign_previous_history_is_ignored(self):
        good = merge(None, daily("2026-11-05T08:00:00+00:00", ["a/one"]))
        for previous in [{"schemaVersion": 2, "days": []}, {"schemaVersion": 1, "period": "daily", "languageFilter": "Go", "days": good["days"]},
                         "broken", dict(good, days=[{"date": "nope", "collectedAt": "x", "ranks": {}}, {"date": "2026-11-04", "collectedAt": "2026-11-04T01:00:00+00:00", "ranks": {"a/one": 0}}])]:
            h = merge(previous, daily("2026-11-06T08:00:00+00:00", ["c/three"]))
            self.assertEqual([d["date"] for d in h["days"]], ["2026-11-06"], previous)

    def test_weekly_lists_are_refused(self):
        with self.assertRaises(ValueError):
            merge(None, dict(daily("2026-11-06T08:00:00+00:00", ["a/one"]), period="weekly"))


if __name__ == "__main__":
    unittest.main()
