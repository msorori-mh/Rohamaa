"""Validate the static site's links, document structure and CSP hygiene, no dependencies."""
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2] / 'site'
ORIGIN = 'https://ruhamaa.com'
class Document(HTMLParser):
    def __init__(self, path):
        super().__init__(); self.path=path; self.ids=set(); self.links=[]; self.h1=0; self.lang=False; self.title=False; self.csp=None; self.noindex=False; self.external=0; self.raw=None
        self.feed(path.read_text()); self.close()
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a:
            assert a['id'] not in self.ids, f"{self.path}: duplicate ID: {a['id']}"
            self.ids.add(a['id'])
        if tag=='h1': self.h1+=1
        if tag=='html': self.lang=a.get('lang')=='ar' and a.get('dir')=='rtl'
        if tag=='title': self.title=True
        if tag=='meta' and (a.get('http-equiv') or '').lower()=='content-security-policy': self.csp=a.get('content') or ''
        if tag=='meta' and a.get('name')=='robots' and 'noindex' in (a.get('content') or ''): self.noindex=True
        if tag=='img': assert 'alt' in a, f'{self.path}: <img> without alt'
        # The CSP forbids inline code and styles; keep the markup free of them so
        # nothing silently stops working and nothing tempts a weaker policy.
        assert tag!='style', f'{self.path}: inline <style> element'
        for name in a:
            assert name!='style', f'{self.path}: inline style= attribute on <{tag}>'
            assert not name.startswith('on'), f'{self.path}: inline event handler {name}= on <{tag}>'
        for key in ['href','src']:
            assert not (a.get(key) or '').strip().lower().startswith('javascript:'), f'{self.path}: javascript: URL on <{tag}>'
        if tag=='script':
            assert a.get('src'), f'{self.path}: <script> without src'
            self.raw='script'
        if tag in ('a','area') and urlsplit(a.get('href') or '').scheme in ('http','https'):
            assert 'noopener' in (a.get('rel') or '').split(), f"{self.path}: external link without rel=noopener: {a['href']}"
            self.external+=1
        for key in ['href','src']:
            if key in a: self.links.append(a[key])
    def handle_data(self, data):
        if self.raw=='script': assert not data.strip(), f'{self.path}: inline <script> body'
    def handle_endtag(self, tag):
        if tag=='script': self.raw=None

docs={p:Document(p) for p in ROOT.rglob('*.html')}
count=0; external=0
for p,d in docs.items():
    assert d.lang and d.title and d.h1==1, f'invalid document: {p}'
    assert d.csp is not None, f'{p}: missing Content-Security-Policy meta'
    directives=[part.strip() for part in d.csp.split(';') if part.strip()]
    assert "default-src 'self'" in directives, f"{p}: CSP must contain default-src 'self'"
    for banned in ('unsafe-inline','unsafe-eval'):
        assert banned not in d.csp, f'{p}: CSP must not allow {banned}'
    for part in directives:
        assert not {'*','data:','http:','https:'} & set(part.split()[1:]), f'{p}: CSP source list is too broad: {part}'
    external+=d.external
    for href in d.links:
        url=urlsplit(href)
        if url.scheme or url.netloc: continue
        target=(ROOT/url.path.lstrip('/')) if url.path.startswith('/') else (p.parent/url.path if url.path else p)
        if target.is_dir(): target=target/'index.html'
        assert target.is_file(), f'{p}: missing {href}'
        if url.fragment and target.suffix=='.html': assert unquote(url.fragment) in docs[target].ids, f'{p}: missing anchor {href}'
        count+=1

# Every sitemap URL must be served by a real, indexable file of this site.
namespace={'s':'http://www.sitemaps.org/schemas/sitemap/0.9'}
locations=[(loc.text or '').strip() for loc in ET.parse(ROOT/'sitemap.xml').getroot().findall('s:url/s:loc',namespace)]
assert locations, 'sitemap.xml lists no URLs'
assert len(set(locations))==len(locations), 'sitemap.xml lists a URL twice'
for loc in locations:
    assert loc.startswith(ORIGIN+'/'), f'sitemap URL outside {ORIGIN}: {loc}'
    path=unquote(urlsplit(loc).path)
    target=ROOT/path.lstrip('/')
    if path.endswith('/'): target=target/'index.html'
    assert target.is_file(), f'sitemap URL has no file: {loc}'
    assert not (target in docs and docs[target].noindex), f'sitemap lists a noindex page: {loc}'

# A page hidden with <meta name="robots" content="noindex"> must stay crawlable,
# otherwise crawlers never see the noindex instruction.
robots=(ROOT/'robots.txt').read_text()
disallowed=[line.split(':',1)[1].strip() for line in robots.splitlines() if line.lower().startswith('disallow:')]
for p,d in docs.items():
    if not d.noindex: continue
    public='/'+p.relative_to(ROOT).as_posix()
    public=public[:-len('index.html')] if public.endswith('/index.html') else public
    assert not any(rule and public.startswith(rule) for rule in disallowed), f'robots.txt blocks the noindex page {public}'
assert f'Sitemap: {ORIGIN}/sitemap.xml' in robots, 'robots.txt must reference the sitemap'

print(f'PASS: {len(docs)} Arabic RTL documents; {count} internal asset/link/anchor references; {external} external links with rel=noopener; strict CSP without inline code; {len(locations)} sitemap URLs mapped to files.')
