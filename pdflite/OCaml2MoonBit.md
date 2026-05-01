# OCaml to MoonBit Migration Notes

This document is the living migration ledger for porting CamlPDF from OCaml to
MoonBit. Update it whenever a porting rule, API choice, test pattern, or
migration ordering decision changes.

The vendored CamlPDF source in this checkout is under `.repos/` directly. The
first files inspected were `.repos/pdfio.mli`, `.repos/pdfio.ml`,
`.repos/pdf.mli`, `.repos/pdf.ml`, `.repos/pdfutil.mli`, and
`.repos/pdfutil.ml`.

## Verified MoonBit Facts

Verified with `moon 0.1.20260430` and OCaml 4.14.1.

The key byte/text contrast was validated on both sides:

```sh
ocaml -noprompt -noinit <<'EOF'
let s = "𝄞";;
Printf.printf "%d\n" (String.length s);;
Printf.printf "%d\n" (Char.code s.[0]);;
EOF
# 4
# 240
```

OCaml `String.length` counts bytes. The first byte of the UTF-8 spelling of
`𝄞` is 240.

Run small language/API probes with `moon run -c '...'` before committing a
porting pattern to the codebase. Useful verified probes:

```sh
moon run -c 'fn main { let s = "𝄞"; println(s.length()); println(s.char_length()) }'
# 2
# 1
```

MoonBit `String::length()` counts UTF-16 code units, not bytes and not Unicode
scalar values. `String::char_length()` counts Unicode characters.

```sh
moon run -c 'fn main { let raw : Array[Byte] = [65, 0, 255]; let b = Bytes::from_array(raw); println(b.length()); println(b[2].to_int()) }'
# 3
# 255
```

Use `Bytes`/`Byte` for byte-addressed PDF data. Integer literals can be
disambiguated by type context, so `Array[Byte] = [65, 0, 255]` is valid.

```sh
moon run -c 'fn main { let (b, u16, i64, u64) : (Byte, UInt16, Int64, UInt64) = (255, 65535, 42, 42); println(b.to_int()); println(u16.to_int()); println(i64.to_string()); println(u64.to_string()) }'
# 255
# 65535
# 42
# 42
```

MoonBit has useful scalar types for a PDF library: `Byte`, `Int16`, `UInt16`,
`Int`, `UInt`, `Int64`, `UInt64`, `Float`, and `Double`.

```sh
moon run -c 'fn main { let r : Ref[Int] = Ref::{ val: 0 }; r.val += 1; let xs = [1, 2, 3]; xs[0] = 9; println(r.val); println(xs[0]) }'
# 1
# 9
```

Use `Ref[T]` for primitive mutability and mutable fields on structs for larger
state. MoonBit `Array` is a growable mutable vector; `FixedArray` is the closer
match for OCaml `array` because its length is fixed.

```sh
moon run -c $'fn len(xs : ArrayView[Int]) -> Int { xs.length() }\nfn main { let grow = [1, 2, 3]; let fixed : FixedArray[Int] = [1, 2, 3]; println(len(grow)); println(len(fixed)) }'
# 3
# 3
```

Use `ArrayView[T]` for read-only sequence parameters when callers should be
able to pass `Array`, `FixedArray`, or read-only arrays without copying.

```sh
moon run -c 'fn main { let fixed : FixedArray[Int] = [1, 2, 3]; let doubled = [ for x in fixed => x * 2 ]; println(doubled.length()); println(doubled[2]) }'
# 3
# 6
```

MoonBit array/list comprehension syntax is `[ for x in xs => expr ]`.

```sh
moon run -c 'fn main { let m : @hashmap.HashMap[Int, String] = @hashmap.HashMap::new(); m[7] = "seven"; println(m.get(7).unwrap()) }'
# seven
```

Code files do not contain OCaml-style `open`. Add package imports in
`moon.pkg`, then call imported packages with their `@alias`. This is validated
in `ocaml2moonbit_wbtest.mbt` with `@hashmap.HashMap`.

Current package testing status:

```sh
moon test --outline
# ocaml2moonbit_wbtest.mbt contains the initial migration-assumption tests.

moon test
# Total tests: 10, passed: 10, failed: 0.
```

