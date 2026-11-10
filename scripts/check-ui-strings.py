#!/usr/bin/env python3
"""Fail when an interface string passed to ui("…") has no Korean entry in Korean.json.

Strings built at run time (ui(variable)) cannot be checked here; keep their sources as
literals somewhere in Sources/GitMorning so this check sees them, or add them by hand.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = ROOT / 'Sources/GitMorning/Resources/Korean.json'
# Names and examples that read the same in every language.
UNTRANSLATED = {'GitHub', 'GitMorning', 'https://example.com/snapshots'}
LITERAL = re.compile(r'\bui\("((?:[^"\\]|\\.)*)"\)')


def missing(sources, table):
    found = {}
    for path in sources:
        for number, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
            for text in LITERAL.findall(line):
                if '\\' in text:  # escapes or interpolation: not a plain lookup key
                    continue
                if text not in table and text not in UNTRANSLATED and re.search(r'[A-Za-z]', text):
                    found.setdefault(text, f'{path.relative_to(ROOT)}:{number}')
    return found


def main():
    table = json.loads(TABLE.read_text(encoding='utf-8'))
    gaps = missing(sorted((ROOT / 'Sources/GitMorning').glob('*.swift')), table)
    for text, where in gaps.items():
        print(f'{where}: no Korean entry for "{text}"')
    if gaps:
        print(f'Add {len(gaps)} entr{"y" if len(gaps) == 1 else "ies"} to {TABLE.relative_to(ROOT)}.')
        return 1
    print(f'PASS: every ui("…") literal has a Korean entry ({len(table)} entries)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
