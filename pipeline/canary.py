"""Check that the live Trending page still parses into a plausible snapshot.

Run daily by .github/workflows/trending-canary.yml so a GitHub layout change, or a
stopped shared feed, is noticed before users see empty or degraded lists. Exits non-zero with a short
reason on failure. Makes two unauthenticated page requests and writes nothing.

    python -m pipeline.canary
"""
from datetime import datetime, timezone
import json
import sys
import urllib.request

from pipeline.collect import CollectionError, request, snapshot, trending_url

MIN_ROWS = 5
MIN_METRIC_RATIO = 0.8
FEED_MANIFEST = "https://ddingddong9.github.io/gitmorning/v1/manifest.json"
MAX_FEED_AGE_HOURS = 8  # same as the app (TrendingSource.maxFeedAge); GitHub runs the hourly schedule every few hours
FEED_FILES = 14


def check(period):
    payload = snapshot(request(trending_url(period)), period)
    rows = payload["repositories"]
    if len(rows) < MIN_ROWS:
        raise CollectionError(f"{period}: only {len(rows)} rows (expected at least {MIN_ROWS})")
    # Metrics are optional per row, but losing most of them means the markup changed.
    for field in ("stars", "periodStars", "language"):
        known = sum(row[field] is not None for row in rows)
        if known < len(rows) * MIN_METRIC_RATIO:
            raise CollectionError(f"{period}: {field} recognized for only {known}/{len(rows)} rows")
    return f"{period}: {len(rows)} rows OK"


def check_feed(manifest=None, now=None):
    """The shared feed must list every file, each collected within the age the app accepts."""
    if manifest is None:
        try:
            with urllib.request.urlopen(FEED_MANIFEST, timeout=20) as response:
                manifest = json.loads(response.read(1_000_000))
        except (OSError, ValueError) as exc:
            raise CollectionError(f"shared feed manifest unavailable ({exc.__class__.__name__})") from None
    now = now or datetime.now(timezone.utc)
    files = manifest.get("files", {})
    if len(files) < FEED_FILES:
        raise CollectionError(f"shared feed lists {len(files)}/{FEED_FILES} files")
    old = sorted(name for name, item in files.items()
                 if (now - datetime.fromisoformat(item["collectedAt"])).total_seconds() > MAX_FEED_AGE_HOURS * 3600)
    if old:
        raise CollectionError(f"shared feed older than {MAX_FEED_AGE_HOURS}h: {', '.join(old)} (apps are reading GitHub directly)")
    return f"shared feed: {len(files)} files fresh"


def main():
    failures = []
    for check_one in (lambda: check("daily"), lambda: check("weekly"), check_feed):
        try:
            print(check_one())
        except CollectionError as exc:
            failures.append(str(exc))
    if failures:
        print("Trending canary failed:\n" + "\n".join(failures), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
