///|
let rel_office_document = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
let rel_core_properties = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"

///|
let rel_extended_properties = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"

///|
let rel_worksheet = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"

///|
let rel_styles = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"

///|
let rel_theme = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"

///|
let rel_shared_strings = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings"

///|
let ct_rels = "application/vnd.openxmlformats-package.relationships+xml"

///|
let ct_xml = "application/xml"

///|
let ct_workbook = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"

///|
let ct_worksheet = "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"

///|
let ct_styles = "application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"

///|
let ct_shared_strings = "application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"

///|
let ct_theme = "application/vnd.openxmlformats-officedocument.theme+xml"

///|
let ct_core_props = "application/vnd.openxmlformats-package.core-properties+xml"

///|
let ct_app_props = "application/vnd.openxmlformats-officedocument.extended-properties+xml"

///|
pub struct WorkbookManifest {
  content_types : ContentTypes
  root_rels : Relationships
  workbook_rels : Relationships
}

///|
pub fn WorkbookManifest::new(
  sheet_count : Int,
  include_shared_strings? : Bool = true,
) -> WorkbookManifest {
  let safe_sheet_count = if sheet_count < 0 { 0 } else { sheet_count }
  let content_types = ContentTypes::new()
  content_types.add_default("rels", ct_rels)
  content_types.add_default("xml", ct_xml)
  content_types.add_override("/xl/workbook.xml", ct_workbook)
  content_types.add_override("/xl/styles.xml", ct_styles)
  content_types.add_override("/xl/theme/theme1.xml", ct_theme)
  if include_shared_strings {
    content_types.add_override("/xl/sharedStrings.xml", ct_shared_strings)
  }
  if safe_sheet_count > 0 {
    for i in 1..<=safe_sheet_count {
      content_types.add_override("/xl/worksheets/sheet\{i}.xml", ct_worksheet)
    }
  }
  content_types.add_override("/docProps/core.xml", ct_core_props)
  content_types.add_override("/docProps/app.xml", ct_app_props)
  let root_rels = Relationships::new()
  ignore(
    root_rels.add_auto(rel_type=rel_office_document, target="xl/workbook.xml"),
  )
  ignore(
    root_rels.add_auto(rel_type=rel_core_properties, target="docProps/core.xml"),
  )
  ignore(
    root_rels.add_auto(
      rel_type=rel_extended_properties,
      target="docProps/app.xml",
    ),
  )
  let workbook_rels = Relationships::new()
  if safe_sheet_count > 0 {
    for i in 1..<=safe_sheet_count {
      ignore(
        workbook_rels.add_auto(
          rel_type=rel_worksheet,
          target="worksheets/sheet\{i}.xml",
        ),
      )
    }
  }
  ignore(workbook_rels.add_auto(rel_type=rel_styles, target="styles.xml"))
  ignore(workbook_rels.add_auto(rel_type=rel_theme, target="theme/theme1.xml"))
  if include_shared_strings {
    ignore(
      workbook_rels.add_auto(
        rel_type=rel_shared_strings,
        target="sharedStrings.xml",
      ),
    )
  }
  { content_types, root_rels, workbook_rels }
}

///|
pub fn WorkbookManifest::content_types_xml(self : WorkbookManifest) -> String {
  self.content_types.to_xml()
}

///|
pub fn WorkbookManifest::root_rels_xml(self : WorkbookManifest) -> String {
  self.root_rels.to_xml()
}

///|
pub fn WorkbookManifest::workbook_rels_xml(self : WorkbookManifest) -> String {
  self.workbook_rels.to_xml()
}
