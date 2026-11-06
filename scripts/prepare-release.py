"""Build one authenticated archive, a Sparkle feed, and a Homebrew cask.

No network, upload, paid service, or credentials are configured by this command.
"""
import argparse
import base64
from datetime import datetime, timezone
from email.utils import format_datetime
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import xml.etree.ElementTree as ET

SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', SPARKLE)


def release_metadata(info, repository, public_key):
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Invalid distribution repository')
    version, build = info['CFBundleShortVersionString'], info['CFBundleVersion']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version) or not re.fullmatch(r'[1-9]\d*', build):
        raise ValueError('Invalid release version/build')
    feed = f'https://github.com/{repository}/releases/latest/download/appcast.xml'
    if info.get('SUFeedURL') != feed or info.get('SUPublicEDKey') != public_key:
        raise ValueError('Built app feed/key does not match this release; rebuild first')
    if len(base64.b64decode(public_key, validate=True)) != 32:
        raise ValueError('Invalid Ed25519 public key')
    return dict(version=version, build=build, feed=feed, repository=repository,
                filename=f'GitMorning-{version}-arm64.zip')


def appcast(metadata, archive, signature, notes):
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Invalid Ed25519 signature')
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'GitMorning Updates'
    ET.SubElement(channel, 'link').text = f'https://github.com/{metadata["repository"]}'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'GitMorning {metadata["version"]}'
    ET.SubElement(item, 'pubDate').text = format_datetime(datetime.now(timezone.utc))
    ET.SubElement(item, 'description').text = notes
    for name, value in [('version', metadata['build']), ('shortVersionString', metadata['version']),
                        ('minimumSystemVersion', '14.0'), ('hardwareRequirements', 'arm64')]:
        ET.SubElement(item, f'{{{SPARKLE}}}{name}').text = value
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/{metadata["repository"]}/releases/download/v{metadata["version"]}/{archive.name}',
        'length': str(archive.stat().st_size), 'type': 'application/octet-stream',
        f'{{{SPARKLE}}}edSignature': signature,
    })
    ET.indent(root)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)


def cask(metadata, checksum):
    if not re.fullmatch('[a-f0-9]{64}', checksum):
        raise ValueError('Cask requires the actual archive SHA-256')
    return f'''cask "gitmorning" do
  version "{metadata['version']},{metadata['build']}"
  sha256 "{checksum}"

  url "https://github.com/{metadata['repository']}/releases/download/v#{{version.csv.first}}/GitMorning-#{{version.csv.first}}-arm64.zip"
  name "GitMorning"
  desc "Explore GitHub Trending and read original descriptions"
  homepage "https://github.com/{metadata['repository']}"

  livecheck do
    url "{metadata['feed']}"
    strategy :sparkle
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "GitMorning.app"
  uninstall quit: "dev.gitmorning.prototype"

  caveats <<~EOS
    On-device summaries require macOS 26+ and enabled Apple Intelligence.
    Free preview builds are ad-hoc signed and may require macOS approval at first launch.
  EOS
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path('dist/GitMorning.app'))
    parser.add_argument('--repository', required=True, help='Public distribution repo, e.g. owner/gitmorning')
    parser.add_argument('--key-file', type=Path, required=True)
    parser.add_argument('--signing-tool', type=Path, default=Path('.build/release-signing'))
    parser.add_argument('--notes', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    with (args.app / 'Contents/Info.plist').open('rb') as file:
        info = plistlib.load(file)
    framework = args.app / 'Contents/Frameworks/Sparkle.framework'
    if not framework.is_dir():
        raise ValueError('Cannot release a build without Sparkle')
    with (framework / 'Resources/Info.plist').open('rb') as file:
        if plistlib.load(file).get('CFBundleShortVersionString') != '2.10.1':
            raise ValueError('Release requires the pinned official Sparkle 2.10.1 dependency')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(args.app)], check=True)
    architectures = subprocess.check_output(['lipo', '-archs', str(args.app / 'Contents/MacOS/GitMorning')], text=True).strip()
    if architectures != 'arm64':
        raise ValueError('This release/cask supports arm64 only')
    tool = str(args.signing_tool.resolve())
    public_key = subprocess.check_output([tool, 'public-key', str(args.key_file)], text=True).strip()
    metadata = release_metadata(info, args.repository, public_key)
    args.output.mkdir(parents=True, exist_ok=True)
    archive = args.output / metadata['filename']
    if archive.exists():
        raise ValueError('Archive already exists; use a new output folder and never replace a published version')
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(args.app), str(archive)], check=True)
    signature = subprocess.check_output([tool, 'sign', str(args.key_file), str(archive)], text=True).strip()
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    (args.output / 'appcast.xml').write_bytes(appcast(metadata, archive, signature, args.notes.read_text()))
    (args.output / 'Casks').mkdir(exist_ok=True)
    (args.output / 'Casks/gitmorning.rb').write_text(cask(metadata, checksum))
    (args.output / 'SHA256SUMS').write_text(f'{checksum}  {archive.name}\n')
    metadata.update(sha256=checksum, publicKey=public_key, signature=signature)
    (args.output / 'release.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('Prepared release archive, signed appcast, SHA256SUMS, and Homebrew cask. Nothing uploaded.')


if __name__ == '__main__':
    main()
