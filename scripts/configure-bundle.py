"""Set release identity without keeping credentials in the source tree."""
import base64
import os
from pathlib import Path
import plistlib
import re
import sys
from urllib.parse import urlsplit


def configure(path, environ):
    path = Path(path)
    with path.open('rb') as file:
        info = plistlib.load(file)
    if version := environ.get('GITMORNING_VERSION'):
        if not re.fullmatch(r'\d+\.\d+\.\d+', version):
            raise ValueError('Version must be major.minor.patch')
        info['CFBundleShortVersionString'] = version
    if build := environ.get('GITMORNING_BUILD'):
        if not re.fullmatch(r'[1-9]\d*', build):
            raise ValueError('Build must be a positive, monotonically increasing integer')
        info['CFBundleVersion'] = build
    feed = environ.get('GITMORNING_UPDATE_FEED', '')
    key = environ.get('GITMORNING_UPDATE_PUBLIC_KEY', '')
    if bool(feed) != bool(key):
        raise ValueError('Update feed and public key must be configured together')
    if feed:
        url = urlsplit(feed)
        if url.scheme != 'https' or not url.hostname or url.username or url.password or url.query or url.fragment:
            raise ValueError('Update feed must be a public HTTPS URL without credentials/query/fragment')
        if len(base64.b64decode(key, validate=True)) != 32:
            raise ValueError('Ed25519 public key must contain exactly 32 bytes')
        info.update(SUFeedURL=feed, SUPublicEDKey=key, SUEnableAutomaticChecks=True,
                    SUAutomaticallyUpdate=False, SUScheduledCheckInterval=86400,
                    SUVerifyUpdateBeforeExtraction=True, SUSendProfileInfo=False)
    if environ.get('GITMORNING_RELEASE') == '1':
        if environ.get('GITMORNING_CORE_ONLY') == '1' or not feed:
            raise ValueError('Release requires Sparkle, a real feed URL, and signing public key')
    with path.open('wb') as file:
        plistlib.dump(info, file)


if __name__ == '__main__':
    configure(sys.argv[1], os.environ)
