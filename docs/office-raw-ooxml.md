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
  [--out FILE] [--dry-run] [--overwrite] [--json]
office raw edit FILE PART --path PATH --action ACTION
  [--xml XML | --xml-file FILE]
  [--attribute NAME --value VALUE]
  [--namespace PREFIX=URI]... [--all]
  [--out FILE] [--dry-run] [--overwrite] [--json]
```

`list` inventories every package part in canonical name order. Its records
carry the canonical name, content type, XML/binary kind, uncompressed byte
size, and every semantic alias known for that part.

`read` accepts either a semantic alias or an absolute package part name. XML
is decoded strictly as UTF-8, UTF-16LE, or UTF-16BE and may be printed as text
or returned in the versioned JSON envelope. Span edits remain UTF-8-only
because they preserve exact source byte ranges. Binary data is never written
to a terminal by default: callers must select `--base64` or `--output`.
Human XML and base64 modes print the selected payload followed by one line
terminator. Use `--output` when exact payload bytes are required. JSON includes
the part's uncompressed byte size, while human file mode confirms the number
of bytes written. File output uses same-directory staging, sync, and an atomic
no-replace rename; failure or pre-commit cancellation removes private staging.

`replace` replaces one existing XML part with a complete, strict XML
document. `edit` changes selected elements inside one existing XML part.
Neither command creates or removes parts.

For either mutation command, `--out` must use the same supported extension as
the input package: `.docx` for DOCX and `.xlsx` for XLSX. A mismatched output
extension fails candidate validation before publication, leaving the input
unchanged and creating no destination.

## Relationship-driven aliases

Aliases are derived only from exact Transitional or Strict Office
relationship type URIs whose targets have the expected content type. The
collision-rejecting raw resolver validates exact OPC namespaces, main-part
identity, relationship dialect, and alias budgets before the generic portable
detector runs. Vendor relationship URIs that happen to share a standard suffix
never create aliases. Except for the OPC-mandated `[Content_Types].xml` and
root relationship part, implementation code must not assume conventional
`word/` or `xl/` locations.

Common aliases include:

- `/content-types` and `/relationships`;
- DOCX `/document`, `/document/relationships`, `/styles`, `/settings`,
  `/numbering`, `/comments`, `/footnotes`, `/endnotes`, `/theme`,
  `/header[N]`, and `/footer[N]`;
- XLSX `/workbook`, `/workbook/relationships`, `/styles`, `/shared-strings`,
  `/theme`, `/sheet[N]`, `/<SheetName>`, and the corresponding worksheet
  relationship aliases.

`/sheet[N]` uses the worksheet declaration's ordinal in `workbook.xml`.
Unresolved or wrong-role declarations leave gaps; they never compact a later
worksheet into an earlier numeric alias. Strict workbooks accept only Strict
`r:id` namespaces and relationship type families, and Transitional workbooks
accept only Transitional ones.

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

Built-in prefixes cover both Transitional and Strict OOXML. The namespace
family is derived from the selected part's document element, while `xml` is
always bound to its fixed W3C namespace. `--namespace PREFIX=URI` adds or
intentionally overrides any other selector binding. Matching uses expanded
namespace names, so a producer's choice of source prefix does not affect a
selector. Unprefixed selector names match only the empty namespace.

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
fragment itself, and only whitespace may surround that element. A strict
DTD-free parser rejects malformed names, duplicate expanded attributes,
invalid characters, unknown prefixes, DTDs, and external entities before any
package bytes are built.

A standalone fragment without an explicit default namespace is normalized
with `xmlns=""` on its root. This preserves the fragment's no-namespace
expanded names when it is inserted below an element that has an inherited
OOXML default namespace; the destination context cannot silently reinterpret
the supplied element names.

The action argument matrix is strict: append, prepend, insert-before,
insert-after, and replace require exactly one of `--xml` or `--xml-file` and
forbid attribute arguments; remove forbids all XML and attribute arguments;
set-attribute requires both `--attribute` and `--value` and forbids XML.
Insert-before, insert-after, and remove cannot target the document element.
The same matrix is published structurally by `office help raw --json`.

`set-attribute` serializes tabs, line feeds, and carriage returns as numeric
character references so the XML parser's decoded value is exactly the value
the caller supplied. Processing instructions such as `xml-stylesheet` remain
legal; only an actual XML declaration is treated as a declaration.

Edits are source-span splices. Bytes outside the declared spans of the
mutated XML part remain identical. Untouched ZIP local records are copied
byte-for-byte; their compressed payloads, timestamps, extras, descriptors,
and central metadata remain intact. For a rewritten member, the writer retains
the original local and central templates and patches only payload-dependent
CRC, size, descriptor, and offset fields. Filename bytes, flags, versions,
timestamps, custom extras, comments, attributes, ZIP64 layout, local-record
order, central-directory order, and archive comment are preserved. Replacing
a payload with identical bytes leaves the whole member record unchanged.

## Validation and publication

All inputs are bounded before materialization: package bytes, entry count,
per-entry and aggregate expansion, 1,024-character package part names, XML
part bytes, path Unicode-scalar length/depth, fragment and attribute bytes, selected node
count, metadata records and fields, semantic aliases, and inventory
serialization. A lexical XML preflight enforces element, attribute,
namespace-declaration, in-scope namespace, namespace URI, cumulative expanded
name, scope-work, text, depth, and per-field budgets before the strict DOM
parser runs. Expanded names are interned and namespace scopes use push/pop
updates instead of per-element map copies. The complete post-edit size is
checked with overflow-safe arithmetic before repeated splice buffers are
allocated.

The transaction materializes each ZIP exactly once. The complete bounded raw
identifier consumes an isolated fork of the already materialized input archive;
generic Office DOM parsing cannot precede this boundary. The mutation consumes
another shallow fork, revalidates the logical archive without reinflation, and
produces serialized candidate bytes plus a one-part preservation manifest. The
transaction then:

1. materializes the serialized candidate once under the aggregate live-memory
   budget shared with the still-live original archive;
2. reruns the complete raw collision, namespace, relationship, alias,
   serialization, portable OPC, main-part identity, and format boundary on an
   isolated candidate archive fork;
3. runs configured deeper validators against additional shallow forks;
4. checks the manifest against payload-level archive differences;
5. publishes through the cancellation-safe same-directory transaction, or
   reports a dry run without creating output.

Therefore malformed fragments, relationship regressions, main-part changes,
source races, validation failures, and publication failures leave the input
unchanged. Native and Wasm use the same `moonbitlang/async` I/O path; this
feature adds no project C stubs. Individually valid packages are also rejected
before publication when the concurrently retained input and candidate
materializations would exceed the transaction-wide envelope.

## Explicit non-goals

A5 does not add or remove parts, synthesize relationships, execute general
XPath, infer namespace bindings for fragments, edit binary payloads, or
provide typed content authoring. PowerPoint and MCP remain out of scope.
