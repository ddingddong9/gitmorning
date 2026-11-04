# Copied from the GitMorning app repository (pipeline/collect.py). Edit it there, then copy here;
# the app repository CI checks that both copies match.
"""Read the canonical Trending page and publish a validated, atomic JSON snapshot.

No credentials are needed for Trending. GITHUB_TOKEN is used only with the
GitHub API when --readmes is explicitly requested, never with page requests.
"""
import argparse
import base64
from datetime import datetime, timezone
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import tempfile
import urllib.error
import urllib.parse
import urllib.request

LANGUAGES = {"all": "", "Python": "python", "TypeScript": "typescript", "JavaScript": "javascript", "Swift": "swift", "Go": "go", "Rust": "rust"}
PERIODS = {"daily", "weekly"}
REPO_PATH = re.compile(r"^/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$")
BLOCKED_TAGS = {"template", "script", "style", "dialog", "form"}
VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}


class CollectionError(ValueError):
    pass


MAX_DEPTH = 128
MAX_HTML_BYTES = 3_000_000


class Node:
    # Parsing rules are shared with Sources/GitMorningCore/TrendingReader.swift and
    # pinned by pipeline/tests/fixtures/parity. Change both parsers together.
    def __init__(self, tag="root", attrs=()):
        self.tag, self.children = tag, []
        self.attrs = {}
        for key, value in attrs:
            # First occurrence wins, as in browsers; valueless attributes are "".
            self.attrs.setdefault(key, value or "")

    @property
    def ignored(self):
        return self.tag in BLOCKED_TAGS or "hidden" in self.attrs or self.attrs.get("aria-hidden") == "true"

    def nodes(self, tag=None):
        for child in self.children:
            if isinstance(child, Node) and not child.ignored:
                if tag is None or child.tag == tag:
                    yield child
                yield from child.nodes(tag)

    def text(self):
        return " ".join(" ".join(child.text() if isinstance(child, Node) and not child.ignored else child if isinstance(child, str) else "" for child in self.children).split())


class TreeParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node()
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs)
        self.stack[-1].children.append(node)
        if tag not in VOID_TAGS:
            if len(self.stack) >= MAX_DEPTH:
                raise CollectionError("Trending page nesting is too deep")
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def number(value):
    """Digits with optional thousands separators; anything else is unknown (None), never zero."""
    cleaned = re.sub(r"[\s,]", "", value)
    return int(cleaned) if re.fullmatch(r"[0-9]+", cleaned) else None


def trending_url(period="daily", language="all"):
    if period not in PERIODS or language not in LANGUAGES:
        raise CollectionError("Unsupported period or language")
    slug = LANGUAGES[language]
    return "https://github.com/trending" + ("/" + slug if slug else "") + "?since=" + period


def parse_trending(html, period="daily"):
    if period not in PERIODS:
        raise CollectionError("Unsupported period")
    if len(html.encode("utf-8")) > MAX_HTML_BYTES:
        raise CollectionError("Response exceeds collection size limit")
    parser = TreeParser()
    parser.feed(html)
    parser.close()
    articles = [n for n in parser.root.nodes("article") if "Box-row" in n.attrs.get("class", "").split()]
    if not articles:
        raise CollectionError("No Trending rows found; page structure may have changed")
    entries, seen = [], set()
    for article in articles:
        heading = next(article.nodes("h2"), None)
        link = next(heading.nodes("a"), None) if heading else None
        match = REPO_PATH.fullmatch(link.attrs.get("href", "")) if link else None
        if not match:
            raise CollectionError("Trending row is missing its repository heading")
        owner, name = match.groups()
        full_name = owner + "/" + name
        if full_name.casefold() in seen:
            raise CollectionError("Duplicate repository in Trending snapshot")
        seen.add(full_name.casefold())
        description = next(article.nodes("p"), None)
        lang = next((n.text() for n in article.nodes() if n.attrs.get("itemprop") == "programmingLanguage"), None)
        stars = next((number(a.text()) for a in article.nodes("a") if a.attrs.get("href") == "/" + full_name + "/stargazers"), None)
        suffix = "today" if period == "daily" else "this week"
        period_stars = None
        for span in article.nodes("span"):
            found = re.fullmatch(r"([0-9, ]+) stars? " + suffix, span.text())
            if found:
                period_stars = number(found.group(1))
                break
        # Unknown metrics remain null; missing values never become zeros.
        entries.append({"id": full_name, "owner": owner, "name": name, "url": "https://github.com/" + full_name, "rank": len(entries) + 1, "description": description.text() if description else "", "language": lang, "stars": stars, "periodStars": period_stars, "summaryStatus": "pending"})
    return entries


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Do not forward credentials to redirects; retry a renamed repository
        # using a newly verified canonical identity in a future collection.
        raise CollectionError("Unexpected HTTP redirect; verify the source URL")


