# Page layout engine: DOCX → page-model IR → SVG/PDF

Design record for a paginated document renderer, decided 2026-08-07.
This is the decision log and milestone map; see Status for what shipped
and which decisions measurement reversed.

## Goal

Deterministic, browser-free, cross-platform paginated rendering of DOCX to
print-grade output. The quality bar is **self-consistent professional
typography** — correct line breaking, pagination, and spacing that reads
right — not pixel parity with Microsoft Word (chasing Word-identical layout
is a decades-deep compatibility tarpit; we deliberately do not enter it).

### Why not the browser route

OfficeCLI (the closest prior art, reviewed in `.repos/officecli`) renders
DOCX to HTML with page-box CSS plus an in-browser JS paginator, screenshots
it with a headless Chrome family browser for PNG, and only produces PDF via
Windows-only OS services. That gets breadth fast but the fidelity ceiling,
determinism, and PDF story all live outside the binary: output depends on
the installed browser and system fonts, and a machine without a browser
gets no raster and no page map. Owning layout is exactly the hole in that
offering, and this repo is unusually equipped for it: `pdflite` already has
TrueType parsing (`hmtx` advance widths), AFM metrics for the standard 14,
CJK CMap machinery, and a PDF writer — and the large-constant-data compile
cost that once made embedding data unattractive is resolved
(`docs/moonc-large-const-codegen.md`).

## Status (2026-08-08)

v1 shipped, plus tables, lists, and both backends. Merged in order: #357 design record,
#358 IR, #359 fonts, #360 line breaking, #361 paragraphs, #362
pagination, #363 SVG, #364 DOCX frontend, #365 CLI, #366–#368 tables,
#369–#370 numbering and lists, #372 the real-document corpus check,
#373 the PDF backend. A `.docx` renders to paginated SVG *or* PDF
through `pagelayout/cmd/pagelayout`.

The PDF backend confirmed the architecture's central bet: because the
IR carries absolute positions and per-character advances, the emitter
is largely transcription, and the only real work was the coordinate
flip and font resources.

