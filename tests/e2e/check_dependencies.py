"""Query OSV for the exact hosted Dart versions resolved in this CI run.

Only package names and versions are sent. Network/format errors fail the gate.
This does not scan Gradle, native binaries, or unpublished vulnerabilities.
"""
import hashlib
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen

lock = Path('app/pubspec.lock').read_text()
packages = []
for name, block in re.findall(r'^  ([a-zA-Z0-9_]+):\n(.*?)(?=^  [a-zA-Z0-9_]+:|^sdks:|\Z)', lock, re.M | re.S):
    if re.search(r'^    source: hosted\s*$', block, re.M):
        version = re.search(r'^    version: ["\x27]?([^"\x27\s]+)', block, re.M)
        if not version:
            raise RuntimeError('Hosted package lacks version: ' + name)
        packages.append({'package': {'ecosystem': 'Pub', 'name': name}, 'version': version.group(1)})
if not packages:
    raise RuntimeError('No hosted Dart packages parsed; refusing an empty scan')
findings = []
pending = packages
while pending:
    req = Request('https://api.osv.dev/v1/querybatch', data=json.dumps({'queries': pending}).encode(), headers={'Content-Type': 'application/json'}, method='POST')
    with urlopen(req, timeout=60) as response:
        result = json.load(response)['results']
    if len(result) != len(pending):
        raise RuntimeError('OSV response length mismatch')
    next_queries = []
    for query, item in zip(pending, result):
        if item.get('vulns'):
            findings.append({'name': query['package']['name'], 'version': query['version'], 'vulnerabilities': item['vulns']})
        if item.get('next_page_token'):
            next_queries.append({**query, 'page_token': item['next_page_token']})
    pending = next_queries
out = {'source': 'OSV querybatch', 'ecosystem': 'Pub', 'package_count': len(packages), 'lock_sha256': hashlib.sha256(lock.encode()).hexdigest(), 'findings': findings}
Path('test-results').mkdir(exist_ok=True)
Path('test-results/dependencies.json').write_text(json.dumps(out, indent=2) + '\n')
Path('test-results/pubspec.lock').write_text(lock)
print(json.dumps({'packages_queried': len(packages), 'packages_with_advisories': len(findings)}))
raise SystemExit(1 if findings else 0)
