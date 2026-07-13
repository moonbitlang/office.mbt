# Validated raw OOXML fallback

Issue [#145](https://github.com/moonbitlang/office.mbt/issues/145) adds a
portable escape hatch for existing DOCX and XLSX packages. Typed commands
remain the preferred API. The raw family exists for uncommon OOXML features
that the typed model cannot yet express.

## Command family

The canonical CLI surface is nested under `office raw`:

```text
office raw list FILE [--json]
office raw read FILE PART [--json] [--base64 | --output FILE]
office raw replace FILE PART (--xml XML | --xml-file FILE)
  [--out FILE] [--dry-run] [--overwrite]
office raw edit FILE PART --path PATH --action ACTION
  [--xml XML | --xml-file FILE]
  [--attribute NAME --value VALUE]
  [--namespace PREFIX=URI]... [--all]
  [--out FILE] [--dry-run] [--overwrite]
```

`list` inventories every package part in canonical name order. Its records
carry the canonical name, content type, XML/binary kind, uncompressed byte
size, and every semantic alias known for that part.

`read` accepts either a semantic alias or an absolute package part name. XML
is decoded strictly as UTF-8 and may be printed as text or returned in the
versioned JSON envelope. Binary data is never written to a terminal by
default: callers must select `--base64` or `--output`. Every mode reports the
decoded byte size.

`replace` replaces one existing XML part with a complete, strict XML
document. `edit` changes selected elements inside one existing XML part.
Neither command creates or removes parts.

## Relationship-driven aliases

Aliases are derived only from exact Transitional or Strict Office
relationship type URIs whose targets have the expected content type, after
the portable package validator succeeds. Vendor relationship URIs that happen
to share a standard suffix never create aliases. Except for the OPC-mandated
`[Content_Types].xml` and root relationship part, implementation code must not
assume conventional `word/` or `xl/` locations.

Common aliases include:

- `/content-types` and `/relationships`;
- DOCX `/document`, `/document/relationships`, `/styles`, `/settings`,
  `/numbering`, `/comments`, `/footnotes`, `/endnotes`, `/theme`,
  `/header[N]`, and `/footer[N]`;
- XLSX `/workbook`, `/workbook/relationships`, `/styles`, `/shared-strings`,
  `/theme`, `/sheet[N]`, `/<SheetName>`, and the corresponding worksheet
  relationship aliases.

An absolute package name such as `/customXml/item1.xml` remains available for
every part. Alias lookup and OPC target resolution are case-insensitive while
the exact archive spelling is retained for reads and writes. Ambiguous aliases
fail closed.

The short `/name` form resolves automatically only when it is unambiguous.
If a semantic alias collides with a different literal root part, use
`alias:/name` for the relationship-derived alias or `part:/name` for the
literal package part. These explicit forms ensure that every real part remains
addressable without silently choosing the wrong mutation target.

## Bounded XML path grammar

Raw edit paths are absolute and select elements only:

```text
path       := "/" segment ("/" segment)*
segment    := qname predicate?
predicate  := "[" positive-integer "]"
            | "[@" qname "=" quoted-string "]"
qname      := ncname | ncname ":" ncname
```

Examples:

```text
/w:document/w:body/w:p[2]
/x:worksheet/x:sheetData/x:row[@r="10"]
```

Positions are one-based among same-name sibling elements. Attribute
predicates use exact decoded XML values. A path with zero matches fails. A
path with more than one match fails unless `--all` is explicit, and even then
the match count is capped.

Built-in prefixes cover the stable OOXML namespaces used by DOCX and XLSX.
`--namespace PREFIX=URI` adds or intentionally overrides a selector binding.
Matching uses expanded namespace names, so a producer's choice of source
prefix does not affect a selector. Unprefixed selector names match only the
empty namespace.

There is no descendant axis, wildcard, parent axis, function, union, regular
expression, arbitrary XPath predicate, or executable expression.

## Edit actions

The bounded action set is:

- `append` and `prepend`, relative to the selected element's children;
- `insert-before` and `insert-after`, relative to the selected element;
- `replace` and `remove`, covering the selected element's exact source span;
- `set-attribute`, using `--attribute` and `--value`.

Element-producing actions accept exactly one XML element. The fragment must
be self-contained: every namespace prefix it uses must be declared in the
fragment itself. A strict DTD-free parser rejects malformed names, duplicate
expanded attributes, invalid characters, unknown prefixes, DTDs, and external
entities before any package bytes are built.

Edits are source-span splices. Bytes outside the declared spans of the
mutated XML part remain identical. Untouched ZIP local records are copied
byte-for-byte; their compressed payloads, timestamps, extras, descriptors,
and central metadata remain intact. Local-record order, central-directory
order, entry comments, attributes, and the archive comment are preserved.

## Validation and publication

All inputs are bounded before materialization: package bytes, entry count,
per-entry and aggregate expansion, XML part bytes, path length/depth, fragment
bytes, and selected node count.

The mutation callback is pure and produces a candidate package plus a
one-part preservation manifest. A4 then:

1. checks the manifest against payload-level archive differences;
2. reruns portable OPC, relationship, content-type, main-part identity, and
   format validation;
3. runs any configured deeper validator;
4. publishes through the cancellation-safe same-directory transaction, or
   reports a dry run without creating output.

Therefore malformed fragments, relationship regressions, main-part changes,
source races, validation failures, and publication failures leave the input
unchanged. Native and Wasm use the same `moonbitlang/async` I/O path; this
feature adds no project C stubs.

## Explicit non-goals

A5 does not add or remove parts, synthesize relationships, execute general
XPath, infer namespace bindings for fragments, edit binary payloads, or
provide typed content authoring. PowerPoint and MCP remain out of scope.
