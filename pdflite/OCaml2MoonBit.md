# OCaml to MoonBit Migration Guide

This document is a library-agnostic guide for transferring OCaml programs to
MoonBit. Update it whenever a reusable porting rule, language fact, API choice,
or test pattern is verified. Project-specific architecture and migration plans
belong in their own project plan documents.

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

Use `Bytes`/`Byte` for byte-addressed data. Integer literals can be
disambiguated by type context, so `Array[Byte] = [65, 0, 255]` is valid.
When calling a method directly on an integer literal, parenthesize the literal:
use `(65).to_byte()`, not `65.to_byte()`, because `65.` is parsed as the start
of a floating-point literal.

```sh
moon run -c 'fn main { let b = @ascii.encode("PDF"); println(b.length()); println(b[0].to_int()) }'
# 3
# 80
```

Use ASCII encoding helpers for format syntax that is defined as ASCII bytes,
then append binary payloads as `Bytes`/`BytesView`. Do not build binary file
formats through `String` concatenation.

```sh
moon run -c $'fn push_ascii(output : Array[Byte], text : String) -> Unit { for byte in @ascii.encode(text)[:] { output.push(byte) } }\nfn main { let output : Array[Byte] = []; push_ascii(output, "PDF"); output.push(10); let bytes = Bytes::from_array(output); println(bytes.length()); println(bytes[0].to_int()); println(bytes[3].to_int()) }'
# 4
# 80
# 10
```

For binary writers, use `Array[Byte]` as the mutable output builder. Append
ASCII format syntax by iterating over `@ascii.encode(text)[:]`, append binary
payloads from `BytesView`, and call `Bytes::from_array` once at the ownership
boundary. This is the usual MoonBit replacement for OCaml code that used
`Buffer`, `Bytes`, or byte-oriented `string` concatenation to construct output.

```sh
moon run -c 'fn main { let (b, u16, i64, u64) : (Byte, UInt16, Int64, UInt64) = (255, 65535, 42, 42); println(b.to_int()); println(u16.to_int()); println(i64.to_string()); println(u64.to_string()) }'
# 255
# 65535
# 42
# 42
```

MoonBit has useful scalar types for ports from OCaml: `Byte`, `Int16`,
`UInt16`, `Int`, `UInt`, `Int64`, `UInt64`, `Float`, and `Double`.

```sh
moon run -c 'fn main { let b : Byte = 255; let x : UInt64 = b.to_uint64(); println(x.to_string()); println((x / 85).to_string()); println((x % 85).to_byte().to_int()) }'
# 255
# 3
# 0
```

For byte-codec arithmetic, promote `Byte` to `UInt64` before multiplying by
large radices. Convert back only after reducing the value into byte range,
because `UInt64::to_int()` truncates to 32 signed bits for large values.

```sh
moon run -c 'fn main { println((-1) % 256); let normalized = if (-1) % 256 < 0 { ((-1) % 256) + 256 } else { (-1) % 256 }; println(normalized); println(normalized.to_byte().to_int()) }'
# -1
# 255
# 255
```

MoonBit `%` keeps a negative remainder when the left operand is negative. When
porting OCaml byte-codec expressions such as `(a - b) mod 256`, normalize the
remainder into `0..255` before converting to `Byte`.

```sh
moon run -c 'fn main { let tiny : Double = try! @strconv.from_str("1e-10"); println(tiny.to_string()) }'
# 1e-10
```

