"""Check inline Markdown file links reachable from the packaged SKILL.md.

With no argument, check the Office skill source directory. Pass a skills.zip
to check the actual release archive with the same reference-closure check.
"""
import argparse
from pathlib import Path
import posixpath
import re
from urllib.parse import unquote, urlsplit
import zipfile


def check_references(files):
    pending = ["SKILL.md"]
    visited = set()
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        for link in re.findall(r"\[[^\]\n]*\]\(([^\s)]+)\)", files[name].decode("utf-8")):
            url = urlsplit(link)
            if url.scheme or url.netloc or not url.path:
                continue
            target = posixpath.normpath(posixpath.join(posixpath.dirname(name), unquote(url.path)))
            if target.startswith(("../", "/")) or target == ".." or target not in files:
                raise ValueError(f"{name}: {link} is outside the skill or missing from it")
            if target.endswith(".md"):
                pending.append(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", nargs="?", type=Path)
    args = parser.parse_args()
    if args.archive:
        with zipfile.ZipFile(args.archive) as archive:
            files = {name: archive.read(name) for name in archive.namelist() if not name.endswith("/")}
    else:
        root = Path(__file__).resolve().parents[1] / "office-cli"
        files = {
            path.relative_to(root).as_posix(): path.read_bytes()
            for path in root.rglob("*")
            if path.is_file() and not {".git", ".mooncakes", "_build"}.intersection(path.relative_to(root).parts)
        }
    try:
        check_references(files)
    except (KeyError, ValueError) as error:
        parser.exit(1, f"Office skill reference check failed: {error}\n")
    print("Office skill references are complete and contained in the skill.")


if __name__ == "__main__":
    main()
