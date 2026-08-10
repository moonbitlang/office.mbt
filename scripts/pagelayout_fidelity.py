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
Reported per document:

  sized       Fraction of comparable words whose width matches the
              reference within 0.5%. This is the sharpest signal
              available: a low value means the text is being set at the
              wrong size, and every other number is downstream of that.

  scale       Median ratio of our word widths to the reference's, over
              the same words. Says which way `sized` is wrong and by how
              much -- 1.10 is a ten percent overset. Read it only when
              `sized` is already low; a median alone cannot tell a
              uniform error from a bimodal one, which is what `sized` is
              for.

  pages       Page counts, from pdfinfo. The coarsest symptom and usually
              the last thing to converge.

  same page   Fraction of the *reference's* words that we place on the
              same page number.

  drift       Median vertical distance between comparable words that
              share a page, in points.

  recall      Fraction of reference words that appear anywhere in ours,
              counted as a multiset.

  aligned     Fraction of reference words that could be matched to one of
              ours at all. This is the honesty column: `sized`, `scale`
              and `drift` are computed only over matched words, so a low
              `aligned` means they describe only that fraction of the
              document and should be read with suspicion.

HOW WORDS ARE COMPARED, AND WHAT THAT COSTS
-------------------------------------------
Words are matched by aligning the two word streams with difflib, so
inserted or dropped text shifts nothing downstream. That alignment is a
heuristic and it does not match everything: on reordered table cells it
picks one consistent subsequence and leaves the rest unmatched.

Two consequences, both deliberate:

- `same page` divides by the reference's total word count, not by the
  number of matched words. A word we never render, or render somewhere
  the alignment cannot follow, counts against us. Dividing by matches
  instead would let the metric report perfect agreement off a handful of
  aligned words while the rest of the document disagreed -- the one
  failure this tool must not have.
- `recall` does not use the alignment at all; it is a multiset
  difference. Two renderers can walk a table's cells in different orders
  while both draw every cell, and an alignment scores those cells as
  missing. Loss and disorder are different defects, and recall answers
  only "is the content there at all".

Nothing here measures word order *within* a page. A renderer that emitted
a page's words in a scrambled order would score well on every column.

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
import hashlib
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

# A word whose width is within this of the reference's is "the right size".
# Loose enough for rounding in either PDF, tight enough that a font-size
# error of one half-point at 10pt (5%) cannot hide inside it.
SIZE_TOLERANCE = 0.005

# Below this same-page fraction, the words still sharing a page number are
# there by coincidence and their median drift describes nothing.
DRIFT_FLOOR = 0.5


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
    sized: float | None
    scale: float | None
    same_page: float | None
    drift_pt: float | None
    recall: float | None
    aligned: float | None
    ref_words: int
    matched_words: int


def die(message: str):
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def run(command: list[str], what: str, timeout: int = 600) -> bytes:
    """Run a subprocess, and if it fails say why rather than tracebacking."""
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout)
    except FileNotFoundError:
        die(f"{what}: {command[0]} not found")
    except subprocess.TimeoutExpired:
        die(f"{what}: timed out after {timeout}s")
    if result.returncode != 0:
        detail = result.stderr.decode("utf8", "replace").strip()
        detail = detail or result.stdout.decode("utf8", "replace").strip()
        die(f"{what}: exit {result.returncode}\n{detail}")
    return result.stdout


