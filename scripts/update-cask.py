"""Update the Homebrew cask and release records from a published release's files.

    python3 scripts/update-cask.py --appcast appcast.xml --sums SHA256SUMS --repository owner/gitmorning

Writes Casks/gitmorning.rb (version, build, SHA-256), distribution/appcast.xml, and the
published-versions line in distribution/README.md. Run by .github/workflows/release-cask.yml.
"""
import argparse
import importlib.util
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def _load(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = _load('prepare_release', 'prepare-release.py')
versions = _load('release_version', 'release-version.py')


def checksum_for(sums, filename):
    for line in sums.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[1] == filename and re.fullmatch('[a-f0-9]{64}', parts[0]):
            return parts[0]
    raise ValueError(f'SHA256SUMS has no checksum for {filename}')


def add_version(readme, version):
    """Appends `version` to the "Published versions:" line once."""
    match = re.search(r'Published versions: ([^\n]*?)\.\n', readme)
    if not match:
        raise ValueError('distribution/README.md has no "Published versions:" line')
    listed = [v.strip() for v in match.group(1).split(',')]
    if version in listed:
        return readme
    return readme[:match.start(1)] + ', '.join(listed + [version]) + readme[match.end(1):]


def update(root, appcast_xml, sums, repository):
    version, build = versions.published(appcast_xml)
    metadata = dict(version=version, build=str(build), repository=repository,
                    feed=f'https://github.com/{repository}/releases/latest/download/appcast.xml')
    checksum = checksum_for(sums, f'GitMorning-{version}-arm64.zip')
    (root / 'Casks/gitmorning.rb').write_text(release.cask(metadata, checksum))
    (root / 'distribution/appcast.xml').write_bytes(appcast_xml)
    readme = root / 'distribution/README.md'
    readme.write_text(add_version(readme.read_text(), version))
    return version, build, checksum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--appcast', type=Path, required=True)
    parser.add_argument('--sums', type=Path, required=True)
    parser.add_argument('--repository', required=True)
    args = parser.parse_args()
    version, build, checksum = update(ROOT, args.appcast.read_bytes(), args.sums.read_text(), args.repository)
    print(f'version={version}')
    print(f'build={build}')
    print(f'sha256={checksum}')


if __name__ == '__main__':
    main()
