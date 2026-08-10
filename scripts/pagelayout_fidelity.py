#!/usr/bin/env python3
"""Measure how far pagelayout's DOCX->PDF output sits from a reference renderer.

The engine's own tests are reference-free: they assert that nothing crashes,
that no glyph leaves the page, and that no character is silently dropped.
Those catch missing content. They cannot say "this line breaks two words
early" or "this document runs eight pages long", which is the entire
question when the goal is output on par with Word.

This renders each corpus document twice -- once through pagelayout, once
through LibreOffice headless -- and reports where they disagree.

WHAT THE NUMBERS ARE WORTH
--------------------------
LibreOffice is a proxy, not Word. It has its own divergence from Word, so
a nonzero score is not automatically a defect on our side, and a zero score
would not prove parity. Treat it as a trend indicator: the useful question
is whether a change moved a number toward or away from the reference, not
what the number is in isolation.

Underneath both sits a font-substitution floor that no layout work can
close. The bundle ships metric-compatible substitutes -- Carlito has
Calibri's advance widths but different outlines -- so glyph positions can
converge while glyph shapes cannot.

THE METRICS
-----------
Reported per document, most diagnostic first:

  scale       Median ratio of our word widths to the reference's, over
              words matched by text. This is the sharpest signal available:
              layout differences perturb it, but a *systematic* deviation
              means the text is being set at the wrong size, and every
              other number is downstream of that. 1.000 is the target.

  pages       Page counts. A delta is the coarsest symptom and usually the
              last thing to converge.

  same page   Of the words present in both renders, the fraction landing
              on the same page number. Insensitive to a single early
              divergence shifting everything after it, which page counts
              alone cannot distinguish from pervasive disagreement.

  drift       Median vertical distance between matched words that share a
              page, in points. Small and flat means the geometry agrees;
              growing down a page means line height or spacing does not.

  recall      Fraction of reference words that appear anywhere in ours,
              counted as a multiset. Below 1.0 means content the reference
              renders and we do not.

Words are matched by aligning the two word streams with difflib, so
inserted or dropped text shifts nothing downstream.

Recall deliberately does *not* use that alignment. Two renderers can walk
a table's cells in different orders while both drawing every cell, and a
sequence alignment scores those cells as missing: on the smaller report it
reads 0.841 aligned against 0.934 counted as a multiset, and the ~10-point
difference is entirely reordering. Loss and disorder are different
defects, so recall answers only "is the content there at all". Disorder
shows up in `same page` instead.

USAGE
-----
    python3 scripts/pagelayout_fidelity.py                 # whole corpus
    python3 scripts/pagelayout_fidelity.py --json          # machine-readable
    python3 scripts/pagelayout_fidelity.py path/to/doc.docx
    python3 scripts/pagelayout_fidelity.py --refresh       # re-render refs

Needs LibreOffice and poppler's pdftotext/pdfinfo. Neither is available in
CI, which is why this is a command you run rather than a test that runs
itself.
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import shutil
import statistics
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass, asdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_CORPUS = sorted(
    (REPO / "docx2html" / "tests" / "stress" / "fixtures").glob("docxcorp-*.docx")
)
DEFAULT_CLI = (
    REPO
    / "_build"
    / "native"
    / "debug"
    / "build"
    / "bobzhang"
    / "pagelayout"
    / "cmd"
    / "pagelayout"
    / "pagelayout.exe"
)
SOFFICE_CANDIDATES = [
    "/Applications/LibreOffice.app/Contents/MacOS/soffice",
    "/usr/bin/soffice",
    "/usr/local/bin/soffice",
]


@dataclass
class Word:
    page: int
    left: float
    top: float
    width: float
    height: float
    text: str


@dataclass
class Score:
    document: str
    pages_ours: int
    pages_ref: int
    scale: float
    same_page: float
    drift_pt: float
    recall: float
    matched_words: int


def die(message: str) -> "typing.NoReturn":  # noqa: F821
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def find_soffice(explicit: str | None) -> str:
    if explicit:
        return explicit
    for candidate in SOFFICE_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    found = shutil.which("soffice") or shutil.which("libreoffice")
    if found:
        return found
    die(
        "LibreOffice not found. Install it (`brew install --cask libreoffice`) "
        "or pass --soffice."
    )


def require_poppler() -> None:
    for tool in ("pdftotext", "pdfinfo"):
        if not shutil.which(tool):
            die(f"{tool} not found. Install poppler (`brew install poppler`).")


def render_reference(soffice: str, docx: Path, outdir: Path, profile: Path) -> Path:
    """LibreOffice headless DOCX->PDF.

    The -env:UserInstallation flag is not optional: without it this collides
    with a running LibreOffice or stalls on first-run profile setup.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    target = outdir / (docx.stem + ".pdf")
    if target.exists():
        return target
    subprocess.run(
        [
            soffice,
            "--headless",
            "--norestore",
            f"-env:UserInstallation=file://{profile}",
            "--convert-to",
            "pdf",
            "--outdir",
            str(outdir),
            str(docx),
        ],
        check=True,
        capture_output=True,
        timeout=600,
    )
    if not target.exists():
        die(f"LibreOffice produced no PDF for {docx.name}")
    return target


