"""Surface a filtered tool log as ONE workflow annotation.

Annotations are readable through the checks API without downloading job logs.
Only tool findings are emitted (analyzer issues, failing test names and the
first line of each failure); anything shaped like a token or key is redacted.
Usage: annotate.py <title> <log-file> [full]
"""
import base64
import gzip
import re
import sys
from pathlib import Path

LIMIT = 60000
INTERESTING = re.compile(
    r'(error|warning|info) [•-] |issues? found|Some tests failed|All tests passed|'
    r'^(FAIL|ERROR): |^Ran \d+ tests|^OK\b|^FAILED|AssertionError|\[E\]|'
    r'Expected: |Actual: |Which: |^\d+:\d+ \+\d+.* -\d+: .*\[E\]|'
    r'Failed assertion|❌|\(failed\)|\(skipped\)|^::error|Error: |The following .* was thrown|Because .* depends|version solving failed', re.I)
SECRET = re.compile(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_.-]+|sb_[a-z]+_[A-Za-z0-9_-]{8,}|'
                    r'(?:password|token|apikey|secret|authorization)\S*\s*[:=]\s*\S+', re.I)


def main():
    title, path = sys.argv[1], Path(sys.argv[2])
    full = len(sys.argv) > 3 and sys.argv[3] == 'full'
    if not path.exists():
        print(f'::notice title={title}::no file')
        return
    lines = path.read_text(errors='replace').splitlines()
    if not full:
        keep = set()
        for index, line in enumerate(lines):
            if INTERESTING.search(line):
                keep.add(index)
                # Framework errors put the actual reason on the following lines.
                if 'was thrown' in line or 'Failed assertion' in line:
                    keep.update(range(index, min(len(lines), index + 12)))
        lines = [lines[i][:300] for i in sorted(keep)] or ['(no findings)']
    if full:
        # Annotation messages are capped near 4 KB: ship the exact file as
        # gzip+base64 chunks (reassemble in title order).
        text = base64.b64encode(gzip.compress(path.read_bytes(), 9)).decode()
    else:
        text = SECRET.sub('[redacted]', '\n'.join(lines))[:LIMIT]
    chunk = 3800
    parts = [text[i:i + chunk] for i in range(0, len(text), chunk)] or ['']
    for number, part in enumerate(parts, 1):
        encoded = part.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        label = title if len(parts) == 1 else f'{title} {number:02d}/{len(parts):02d}'
        print(f'::notice title={label}::{encoded}')


if __name__ == '__main__':
    main()
