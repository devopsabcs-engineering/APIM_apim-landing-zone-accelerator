#!/usr/bin/env python3
"""Check EN/FR parity of the bilingual docs.

Rules, for every Markdown file under docs/en and docs/fr:

* the same set of files exists in both languages;
* both versions have the same number of H2 and the same number of H3 headings
  (headings inside fenced code blocks are ignored);
* both versions reference the same images (a ``.fr`` suffix before the extension is
  ignored, so ``shot.png`` in English matches ``shot.fr.png`` in French);
* both versions have a non-empty ``title`` and ``description`` front-matter field.

Exit code 0 when everything matches, 1 otherwise.
"""

from __future__ import annotations

import posixpath
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
LANGS = ("en", "fr")
REQUIRED_FRONT_MATTER = ("title", "description")

FENCE = re.compile(r"^\s*(```|~~~)")
HEADING = re.compile(r"^(#{2,3})\s+\S")
MD_IMAGE = re.compile(r"!\[[^\]]*\]\(\s*<?([^)\s>]+)")
HTML_IMAGE = re.compile(r"<img\b[^>]*?\bsrc\s*=\s*[\"']([^\"']+)[\"']", re.IGNORECASE)
INLINE_CODE = re.compile(r"`[^`\n]*`")
LANG_SUFFIX = re.compile(r"\.(?:fr|en)(\.[A-Za-z0-9]+)$")


def markdown_files(lang: str) -> dict[str, Path]:
    base = DOCS / lang
    return {p.relative_to(base).as_posix(): p for p in sorted(base.rglob("*.md"))}


def split_front_matter(text: str) -> tuple[dict, str]:
    if not text.startswith("---"):
        return {}, text
    lines = text.splitlines()
    for index in range(1, len(lines)):
        if lines[index].strip() == "---":
            data = yaml.safe_load("\n".join(lines[1:index])) or {}
            return (data if isinstance(data, dict) else {}), "\n".join(lines[index + 1 :])
    return {}, text


def analyse(path: Path, lang: str) -> dict:
    rel_dir = posixpath.dirname(path.relative_to(DOCS / lang).as_posix())
    text = path.read_text(encoding="utf-8")
    front, body = split_front_matter(text)
    h2 = h3 = 0
    images: list[str] = []
    in_fence = False
    for line in body.splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = HEADING.match(line)
        if match:
            if len(match.group(1)) == 2:
                h2 += 1
            else:
                h3 += 1
        clean = INLINE_CODE.sub("", line)
        for ref in MD_IMAGE.findall(clean) + HTML_IMAGE.findall(clean):
            if re.match(r"^[a-z][a-z0-9+.-]*:", ref, re.IGNORECASE):
                images.append(ref)
                continue
            target = ref.split("#", 1)[0].split("?", 1)[0]
            resolved = posixpath.normpath(posixpath.join(rel_dir, target))
            images.append(LANG_SUFFIX.sub(r"\1", resolved))
    return {"front": front, "h2": h2, "h3": h3, "images": sorted(images)}


def main() -> int:
    errors: list[str] = []
    files = {lang: markdown_files(lang) for lang in LANGS}

    for lang, other in (("en", "fr"), ("fr", "en")):
        for missing in sorted(set(files[lang]) - set(files[other])):
            errors.append(f"docs/{lang}/{missing} has no twin in docs/{other}/")

    common = sorted(set(files["en"]) & set(files["fr"]))
    for name in common:
        en = analyse(files["en"][name], "en")
        fr = analyse(files["fr"][name], "fr")
        for lang, info in (("en", en), ("fr", fr)):
            for field in REQUIRED_FRONT_MATTER:
                value = info["front"].get(field)
                if not isinstance(value, str) or not value.strip():
                    errors.append(f"docs/{lang}/{name}: front matter '{field}' is missing or empty")
        for level in ("h2", "h3"):
            if en[level] != fr[level]:
                errors.append(f"{name}: {level.upper()} count differs (en={en[level]}, fr={fr[level]})")
        if en["images"] != fr["images"]:
            only_en = sorted(set(en["images"]) - set(fr["images"]))
            only_fr = sorted(set(fr["images"]) - set(en["images"]))
            errors.append(f"{name}: image references differ (only en: {only_en}; only fr: {only_fr})")

    if errors:
        print("EN/FR parity check FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"EN/FR parity check passed: {len(common)} page pairs.")
    return 0


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