`Double::to_string()` may emit scientific notation. When porting binary or
document formats whose numeric grammar disallows exponents, add a named
formatter at the serialization boundary instead of writing `Double::to_string()`
directly.

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
moon run -c 'fn has_ab(view : BytesView) -> Bool { match view { [65, 66, ..] => true; _ => false } }
fn main { let bytes : Bytes = [65, 66, 67]; let view = bytes[:2]; println(view.length()); println(view[0].to_int()); println(has_ab(bytes[:])); println(has_ab(view)) }'
# 2
# 65
# true
# true
```

Use `BytesView` for read-only byte slices. It is the byte-sequence counterpart
to `ArrayView`: views are cheap slices, expose read-only byte operations, and
support pattern matching with rest patterns. Prefer passing or returning
`BytesView` while data can remain borrowed; call `.to_owned()` only when an
owned `Bytes` value is required. `BytesView::to_owned()` returns the original
bytes for a whole view but allocates and copies for a partial slice.

```sh
moon run -c 'fn main { let fixed : FixedArray[Int] = [1, 2, 3]; let doubled = [ for x in fixed => x * 2 ]; println(doubled.length()); println(doubled[2]) }'
# 3
# 6
```

MoonBit array/list comprehension syntax is `[ for x in xs => expr ]`.
Use a simple identifier as the comprehension or `for ... in` binder; destructure
tuples inside the loop body or access tuple fields.

```sh
moon run -c 'fn main { let pairs = [(1, 2), (3, 4)]; let firsts = [ for pair in pairs => pair.0 ]; println(firsts[0]); println(firsts[1]) }'
# 1
# 3
```

```sh
moon run -c 'fn main { let xs = [(2, "b"), (1, "a")]; xs.sort_by(fn(a, b) { a.0.compare(b.0) }); println(xs[0].0) }'
# 1
```

MoonBit `Array::sort_by` sorts the mutable array in place. Its comparator
returns an `Int`, so OCaml `List.sort compare` or `Array.sort compare` ports can
usually become `xs.sort_by(fn(a, b) { ...compare... })` after copying to an
owned `Array` if the source is an `ArrayView` or other read-only view.

```sh
moon run -c 'fn main { let xs = [1, 2, 3]; match xs { [_, .. rest] => { let owned = [ for x in rest => x ]; println(rest.length()); println(owned.length()); println(owned[0]) }; _ => () } }'
# 2
# 2
# 2
```

Array rest patterns bind read-only views. If an enum payload or API requires an
owned `Array[T]`, copy the rest view deliberately with a comprehension such as
`[ for x in rest => x ]`.

```sh
moon run -c 'fn main { let m : @hashmap.HashMap[Int, String] = @hashmap.HashMap::new(); m[7] = "seven"; println(m.get(7).unwrap()) }'
# seven
```

Code files do not contain OCaml-style `open`. Add package imports in
`moon.pkg`, then call imported packages with their `@alias`.

```sh
moon run -c 'fn first_positive(xs : Array[Int]) -> Int? { let mut i = 0; while i < xs.length() { if xs[i] > 0 { break Some(xs[i]) }; i += 1 } nobreak { None } }
fn main { println(first_positive([-2, 0, 7]).unwrap()); println(first_positive([-2, 0]) is None) }'
# 7
# true
```

MoonBit `while` loops may produce a value with `break value`; the branch used
when the loop condition becomes false is `nobreak { ... }`. Older examples may
spell this as `else`, but that form is deprecated.

```sh
moon run -c 'fn count_until(limit : Int) -> Int { let mut count = 0; let mut done = false; while !done { count += 1; if count >= limit { done = true } }; count }
fn main { println(count_until(3)) }'
# 3
```

Avoid the older functional `loop ... { ... }` form in new ports; MoonBit now
warns on it. Use an explicit `while` loop with mutable state for simple
translation of recursive OCaml loops, or a modern `for` loop with loop binders
when carrying structured state.

```sh
moon run -c $'fn greet(name? : String = "pdf") -> String { name }\nfn main { println(greet()); println(greet(name="moon")) }'
# pdf
# moon
```

MoonBit default arguments are labelled arguments. Write `name? : T = default`
in the function declaration and call it as `name=value`. Do not write a default
on an unlabelled positional parameter.

```sh
moon run -c 'fn takes_view(xs : ArrayView[Int]) -> Int { xs.length() }
fn sample(xs? : ArrayView[Int] = []) -> Int { takes_view(xs) }
fn main { println(sample()); println(sample(xs=[1, 2, 3])) }'
# 0
# 3
```

Optional arguments with view types can use an empty array literal as the
default. If a function parameter is optional-only, pass a non-default value with
its label, for example `sample(xs=[1, 2, 3])`, not `sample([1, 2, 3])`.

```sh
moon run -c 'struct Item { value : Int; label : String } derive(Debug)
fn main { let old = Item::{ value: 1, label: "a" }; let next = { ..old, value: 2 }; println(next.value); println(next.label) }'
# 2
# a
```

MoonBit record update uses `{ ..old, field: value }`, which is the direct
replacement for OCaml `{ old with field = value }` when translating immutable
record updates.

## Core Porting Rules

### Strings and Bytes

OCaml `string` is a byte sequence. MoonBit `String` is UTF-16 text.
Do not mechanically port OCaml `string` to MoonBit `String`.

Default rule:

- OCaml values used as binary payloads, protocol frames, checksums, encrypted
  data, compressed data, file contents, or parser input become `Bytes`.
- Single byte values become `Byte` where range is known to be 0..255, otherwise
  use `Int` at parser boundaries and convert deliberately.
- Human text, diagnostics, file/source labels, and API names that are truly
  Unicode text use `String`.
- Format-specific identifiers that are byte-oriented should get a small newtype
  or alias instead of being represented as raw `String`.
- Only convert `Bytes` to `String` through named helpers that document the
  encoding assumption: ASCII, UTF-8, UTF-16BE/LE, a domain-specific encoding,
  or unchecked debug output.
- MoonBit `Bytes` is immutable. Build mutable byte data with
  `FixedArray[Byte]`, `Array[Byte]`, or a buffer, then freeze it into `Bytes`.

### Numbers

OCaml `int` is used for many distinct concepts. In MoonBit, choose the narrow
meaning:

- Identifiers, array indexes, and counts: usually `Int`.
- File offsets and large serialized positions: `Int64` unless the API is
  explicitly bounded by in-memory `Bytes.length()`.
- Raw bytes: `Byte`.
- Bit-level unsigned arithmetic: `UInt`, `UInt64`, or `Byte` as appropriate.
- OCaml `float`: usually `Double`.

### Data Structures

Map OCaml variants to MoonBit `enum` values. Derive `Debug`, `Eq`, and `ToJson`
for types that will be inspected in tests.

OCaml `array` maps most directly to MoonBit `FixedArray`. MoonBit `Array` is
resizable. Prefer `ArrayView[T]` for read-only function parameters so callers
can pass fixed, growable, or read-only arrays by coercion.

For an OCaml variant, start with a direct MoonBit `enum` shape and make payload
types explicit:

```mbt
enum Value {
  Null
  Boolean(Bool)
  Integer(Int)
  Real(Double)
  String(Bytes)
  Array(Array[Value])
} derive(Debug, Eq, ToJson)
```

Use ordered arrays of pairs when the OCaml code relies on insertion order or
stable rendering. Use `@hashmap.HashMap` for non-ordered lookup tables once the
package imports are added to `moon.pkg`.

### Mutation and Laziness

OCaml uses `ref`, mutable records, and lazy object parsing. MoonBit equivalents:

- `Ref[T]` for a direct `ref`.
- `mut` fields inside structs for document/object-map state.
- Structs with mutable fields for larger state, instead of hiding mutation
  inside tuple refs or nested mutable containers.
- Immutable record updates use `{ ..old, field: value }`.
- Represent lazy/deferred states as explicit `enum` variants.

### Errors

OCaml exceptions such as domain-specific errors, `Not_found`, `End_of_file`, and
`Invalid_argument` should not be copied as unchecked control flow.

MoonBit uses checked errors:

- Define a project-level `suberror` once the first fallible functions are
  ported.
- Functions that can fail should declare `raise ProjectError` or plain `raise`
  if the error set is intentionally broad.
- In tests, use `try? f()` and inspect or pattern-match the `Result`.
- In ordinary code, avoid `match (try? f()) { Ok(...) => ...; Err(...) => ... }`.
  MoonBit warns on that anti-pattern; prefer `try f() catch { ... } noraise
  { ... }`.

### Async I/O

MoonBit supports async I/O and encourages explicit async boundaries. There is
no `await` keyword; async functions call other async functions directly.

Migration rule:

- Keep CPU-bound pure transformations over `Bytes` synchronous.
- Make filesystem/network-facing entry points async when they touch
  `moonbitlang/async` APIs.
- Prefer async wrappers that load file contents into `Bytes`, then call the
  synchronous core. This avoids making every recursive helper async.
- Async tests require native target support and package imports for
  `moonbitlang/async` in the test section of `moon.pkg`.

## MoonBit Testing Model

Testing should be part of each migration slice.

Test file roles:

- `*_test.mbt`: black-box tests. They call only public APIs through the package
  alias.
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
- For parser/serializer, encoder/decoder, or loader/writer pairs, pair focused
  edge-case tests with at least one public API round-trip test when practical.
  This catches ownership, byte/text, and object-boundary mistakes that isolated
  unit tests can miss.

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

## Update Discipline

When a reusable OCaml pattern is encountered, record the MoonBit decision here
before or alongside the code change. Each rule should leave behind:

- The OCaml behavior being replaced.
- The MoonBit API or idiom chosen.
- The verification command(s), especially `moon run -c` probes.
- Any known incompatibility or deferred behavior.
