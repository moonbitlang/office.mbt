# Porting plan: Excelize (Go) -> MoonBit

This document catalogs Excelize feature areas and a proposed MoonBit package
layout for the port. It also calls out UTF-16 string handling risks and test
coverage expectations.

## Feature map (by Excelize area)

- File/container
  - ZIP reader/writer
  - OOXML package: content types + relationships
- Workbook model
  - workbook metadata, sheets, sheet views
  - shared strings
  - styles and number formats
- Worksheet core
  - cell read/write, cell types
  - rows/cols, dimensions, merged cells
  - calc chain and formulas
- Assets and visuals
  - drawings
  - images
  - charts
  - shapes/VML
- Tables and data features
  - tables
  - data validation
  - conditional formatting
  - sparklines
  - slicers and pivot tables
- Streaming and performance
  - stream writer/reader
- Security and metadata
  - encryption
  - document properties

## Proposed MoonBit package layout

This is a starting layout; packages can be split further as the port grows.

- `zip/`
  - ZIP container read/write
- `ooxml/`
  - content types, relationships, package manifest
- `workbook/`
  - workbook, sheets, shared strings, styles
- `worksheet/`
  - rows, cols, cells, merges, dimensions
- `formula/`
  - formula parsing/serialization, calc chain
- `drawings/`
  - drawings, images, charts, shapes, VML
- `tables/`
  - table definitions and XML
- `validation/`
  - data validation and conditional formatting
- `pivot/`
  - pivot tables and slicers
- `stream/`
  - streaming read/write paths
- `crypto/`
  - encryption/decryption helpers

## UTF-16 string handling notes (MoonBit vs Go)

MoonBit `String` is immutable UTF-16. Excel XML uses UTF-8 on disk. Avoid
porting byte-indexed logic directly from Go.

Guidelines:
- Use `Bytes` for raw XML payloads; decode/encode with `@encoding/utf8`.
- Avoid indexing strings by byte offsets; use `get_char`, `StringView`, or
  explicit UTF-8 byte traversal when offsets are from XML byte positions.
- Keep shared strings as `String` values; only convert to bytes when writing.
- When translating algorithms that assume byte length or `[]byte` slicing,
  re-derive indices in UTF-16 or operate on `Bytes` instead.

## Test coverage expectations

Every feature slice should include snapshot or roundtrip tests. In particular,
UTF-16-sensitive tests must cover:
- Non-BMP characters (surrogate pairs, e.g. emoji)
- Combining marks and multi-codepoint graphemes
- Mixed ASCII + non-ASCII in shared strings and inline XML text
- Range/cell reference parsing that touches string slicing
