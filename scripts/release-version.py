"""Version and build for a release tag, checked against the published appcast.

    python3 scripts/release-version.py v0.5.7 published-appcast.xml   # prints version=0.5.7 and build=12

The tag must be vMAJOR.MINOR.PATCH and newer than the published version; the build
number is the published build plus one, so Sparkle always sees a higher CFBundleVersion.
"""
import re
import sys
import xml.etree.ElementTree as ET

SPARKLE = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'


def published(appcast_xml):
    """(version, build) of the newest item in a Sparkle appcast."""
    root = ET.fromstring(appcast_xml)
    best = None
    for item in root.iter('item'):
        version = item.findtext(SPARKLE + 'shortVersionString')
        build = item.findtext(SPARKLE + 'version')
        if not version or not build or not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[1-9]\d*', build):
            raise ValueError('Appcast item without a valid version and build')
        if best is None or int(build) > best[1]:
            best = (version, int(build))
    if best is None:
        raise ValueError('Appcast has no items')
    return best


def next_release(tag, appcast_xml):
    match = re.fullmatch(r'v(\d+)\.(\d+)\.(\d+)', tag)
    if not match:
        raise ValueError(f'Tag {tag!r} is not vMAJOR.MINOR.PATCH')
    version = '.'.join(match.groups())
    old_version, old_build = published(appcast_xml)
    if tuple(map(int, match.groups())) <= tuple(map(int, old_version.split('.'))):
        raise ValueError(f'{version} is not newer than the published {old_version}')
    return version, old_build + 1


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[2], 'rb') as file:
        version, build = next_release(sys.argv[1], file.read())
    print(f'version={version}')
    print(f'build={build}')


if __name__ == '__main__':
    main()
