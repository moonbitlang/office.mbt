# CamlPDF Architecture Plan

This is the project-specific architecture checklist for the MoonBit port of the
vendored CamlPDF sources in `.repos/`. Keep `OCaml2MoonBit.md` library-agnostic;
update this file when the project architecture, migration order, or remaining
work changes.

## Architecture Layers

1. Foundation bytes and geometry.
   Owner modules: `pdf_bytes.mbt`, `pdf_io.mbt`, `pdf_transform.mbt`,
   `pdf_units.mbt`, `pdf_paper.mbt`.
   Status: mostly complete for in-memory synchronous operation. Keep byte data
   as `Bytes`/`BytesView`, with ownership changes only at explicit boundaries.

2. Core object graph.
   Owner modules: `pdf_object.mbt`, `pdf_document.mbt`, `pdf_writer.mbt`,
   `pdf_reader.mbt`, `pdf_renumber.mbt`.
   Status: broad coverage for objects, streams, lazy/deferred stream slices,
   reading, writing, strict/reconstructed xrefs, object streams, name trees, and
   renumbering. Strict classic xref parsing now includes CamlPDF's fixed-width
   malformed-separator tolerance for independently bad separator columns and
   CR/CRLF line terminators.
   Remaining focus: broader malformed xref-table recovery and parser-state
   behavior around encrypted/deferred objects.

3. Filters, predictors, and codecs.
   Owner modules: `pdf_codec.mbt`, `pdf_flate.mbt`, `pdf_jpeg.mbt`.
   Status: ASCIIHex, ASCII85, RunLength, LZW decode, Flate decode/encode,
   predictors, filter arrays, document-aware stream decoding, document-wide
   stop-at-unknown stream decompression, and JPEG data extraction are started.
   Remaining focus: higher-ratio dynamic-Huffman Flate output, CCITT/JBIG2
   external-style decode parity, and actual JPEG pixel decoding.

4. Page and content layer.
   Owner modules: `pdf_content.mbt`, `pdf_page.mbt`, `pdf_dest.mbt`,
   `pdf_bookmark.mbt`, `pdf_annot.mbt`, `pdf_page_label.mbt`.
   Status: page tree read/write/change/extract flows, content operators,
   `pdfhello.ml`-style standard-font document round-trip fixtures,
   `pdftest.ml`-style content rewrite fixtures, inline images, destinations,
   bookmarks, annotations, page labels, duplicate annotation fixups, and
   destination pruning are started with direct tests. Direct annotation
   dictionaries in `/Annots` arrays now participate in geometry transforms and
   `change_pages` link-destination matrix transforms; count-changing
   `change_pages` replacements keep CamlPDF's no-mapping behavior and bookmark
   matrix guard, while replacement preserves document metadata, trailer extras,
   and object-stream bookkeeping.
   Remaining focus: additional `change_pages` compatibility fixtures.

5. Text, font, color, function, and image layer.
   Owner modules: `pdf_text.mbt`, `pdf_space.mbt`, `pdf_fun.mbt`,
   `pdf_image.mbt`.
   Status: encodings, UTF-16BE/PDFDocEncoding, ToUnicode CMaps, Identity-H/V
   two-byte CID text extraction, CamlPDF-style whitespace-elided ToUnicode CMap
   section scanning, standard-font extraction, color spaces,
   sampled/interpolation/stitching/calculator functions, and raw/encoded image
   extraction are started.
   Remaining focus: broader predefined CMap semantics, JPEG pixel decode, and
   remaining image filter families.

6. Encryption.
   Owner modules: `pdf_crypt*.mbt`.
   Status: ARC4, hashes, AES primitives, R2/R3/R4/R5/R6 authentication,
   object/string/stream crypt, decryption, deterministic provider adapters,
   provider-backed encryption, deterministic recrypt paths, and a
   `pdfencrypt.ml`-style AES-128 acceptance fixture are started.
   Remaining focus: selecting a true secure OS-entropy provider and deferred
   parser-state encryption/decryption edges.

7. Document-level features.
   Owner modules: `pdf_merge.mbt`, `pdf_ocg.mbt`, `pdf_date.mbt`, plus feature
   helpers in page/text modules.
   Status: merge, optional content groups, dates, page labels, bookmarks,
   duplicate-font paths, the `pdfdecomp.ml` stream-decompression workflow, a
   `pdfmergeexample.ml`-style public workflow fixture, and a `pdfdraft.ml`
   image-replacement acceptance fixture are started.
   Remaining focus: more CamlPDF example-level acceptance fixtures and
   compatibility behavior for unusual real-world documents.

## Current High-Level Checklist

- Done: byte foundation, object model, writer, major reader paths, page tree,
  content parser/writer, standard filters, predictors, many encryption flows,
  text extraction basics, color spaces, functions, bookmarks, annotations,
  page labels, OCG, merge, and image extraction basics.
- In progress: image/filter parity, text CMap parity, encryption finishing
  edges, malformed-reader recovery, and example-level integration fixtures.
- Deferred: CCITT/JBIG2 external-style decode, JPEG pixel decode, default AES
  random source, broader predefined CMap coverage, and broad real-world PDF
  recovery behavior.

## Working Rule

Pick one bounded compatibility slice at a time. Each slice should include:

- a narrow code change,
- focused black-box or white-box tests,
- `CamlPDFMigrationPlan.md` status updates when project behavior changes,
- `OCaml2MoonBit.md` updates only when a reusable language/API fact is newly
  verified,
- `moon info && moon fmt`, `moon test --target all`, coverage, and a regular
  commit.
