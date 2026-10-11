"""Idempotent display-name migration, safe to run after merging older feature branches.
Does not rename package IDs, auth/storage identifiers, URLs, email, or history.

Usage:
  python3 tools/branding/apply_identity.py            apply the changes (default)
  python3 tools/branding/apply_identity.py --check    change nothing; exit 1 if a file would change
  (--dry-run is an alias of --check)
"""
from pathlib import Path
import re,sys
ROOT=Path(__file__).resolve().parents[2]
FLAGS={'--check','--dry-run'}
unknown=[a for a in sys.argv[1:] if a not in FLAGS]
if unknown:raise SystemExit(f'Unknown argument(s): {" ".join(unknown)}. Usage: apply_identity.py [--check|--dry-run]')
CHECK=bool(sys.argv[1:])
HISTORY={'HANDOVER_AHMED_FATHI.md','WEBSITE_V2.md','FRAUD_SIMULATION_1000.md','IMPLEMENTATION_STATUS.md'}
# Documents that must keep the historical names verbatim because they explain them.
NAME_REFERENCE={'ATAA_IDENTITY.md','NAMING.md'}
pending=[]
def write(p,new):
    """Write in the default mode; only record the path in --check mode."""
    pending.append(p)
    if not CHECK:p.write_text(new)
def convert(text):
    text=text.replace('رحماء','عطاء')
    # Standalone prose only: preserve paths, package/import/class names and URLs.
    return re.sub(r'(?<![\w/\\])(?:Ruhamaa|Rohamaa)(?![\w/\\]|\.[a-zA-Z])','Ataa',text)
paths=[]
for parent in ['app/lib','app/test','app/integration_test','site','supabase/functions']:
    folder=ROOT/parent
    if folder.exists():paths.extend(p for p in folder.rglob('*') if p.suffix in {'.dart','.html','.ts'})
paths.extend([ROOT/'app/android/app/src/main/AndroidManifest.xml',ROOT/'app/README.md',ROOT/'README.md'])
paths.extend(p for p in (ROOT/'docs').glob('*.md') if p.name not in HISTORY and p.name not in NAME_REFERENCE)
for p in paths:
    old=p.read_text();new=convert(old)
    if new!=old:write(p,new)
for name in HISTORY:
    p=ROOT/'docs'/name
    if p.exists() and 'ATAA_IDENTITY.md' not in p.read_text():write(p,'> **تحديث الهوية:** اعتمد اسم «عطاء» (Ataa). هذه وثيقة تاريخية؛ راجع [الهوية الحالية وخطوات التوافق](ATAA_IDENTITY.md).\n\n'+p.read_text())
for p in (ROOT/'.github/workflows').glob('*.yml'):
    old=p.read_text()
    s=old.replace('Deploy Ruhamaa site','Deploy Ataa site').replace('ruhamaa-debug-apk','ataa-debug-apk').replace('ruhamaa-release-aab-','ataa-release-aab-')
    if s!=old:write(p,s)
if CHECK:
    for p in pending:print(f'would change: {p.relative_to(ROOT)}')
    if pending:raise SystemExit(f'FAIL: {len(pending)} file(s) still need the Ataa display identity. Run tools/branding/apply_identity.py without --check.')
    print('PASS: Ataa display identity already applied; no file would change.')
else:
    print('Applied Ataa display identity; technical identifiers and historical evidence retained.')
