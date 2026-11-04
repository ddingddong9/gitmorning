# Copied from the GitMorning app repository (pipeline/collect.py). Edit it there, then copy here;
# the app repository CI checks that both copies match.
"""Read the canonical Trending page and publish a validated, atomic JSON snapshot.

No credentials are needed for Trending. GITHUB_TOKEN is used only with the
GitHub API (README reads), never with page requests.
"""
import argparse
import base64
from datetime import datetime, timezone
import html as html_text
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


README_EXCERPT_LIMIT = 320
_FENCE = re.compile(r"^(```|~~~).*?^\1[^\n]*$", re.M | re.S)
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_FRONT_MATTER = re.compile(r"\A---\n.*?\n---\n", re.S)
_IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)|!\[[^\]]*\]\[[^\]]*\]")
_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)|\[([^\]]*)\]\[[^\]]*\]")
_TAG = re.compile(r"</?[A-Za-z][^>]*>")
_REFERENCE = re.compile(r"^\s*\[[^\]]+\]:\s*\S+", re.M)
_CJK = re.compile(r"[぀-ヿ㐀-鿿가-힯]")
_SKIP_START = ("#", "|", "- [", "* [", "[!", "$ ", "> [!", "=", "---", "***", "```", "~~~")
_SKIP_WORDS = ("table of contents", "contents", "installation", "install", "getting started", "quick start", "license", "documentation")


def _inline(text):
    """Markdown/HTML paragraph to plain text: keep link text, drop images, tags, emphasis and code ticks."""
    text = _IMAGE.sub("", text)
    text = _LINK.sub(lambda m: m.group(1) if m.group(1) is not None else m.group(2), text)
    text = _TAG.sub(" ", text)
    text = re.sub(r"(\*\*|__)(.+?)\1", r"\2", text)
    text = re.sub(r"(?<![\w*])([*_])(?!\s)(.+?)(?<!\s)\1(?![\w*])", r"\2", text)
    text = text.replace("`", "")
    text = re.sub(r"^\s*>\s?", "", text, flags=re.M)
    return re.sub(r"\s+", " ", html_text.unescape(text)).strip()


def _readable(line, raw):
    if not line or raw.lstrip().startswith(_SKIP_START) or re.match(r"^\s*(\d+\.|[-*+])\s", raw):
        return False
    if line.casefold().rstrip(":") in _SKIP_WORDS or line.count(" | ") >= 2 or line.count(" · ") >= 3:
        return False  # headings written as text, language switchers, link bars
    letters = sum(ch.isalpha() for ch in line)
    if letters < len(line) * 0.5:
        return False  # mostly symbols, commands or URLs
    cjk = len(_CJK.findall(line))
    return len(line) >= 40 or cjk >= 12


def _shorten(text, limit=README_EXCERPT_LIMIT):
    if len(text) <= limit:
        return text
    cut = text[:limit]
    stops = [cut.rfind(mark) + 1 for mark in (". ", "! ", "? ", "。", "！", "？")]
    stop = max(stops)
    if stop >= limit * 0.5:
        return cut[:stop].strip()
    space = cut.rfind(" ")
    return (cut[:space] if space >= limit * 0.6 else cut).rstrip(" ,;:-") + "…"


_SEPARATOR = re.compile(r"\s[•·|–—-]\s")
_URL_ONLY = re.compile(r"^\s*<?https?://\S+>?\s*$")
_SKIP_PHRASES = ("follow ", "join ", "check out", "star ", "⭐", "🎉", "sponsor", "if you like", "please star", "read this in", "english |")


def _noise(raw):
    """A line that carries no description: link bars, badge rows, language switchers, bare URLs."""
    if _URL_ONLY.match(raw):
        return True
    links = len(_LINK.findall(raw)) + len(_IMAGE.findall(raw)) + len(re.findall(r"<a\s", raw, re.I))
    rest = _inline(re.sub(r"<a\s.*?</a>", " ", _LINK.sub(" ", _IMAGE.sub(" ", raw)), flags=re.I | re.S))
    if links >= 2 and sum(ch.isalpha() for ch in rest) < 12:
        return True
    line = _inline(raw)
    return len(_SEPARATOR.findall(line)) >= 3 or line.casefold().startswith(_SKIP_PHRASES)


def readme_excerpt(markdown, description=""):
    """The first one or two descriptive paragraphs of a README, as plain text.

    Skips badges, logos, headings, lists, tables, code, quotes (usually notices),
    link bars and anything that repeats the repository description. Returns None
    when nothing readable is found; the app then shows only the description.
    """
    text = _FRONT_MATTER.sub("", markdown.replace("\r\n", "\n"))
    text = _FENCE.sub("\n", _COMMENT.sub("", text))
    text = _REFERENCE.sub("", text)
    paragraphs, block = [], []
    for raw in text.split("\n"):
        if raw.strip():
            block.append(raw)
        elif block:
            paragraphs.append(block); block = []
    if block:
        paragraphs.append(block)
    picked, known = [], description.casefold().strip()
    for block in paragraphs:
        if block[0].lstrip().startswith(">") or "<sub>" in "".join(block) or _noise("\n".join(block)):
            continue  # notices, image captions, link bars written across lines
        lines = []
        for b in block:
            if lines and re.match(r"^\s*(\d+[.)]|[-*+])\s", b):
                break  # a list starts; keep only the lead-in prose
            if not _noise(b):
                lines.append(re.sub(r"^\s*>\s?", "", b))
        if not lines:
            continue
        raw = " ".join(lines)
        structural = raw.lstrip().startswith(("#", "|")) or (len(lines) > 1 and all(b.lstrip().startswith(("- ", "* ", "|", "#")) for b in lines))
        line = "" if structural else _inline(raw)
        if structural or not _readable(line, raw) or _noise(line):
            if picked:
                break
            continue
        folded = line.casefold()
        if known and (folded in known or (known in folded and len(folded) - len(known) < 20) or folded[:60] == known[:60]):
            continue  # repeats the description
        picked.append(line)
        if sum(len(p) for p in picked) >= 120 or len(picked) == 2:
            break
    if not picked:
        return None
    text = re.sub(r"\s+([.,;:!?])", r"\1", " ".join(picked))
    text = re.sub(r"[:：]$", ".", text)
    return _shorten(text)


def readme_markdown(full_name, etag=None):
    """GitHub's README for a repository as raw Markdown.

    Returns (status, etag, text): 200 with new text, 304 when unchanged since
    ``etag`` (free with a token), or 404 when the repository has no README.
    """
    if not REPO_PATH.fullmatch("/" + full_name):
        raise CollectionError("Invalid repository identity")
    headers = {"User-Agent": "GitMorning/0.2 (README excerpt)", "Accept": "application/vnd.github.raw", "X-GitHub-Api-Version": "2022-11-28"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    if etag:
        headers["If-None-Match"] = etag
    url = "https://api.github.com/repos/" + full_name + "/readme"
    try:
        with urllib.request.build_opener(NoRedirect()).open(urllib.request.Request(url, headers=headers), timeout=25) as response:
            data = response.read(500_001)
            if len(data) > 500_000:
                raise CollectionError("README is too large")
            return 200, response.headers.get("ETag"), data.decode("utf-8", errors="replace")
    except urllib.error.HTTPError as exc:
        if exc.code in (304, 404):
            return exc.code, etag if exc.code == 304 else None, None
        raise CollectionError("GitHub returned HTTP " + str(exc.code)) from None
    except (urllib.error.URLError, TimeoutError):
        raise CollectionError("README request failed") from None


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
