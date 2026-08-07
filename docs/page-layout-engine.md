# Page layout engine: DOCX → page-model IR → SVG/PDF

Design record for a paginated document renderer, decided 2026-08-07.
Status: v1 in progress; this doc is the decision log and milestone map.

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
| 2 | CJK | Bundle a CJK font too (Noto Sans CJK, SC first) | Full determinism for CJK accepted at the ~10–20 MB cost; layout gets real advances, SVG/PDF get a real embeddable font. Kinsoku break rules in the line breaker from day one. |
| 3 | Location | New top-level `pagelayout/` package tree | Engine + IR are format-neutral; keeps `pdflite` a PDF library and leaves the door open for XLSX print rendering. |
| 4 | Testing | svgdiff-guarded goldens + reference-free oracles | See below. `Milky2018/svgdiff` compares SVG semantically with typed reports; goldens stay stable under harmless formatting churn. |
| 5 | Shaping | Latin + CJK only in v1 | Kerning via pair lookup is in scope; Arabic joining / Indic reordering (HarfBuzz territory) is explicitly out until a shaping strategy is chosen. |
| 6 | Line breaking | Greedy first-fit (what Word does) | No paragraph-level optimization (Knuth-Plass) — simpler and closer to Word behavior. No hyphenation in v1. |

### Font data embedding

Fonts ship as flate-compressed `Bytes` chunks in source (the
`pdflite/text/unicodedata` pattern), decompressed and parsed once at first
use through `pdflite/font/truetype`. The native backend lowers these to
static C data — measured harmless after the moonc fix (see
`docs/moonc-large-const-codegen.md`). If `moon`'s pre-build embed support
fits the current `moon.pkg` format, generated chunks may be replaced by
build-time embedding; that is an implementation detail behind the same API.

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
4. **Reviewed goldens**: a curated fixture corpus rendered to SVG, judged
   by eye once, then frozen. `Milky2018/svgdiff` guards them from then on
   (`compare` with the default profile; a test asserts
   `analysis_status == "complete"` so the emitter provably stays inside
   svgdiff's supported subset — solid fills, positioned text, data-URL
   images, no filters/masks/animation).

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

Then, in rough order: tables, lists/numbering, headers/footers, images,
the pdflite PDF backend (font embedding + CID subsetting), justification
polish (CJK inter-character), XLSX print frontend.
