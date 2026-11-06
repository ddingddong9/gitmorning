"""Build the public GitMorning Trending feed for GitHub Pages.

Collects every period/language page once, writes v1/<period>-<language>.json in
the app's data contract, and a manifest. A page that fails to collect keeps the
previously published file (its collectedAt stays old, so apps can see its age),
so one bad response never blanks a list. The app falls back to reading GitHub
Trending directly when this feed is missing or stale.

Daily lists also get history-daily-<language>.json: each repository's rank for
the last 14 days, so the app can show how long a project has been trending.

Each repository also gets a short readmeExcerpt: the first descriptive paragraph
of its README, so projects with a missing or one-line description still say
what they do. READMEs are read with the workflow's GITHUB_TOKEN and cached by
ETag in v1/readmes.json; unchanged READMEs cost nothing. A README failure only
leaves that excerpt as it was and never blocks publishing.

    python feed/build_site.py --output site
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from pipeline.collect import LANGUAGES, PERIODS, CollectionError, publish, readme_excerpt, readme_markdown, request, snapshot, trending_url  # noqa: E402
import hashlib  # noqa: E402
from pipeline.history import history_name, merge as merge_history  # noqa: E402

PUBLISHED = "https://ddingddong9.github.io/gitmorning/v1/"
README_CACHE = "readmes.json"
README_BUDGET = 300  # requests per run; 304s with a token are free, new READMEs are the cost


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


def previous_json(name):
    """Any currently published JSON file, or None."""
    try:
        with urllib.request.urlopen(PUBLISHED + name, timeout=20) as response:
            return json.loads(response.read(5_000_000))
    except (OSError, ValueError):
        return None


def previous_readmes():
    try:
        with urllib.request.urlopen(PUBLISHED + README_CACHE, timeout=20) as response:
            payload = json.loads(response.read(5_000_000))
        if payload.get("schemaVersion") == 1 and isinstance(payload.get("readmes"), dict):
            return payload["readmes"]
    except (OSError, ValueError):
        pass
    return {}


def add_readme_excerpts(payloads, cache):
    """Attach readmeExcerpt to every repository; returns the updated cache and counts."""
    descriptions = {}
    for payload in payloads:
        for entry in payload["repositories"]:
            descriptions.setdefault(entry["id"], entry.get("description", ""))
    updated, fetched, unchanged, failed = {}, 0, 0, 0
    for repo_id, description in descriptions.items():
        key = hashlib.sha256(description.encode()).hexdigest()[:16]
        cached = cache.get(repo_id) if isinstance(cache.get(repo_id), dict) else {}
        etag = cached.get("etag") if cached.get("descriptionKey") == key else None
        if fetched + unchanged >= README_BUDGET:
            updated[repo_id] = cached
            continue
        try:
            status, new_etag, markdown = readme_markdown(repo_id, etag)
            if status == 304:
                unchanged += 1
                updated[repo_id] = cached
            else:
                fetched += 1
                excerpt = readme_excerpt(markdown, description) if markdown else None
                updated[repo_id] = {"etag": new_etag, "descriptionKey": key, "excerpt": excerpt}
        except Exception as exc:  # noqa: BLE001 - a README problem must never block the feed
            failed += 1
            updated[repo_id] = cached
            print(f"{repo_id}: README skipped ({exc})", file=sys.stderr)
        time.sleep(0.1)
    for payload in payloads:
        for entry in payload["repositories"]:
            entry["readmeExcerpt"] = (updated.get(entry["id"]) or {}).get("excerpt")
    return updated, fetched, unchanged, failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="site")
    args = parser.parse_args()
    directory = Path(args.output) / "v1"
    collected, fresh, kept, missing = [], 0, 0, []
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
            collected.append((name, payload))
            time.sleep(1)  # Be gentle with github.com.
    readmes, fetched, unchanged, failed = add_readme_excerpts([payload for _, payload in collected], previous_readmes())
    files = {}
    for name, payload in collected:
        publish(payload, directory)
        files[name] = {"collectedAt": payload["collectedAt"], "count": len(payload["repositories"])}
    if not files:
        sys.exit("No snapshot could be collected or kept; not publishing an empty feed.")
    # Daily rank history: one file per daily list, the last 14 days. A failure keeps the published file.
    histories = {}
    for name, payload in collected:
        if payload["period"] != "daily":
            continue
        history_file = history_name(payload["languageFilter"])
        previous_history = previous_json(history_file)
        try:
            history = merge_history(previous_history, payload)
        except (KeyError, TypeError, ValueError) as exc:
            print(f"{history_file}: not updated ({exc})", file=sys.stderr)
            history = previous_history
        if history:
            (directory / history_file).write_text(json.dumps(history, ensure_ascii=False) + "\n", encoding="utf-8")
            histories[history_file] = {"updatedAt": history["updatedAt"], "days": len(history["days"])}
    manifest = {"schemaVersion": 1, "generatedAt": datetime.now(timezone.utc).isoformat(), "files": files, "history": histories}
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (directory / README_CACHE).write_text(json.dumps({"schemaVersion": 1, "readmes": readmes}, ensure_ascii=False) + "\n", encoding="utf-8")
    (Path(args.output) / "index.html").write_text(
        "<!doctype html><meta charset=utf-8><title>GitMorning feed</title>"
        "<p>Public GitHub Trending snapshots for the GitMorning Mac app: <a href=v1/manifest.json>v1/manifest.json</a>.</p>\n",
        encoding="utf-8")
    print(f"fresh {fresh}, kept {kept}, missing {len(missing)}; READMEs fetched {fetched}, unchanged {unchanged}, failed {failed}")


if __name__ == "__main__":
    main()