def render_ours(cli: Path, docx: Path, outdir: Path) -> Path:
    outdir.mkdir(parents=True, exist_ok=True)
    target = outdir / (docx.stem + ".pdf")
    result = subprocess.run(
        [str(cli), "pdf", str(docx), str(target)], capture_output=True, timeout=600
    )
    if result.returncode != 0 or not target.exists():
        die(
            f"pagelayout failed on {docx.name}: "
            f"{result.stderr.decode('utf8', 'replace').strip()}"
        )
    return target


def page_count(pdf: Path) -> int:
    out = subprocess.run(
        ["pdfinfo", str(pdf)], capture_output=True, check=True
    ).stdout.decode("utf8", "replace")
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[1])
    die(f"pdfinfo reported no page count for {pdf}")


def words_of(pdf: Path) -> list[Word]:
    """Word boxes in reading order, via pdftotext's TSV mode."""
    out = subprocess.run(
        ["pdftotext", "-tsv", str(pdf), "-"], capture_output=True, check=True
    ).stdout.decode("utf8", "replace")
    words: list[Word] = []
    for line in out.splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) < 12 or parts[0] != "5":
            continue  # levels below 5 are page/flow/line markers, not words
        text = parts[11].strip()
        if not text or text.startswith("###"):
            continue
        try:
            words.append(
                Word(
                    page=int(parts[1]),
                    left=float(parts[6]),
                    top=float(parts[7]),
                    width=float(parts[8]),
                    height=float(parts[9]),
                    text=text,
                )
            )
        except ValueError:
            continue
    return words


def score(document: str, ours: list[Word], ref: list[Word]) -> Score:
    """Align the two word streams and measure where they disagree."""
    our_text = [w.text for w in ours]
    ref_text = [w.text for w in ref]
    matcher = difflib.SequenceMatcher(a=ref_text, b=our_text, autojunk=False)

    ratios: list[float] = []
    drifts: list[float] = []
    same_page = 0
    matched = 0
    for block in matcher.get_matching_blocks():
        for offset in range(block.size):
            r = ref[block.a + offset]
            o = ours[block.b + offset]
            matched += 1
            if r.width > 0.5:  # a hairline box carries no usable ratio
                ratios.append(o.width / r.width)
            if r.page == o.page:
                same_page += 1
                drifts.append(abs(o.top - r.top))

    # Counted as a multiset, not off the alignment above: see the module
    # docstring on why reordering must not read as loss.
    missing = Counter(w.text for w in ref) - Counter(w.text for w in ours)

    return Score(
        document=document,
        pages_ours=max((w.page for w in ours), default=0),
        pages_ref=max((w.page for w in ref), default=0),
        scale=round(statistics.median(ratios), 4) if ratios else float("nan"),
        same_page=round(same_page / matched, 4) if matched else float("nan"),
        drift_pt=round(statistics.median(drifts), 2) if drifts else float("nan"),
        recall=round(1 - sum(missing.values()) / len(ref), 4) if ref else float("nan"),
        matched_words=matched,
    )


