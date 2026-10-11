"""Surface a filtered tool log as ONE workflow annotation.

Annotations are readable through the checks API without downloading job logs.
Only tool findings are emitted (analyzer issues, failing test names and the
first line of each failure); anything shaped like a token or key is redacted.
Usage: annotate.py <title> <log-file> [full]
"""
import re
import sys
from pathlib import Path

LIMIT = 60000
INTERESTING = re.compile(
    r'(error|warning|info) [•-] |issues? found|Some tests failed|All tests passed|'
    r'^(FAIL|ERROR): |^Ran \d+ tests|^OK\b|^FAILED|AssertionError|\[E\]|'
    r'Expected: |Actual: |Which: |^\d+:\d+ \+\d+.* -\d+: .*\[E\]|'
    r'❌|\(failed\)|\(skipped\)|^::error|Error: |The following .* was thrown|Because .* depends|version solving failed', re.I)
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
        lines = [line[:300] for line in lines if INTERESTING.search(line)] or ['(no findings)']
    text = SECRET.sub('[redacted]', '\n'.join(lines))[:LIMIT]
    encoded = text.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
    print(f'::notice title={title}::{encoded}')


if __name__ == '__main__':
    main()