The initial executable validation lives in `ocaml2moonbit_wbtest.mbt`; the
first public byte/name API tests live in `pdflite_test.mbt`.

## Core Porting Rules

### Strings and Bytes

OCaml `string` is a byte sequence in CamlPDF. MoonBit `String` is UTF-16 text.
Do not mechanically port OCaml `string` to MoonBit `String`.

Default rule:

- OCaml values used as PDF stream data, PDF string objects, encryption keys,
  checksums, binary filters, and parser input become `Bytes`.
- Single byte values become `Byte` where range is known to be 0..255, otherwise
  use `Int` at parser boundaries and convert deliberately.
- Human text, diagnostics, file/source labels, and API names that are truly
  Unicode text use `String`.
- PDF names and dictionary keys are bytes in the PDF format. Prefer a small
  `PdfName` newtype or alias over raw `String`; provide ASCII convenience
  helpers later.
- Only convert `Bytes` to `String` through named helpers that document the
  encoding assumption: ASCII, UTF-8, UTF-16BE/LE, PDFDocEncoding, or unchecked
  debug output.
- MoonBit `Bytes` is immutable. This differs from CamlPDF `Pdfio.bytes`, which
  has mutation helpers such as `bset`. Build mutable byte data with
  `FixedArray[Byte]`, `Array[Byte]`, or a buffer, then freeze it into
  `PdfBytes`/`Bytes`.

### Numbers

OCaml `int` is used for many distinct concepts. In MoonBit, choose the narrow
meaning:

- Object numbers, generation numbers, array indexes, and counts: `Int`.
- File offsets and xref positions: `Int64` unless the API is explicitly bounded
  by in-memory `Bytes.length()`.
- Raw bytes: `Byte`.
- Bit-level unsigned arithmetic: `UInt`, `UInt64`, or `Byte` as appropriate.
- OCaml `float` / PDF real numbers: `Double`.

### Data Structures

Map OCaml variants to MoonBit `enum` values. Derive `Debug`, `Eq`, and `ToJson`
for types that will be inspected in tests.

OCaml `array` maps most directly to MoonBit `FixedArray`. MoonBit `Array` is
resizable. Prefer `ArrayView[T]` for read-only function parameters so callers
can pass fixed, growable, or read-only arrays by coercion.

For CamlPDF `Pdf.pdfobject`, start with a MoonBit shape like:

```mbt
enum PdfObject {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(Bytes)
  Name(PdfName)
  Array(Array[PdfObject])
  Dictionary(Array[(PdfName, PdfObject)])
  Stream(StreamObject)
  Indirect(Int)
} derive(Debug, Eq, ToJson)
```

Keep dictionaries as ordered arrays of pairs at first. CamlPDF often preserves
dictionary order when rewriting, and a linear lookup helper is simpler and more
faithful than immediately normalizing everything into a hash map.

Use `@hashmap.HashMap` for object maps and other non-ordered lookup tables once
the package imports are added to `moon.pkg`.

### Mutation and Laziness

OCaml uses `ref`, mutable records, and lazy object parsing. MoonBit equivalents:

- `Ref[T]` for a direct `ref`.
- `mut` fields inside structs for document/object-map state.
- Structs with mutable fields for stream state, instead of hiding mutation
  inside tuple refs.
- Represent lazy parse states as an `enum ObjectData`, mirroring CamlPDF:
  parsed, parsed-already-decrypted, to-parse, and to-parse-from-object-stream.

### Errors

OCaml exceptions such as `PDFError`, `Not_found`, `End_of_file`, and
`Invalid_argument` should not be copied as unchecked control flow.

MoonBit uses checked errors:

- Define `pub(all) suberror PdfError` once the first parser/lookup functions are
  ported.
- Functions that can fail should declare `raise PdfError` or plain `raise` if
  the error set is intentionally broad.
- In tests, use `try? f()` and inspect or pattern-match the `Result`.

### Async I/O

MoonBit supports async I/O and encourages explicit async boundaries. There is
no `await` keyword; async functions call other async functions directly.

