"""Daily Trending rank history for the shared feed.

The feed keeps one file per daily list, `history-daily-<language>.json`, with the
rank of every repository for each of the last HISTORY_DAYS days (UTC dates). The
app uses it to show how long a project has been trending and how its rank moved.
Each feed run replaces today's entry with its newest list, so a day records the
last list collected that day.
"""
from datetime import date, datetime, timedelta

HISTORY_DAYS = 14


def history_name(language):
    return "history-daily-" + language.lower() + ".json"


def _day(collected_at):
    return datetime.fromisoformat(collected_at.replace("Z", "+00:00")).date()


def _valid_days(previous, language):
    """Days from a previously published history, or [] when it is missing, malformed, or for another list."""
    if not isinstance(previous, dict) or previous.get("schemaVersion") != 1 or previous.get("period") != "daily" \
            or previous.get("languageFilter") != language or not isinstance(previous.get("days"), list):
        return []
    days = []
    for entry in previous["days"]:
        try:
            date.fromisoformat(entry["date"])
            _day(entry["collectedAt"])
            ranks = entry["ranks"]
            if isinstance(ranks, dict) and all(isinstance(k, str) and isinstance(v, int) and v > 0 for k, v in ranks.items()):
                days.append({"date": entry["date"], "collectedAt": entry["collectedAt"], "ranks": ranks})
        except (KeyError, TypeError, ValueError):
            continue
    return days


def merge(previous, payload, keep=HISTORY_DAYS):
    """The history with `payload` (a daily snapshot) recorded for its UTC date, trimmed to `keep` days."""
    if payload.get("period") != "daily":
        raise ValueError("history is kept for daily lists only")
    language = payload["languageFilter"]
    today = _day(payload["collectedAt"])
    entry = {"date": today.isoformat(), "collectedAt": payload["collectedAt"],
             "ranks": {repo["id"]: repo["rank"] for repo in payload["repositories"]}}
    days = [d for d in _valid_days(previous, language) if d["date"] != entry["date"]]
    # Keep a newer day from the previous file if this run published an older, kept list.
    days.append(entry)
    oldest = (max(date.fromisoformat(d["date"]) for d in days) - timedelta(days=keep - 1)).isoformat()
    days = sorted((d for d in days if d["date"] >= oldest), key=lambda d: d["date"])
    latest = max(days, key=lambda d: d["collectedAt"])
    return {"schemaVersion": 1, "period": "daily", "languageFilter": language,
            "updatedAt": latest["collectedAt"], "days": days}
