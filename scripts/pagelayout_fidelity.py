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
              reference within 0.5%. Usually the sharpest signal
              available, and usually a font-size difference -- but it
              measures *width*, and letter-spacing or a substituted face
              with different advances would move it too, so read it as
              "this text is not the width theirs is" and diagnose the
              cause separately.

  scale       Median ratio of our word widths to the reference's, over
              the same words. Says which way `sized` is wrong and by how
              much -- 1.10 is a ten percent overset. Read it only when
              `sized` is already low; a median alone cannot tell a
              uniform error from a bimodal one, which is what `sized` is
              for. `--ratios` prints the whole distribution.

  pages       Page counts, from pdfinfo. The coarsest symptom and usually
              the last thing to converge.

  same page   Fraction of the *reference's* words that we place on the
              same page number.

  y drift     Median vertical distance between comparable words that
              share a page, in points. Line height and spacing land here.

  x drift     The same horizontally. Indents, justification and tab stops
              land here; a document can score a perfect y drift with
              every line starting in the wrong place.

  recall      Fraction of reference words that appear anywhere in ours,
              counted as a multiset. Content we lose.

  precision   Fraction of *our* words that appear anywhere in the
              reference. Content we invent -- a word drawn twice, or
              furniture the reference does not emit. Recall alone cannot
              see it.

  aligned     Fraction of reference words that could be matched to one of
              ours at all. This is the honesty column: `sized`, `scale`
              and the drifts are computed only over matched words, so a
              low `aligned` means they describe only that fraction of the
              document and should be read with suspicion.

Every fraction above is rounded to four places and most are computed over
a different subset, so `--json` carries the raw counts: `comparable_words`
is the denominator behind `sized` and `scale`, `co_paged_words` the one
behind both drifts (a much smaller set -- 20,216 against 316 on the
technical manual), and `mis_sized_words` / `missing_words` /
`surplus_words` the exact integers behind `sized`, `recall` and
`precision`. One bad word in twenty thousand rounds those fractions to a
perfect 1.0; the counts do not round.

None of this establishes that two renders agree. Every column can be
satisfied by output that still looks wrong -- nothing here checks glyph
shape, colour, rules, images, or word order within a page. The columns
are tripwires for specific, known failures, not a proof of equivalence.

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
    y_drift_pt: float | None
    x_drift_pt: float | None
    recall: float | None
    precision: float | None
    aligned: float | None
    ref_words: int
    our_words: int
    matched_words: int
    # The denominator behind `sized` and `scale`: matched words that
    # carried a usable width ratio. Reported because a high `aligned` does
    # not imply a high one of these.
    comparable_words: int
    # The denominator behind both drifts, which is a different set again.
    co_paged_words: int
    # Exact counts behind `sized`, `recall` and `precision`. The fractions
    # round to four places, so one bad word in twenty thousand prints as a
    # perfect 1.0 -- these do not round, and a tripwire that cannot see
    # the single-word case is not a tripwire.
    mis_sized_words: int
    missing_words: int
    surplus_words: int


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
        # A bare name is a legitimate value; resolve it the way the shell
        # would rather than insisting on a path that exists as written.
        resolved = explicit if Path(explicit).exists() else shutil.which(explicit)
        if not resolved:
            die(f"no LibreOffice binary at {explicit}")
        return resolved
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


def renderer_identity(soffice: str) -> str:
    """A stable tag for the reference renderer.

    Part of the cache key, because a cached PDF is only a valid reference
    for the renderer that produced it: switching --soffice or upgrading
    LibreOffice otherwise reuses the old build's output and silently
    reports its pagination as the new one's.

    The resolved path is included as well as the version string, because
    two builds can report the same version and render differently -- a
    patched build, or a wrapper.
    """
    version = run([soffice, "--version"], "LibreOffice --version", timeout=120)
    return f"{Path(soffice).resolve()}\n{version.decode('utf8', 'replace').strip()}"


def render_reference(
    soffice: str, identity: str, docx: Path, outdir: Path, profile: Path
) -> Path:
    """LibreOffice headless DOCX->PDF, cached by content and renderer.

    The cache name carries a hash of the source bytes and of the renderer
    identity. Keying on the file name alone would reuse one document's
    reference for another of the same name, and would survive an edit to
    the document itself -- both of which silently compare our render of one
    file against LibreOffice's render of a different one.

    It is not a full fingerprint of the renderer. It does not capture the
    environment LibreOffice draws in -- installed fonts above all, but
    also the persistent profile and any layout-affecting configuration --
    and a binary replaced in place while still reporting the same version
    keeps the same identity. Those cases still need --refresh.

    The -env:UserInstallation flag is not optional: without it this collides
    with a running LibreOffice or stalls on first-run profile setup.
    """
    outdir.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256()
    key.update(docx.read_bytes())
    key.update(identity.encode("utf8"))
    digest = key.hexdigest()[:16]
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


