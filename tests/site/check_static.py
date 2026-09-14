"""Validate the static site's internal links and document structure, no dependencies."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2] / 'site'
class Document(HTMLParser):
    def __init__(self, path):
        super().__init__(); self.ids=set(); self.links=[]; self.h1=0; self.lang=False; self.title=False; self.csp=False
        self.feed(path.read_text())
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a:
            assert a['id'] not in self.ids, f"duplicate ID: {a['id']}"
            self.ids.add(a['id'])
        if tag=='h1': self.h1+=1
        if tag=='html': self.lang=a.get('lang')=='ar' and a.get('dir')=='rtl'
        if tag=='title': self.title=True
        if tag=='meta' and a.get('http-equiv')=='Content-Security-Policy': self.csp=True
        if tag=='img': assert 'alt' in a
        for key in ['href','src']:
            if key in a: self.links.append(a[key])

docs={p:Document(p) for p in ROOT.rglob('*.html')}
count=0
for p,d in docs.items():
    assert d.lang and d.title and d.csp and d.h1==1, f'invalid document: {p}'
    for href in d.links:
        url=urlsplit(href)
        if url.scheme or url.netloc: continue
        target=(ROOT/url.path.lstrip('/')) if url.path.startswith('/') else (p.parent/url.path if url.path else p)
        if target.is_dir(): target=target/'index.html'
        assert target.is_file(), f'{p}: missing {href}'
        if url.fragment and target.suffix=='.html': assert unquote(url.fragment) in docs[target].ids, f'{p}: missing anchor {href}'
        count+=1
ET.parse(ROOT/'sitemap.xml')
print(f'PASS: {len(docs)} Arabic RTL documents; {count} internal asset/link/anchor references; sitemap XML.')
