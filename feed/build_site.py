"""Build the public GitMorning Trending feed for GitHub Pages.

Collects every period/language page once, writes v1/<period>-<language>.json in
the app's data contract, and a manifest. A page that fails to collect keeps the
previously published file (its collectedAt stays old, so apps can see its age),
so one bad response never blanks a list. The app falls back to reading GitHub
Trending directly when this feed is missing or stale.

    python feed/build_site.py --output site
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))
from collect import LANGUAGES, PERIODS, CollectionError, publish, request, snapshot, trending_url  # noqa: E402

PUBLISHED = "https://ddingddong9.github.io/gitmorning/v1/"


def previous(name):
    """The currently published file, if it is still a valid snapshot."""
    try:
        with urllib.request.urlopen(PUBLISHED + name, timeout=20) as response:
            payload = json.loads(response.read(3_000_000))
        if payload.get("schemaVersion") == 1 and payload.get("status") == "complete" and payload.get("repositories"):
            return payload
    except (OSError, ValueError):
        pass
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="site")
    args = parser.parse_args()
    directory = Path(args.output) / "v1"
    files, fresh, kept, missing = {}, 0, 0, []
    for period in sorted(PERIODS):
        for language in LANGUAGES:
            name = period + "-" + language.lower() + ".json"
            try:
                payload = snapshot(request(trending_url(period, language)), period, language)
                fresh += 1
            except CollectionError as exc:
                payload = previous(name)
                print(f"{name}: collection failed ({exc}); " + ("kept previous" if payload else "no previous file"), file=sys.stderr)
                if payload is None:
                    missing.append(name)
                    continue
                kept += 1
            publish(payload, directory)
            files[name] = {"collectedAt": payload["collectedAt"], "count": len(payload["repositories"])}
            time.sleep(1)  # Be gentle with github.com.
    if not files:
        sys.exit("No snapshot could be collected or kept; not publishing an empty feed.")
    manifest = {"schemaVersion": 1, "generatedAt": datetime.now(timezone.utc).isoformat(), "files": files}
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (Path(args.output) / "index.html").write_text(
        "<!doctype html><meta charset=utf-8><title>GitMorning feed</title>"
        "<p>Public GitHub Trending snapshots for the GitMorning Mac app: <a href=v1/manifest.json>v1/manifest.json</a>.</p>\n",
        encoding="utf-8")
    print(f"fresh {fresh}, kept {kept}, missing {len(missing)}")


if __name__ == "__main__":
    main()
