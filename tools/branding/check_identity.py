"""Guard public identity and stable Android/OAuth identifiers across future merges."""
from pathlib import Path
import re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
old='\u0631\u062d\u0645\u0627\u0621'
files=list((ROOT/'app/lib').rglob('*.dart'))+list((ROOT/'site').rglob('*.html'))
for p in files:
    s=p.read_text()
    assert old not in s,f'Old Arabic display name in {p}'
    assert not re.search(r'(?<![\w/\\])Ruhamaa(?![\w/\\]|\.[a-zA-Z])',s),f'Old Latin display name in {p}'
manifest=ET.parse(ROOT/'app/android/app/src/main/AndroidManifest.xml').getroot()
android='{http://schemas.android.com/apk/res/android}'
app=manifest.find('application')
assert app.get(android+'label')=='عطاء'
assert app.get(android+'icon')=='@drawable/ataa_launcher'
schemes={x.get(android+'scheme') for x in manifest.iter('data')}
assert 'com.ruhamaa.app' in schemes
assert 'applicationId = "com.ruhamaa.app"' in (ROOT/'app/android/app/build.gradle.kts').read_text()
assert (ROOT/'site/CNAME').read_text().strip()=='ruhamaa.com'
assert 'SYSTRAC.TECH' in (ROOT/'site/index.html').read_text()
for p in ['site/assets/ataa-mark.svg','site/assets/favicon.svg','app/android/app/src/main/res/drawable/ataa_launcher.xml']:ET.parse(ROOT/p)
print(f'PASS: {len(files)} public source files use Ataa; Android ID, OAuth callback, domain and SYSTRAC credit preserved.')
