# pdflite Package Map (transition snapshot)

This file documents the gap between the directory layout and where code actually
lives, during the architecture refactor (see `../ARCHITECTURE_PROPOSAL.md` and
`../EXECUTION_PLAN.md`). It is a working snapshot, not the target design.

Measured 2026-06-20 (root = the top-level `bobzhang/pdflite` package). "Root
files" / "root LOC" count non-test `.mbt` files still in the root package for
that domain; "Package" shows the sibling package's current non-test LOC.

## Foundation / syntax / data — already well factored

These are the model layers the refactor builds on; they are NOT monolithic.

| Package | Role |
| --- | --- |
| `core` | bytes, cursors, bitstream, errors, names, number sets |
| `syntax` | `PdfObject`, lexemes, parser, stream model |
| `crypt_core` | crypt primitives |
| `reader` | xref + object-stream parsing (1549 LOC) |
| `writer` | low-level write helpers (48 LOC) |
| `flate`, `codec` | stream filters |
| `geometry`, `shape` | geometry primitives |
| `text/cmapdata`, `text/encodingdata`, `text/glyphdata`, `text/unicodedata` | generated data tables |
| `font/afm`, `font/standard14`, `font/truetype` | font data/helpers |
| `date`, `destination`, `page/label`, `page/spec`, `content/colour`, `content/path` | small leaf packages |

## Feature domains — the monolith

Legend for **State**:
- `stub` — a sibling package exists but holds a fraction of the domain; the bulk
  is still in root.
- `split` — a real low-level/data package exists and carries meaningful code, but
  a separate document/feature-level slice of the same domain still lives in root
  (e.g. low-level `reader`/`writer` vs the doc-level reader/writer code in root;
  `font`/`font/truetype` data vs root font logic).
- `dir-only` — a directory exists but only for fixture/data subpackages; no
  domain package yet.
- `none` — no package; the whole domain lives in root.

| Domain (root prefix) | Root files | Root LOC | Sibling package | State |
| --- | ---: | ---: | --- | --- |
| `page` | 68 | 9109 | `page/` (87) | stub |
| `text` | 52 | 7716 | `text/*data` only | dir-only |
| `content` | 55 | 6132 | `content/` (824) | stub |
| `ua` (accessibility) | 36 | 5871 | — | none |
| `draw` | 33 | 4195 | `draw/fixture_acceptance` only | dir-only |
| `image` | 29 | 4071 | `image/fixture_acceptance` only | dir-only |
| `metadata` | 29 | 3818 | `metadata/` (149) | stub |
| `addtext` | 21 | 3157 | `addtext/` (626) | stub |
| `crypt` | 17 | 2653 | — | none |
| `ocg` | 19 | 2571 | `ocg/` (123) | stub |
| `bookmark` | 21 | 2236 | `bookmark/` (32) | stub |
| `reader` (doc-level) | 32 | 2295 | `reader/` (1549, low-level) | split |
| `codec` (root part) | 16 | 2136 | `codec/` (969) | stub |
| `merge` | 14 | 1922 | — | none |
| `util` | 13 | 1961 | — | none |
| `fun` (functions/shading) | 9 | 1808 | — | none |
| `truetype` | 8 | 1699 | `font/truetype` (data) | split |
| `font` | 8 | 1183 | `font/` (40) + `font/afm`, `font/standard14` | split |
| `writer` (doc-level) | 10 | 1693 | `writer/` (48, low-level) | split |
| `annotation` | 7 | 1567 | `annotation/` (144) | stub |
| `tweak` | 13 | 1391 | — | none |
| `impose` | 6 | 1137 | — | none |
| `toc` | 8 | 961 | `toc/fixture_acceptance` only | dir-only |
| `space` | 5 | 906 | — | none |
| `ccitt` | 6 | 816 | (codec) | none |
| `attach` | 6 | 801 | `attachment/` (13) | stub |
| `document` (stays in root) | 7 | 747 | — | root facade (NOT extracted — see proposal §0) |
| `dest` | 5 | 583 | `destination/` | split |
| `squeeze` | 5 | 552 | — | none |
| `composition` | 4 | 450 | `composition/` (128) | stub |
| `structure` | 4 | 460 | — | none |
| `portfolio` | 4 | 400 | `portfolio/` (24) | stub |
| `redact` | 1 | 344 | — | none |

## How to read this during the refactor

- A `stub` or `dir-only` row is a half-finished extraction: opening the directory
  will mislead you about where the domain's code is. Search root
  `pdf_<prefix>_*.mbt` for the real logic.
- `PdfDocument` and its method API STAY in root as the public facade — the
  `document` extraction (old "keystone/Slice 1") was abandoned as infeasible in
  MoonBit; see `../ARCHITECTURE_PROPOSAL.md` §0.
- Going forward, only the *leaf* parts of a domain (pure models/algorithms that
  don't reference `PdfDocument`) move into packages below root; the
  document-facing feature logic remains in root by design.