def request(url, *, api=False, limit=3_000_000):
    parts = urllib.parse.urlsplit(url)
    expected = "api.github.com" if api else "github.com"
    if parts.scheme != "https" or parts.hostname != expected or parts.username or parts.password or parts.port:
        raise CollectionError("Unapproved collection origin")
    headers = {"User-Agent": "GitMorning/0.2 (Trending reader)", "Accept": "application/vnd.github+json" if api else "text/html"}
    token = os.environ.get("GITHUB_TOKEN")
    if api and token:
        headers["Authorization"] = "Bearer " + token
    try:
        with urllib.request.build_opener(NoRedirect()).open(urllib.request.Request(url, headers=headers), timeout=25) as response:
            data = response.read(limit + 1)
            if len(data) > limit:
                raise CollectionError("Response exceeds collection size limit")
            return data.decode("utf-8")
    except urllib.error.HTTPError as exc:
        raise CollectionError("GitHub returned HTTP " + str(exc.code)) from None
    except (urllib.error.URLError, TimeoutError, UnicodeError):
        raise CollectionError("GitHub request failed; previous snapshot preserved") from None


def readme(full_name):
    if not REPO_PATH.fullmatch("/" + full_name):
        raise CollectionError("Invalid repository identity")
    data = json.loads(request("https://api.github.com/repos/" + full_name + "/readme", api=True, limit=1_000_000))
    if data.get("encoding") != "base64" or data.get("size", 0) > 200_000:
        raise CollectionError("README is unsupported or too large")
    content = base64.b64decode(data["content"]).decode("utf-8")
    return {"sha": data["sha"], "sourceURL": data["html_url"], "content": content, "summaryStatus": "pending"}


def snapshot(html, period="daily", language="all", collected_at=None):
    return {"schemaVersion": 1, "period": period, "languageFilter": language, "sourceURL": trending_url(period, language), "collectedAt": collected_at or datetime.now(timezone.utc).isoformat(), "status": "complete", "repositories": parse_trending(html, period)}


def publish(payload, directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, indent=2).encode()
    name = payload["period"] + "-" + payload["languageFilter"].lower() + ".json"
    # Replace only after parsing has fully succeeded. Readers see old or new,
    # never a half-written JSON file.
    fd, temporary = tempfile.mkstemp(prefix=".snapshot-", dir=directory)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, directory / name)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return directory / name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--period", choices=sorted(PERIODS), default="daily")
    parser.add_argument("--language", choices=LANGUAGES, default="all")
    parser.add_argument("--output", default="pipeline/output")
    parser.add_argument("--html", type=Path, help="Parse saved public HTML instead of making a network request")
    parser.add_argument("--readmes", action="store_true", help="Also save README sources for later summarization")
    args = parser.parse_args()
    try:
        html = args.html.read_text(encoding="utf-8") if args.html else request(trending_url(args.period, args.language))
        payload = snapshot(html, args.period, args.language)
        if args.readmes:
            sources = {}
            for entry in payload["repositories"]:
                try:
                    sources[entry["id"]] = readme(entry["id"])
                    entry["readmeStatus"] = "ready"
                except CollectionError:
                    entry["readmeStatus"] = "unavailable"
            payload["readmeSources"] = sources
        path = publish(payload, args.output)
        print(f"Saved {len(payload['repositories'])} repositories: {path}")
    except (CollectionError, OSError, ValueError, KeyError) as exc:
        parser.exit(1, "Collection failed: " + str(exc) + "\n")


if __name__ == "__main__":
    main()
