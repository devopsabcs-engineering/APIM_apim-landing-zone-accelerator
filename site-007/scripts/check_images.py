#!/usr/bin/env python3
"""Check every image referenced from the docs.

For every Markdown file under docs/ (except documentation of the screenshot slots):

* each ``![alt](path)`` and ``<img src=... alt=...>`` must have non-empty alt text;
* each local image path must exist (relative to the page, or to docs/ when it starts with '/').

Images under docs/assets/img that no page references are reported as warnings only.
Fenced code blocks and inline code are ignored.

Exit code 0 when everything is fine, 1 otherwise.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
IMAGE_DIR = DOCS / "assets" / "img"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".avif"}

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`\n]*`")
MD_IMAGE = re.compile(r"!\[(?P<alt>[^\]]*)\]\(\s*<?(?P<src>[^)\s>]+)")
HTML_IMG_TAG = re.compile(r"<img\b[^>]*>", re.IGNORECASE)
HTML_SRC = re.compile(r"\bsrc\s*=\s*[\"']([^\"']*)[\"']", re.IGNORECASE)
HTML_ALT = re.compile(r"\balt\s*=\s*[\"']([^\"']*)[\"']", re.IGNORECASE)
REMOTE = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|//)", re.IGNORECASE)


def iter_pages() -> list[Path]:
    skip = IMAGE_DIR / "README.md"
    return [p for p in sorted(DOCS.rglob("*.md")) if p != skip]


def references(path: Path) -> list[tuple[int, str, str]]:
    """Return (line number, src, alt) for every image reference outside code."""
    found: list[tuple[int, str, str]] = []
    in_fence = False
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        clean = INLINE_CODE.sub("", line)
        for match in MD_IMAGE.finditer(clean):
            found.append((number, match.group("src"), match.group("alt")))
        for tag in HTML_IMG_TAG.findall(clean):
            src = HTML_SRC.search(tag)
            alt = HTML_ALT.search(tag)
            found.append((number, src.group(1) if src else "", alt.group(1) if alt else ""))
    return found


def resolve(page: Path, src: str) -> Path:
    target = unquote(src.split("#", 1)[0].split("?", 1)[0])
    base = DOCS if target.startswith("/") else page.parent
    return (base / target.lstrip("/")).resolve()


def main() -> int:
    errors: list[str] = []
    used: set[Path] = set()
    count = 0

    for page in iter_pages():
        rel = page.relative_to(ROOT).as_posix()
        for number, src, alt in references(page):
            count += 1
            if not alt.strip():
                errors.append(f"{rel}:{number}: image '{src}' has no alt text")
            if not src:
                errors.append(f"{rel}:{number}: <img> without src")
                continue
            if REMOTE.match(src):
                continue
            target = resolve(page, src)
            if not target.is_file():
                errors.append(f"{rel}:{number}: image '{src}' does not exist")
            else:
                used.add(target)

    if IMAGE_DIR.is_dir():
        for image in sorted(IMAGE_DIR.rglob("*")):
            if image.suffix.lower() in IMAGE_EXTENSIONS and image.resolve() not in used:
                print(f"warning: {image.relative_to(ROOT).as_posix()} is not referenced by any page")

    if errors:
        print("Image check FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"Image check passed: {count} image references.")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
