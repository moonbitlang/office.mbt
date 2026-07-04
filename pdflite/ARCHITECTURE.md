# pdflite Architecture

This document describes the intended long-term package shape. The current code
base still has a large root package; refactors should move it toward these
layers in small, reviewable slices.

## Goals

- Keep PDF syntax, document state, codecs, and feature APIs separated by
  responsibility.
- Prefer narrow packages with clear dependency direction over broad files in the
  root package.
- Treat root package APIs as movable during the current refactor period. There
  are few third-party users, so compatibility wrappers can be removed when they
  block a cleaner package shape.
- Keep each refactor slice behavior-preserving unless the commit explicitly says
  it changes API or behavior.

## Target Layers

1. Foundation
   - byte cursors and byte output
   - bit streams
   - primitive name/string/number helpers
   - small data structures such as number sets

2. PDF syntax and object model
   - lexemes and parser helpers
   - PDF object model
   - dictionaries, arrays, streams, indirect references
   - object serialization

3. Document core
   - `PdfDocument`
   - object maps and event logs
   - catalog and trailer access
   - page tree lookup
   - reader/writer reconstruction state

4. Codecs and stream filters
   - ASCIIHex, ASCII85, RunLength, LZW, Flate
   - image predictors
   - CCITT/JPEG/JPEG2000/PNG helpers
   - encryption primitives and stream policies

5. Feature domains
   - pages and page transforms
   - content streams and text extraction
   - images
   - metadata/XMP/catalog reporting
   - annotations, bookmarks, attachments, forms, portfolios
   - composition, impose, drawing, markdown

6. Entry points
   - CLI packages
   - async file I/O
   - fixture and cram acceptance tests

## Dependency Direction

Dependencies should point down the layer list:

- Feature domains may depend on document core, syntax/object, codecs, and
  foundation.
- Document core may depend on syntax/object and foundation.
- Syntax/object may depend on foundation.
- Foundation packages should not depend on document or feature packages.
- CLI and async packages may depend on public feature/domain packages.

Temporary exceptions are acceptable while extracting the current root package,
but every exception should have an obvious next extraction step.

## Refactor Workflow

1. Start inside the current package by splitting large files into cohesive
   responsibility files. File moves inside a package should not change semantics.
2. Move pure helpers into `internal/*` packages once their dependencies are
   one-way and obvious.
3. Move feature domains into public subpackages when they can depend on the
   document core without cycles.
4. Remove source-compatibility wrapper APIs when they keep old CamlPDF/cpdf
   shapes alive without improving MoonBit ergonomics.
5. After each slice, run:

   ```bash
   moon check
   moon info
   moon fmt
   moon test
   ```

6. Review `pkg.generated.mbti` diffs. API changes are allowed during this
   refactor period, but they should be intentional and described in the commit.

## Current High-ROI Slices

- Split `pdf_metadata.mbt` into catalog, XML tree, XMP lookup/rewrite, reporting,
  date, stream, and compatibility-wrapper files.
- Split `pdf_codec.mbt` into one file per filter family and a small filter
  dispatch file.
- Move byte cursor/output/bitstream helpers toward a foundation package.
- Move PDF syntax parsing/serialization toward a syntax package.
- Move large text CMap data tables into a data package or generated-data
  directory so hand-written text logic is easier to review.