Migration rule:

- Keep pure parsing and writing over `Bytes` synchronous.
- Make filesystem/network-facing entry points async when they touch
  `moonbitlang/async` APIs.
- Prefer async wrappers that load file contents into `Bytes`, then call the
  synchronous parser. This avoids making every recursive parser helper async.
- Async tests require native target support and package imports for
  `moonbitlang/async` in the test section of `moon.pkg`.

## MoonBit Testing Model

Testing is part of each migration slice.

Test file roles:

- `*_test.mbt`: black-box tests. They call only public APIs through the package
  alias, such as `@pdflite.fn`.
- `*_wbtest.mbt`: white-box tests. They run inside the package and may test
  private helpers.
- `*.mbt.md`: documentation with checked code blocks. Use `mbt check` for code
  that should compile and test, and `mbt nocheck` for illustrative code.

Assertion style:

- Use `@test.assert_eq` for stable scalar or structural results; it has a
  `Debug` bound and avoids the deprecated `Show`-based assertion path.
- Use `assert_true(value is Pattern(...))` or `guard ... else { fail(...) }`
  for pattern checks.
- Use `inspect(value, content="...")` for snapshot tests of small values.
- Use `json_inspect(value, content=...)` for complex values with `ToJson`.
- If the expected snapshot is unknown, write `inspect(value)`, run
  `moon test --update`, then review the updated `content=...` diff.
- For raising functions, use `let result : Result[T, Error] = try? f()` and
  assert or inspect the result.

Useful commands:

```sh
moon run -c 'fn main { ... }'              # quick language/API probe
moon check --warn-list +73                 # fast type check with extra warnings
moon test --outline                        # list discovered tests
moon test                                  # run all tests
moon test path/to/file_test.mbt            # run one test file
moon test package/dir --filter 'glob'      # targeted test glob
moon test --update                         # refresh snapshots, then review diff
moon test --target native                  # required for async I/O tests
moon coverage analyze > uncovered.log      # coverage report
moon info && moon fmt                      # final interface update and format
```

Validation rule for each migration patch:

1. Add or update tests before or with the ported code.
2. Add any `moon run -c` probe to this document if it taught us a reusable rule.
3. Run targeted `moon test` while developing.
4. Finish with `moon check --warn-list +73`, `moon test`, and
   `moon info && moon fmt`.

## CamlPDF Architecture Snapshot

This snapshot is based on `.repos/Makefile`, `.repos/META`, the public
`.mli` files, and the examples under `.repos/examples/`.

CamlPDF identifies itself as package `camlpdf` version `2.9`: "Read, write and
modify PDF files". Its build order is the clearest high-level dependency map:

```text
pdfe pdfutil pdfio pdftransform pdfunits pdfpaper
pdfcryptprimitives pdf pdfcrypt pdfflate pdfcodec pdfwrite pdfgenlex
pdfread pdfjpeg pdfops pdfdest pdfmarks pdfpagelabels pdftree pdfst pdfpage
pdfannot pdffun pdfspace pdfimage pdfafm pdfafmdata pdfglyphlist pdfcmap
pdftext pdfstandard14 pdfdate pdfocg pdfmerge
```

The source is about 22,800 lines of OCaml. The largest and highest-risk modules
are `pdfread.ml`, `pdfcodec.ml`, `pdfpage.ml`, `pdfutil.ml`, `pdf.ml`,
`pdfcrypt.ml`, `pdftext.ml`, `pdfops.ml`, `pdfwrite.ml`, and `pdffun.ml`.

Architectural layers:

1. Foundation.
   `pdfe`, `pdfutil`, `pdfio`, `pdftransform`, `pdfunits`, and `pdfpaper`
   provide logging, list/string utilities, byte input/output, bitstreams,
   geometry, units, and paper sizes. Nearly every module opens `Pdfutil`, and
   parser/filter modules also depend on `Pdfio`.

2. Core PDF model.
   `pdf` defines `pdfobject`, streams, lazy/deferred object states, object maps,
   document state, dictionary lookup and replacement, indirect object lookup,
   renumbering, traversal, name trees, IDs, and rectangle/matrix helpers. Most
   other modules depend on this layer.