def report(scores: list[Score]) -> None:
    name_width = max((len(s.document) for s in scores), default=8)
    header = (
        f"{'document'.ljust(name_width)}  {'pages':>11}  {'scale':>7}  "
        f"{'same page':>9}  {'drift':>7}  {'recall':>7}"
    )
    print(header)
    print("-" * len(header))
    for s in scores:
        pages = f"{s.pages_ours} vs {s.pages_ref}"
        flag = "" if abs(s.scale - 1.0) < 0.005 else "  <- text set at the wrong size"
        # Drift is a median over co-paged words only. Once pagination has
        # diverged, the few words still sharing a page number are there by
        # coincidence, and their median says nothing about geometry.
        drift = f"{s.drift_pt:>6.1f}pt" if s.same_page >= 0.5 else "      --"
        print(
            f"{s.document.ljust(name_width)}  {pages:>11}  {s.scale:>7.3f}  "
            f"{s.same_page:>9.3f}  {drift}  {s.recall:>7.3f}{flag}"
        )
    print()
    print(
        "scale 1.000 = our glyph advances match the reference's. same page 1.000 =\n"
        "every shared word paginates identically. drift = median vertical gap between\n"
        "words that do share a page, withheld as -- below 0.5 same page, where the\n"
        "survivors are coincidence. recall 1.000 = we render every word it does.\n"
    )
    print(
        "LibreOffice is a proxy, not Word: it carries its own divergence from Word, so\n"
        "read these as a trend across commits rather than as a parity verdict. The\n"
        "bundled faces are metric-compatible substitutes, so glyph shapes stay\n"
        "different even where every number here reaches its target."
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Score pagelayout's PDF output against LibreOffice."
    )
    parser.add_argument("documents", nargs="*", type=Path, help="DOCX paths")
    parser.add_argument("--cli", type=Path, default=DEFAULT_CLI)
    parser.add_argument("--soffice", default=None)
    parser.add_argument(
        "--work",
        type=Path,
        default=Path(os.environ.get("TMPDIR", "/tmp")) / "pagelayout-fidelity",
        help="where renders are cached",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="discard cached reference renders and rebuild them",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON")
    args = parser.parse_args()

    require_poppler()
    soffice = find_soffice(args.soffice)
    if not args.cli.exists():
        die(f"pagelayout CLI not found at {args.cli}; run `moon build --target native`")

    documents = args.documents or DEFAULT_CORPUS
    if not documents:
        die("no documents to score")

    ref_dir = args.work / "reference"
    our_dir = args.work / "ours"
    profile = args.work / "profile"
    if args.refresh and ref_dir.exists():
        shutil.rmtree(ref_dir)
    profile.mkdir(parents=True, exist_ok=True)

    scores: list[Score] = []
    for docx in documents:
        if not docx.exists():
            die(f"no such document: {docx}")
        if not args.json:
            print(f"scoring {docx.name} ...", file=sys.stderr)
        reference = render_reference(soffice, docx, ref_dir, profile)
        ours = render_ours(args.cli, docx, our_dir)
        scores.append(score(docx.stem, words_of(ours), words_of(reference)))
        # Page counts come from pdfinfo rather than the last word's page: a
        # trailing page holding only a picture has no words on it.
        scores[-1].pages_ours = page_count(ours)
        scores[-1].pages_ref = page_count(reference)

    if args.json:
        print(json.dumps([asdict(s) for s in scores], indent=2))
    else:
        report(scores)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