It also surfaced the cost of an earlier decision. Bundling
**metrics-only** faces (#359) kept ~150KB in the repository instead of
~20MB, but a PDF `/FontFile2` needs glyph outlines, so fonts were
*declared* with a `/Widths` array rather than embedded — which left CJK
unrepresentable in PDF output, since a simple font's WinAnsi encoding is
8-bit and cannot address more than 256 codes.

**CJK now ships (#384–#389.)** Glyph outlines live in their own package,
`pagelayout/fontoutlines`, apart from the metrics: every backend measures
with metrics, only PDF embeds outlines, and an SVG or wasm build has no
reason to carry ten megabytes of `glyf`. Families with a bundled program
are written as Type0 composite fonts with Identity-H over a CIDFontType2
descendant, subset to the characters the document actually uses; families
without one keep the declared-not-embedded path, because for Latin a
substituted face is cosmetic.

Embedding is not optional for CJK the way it is for Latin. Under
Identity-H a code *is* a glyph index into the embedded program, so a
substituted face draws whatever glyphs sit at those indices — mojibake,
not a near miss.

Four things worth recording from that work:

- **The `\xNN` cost was avoidable.** MoonBit byte escapes spend four
  source characters per byte, which would have made the CJK face 23MB of
  generated source. ASCII85 armour costs 1.25 and reuses pdflite's tested
  decoder: 8.3MB instead, ~6MB packed, and it is write-once data that
  never churns. The compile pathology feared in the original plan did not
  materialise — all three targets build the blob in under two seconds.
- **The bundled Noto was the wrong weight.** Noto Sans SC is a variable
  font whose `fvar` default is wght=100, so the metrics bundle had been
  measuring *Thin* since #359. Ideographs are full-width at every weight,
  which is why it went unnoticed; the 482 proportional codepoints that
  differ would have made layout measure a 574-unit `A` and draw a
  608-unit one once outlines were embedded.
- **Generation was not reproducible.** `fontTools` stamps `head.modified`
  with the wall clock, so regenerating produced a fresh diff across all
  seventeen data files every time. Fixed before the weight change, which
  is what let that change read as the one-file diff it actually was.
- **Rendering correctly is not the same as extracting correctly.**
  pdflite's ToUnicode writer was built for simple fonts and declared a
  one-byte codespace. Composite fonts rendered perfectly and `pdftotext`
  returned *nothing*; only checking against poppler caught it.

Three decisions in this document were **reversed by measurement**, and
the reasoning is worth keeping:

1. **svgdiff cannot guard this backend.** Probed at 0.5.13: any document
   carrying a `viewBox` or a `<text>` element reports
   `analysis_status = "partial"`, and changing a `<text>` fill from
   `#000000` to `#ff0000` yields **zero** differences — font-dependent
   text semantics are outside its supported subset. Text is nearly
   everything this backend emits. It also cost five third-party packages
   inside the dependency closure that office's fresh-agent release gate
   reviews and locks, which is how the problem surfaced (that job failed
   with *resolved dependency inventory does not match the tracked build
   lock*). Dropped; exact snapshots guard the goldens instead.

2. **Font resolution needs the theme, not a default.** Real Word
   documents rarely name a font in `docDefaults`; they write
   `w:asciiTheme="minorHAnsi"` and let `theme1.xml` supply it. An early
   hardcoded Calibri fallback looked correct on the first fixture purely
   because that theme's `minorHAnsi` *is* Calibri — while every
   `majorHAnsi` heading and every Word 365 (Aptos) document would have
   rendered wrong.

3. **`moon test --update` is not a verification step.** It froze wrong
   answers into snapshots three separate times — a fixture asserted as US
   Letter that is actually A4, the font coincidence above, and a list
   whose labels read `1. 1.` instead of `1. 2.`. Each read as passing.
   Snapshots here assert values derived from the **source format**
   (twips, half-points, the OOXML attributes), never from the engine's
   own output, so the arithmetic can be checked by hand.

## Architecture

```
DOCX ──(frontend: pagelayout/docx)──► engine input (paragraphs/runs/props)
                                            │
                                   layout engine (pagelayout)
                                — measure → line-break → paginate —
                                            │
                                    page-model IR (pages of
                                positioned glyph runs, rects,
                                    images, link regions)
                                       │            │
                              SVG emitter      PDF backend
                            (pagelayout/svg)   (via pdflite)
                                       │            │
                                    (PNG: rasterize SVG/PDF with
                                     external tools; never owned)
```

- **HTML stays a separate path.** `docx2html` remains the semantic,
  non-paginated converter; the layout engine does not replace it.
- **The IR is format-neutral.** DOCX is the first frontend; XLSX print
  rendering can target the same IR later.
- **Backends are thin.** SVG first (trivially inspectable — the dev-loop
  and golden-test target), then PDF (mostly mechanical once the IR is
  proven; the new work there is font embedding/subsetting).

## Decisions

| # | Decision | Choice | Why |
| --- | --- | --- | --- |
| 1 | Font source | Bundle metric-compatible fonts as compressed bytes | Determinism on every machine; embeddable in PDF later. Carlito (≈Calibri), Liberation Sans/Serif/Mono (≈Arial/Times New Roman/Courier New) — all SIL OFL. |
| 2 | CJK | Bundle a CJK font too (Noto Sans CJK, SC first) | Full determinism for CJK accepted at the size cost; layout gets real advances, PDF gets a real embeddable font. Kinsoku break rules in the line breaker from day one. **Shipped:** metrics from #359, outlines and Type0 embedding in #386/#389, at 6.25 MB compressed rather than the 10–20 MB estimated here. |
| 3 | Location | New top-level `pagelayout/` package tree | Engine + IR are format-neutral; keeps `pdflite` a PDF library and leaves the door open for XLSX print rendering. |
| 4 | Testing | Exact reviewed goldens + reference-free oracles | See below. Originally svgdiff-guarded; that was **reversed** once measured — see the Status section. |
| 5 | Shaping | Latin + CJK only in v1 | Kerning via pair lookup is in scope; Arabic joining / Indic reordering (HarfBuzz territory) is explicitly out until a shaping strategy is chosen. |
| 6 | Line breaking | Greedy first-fit (what Word does) | No paragraph-level optimization (Knuth-Plass) — simpler and closer to Word behavior. No hyphenation in v1. |

### Font data embedding

Fonts ship as flate-compressed `Bytes` chunks in source (the
`pdflite/text/unicodedata` pattern), decompressed and parsed once at first
use through `pdflite/font/truetype`. The native backend lowers these to
static C data — measured harmless after the moonc fix (see
`docs/moonc-large-const-codegen.md`), and re-measured for the multi-megabyte
CJK outline blob, which builds in under two seconds on all three targets.

Two packages, because the cost is lopsided. `pagelayout/fonts` holds
metrics-only sfnts (~150KB) that every backend needs to measure with;
`pagelayout/fontoutlines` holds full font programs that only the PDF
backend needs to embed. Metrics chunks use `\xNN` byte escapes, which are
fine at that size. Outlines use ASCII85 armour instead — pdflite already
ships a tested decoder, and at 1.25 source characters per byte it costs a
third of what escapes would. Chunks are cut on 4-byte boundaries so each
is a whole number of ASCII85 groups that decodes independently, and sized
to stay inside the js backend's 65535-character literal limit.

Variable fonts are instanced at generation time (Noto Sans SC at
wght=400), and `recalcTimestamp` is disabled so regeneration is a pure
function of the inputs.

Subsetting has a floor. pdflite's subsetter is cpdf-style: it preserves
original glyph ids, which is what lets the CID be the glyph id and
`/CIDToGIDMap` stay `/Identity`, but it therefore keeps `loca` and `hmtx`
at full length. For a 31,036-glyph face that is ~250KB before any outline
is included, so a one-ideograph document embeds roughly the same program
as a one-page one — 275KB uncompressed, 52KB after flate. Shrinking that
would mean renumbering glyphs and writing a `/CIDToGIDMap` stream; the
trade was not worth it at this size.

Family mapping (extendable): Calibri→Carlito, Arial→Liberation Sans,
Times New Roman→Liberation Serif, Courier New→Liberation Mono,
CJK families (SimSun, SimHei, MS Mincho/Gothic, Yu Mincho/Gothic, …)→Noto
Sans CJK. Unknown families fall back by generic class (serif/sans/mono),
then to the CJK font for CJK codepoints (per-character fallback).

## Page-model IR (sketch)

```
PageModel   { pages : Array[Page], fonts : Array[FontRef] }
Page        { width_pt, height_pt, items : Array[PageItem] }
PageItem    = GlyphRun  { font : FontRef, size_pt, x_pt, y_pt (baseline),
                          text : String, advances_pt : Array[Double],
                          color, bold/italic synth flags }
            | Rect      { x, y, w, h, fill?, stroke?, stroke_width }
            | Line      { x1, y1, x2, y2, stroke, width }
            | Image     { x, y, w, h, data : Bytes, mime }
            | LinkRegion{ x, y, w, h, target }
```

Coordinates are points, y-down, origin at the page's top-left; text is
positioned by baseline. Glyph runs carry their own advances so backends
never re-measure. All lengths flow through typed unit conversions
(twips/EMU/half-points → points) — no bare unit arithmetic in layout code.

## Layout algorithms (v1)

- **Measure**: advance widths from the bundled fonts' `hmtx` via `cmap`
  char→glyph; runs measured per styled span.
- **Line break**: greedy first-fit. Break opportunities: after spaces and
  soft hyphens for Latin; between CJK ideographs, filtered by kinsoku
  tables (forbidden line-start characters such as `、。」！`, forbidden
  line-end characters such as `「（`); no break inside numbers/words.
- **Paragraph**: first-line/hanging + left/right indents, space
  before/after, line spacing (single = the font's ascent+descent+line-gap;
  exact / atLeast / multiple honored as authored — modern Word templates
  merely *default* to a 1.08–1.15 multiple), alignment
  left/center/right/justify (justify distributes at expandable spaces;
  never the last line).
- **Paginate**: section properties give the content box (page size −
  margins); blocks stack with spacing; page breaks honor widow/orphan (2/2
  default), `keepNext`, `keepLines`, and explicit breaks.

## Correctness references (what goldens are checked against)

1. **Reference-free invariants** on the IR, run for every fixture: every
   source character appears exactly once in reading order; no run crosses
   the content-box right edge beyond tolerance; baselines advance
   monotonically within a column; widow/orphan/keep constraints hold.
2. **Round-trip oracle**: render → PDF → extract text with pdflite's
   reader → equals source text.
3. **Coarse cross-renderer calibration** (occasional, not per-commit):
   LibreOffice headless docx→pdf; compare page count (±1), per-page text
   assignment, and paragraph y-positions within a loose band.

   Implemented as `scripts/pagelayout_fidelity.py`; see **Fidelity
   harness** below.
4. **Reviewed goldens**: a curated fixture corpus rendered to SVG, judged
   by eye once, then frozen as **exact snapshots**. The emitter is
   deterministic (fixed bundled metrics, fixed rounding), so these catch
   every change including text position and colour.

   This decision was reversed from the original plan; see Status.

## Fidelity harness

`scripts/pagelayout_fidelity.py` renders each corpus document twice — once
through `pagelayout`, once through LibreOffice headless — and reports
where they disagree. It needs LibreOffice and poppler, neither of which
is in CI, so it is a command you run rather than a test that runs itself.

```
python3 scripts/pagelayout_fidelity.py            # whole corpus
python3 scripts/pagelayout_fidelity.py --json     # machine-readable
```

The engine's own tests are reference-free: nothing crashes, no glyph
leaves the page, no character is silently dropped. Those catch missing
content, and cannot see a line that breaks two words early or a document
that runs eight pages long.

Five numbers per document, most diagnostic first: **scale** (median ratio
of our word widths to the reference's), **pages**, **same page**
(fraction of shared words paginating identically), **drift** (median
vertical gap between words that share a page), and **recall** (fraction
of reference words present anywhere in ours).

`scale` earns its place at the front. Layout differences perturb it, but
a systematic deviation means the text is being set at the wrong size and
every other number is downstream of that — which is exactly what the
first run found:

| document | pages | scale | same page | drift | recall |
|---|---|---|---|---|---|
| reports-004f20 | 1 vs 2 | 1.001 | 1.000 | 1.6pt | 0.934 |
| reports-015012 | 11 vs 11 | 1.001 | 0.745 | 65.9pt | 0.968 |
| technical-028db | 56 vs 48 | **1.101** | 0.016 | — | 0.968 |

Recorded 2026-08-10, before any fix.

The technical manual's 1.101 is not an accumulation of small differences:
its word widths are uniformly ten percent wide, `11/10` exactly. It is
the one corpus document whose `docDefaults` omits `w:sz`, and the
frontend's fallback for that is 11pt — Word's *default template* value,
not the *format's* default of 10pt. Its two siblings both write
`sz="22"`, never reach the fallback, and score 1.001.

Two cautions the numbers do not carry themselves:

- **LibreOffice is a proxy, not Word.** It has its own divergence, so a
  nonzero score is not automatically ours and a zero score would not
  prove parity. The useful question is whether a change moved a number
  toward the reference.
- **Recall counts a multiset, deliberately.** Two renderers can walk a
  table's cells in different orders while both drawing every cell, and a
  sequence alignment scores those cells as missing — 0.841 against 0.934
  on reports-004f20, all of the difference reordering rather than loss.
  Loss and disorder are different defects; disorder belongs to `same
  page`.

`drift` is withheld below 0.5 `same page`: once pagination has diverged,
the words still sharing a page number are there by coincidence.

## v1 fidelity tier

**In**: paragraphs and runs with common properties (font, size,
bold/italic, color), style resolution (paragraph + character styles with
basedOn chains), lists/numbering, tables (fixed and autofit), inline
images and simply-anchored images, headers/footers, sections (page size,
margins, page breaks).

**Out (explicitly deferred)**: floats with text wrap, footnotes/endnotes,
fields beyond page numbers, text boxes, complex-script shaping, vertical
text, tracked-changes rendering, hyphenation.

## Milestones (one small PR each; self-reviewed, CI-gated)

1. This design doc.
2. `pagelayout/`: units + page-model IR types.
3. `pagelayout/fonts`: bundled fonts (Carlito, Liberation, Noto Sans CJK)
   + metrics API + family mapping/fallback. (Split data/API if large.)
4. Measurer + line breaker (Latin + CJK/kinsoku).
5. Paragraph layout → line boxes.
6. Pagination + section geometry.
7. `pagelayout/svg` emitter + svgdiff golden harness + first fixtures.
8. `pagelayout/docx` frontend (paragraphs/runs/styles/sectPr).
9. CLI wiring + cram doc.

Tables (#366–#368) and lists/numbering (#369) followed.

Headers/footers, images, tab stops, PAGE fields, and CJK font embedding
followed. Remaining, in rough order: embedding the Latin faces too (so a
PDF depends on nothing installed at all), first-page and even-page
header/footer variants, true inline-with-text image placement, decimal
tab stops, justification polish (CJK inter-character), XLSX print
frontend.

Known gaps are also recorded next to the code they affect — see the
comment block at the end of `pagelayout/docx/read.mbt` — so they stay
visible to whoever touches that parser rather than only living here.
