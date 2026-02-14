# ooxml

Helper package for generating OOXML (Office Open XML) package metadata. This is an internal package used by the xlsx package to build the structural elements of XLSX files.

## Overview

OOXML files (like XLSX) are ZIP archives containing XML parts with specific relationships. This package provides types for generating:

- `[Content_Types].xml` - Declares content types for parts in the package
- `_rels/.rels` - Root relationships file
- `xl/_rels/workbook.xml.rels` - Workbook relationships file

## Types

### ContentTypes

Manages content type declarations for the OOXML package:

```mbt check
///|
test "content types" {
  let ct = @ooxml.ContentTypes::new()

  // Add default content types by extension
  ct.add_default("xml", "application/xml")
  ct.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )

  // Add specific part overrides
  ct.add_override(
    "/xl/workbook.xml", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml",
  )

  // Generate XML
  let xml = ct.to_xml()
  inspect(xml.contains("Default Extension"), content="true")
}
```

### Relationships

Manages relationships between parts in the OOXML package:

```mbt check
///|
test "relationships" {
  let rels = @ooxml.Relationships::new()

  // Add relationship with explicit ID
  rels.add(
    "rId1",
    rel_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    target="xl/workbook.xml",
  )

  // Add relationship with auto-generated ID
  let id = rels.add_auto(
    rel_type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    target="xl/styles.xml",
  )
  inspect(id, content="rId1")

  // Generate XML
  let xml = rels.to_xml()
  inspect(xml.contains("Relationship"), content="true")
}
```

### WorkbookManifest

High-level helper that manages all OOXML metadata for a workbook:

```mbt check
///|
test "workbook manifest" {
  // Create manifest for workbook with 2 sheets
  let manifest = @ooxml.WorkbookManifest::new(
    2, // sheet count
    include_shared_strings=true,
    include_calc_chain=false,
  )

  // Add custom relationships
  manifest.add_content_override(
    "/xl/worksheets/sheet3.xml", "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml",
  )

  // Generate XML files
  let content_types = manifest.content_types_xml()
  let root_rels = manifest.root_rels_xml()
  let workbook_rels = manifest.workbook_rels_xml()
  inspect(content_types.contains("Types"), content="true")
  inspect(root_rels.contains("Relationships"), content="true")
  inspect(workbook_rels.contains("Relationships"), content="true")
}
```

## API Reference

### ContentTypes Methods

| Method | Description |
|--------|-------------|
| `ContentTypes::new()` | Create empty content types |
| `add_default(extension, content_type)` | Add default type by extension |
| `add_override(part_name, content_type)` | Add specific part override |
| `to_xml()` | Generate `[Content_Types].xml` |

### Relationships Methods

| Method | Description |
|--------|-------------|
| `Relationships::new()` | Create empty relationships |
| `add(id, rel_type, target, target_mode?)` | Add relationship with explicit ID |
| `add_auto(rel_type, target, target_mode?)` | Add relationship with auto ID |
| `to_xml()` | Generate `.rels` XML |

### WorkbookManifest Methods

| Method | Description |
|--------|-------------|
| `WorkbookManifest::new(sheet_count, ...)` | Create manifest with defaults |
| `add_content_default(extension, type)` | Add default content type |
| `add_content_override(part, type)` | Add content type override |
| `add_workbook_relationship(type, target)` | Add workbook relationship |
| `add_workbook_relationship_with_id(...)` | Add with auto ID, return ID |
| `set_workbook_content_type(type)` | Set main workbook type |
| `content_types_xml()` | Generate `[Content_Types].xml` |
| `root_rels_xml()` | Generate `_rels/.rels` |
| `workbook_rels_xml()` | Generate `xl/_rels/workbook.xml.rels` |

## OOXML Structure

A typical XLSX file has this structure:

```
[Content_Types].xml         <- ContentTypes
_rels/
  .rels                     <- Root Relationships
xl/
  _rels/
    workbook.xml.rels       <- Workbook Relationships
  workbook.xml
  styles.xml
  sharedStrings.xml
  worksheets/
    sheet1.xml
    sheet2.xml
  ...
docProps/
  core.xml
  app.xml
```

This package generates the metadata files that describe how all the parts relate to each other.