def width_ratios(ours: list[Word], ref: list[Word]) -> list[float]:
    """Our width over theirs, for every word the alignment matched.

    Split out so `--ratios` can show the distribution behind `scale`: a
    median cannot distinguish a uniform error from a bimodal one, and the
    difference decides whether one cause or several are in play.
    """
    matcher = difflib.SequenceMatcher(
        a=[w.text for w in ref], b=[w.text for w in ours], autojunk=False
    )
    ratios = []
    for block in matcher.get_matching_blocks():
        for offset in range(block.size):
            r = ref[block.a + offset]
            if r.width > 0.5:  # a hairline box carries no usable ratio
                ratios.append(ours[block.b + offset].width / r.width)
    return ratios


def bucketed(ratios: list[float]) -> dict[float, int]:
    """Width ratios grouped to 0.01, for the `--ratios` histogram."""
    return dict(Counter(round(r, 2) for r in ratios))


def score(document: str, ours: list[Word], ref: list[Word]) -> Score:
    """Align the two word streams and measure where they disagree."""
    matcher = difflib.SequenceMatcher(
        a=[w.text for w in ref], b=[w.text for w in ours], autojunk=False
    )

    ratios: list[float] = []
    y_drifts: list[float] = []
    x_drifts: list[float] = []
    same_page = 0
    matched = 0
    for block in matcher.get_matching_blocks():
        for offset in range(block.size):
            r = ref[block.a + offset]
            o = ours[block.b + offset]
            matched += 1
            if r.width > 0.5:
                ratios.append(o.width / r.width)
            if r.page == o.page:
                same_page += 1
                y_drifts.append(abs(o.top - r.top))
                x_drifts.append(abs(o.left - r.left))

    total = len(ref)
    right_size = sum(1 for x in ratios if abs(x - 1.0) <= SIZE_TOLERANCE)
    # Multiset differences, not the alignment above: reordering is neither
    # loss nor invention. Recall is what we drop, precision what we add.
    our_bag = Counter(w.text for w in ours)
    ref_bag = Counter(w.text for w in ref)
    missing = sum((ref_bag - our_bag).values())
    surplus = sum((our_bag - ref_bag).values())

    def fraction(numerator: int, denominator: int) -> float | None:
        return round(numerator / denominator, 4) if denominator else None

    # Denominator is every reference word, not every matched one: see the
    # module docstring. The floor below tests the unrounded value, so a
    # true 0.49995 is not rounded up into 0.5 and past the gate.
    exact_same_page = same_page / total if total else 0.0

    # Withheld here rather than at print time, so the table and --json
    # cannot disagree about which numbers mean anything. A consumer
    # plotting drift over time must not be handed the one value the
    # report declares meaningless.
    def drift(values: list[float]) -> float | None:
        if not values or exact_same_page < DRIFT_FLOOR:
            return None
        return round(statistics.median(values), 2)

    return Score(
        document=document,
        pages_ours=0,  # filled from pdfinfo by the caller
        pages_ref=0,
        sized=fraction(right_size, len(ratios)),
        scale=round(statistics.median(ratios), 4) if ratios else None,
        same_page=fraction(same_page, total),
        y_drift_pt=drift(y_drifts),
        x_drift_pt=drift(x_drifts),
        recall=fraction(total - missing, total),
        precision=fraction(len(ours) - surplus, len(ours)),
        aligned=fraction(matched, total),
        ref_words=total,
        our_words=len(ours),
        matched_words=matched,
        comparable_words=len(ratios),
        co_paged_words=same_page,
        mis_sized_words=len(ratios) - right_size,
        missing_words=missing,
        surplus_words=surplus,
    )


def cell(value: float | None, width: int, places: int = 3) -> str:
    return "n/a".rjust(width) if value is None else f"{value:>{width}.{places}f}"


