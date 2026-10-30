"""Helpers for publishing the Flutter staff portal under https://ruhamaa.com/admin/.

Subcommands
  check-config   validate SUPABASE_URL / SUPABASE_ANON_KEY from the environment
                 and report whether the admin build should run.
  finalize       take a `flutter build web` output directory, pin the CSP to the
                 Supabase host, verify it is self-contained and copy it to
                 <site>/admin/ (plus <site>/admin/login/index.html, because
                 GitHub Pages has no single-page-app fallback).

Standard library only.
"""
import argparse
import base64
import json
import os
import re
import shutil
import sys
from pathlib import Path
from urllib.parse import urlsplit

PLACEHOLDER = "__SUPABASE_HOST__"
URL_RE = re.compile(r"^https://([A-Za-z0-9.-]+)$")


def _out(name: str, value: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if path:
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(f"{name}={value}\n")


def _key_role(key: str):
    if key.startswith("sb_secret_"):
        return "secret"
    if key.count(".") == 2:
        try:
            body = key.split(".")[1]
            body += "=" * (-len(body) % 4)
            return json.loads(base64.urlsafe_b64decode(body)).get("role")
        except Exception:
            return None
    return None


def check_config() -> int:
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_ANON_KEY", "").strip()
    if not url and not key:
        print(
            "::warning title=Admin portal skipped::SUPABASE_URL and SUPABASE_ANON_KEY "
            "are not set as repository variables (Settings > Secrets and variables > "
            "Actions > Variables). The public site is deployed WITHOUT /admin/."
        )
        _out("enabled", "false")
        return 0
    errors = []
    if not url:
        errors.append("SUPABASE_URL is empty while SUPABASE_ANON_KEY is set.")
    if not key:
        errors.append("SUPABASE_ANON_KEY is empty while SUPABASE_URL is set.")
    if url and not URL_RE.match(url):
        errors.append(
            "SUPABASE_URL must be an https origin without a path, for example "
            "https://<project-ref>.supabase.co."
        )
    if key and re.search(r"\s", key):
        errors.append("SUPABASE_ANON_KEY must not contain whitespace.")
    if key and _key_role(key) in ("secret", "service_role"):
        errors.append(
            "SUPABASE_ANON_KEY holds a secret/service-role key. Only the public "
            "anon/publishable key may be compiled into a web app."
        )
    if errors:
        for message in errors:
            print(f"::error title=Admin portal configuration::{message}")
        return 1
    print("Admin portal configuration looks valid; the admin build will run.")
    _out("enabled", "true")
    return 0


SCRIPT_TAG = re.compile(r"<script\b([^>]*)>(.*?)</script>", re.S | re.I)


def verify_build(index_html: str, build: Path) -> None:
    problems = []
    for attrs, body in SCRIPT_TAG.findall(index_html):
        if "src=" not in attrs or body.strip():
            problems.append("index.html contains an inline script (CSP forbids it).")
    if re.search(r"\son[a-z]+\s*=", index_html, re.I):
        problems.append("index.html contains an inline event handler.")
    if "$FLUTTER_BASE_HREF" in index_html:
        problems.append("base href was not substituted (build without --base-href?).")
    if '<base href="/admin/">' not in index_html:
        problems.append('index.html must contain <base href="/admin/">.')
    if "Content-Security-Policy" not in index_html:
        problems.append("index.html lost its Content-Security-Policy meta tag.")
    if 'name="robots" content="noindex, nofollow"' not in index_html:
        problems.append("index.html lost its noindex meta tag.")
    for needle in ("gstatic.com", "googleapis.com", "unpkg.com", "jsdelivr"):
        if needle in index_html:
            problems.append(f"index.html references an external host ({needle}).")
    bootstrap = build / "flutter_bootstrap.js"
    if not bootstrap.is_file():
        problems.append("flutter_bootstrap.js is missing from the build.")
    else:
        text = bootstrap.read_text(encoding="utf-8", errors="replace")
        for needle in ("gstatic.com", "unpkg.com", "jsdelivr"):
            if needle in text:
                problems.append(
                    f"flutter_bootstrap.js references {needle}: the build must use --no-web-resources-cdn."
                )
    for required in ("main.dart.js", "canvaskit", "assets/FontManifest.json"):
        if not (build / required).exists():
            problems.append(f"{required} is missing from the build (CanvasKit/fonts must be self-hosted).")
    manifest = build / "assets" / "FontManifest.json"
    if manifest.is_file() and "Tajawal" not in manifest.read_text(encoding="utf-8"):
        problems.append("The Tajawal font is not bundled in FontManifest.json.")
    if problems:
        for message in problems:
            print(f"::error title=Admin web build::{message}")
        raise SystemExit(1)


def finalize(build: Path, site: Path, supabase_url: str) -> int:
    match = URL_RE.match(supabase_url.strip())
    if not match:
        print("::error::SUPABASE_URL must be an https origin without a path.")
        return 1
    host = match.group(1)
    index = build / "index.html"
    if not index.is_file():
        print(f"::error::{index} not found; run flutter build web first.")
        return 1
    html = index.read_text(encoding="utf-8")
    if PLACEHOLDER not in html:
        print(f"::error::{PLACEHOLDER} not found in index.html; the CSP cannot be pinned.")
        return 1
    html = html.replace(PLACEHOLDER, host)
    verify_build(html, build)
    # Start from a clean directory so stale files never survive a rebuild.
    target = site / "admin"
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(build, target)
    (target / "index.html").write_text(html, encoding="utf-8")
    login = target / "login"
    login.mkdir()
    (login / "index.html").write_text(html, encoding="utf-8")
    print(f"Admin portal copied to {target} (CSP pinned to {host}); /admin/ and /admin/login/ serve the app.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check-config")
    fin = sub.add_parser("finalize")
    fin.add_argument("--build", required=True, type=Path)
    fin.add_argument("--site", required=True, type=Path)
    fin.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", ""))
    args = parser.parse_args()
    if args.cmd == "check-config":
        return check_config()
    return finalize(args.build, args.site, args.supabase_url)


if __name__ == "__main__":
    sys.exit(main())