3. Compression and encryption infrastructure.
   `pdfcryptprimitives`, `pdfflate`, `pdfcodec`, and `pdfcrypt` implement
   primitive crypto, zlib/flate bindings, stream filters, predictors, stream
   encode/decode mutation, permission handling, and document encryption.

4. Reader and writer.
   `pdfgenlex` defines token/lexeme shapes. `pdfread` reads headers, xrefs,
   trailers, encrypted documents, object streams, dictionaries, strings, names,
   comments, and stream data from `Pdfio.input`. `pdfwrite` serializes objects,
   streams, xrefs, trailers, PDF strings, real numbers, and encrypted output.

5. Page, content, and document feature layer.
   `pdfpage`, `pdfops`, `pdftree`, `pdfst`, `pdfdest`, `pdfmarks`,
   `pdfpagelabels`, `pdfannot`, and `pdfocg` operate on the object model to
   expose page trees, content stream operators, destinations, bookmarks, page
   labels, annotations, optional content groups, and structure tree helpers.

6. Text, font, color, and image layer.
   `pdftext`, `pdfspace`, `pdfimage`, `pdfjpeg`, `pdfafm`, `pdfafmdata`,
   `pdfglyphlist`, `pdfcmap`, and `pdfstandard14` cover font models, encodings,
   PDFDocEncoding, UTF-8/UTF-16BE conversion, glyph names, color spaces, image
   extraction, JPEG data, AFM metrics, CMaps, and the standard fonts.

7. Application-level operations.
   `pdfmerge` combines documents and removes duplicate fonts. The examples also
   show canonical workflows for hello-PDF creation, merge, decompose streams,
   page-content modification, and encryption.

Primary data flow:

```text
file/channel/bytes
  -> Pdfio.input
  -> Pdfread lexing/parsing/xref resolution
  -> Pdf.t object graph with lazy stream/object states
  -> page/content/text/filter/encryption transformations
  -> Pdfwrite serialization
  -> output/file/bytes
```

MoonBit migration consequence:

- Keep the first public API centered on pure `Bytes -> PdfDocument -> Bytes`
  transformations, then layer async file I/O at the boundary.
- Treat `Pdfio` and `Pdf` as the root of the port. The reader, writer, filters,
  and page/text APIs should not start until the byte cursor and object model are
  covered by focused tests.
- Preserve lazy/deferred object and stream states as explicit enums. This keeps
  compatibility with CamlPDF's lazy read path without making recursive parsing
  async.
- Handle native C dependencies deliberately. CamlPDF ships C stubs for flate,
  AES, and SHA2 (`flatestubs.c`, `miniz.c`, `rijndael-alg-fst.c`,
  `stubs-aes.c`, `sha2.c`, `stubs-sha2.c`). Each one needs an explicit
  MoonBit choice: pure MoonBit package, native binding, or deferred unsupported
  filter/encryption path.

## Migration Plan

0. Language and project foundation.
   Status: done for the first checkpoint. `OCaml2MoonBit.md` records validated
   language rules. `ocaml2moonbit_wbtest.mbt` covers the byte/text, scalar,
   mutability, `FixedArray`, `ArrayView`, comprehension, and package-import
   assumptions. `pdf_bytes.mbt` starts the byte foundation with `PdfBytes`,
   `PdfName`, checked `Int` to `Byte` conversion, `ArrayView` inputs, and
   black-box tests in `pdflite_test.mbt`.

1. Low-level byte and input layer.
   Port the useful subset of `.repos/pdfio.mli` first:
   `ByteCursor` over `Bytes`, byte builders, copy/freeze helpers, input
   position/source labels, `peek`, `read`, `rewind`, `nudge`, line reading, EOF
   behavior, and bitstream read/write. Keep this synchronous and in-memory.
   Add white-box tests for offset accounting and black-box tests for public byte
   helpers.

2. Small pure support modules.
   Port `.repos/pdftransform`, `.repos/pdfunits`, `.repos/pdfpaper`, and the
   safe subset of `.repos/pdfutil` needed by later code. Prefer local functions
   over a broad util module when a helper has only one caller. Add assertion
   tests for matrix math, rectangles, units, and paper sizes.