def report(scores: list[Score]) -> None:
    name_width = max((len(s.document) for s in scores), default=8)
    header = (
        f"{'document'.ljust(name_width)}  {'pages':>9}  {'sized':>6}  {'scale':>6}  "
        f"{'same pg':>7}  {'y drift':>8}  {'x drift':>8}  {'recall':>6}  "
        f"{'precis':>6}  {'aligned':>7}"
    )
    print(header)
    print("-" * len(header))
    for s in scores:
        pages = f"{s.pages_ours} vs {s.pages_ref}"
        y = f"{s.y_drift_pt:>6.1f}pt" if s.y_drift_pt is not None else "      --"
        x = f"{s.x_drift_pt:>6.1f}pt" if s.x_drift_pt is not None else "      --"
        flag = ""
        if s.sized is not None and s.sized < 0.9:
            # Deliberately says "width", not "font size": a substituted
            # face or letter-spacing moves this too, and the tool has not
            # established which.
            flag = f"  <- {1 - s.sized:.0%} of the text is not the reference's width"
        print(
            f"{s.document.ljust(name_width)}  {pages:>9}  {cell(s.sized, 6)}  "
            f"{cell(s.scale, 6)}  {cell(s.same_page, 7)}  {y}  {x}  "
            f"{cell(s.recall, 6)}  {cell(s.precision, 6)}  {cell(s.aligned, 7)}{flag}"
        )
    print()
    print(
        "sized   fraction of comparable words whose width matches within 0.5%\n"
        "scale   median width ratio, ours over theirs -- which way sized is wrong\n"
        "        (--ratios shows the distribution a median cannot)\n"
        "same pg fraction of THEIR words we put on the same page number\n"
        "y/x drift  median gap among co-paged words; -- below "
        f"{DRIFT_FLOOR:.1f} same pg, where\n"
        "        the survivors are coincidence. y is line height, x is indent\n"
        "recall  fraction of their words present anywhere in ours (multiset)\n"
        "precis  fraction of OUR words present anywhere in theirs -- content we\n"
        "        invent, which recall cannot see\n"
        "aligned fraction of their words matched to one of ours at all; sized,\n"
        "        scale and the drifts describe only this much of the document\n"
    )
    print(
        "LibreOffice is a proxy, not Word: it carries its own divergence from Word, so\n"
        "read these as a trend across commits rather than as a parity verdict. The\n"
        "bundled faces are metric-compatible substitutes, so glyph shapes stay\n"
        "different even where every number here reaches its target.\n"
    )
    print(
        "None of these columns, together or apart, establishes that two renders agree.\n"
        "Nothing here checks glyph shape, colour, rules, images, or word order within a\n"
        "page. They are tripwires for known failures, not a proof of equivalence."
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
    parser.add_argument(
        "--ratios",
        action="store_true",
        help="print the width-ratio distribution behind `scale`",
    )
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

    identity = renderer_identity(soffice)
    scores: list[Score] = []
    distributions: list[tuple[str, list[float]]] = []
    for docx in documents:
        if not docx.exists():
            die(f"no such document: {docx}")
        if not args.json:
            print(f"scoring {docx.name} ...", file=sys.stderr)
        reference = render_reference(soffice, identity, docx, ref_dir, profile)
        ours = render_ours(args.cli, docx, our_dir)
        our_words, ref_words = words_of(ours), words_of(reference)
        result = score(docx.stem, our_words, ref_words)
        # Page counts come from pdfinfo rather than the last word's page: a
        # trailing page holding only a picture has no words on it.
        result.pages_ours = page_count(ours)
        result.pages_ref = page_count(reference)
        scores.append(result)
        if args.ratios:
            distributions.append((docx.stem, width_ratios(our_words, ref_words)))

    # Keyed by position, not by document name: two files of the same name
    # in different directories share a stem, and a dict would give both
    # rows whichever histogram was computed last.
    histograms = [
        {f"{value:.2f}": count for value, count in sorted(bucketed(ratios).items())}
        for _, ratios in distributions
    ]

    if args.ratios and not args.json:
        for name, ratios in distributions:
            print(f"\n{name}: width ratios over {len(ratios)} comparable words")
            if not ratios:
                print("  (none)")
                continue
            # Every bucket, not the top N: a truncated histogram can hide
            # the mode it was asked to show, and the shares would not sum
            # to 1. Buckets are rounded to 0.01, so membership is "within
            # half a percent of this value", not an exact ratio.
            for value, count in sorted(bucketed(ratios).items()):
                share = count / len(ratios)
                bar = "#" * round(share * 40)
                print(f"  {value:>5.2f}  {count:>7}  {share:>6.1%}  {bar}")
        print()

    if args.json:
        payload = [asdict(s) for s in scores]
        if args.ratios:
            # Carried inside the document rather than printed alongside it:
            # writing the histogram to stdout first would leave --json
            # emitting something no JSON parser accepts.
            for row, histogram in zip(payload, histograms):
                row["ratio_histogram"] = histogram
        # allow_nan=False: every unavailable value is already None, and a
        # bare NaN would be JSON no strict parser accepts.
        print(json.dumps(payload, indent=2, allow_nan=False))
    else:
        report(scores)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
