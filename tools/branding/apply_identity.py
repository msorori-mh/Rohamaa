"""Idempotent display-name migration, safe to run after merging older feature branches.
Does not rename package IDs, auth/storage identifiers, URLs, email, or history.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
HISTORY={'HANDOVER_AHMED_FATHI.md','WEBSITE_V2.md','FRAUD_SIMULATION_1000.md','IMPLEMENTATION_STATUS.md'}
def convert(text):
    text=text.replace('رحماء','عطاء')
    # Standalone prose only: preserve paths, package/import/class names and URLs.
    return re.sub(r'(?<![\w/\\])(?:Ruhamaa|Rohamaa)(?![\w/\\]|\.[a-zA-Z])','Ataa',text)
paths=[]
for parent in ['app/lib','app/test','app/integration_test','site','supabase/functions']:
    folder=ROOT/parent
    if folder.exists():paths.extend(p for p in folder.rglob('*') if p.suffix in {'.dart','.html','.ts'})
paths.extend([ROOT/'app/android/app/src/main/AndroidManifest.xml',ROOT/'app/README.md',ROOT/'README.md'])
paths.extend(p for p in (ROOT/'docs').glob('*.md') if p.name not in HISTORY and p.name!='ATAA_IDENTITY.md')
for p in paths:
    old=p.read_text();new=convert(old)
    if new!=old:p.write_text(new)
for name in HISTORY:
    p=ROOT/'docs'/name
    if p.exists() and 'ATAA_IDENTITY.md' not in p.read_text():p.write_text('> **تحديث الهوية:** اعتمد اسم «عطاء» (Ataa). هذه وثيقة تاريخية؛ راجع [الهوية الحالية وخطوات التوافق](ATAA_IDENTITY.md).\n\n'+p.read_text())
for p in (ROOT/'.github/workflows').glob('*.yml'):
    s=p.read_text().replace('Deploy Ruhamaa site','Deploy Ataa site').replace('ruhamaa-debug-apk','ataa-debug-apk').replace('ruhamaa-release-aab-','ataa-release-aab-')
    p.write_text(s)
print('Applied Ataa display identity; technical identifiers and historical evidence retained.')
