///|
/// Read-time package-level feature detection. Several source features
/// vanish before (or instead of) modeling — external-link parts, query
/// tables, connections, pivot caches without a modeled pivot table, VML,
/// and any part outside the known taxonomy — so a post-read model cannot
/// prove their absence. The read path captures these flags from the raw
/// part list BEFORE lossy modeling; callers with wrong-number safety
/// contracts (template repetition) refuse on them.

///|
/// Raw-package feature flags with the first triggering part path per
/// class (archive entry order, deterministic per package). API-built
/// workbooks carry `XlsxPackageFeatures::none()`.
pub struct XlsxPackageFeatures {
  external_links : Bool
  query_tables : Bool
  connections : Bool
  pivot_parts : Bool
  vml_present : Bool
  unknown_parts : Bool
  first_external_link : String?
  first_query_table : String?
  first_connections : String?
  first_pivot_part : String?
  first_vml_part : String?
  first_unknown_part : String?
} derive(Eq, @debug.Debug)

///|
pub fn XlsxPackageFeatures::none() -> XlsxPackageFeatures {
  {
    external_links: false,
    query_tables: false,
    connections: false,
    pivot_parts: false,
    vml_present: false,
    unknown_parts: false,
    first_external_link: None,
    first_query_table: None,
    first_connections: None,
    first_pivot_part: None,
    first_vml_part: None,
    first_unknown_part: None,
  }
}

///|
/// The package-part taxonomy: parts the reader models, preserves, or that
/// cannot carry spreadsheet-evaluable content (printer settings, media,
/// custom XML, OLE payloads). Anything outside it raises `unknown_parts` —
/// fail-closed, so a nonconforming producer hiding a formula-bearing part
/// at an unexpected path is caught by exclusion rather than enumeration.
fn known_inert_part(lower : String) -> Bool {
  if lower == "[content_types].xml" ||
    lower == "xl/workbook.xml" ||
    lower == "xl/styles.xml" ||
    lower == "xl/sharedstrings.xml" ||
    lower == "xl/calcchain.xml" ||
    lower == "xl/metadata.xml" ||
    lower == "xl/cellimages.xml" ||
    lower == "xl/vbaproject.bin" ||
    lower == "docprops/core.xml" ||
    lower == "docprops/app.xml" ||
    lower == "docprops/custom.xml" {
    return true
  }
  if lower.has_suffix(".rels") &&
    (lower.has_prefix("_rels/") || lower.find("/_rels/") is Some(_)) {
    return true
  }
  for
    prefix in [
      "docprops/thumbnail", "xl/theme/", "xl/worksheets/", "xl/chartsheets/", "xl/tables/",
      "xl/media/", "xl/drawings/", "xl/charts/", "xl/richdata/", "xl/embeddings/",
      "xl/printersettings/", "customxml/", "xl/comments", "xl/slicers/", "xl/slicercaches/",
    ] {
    if lower.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
/// Classifies every physical archive part into the feature flags. Order
/// of checks matters only for VML, which lives under xl/drawings/ and
/// must be flagged before the drawings prefix would absorb it.
fn detect_package_features(
  part_names : Map[String, String],
) -> XlsxPackageFeatures {
  let mut external_links = false
  let mut query_tables = false
  let mut connections = false
  let mut pivot_parts = false
  let mut vml_present = false
  let mut unknown_parts = false
  let mut first_external_link : String? = None
  let mut first_query_table : String? = None
  let mut first_connections : String? = None
  let mut first_pivot_part : String? = None
  let mut first_vml_part : String? = None
  let mut first_unknown_part : String? = None
  for _, physical in part_names {
    let lower = physical.to_lower()
    if lower.has_suffix(".vml") {
      if !vml_present {
        vml_present = true
        first_vml_part = Some(physical)
      }
      continue
    }
    if lower.has_prefix("xl/externallinks/") {
      if !external_links {
        external_links = true
        first_external_link = Some(physical)
      }
      continue
    }
    if lower.has_prefix("xl/querytables/") {
      if !query_tables {
        query_tables = true
        first_query_table = Some(physical)
      }
      continue
    }
    if lower == "xl/connections.xml" {
      if !connections {
        connections = true
        first_connections = Some(physical)
      }
      continue
    }
    if lower.has_prefix("xl/pivottables/") || lower.has_prefix("xl/pivotcache/") {
      if !pivot_parts {
        pivot_parts = true
        first_pivot_part = Some(physical)
      }
      continue
    }
    if known_inert_part(lower) {
      continue
    }
    if !unknown_parts {
      unknown_parts = true
      first_unknown_part = Some(physical)
    }
  }
  {
    external_links,
    query_tables,
    connections,
    pivot_parts,
    vml_present,
    unknown_parts,
    first_external_link,
    first_query_table,
    first_connections,
    first_pivot_part,
    first_vml_part,
    first_unknown_part,
  }
}

///|
/// The package-level feature flags captured when this workbook was read;
/// `XlsxPackageFeatures::none()` for API-built workbooks.
pub fn Workbook::package_features(self : Workbook) -> XlsxPackageFeatures {
  self.package_features
}

///|
/// The first table (sheet name, table name) whose SOURCE part carried
/// calculated-column or totals-row formula markup — content the model
/// drops and the writer regenerates without. None when no table does.
pub fn Workbook::first_table_with_source_formulas(
  self : Workbook,
) -> (String, String)? {
  for sheet in self.sheets {
    for table in sheet.tables() {
      if table.carries_source_formulas {
        return Some((sheet.name(), table.name))
      }
    }
  }
  None
}
