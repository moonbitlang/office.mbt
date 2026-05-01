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
state. Arrays are mutable reference values.

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
# Total tests: 8, passed: 8, failed: 0.
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
  `Array[Byte]` or a buffer, then freeze it into `PdfBytes`/`Bytes`.

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

## Migration Plan

1. Establish the byte/text foundation.
   Port a minimal `PdfBytes`/byte helper layer inspired by `.repos/pdfio.ml`.
   Add tests for byte length, byte indexing, construction/freezing, and
   explicit conversions. Do not parse PDFs yet.
   Status: started in `pdf_bytes.mbt` with `PdfBytes`, `PdfName`, checked
   `Int` to `Byte` conversion, and black-box tests in `pdflite_test.mbt`.

2. Port the in-memory PDF object model.
   Add `PdfObject`, stream state, document/object-map types, and dictionary
   helpers from `.repos/pdf.mli`/`.repos/pdf.ml`. Keep stream data as `Bytes`
   and dictionary keys as `PdfName`. Add black-box tests for constructors and
   white-box tests for dictionary lookup/replacement order.

3. Port low-level parser input over `Bytes`.
   Implement a seekable byte cursor replacing `Pdfio.input_of_string` and
   `input_of_bytes`. Keep this synchronous. Add tests for `peek`, `rewind`,
   line reading, EOF behavior, and byte offsets.

4. Port lexical utilities and primitive PDF token parsing.
   Move whitespace/delimiter predicates, integer/real/name/string token parsing,
   and error reporting. Use snapshot tests for malformed input errors and
   assertion tests for stable tokens.

5. Port object lookup and lazy object parsing.
   Implement the object map, parsed/to-parse states, indirect lookup, and
   delayed object-stream hooks. Add small synthetic object-map tests before
   reading full files.

6. Port reader/writer round trips over `Bytes`.
   Parse a minimal generated PDF, write it back, then parse again. Add golden
   tests using compact hand-written PDFs before larger fixtures.

7. Port filters, compression, encryption, and image/text helpers incrementally.
   Treat each subsystem as a separate slice with focused fixtures. Decide per
   subsystem whether to use pure MoonBit, an existing package, or native C
   bindings.

8. Add async public I/O wrappers and CLI behavior.
   Keep core parse/write pure over `Bytes`; async entry points load/store bytes
   and call the pure core. Add async tests on the native target.

9. Expand compatibility coverage.
   Add fixtures from CamlPDF examples and regression PDFs as available. Track
   uncovered parser/writer branches with `moon coverage analyze`.

## Update Discipline

When a new OCaml pattern is encountered, record the MoonBit decision here before
or alongside the code change. Each section of the port should leave behind:

- The source OCaml file(s) covered.
- The MoonBit files added or changed.
- The verification command(s) used.
- Any known incompatibility or deferred behavior.