def find_soffice(explicit: str | None) -> str:
    if explicit:
        if not Path(explicit).exists():
            die(f"no LibreOffice binary at {explicit}")
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
    """LibreOffice headless DOCX->PDF, cached by content.

    The cache name carries a hash of the source bytes. Keying on the file
    name alone would reuse one document's reference for another of the same
    name, and would survive an edit to the document itself -- both of which
    compare our render of one file against LibreOffice's render of a
    different one, silently.

    The -env:UserInstallation flag is not optional: without it this collides
    with a running LibreOffice or stalls on first-run profile setup.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(docx.read_bytes()).hexdigest()[:12]
    cached = outdir / f"{docx.stem}-{digest}.pdf"
    if cached.exists():
        return cached
    staging = outdir / f".staging-{digest}"
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)
    run(
        [
            soffice,
            "--headless",
            "--norestore",
            f"-env:UserInstallation=file://{profile}",
            "--convert-to",
            "pdf",
            "--outdir",
            str(staging),
            str(docx),
        ],
        f"LibreOffice on {docx.name}",
    )
    produced = staging / (docx.stem + ".pdf")
    if not produced.exists():
        die(f"LibreOffice produced no PDF for {docx.name}")
    produced.replace(cached)
    shutil.rmtree(staging, ignore_errors=True)
    return cached


def render_ours(cli: Path, docx: Path, outdir: Path) -> Path:
    """Never cached: the point is to measure the build in front of us."""
    outdir.mkdir(parents=True, exist_ok=True)
    target = outdir / (docx.stem + ".pdf")
    run([str(cli), "pdf", str(docx), str(target)], f"pagelayout on {docx.name}")
    if not target.exists():
        die(f"pagelayout produced no PDF for {docx.name}")
    return target


def page_count(pdf: Path) -> int:
    out = run(["pdfinfo", str(pdf)], f"pdfinfo on {pdf.name}").decode("utf8", "replace")
    for line in out.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[1])
    die(f"pdfinfo reported no page count for {pdf}")


def words_of(pdf: Path) -> list[Word]:
    """Word boxes in reading order, via pdftotext's TSV mode.

    Level 5 rows are words. The ###PAGE###/###FLOW###/###LINE### structural
    markers live at levels 1, 3 and 4, so the level test already excludes
    them -- filtering on the text as well would drop a real word that
    happens to start with '###', which is content loss reported as
    agreement.
    """
    out = run(["pdftotext", "-tsv", str(pdf), "-"], f"pdftotext on {pdf.name}").decode(
        "utf8", "replace"
    )
    words: list[Word] = []
    for line in out.splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) < 12 or parts[0] != "5":
            continue
        text = parts[11].strip()
        if not text:
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
    matcher = difflib.SequenceMatcher(
        a=[w.text for w in ref], b=[w.text for w in ours], autojunk=False
    )

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

    total = len(ref)
    right_size = sum(1 for x in ratios if abs(x - 1.0) <= SIZE_TOLERANCE)
    # A multiset difference, not the alignment above: reordering is not loss.
    missing = sum((Counter(w.text for w in ref) - Counter(w.text for w in ours)).values())

    def fraction(numerator: int, denominator: int) -> float | None:
        return round(numerator / denominator, 4) if denominator else None

    # Denominator is every reference word, not every matched one: see the
    # module docstring.
    same_page_fraction = fraction(same_page, total)

    # Withheld here rather than at print time, so the table and --json
    # cannot disagree about which numbers mean anything. A consumer
    # plotting drift over time must not be handed the one value the
    # report declares meaningless.
    drift = (
        round(statistics.median(drifts), 2)
        if drifts and (same_page_fraction or 0) >= DRIFT_FLOOR
        else None
    )

    return Score(
        document=document,
        pages_ours=0,  # filled from pdfinfo by the caller
        pages_ref=0,
        sized=fraction(right_size, len(ratios)),
        scale=round(statistics.median(ratios), 4) if ratios else None,
        same_page=same_page_fraction,
        drift_pt=drift,
        recall=fraction(total - missing, total),
        aligned=fraction(matched, total),
        ref_words=total,
        matched_words=matched,
    )


def cell(value: float | None, width: int, places: int = 3) -> str:
    return "n/a".rjust(width) if value is None else f"{value:>{width}.{places}f}"


def report(scores: list[Score]) -> None:
    name_width = max((len(s.document) for s in scores), default=8)
    header = (
        f"{'document'.ljust(name_width)}  {'pages':>9}  {'sized':>6}  {'scale':>6}  "
        f"{'same pg':>7}  {'drift':>8}  {'recall':>6}  {'aligned':>7}"
    )
    print(header)
    print("-" * len(header))
    for s in scores:
        pages = f"{s.pages_ours} vs {s.pages_ref}"
        drift = f"{s.drift_pt:>6.1f}pt" if s.drift_pt is not None else "      --"
        flag = ""
        if s.sized is not None and s.sized < 0.9:
            flag = f"  <- {1 - s.sized:.0%} of the text is set at the wrong size"
        print(
            f"{s.document.ljust(name_width)}  {pages:>9}  {cell(s.sized, 6)}  "
            f"{cell(s.scale, 6)}  {cell(s.same_page, 7)}  {drift}  "
            f"{cell(s.recall, 6)}  {cell(s.aligned, 7)}{flag}"
        )
    print()
    print(
        "sized   fraction of comparable words whose width matches within 0.5%\n"
        "scale   median width ratio, ours over theirs -- which way sized is wrong\n"
        "same pg fraction of THEIR words we put on the same page number\n"
        "drift   median vertical gap among co-paged words; -- below "
        f"{DRIFT_FLOOR:.1f} same pg,\n"
        "        where the survivors are coincidence\n"
        "recall  fraction of their words present anywhere in ours (multiset)\n"
        "aligned fraction of their words matched to one of ours at all; sized,\n"
        "        scale and drift describe only this much of the document\n"
    )
    print(
        "LibreOffice is a proxy, not Word: it carries its own divergence from Word, so\n"
        "read these as a trend across commits rather than as a parity verdict. The\n"
        "bundled faces are metric-compatible substitutes, so glyph shapes stay\n"
        "different even where every number here reaches its target. Nothing here\n"
        "measures word order within a page."
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
        result = score(docx.stem, words_of(ours), words_of(reference))
        # Page counts come from pdfinfo rather than the last word's page: a
        # trailing page holding only a picture has no words on it.
        result.pages_ours = page_count(ours)
        result.pages_ref = page_count(reference)
        scores.append(result)

    if args.json:
        # allow_nan=False: every unavailable value is already None, and a
        # bare NaN would be JSON no strict parser accepts.
        print(json.dumps([asdict(s) for s in scores], indent=2, allow_nan=False))
    else:
        report(scores)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