3. Core object model and document state.
   Port `.repos/pdf.mli` in slices:
   `PdfObject`, `PdfStream`, ordered dictionaries, indirect references,
   document/object-map state, lazy object states, stream `ToGet` metadata,
   lookup helpers, add/remove/iterate object operations, traversal,
   renumbering, and name tree helpers. Use `PdfName` for names, `Bytes` for PDF
   strings and streams, `ArrayView` for read-only sequence parameters, and
   `FixedArray` for fixed OCaml-array semantics.

4. Lexer and primitive parser.
   Port `.repos/pdfgenlex` and the lexical subset of `.repos/pdfread`:
   whitespace and delimiter predicates, numbers, names with `#xx` escapes,
   literal strings, hex strings, comments, dictionaries, arrays, and stream-data
   lexemes. Use snapshot tests for malformed inputs and `@test.assert_eq` for
   stable tokens.

5. Minimal PDF reader.
   Implement header, xref, trailer, indirect object parsing, object streams only
   as a deferred state initially, and lazy/eager read entry points over
   `Bytes`. Acceptance target: parse compact hand-written one-page PDFs and
   inspect the object map. Encryption and most filters can report structured
   unsupported errors at this phase.

6. Minimal PDF writer.
   Port object rendering, dictionary/array rendering, stream rendering, xref,
   trailer, real formatting, and PDF string/name escaping from `.repos/pdfwrite`.
   Acceptance target: build a tiny PDF in MoonBit, serialize it, parse it back,
   and compare stable structure. This becomes the first round-trip gate.

7. Stream filters and predictors.
   Port `pdfcodec` incrementally. Start with no-op/raw streams plus
   ASCIIHex/ASCII85/RunLength because they are byte-local. Then add flate and
   predictors after deciding whether to bind C/zlib or use a MoonBit package.
   Keep DCT/JBIG2/CCITT behavior behind explicit capability checks until image
   support needs them.

8. Page tree and content streams.
   Port `pdfpage`, `pdfops`, `pdftree`, and `pdfst` enough to reproduce the
   `pdfhello.ml`, `pdfdecomp.ml`, and `pdftest.ml` workflows: create a page,
   parse/write content operators, read pages from a page tree, modify page
   contents, remove unreferenced objects, and write the result.

9. Text, fonts, color spaces, and images.
   Port `pdftext`, `pdfstandard14`, `pdfglyphlist`, `pdfcmap`, `pdfafm`,
   `pdfspace`, `pdfimage`, and `pdfjpeg` in that order. Treat encoding
   conversion as byte-sensitive: PDF strings remain `Bytes`, decoded human text
   becomes `String` only through named encoding helpers.

10. Encryption.
    Port `pdfcryptprimitives` and `pdfcrypt` once reader/writer/filter basics
    are stable. Decide the primitive strategy first, then add permission flags,
    key derivation, stream/string encryption, decryption, and re-encryption.
    Use small known-vector tests before document-level encrypted fixtures.

11. Higher-level document features.
    Port destinations, bookmarks/marks, page labels, annotations, optional
    content groups, merge, duplicate-font removal, date helpers, and remaining
    utilities. Use CamlPDF examples and regression fixtures as acceptance tests.

12. Async I/O and command-facing APIs.
    Add async native-target wrappers for reading and writing files after the
    pure `Bytes` APIs are stable. Async wrappers should load/store bytes and
    call the synchronous core. Add `moon test --target native` coverage for
    async file APIs.

13. Compatibility and coverage hardening.
    Add fixture suites as features land, update snapshots deliberately, and use
    `moon coverage analyze > uncovered.log` to find untested parser, writer,
    filter, and page-tree branches.

## Update Discipline

When a new OCaml pattern is encountered, record the MoonBit decision here before
or alongside the code change. Each section of the port should leave behind:

- The source OCaml file(s) covered.
- The MoonBit files added or changed.
- The verification command(s) used.
- Any known incompatibility or deferred behavior.
