"""Build the GitMorning website at the root of the Pages site (the feed lives under v1/).

Copies web/ (including the hero videos in web/media/, rendered from media/readme-demo) and the
screenshots from docs/, and fills in the latest released version from
distribution/appcast.xml (updated by release-cask.yml after each release). Standalone for a
local preview, without collecting anything:

    python3 feed/landing.py --output /tmp/gitmorning-site && python3 -m http.server -d /tmp/gitmorning-site
"""
import argparse
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SITE = "https://ddingddong9.github.io/gitmorning/"
SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
# Published path under assets/ → source in the repository.
ASSETS = {
    "icon.png": "docs/assets/icon.png",
    "morning-brief.png": "docs/morning-brief.png",
    "morning-brief-ko.png": "docs/morning-brief-ko.png",
    "social-preview.png": "docs/social-preview.png",
}


def released_version(appcast):
    """The newest version in the appcast (highest build), e.g. "0.5.7"."""
    items = ET.parse(appcast).getroot().iter("item")
    newest = max(items, key=lambda item: int(item.findtext(SPARKLE + "version") or 0))
    version = newest.findtext(SPARKLE + "shortVersionString")
    if not version:
        raise ValueError(f"{appcast}: newest item has no shortVersionString")
    return version


def site_url(root=ROOT):
    """The site's public address: the custom domain in web/CNAME once one is connected, else GitHub Pages."""
    cname = root / "web/CNAME"
    domain = cname.read_text(encoding="utf-8").strip().lower() if cname.exists() else ""
    if not domain:
        return DEFAULT_SITE
    if "/" in domain or ":" in domain or " " in domain or "." not in domain:
        raise ValueError(f"web/CNAME must hold only a domain such as gitmorning.app, not {domain!r}")
    return f"https://{domain}/"


def build(output, root=ROOT):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    version = released_version(root / "distribution/appcast.xml")
    url = site_url(root)
    for source in (root / "web").iterdir():
        target = output / source.name
        if source.name == "CNAME":
            continue  # a setting for this build; Pages takes the domain from the repository settings
        if source.name == "index.html":
            page = source.read_text(encoding="utf-8").replace("{{VERSION}}", version).replace("{{SITE_URL}}", url)
            target.write_text(page, encoding="utf-8")
        elif source.is_dir():
            shutil.copytree(source, target, dirs_exist_ok=True)  # media/: hero videos and posters
        else:
            shutil.copyfile(source, target)
    (output / "assets").mkdir(exist_ok=True)
    for name, source in ASSETS.items():
        shutil.copyfile(root / source, output / "assets" / name)
    return version


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", default="site")
    args = parser.parse_args()
    print(f"website for {build(args.output)} written to {args.output}")


if __name__ == "__main__":
    main()
