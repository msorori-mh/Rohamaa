"""Compare public HTTPS responses to the exact deployed checkout; no credentials."""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError
import hashlib,json,time
ROOT=Path(__file__).resolve().parents[2]/'site'
BASE='https://ruhamaa.com'
paths=['/','/privacy/','/terms/','/delete-account/','/contact/','/login-callback/','/assets/style.css','/assets/site.js','/assets/favicon.svg']

def get(path):
    req=Request(BASE+path,headers={'Cache-Control':'no-cache','User-Agent':'Ruhamaa-Deployment-Check'})
    with urlopen(req,timeout=20) as response:
        assert response.url.startswith(BASE+'/'),f'Unexpected redirect: {response.url}'
        return response.status,response.read()

last=[]
for attempt in range(1,13):
    results=[]; last=[]
    for path in paths:
        source=ROOT/(path.strip('/')+'/index.html' if path.endswith('/') and path!='/' else 'index.html' if path=='/' else path.lstrip('/'))
        try:
            status,body=get(path)
            assert status==200 and body==source.read_bytes(),'Response differs from checkout'
            results.append({'path':path,'status':status,'sha256':hashlib.sha256(body).hexdigest()})
        except Exception as error:last.append(f'{path}: {error}')
    if not last:
        try:
            get('/ruhamaa-deployment-check-not-found')
            last.append('Unknown URL returned success instead of HTTP 404')
        except HTTPError as error:
            if error.code!=404:last.append(f'Unknown URL returned {error.code}')
            elif error.read()!=(ROOT/'404.html').read_bytes():last.append('Custom 404 content differs')
        except Exception as error:last.append(f'404 check: {error}')
    if not last:
        Path('deployment-results.json').write_text(json.dumps({'origin':BASE,'attempt':attempt,'checks':results,'custom_404':'PASS'},indent=2)+'\n')
        print(f'PASS: {len(results)} exact public HTTPS responses and custom HTTP 404 on {BASE}')
        break
    print(f'Attempt {attempt}: '+ '; '.join(last),flush=True)
    if attempt<12:time.sleep(10)
else:raise SystemExit('Production verification failed: '+'; '.join(last))
