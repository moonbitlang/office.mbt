///|
/// The document-level `office.template.data/1` parser: the scalar `values`
/// member plus the additive optional `regions` member describing repeating
/// regions. `parse_template_data` stays scalar-only and continues to reject
/// a `regions` member as unknown; callers that implement repetition opt in
/// by parsing through `parse_template_document` instead.

///|
/// Repetition bounds shared by parsers, merge layers, and reports.
pub const MAX_TEMPLATE_REGIONS : Int = 64

///|
pub const MAX_TEMPLATE_REGION_RECORDS : Int = 4096

///|
/// Total rows written by repetition across all regions (ΣK, counting every
/// record's row — the template row is rewritten as the first record).
pub const MAX_TEMPLATE_TOTAL_REGION_ROWS : Int = 10000

///|
/// Header/footer story ordinals and table/row path ordinals are bounded before
/// arithmetic or selector allocation.
pub const MAX_TEMPLATE_STORY_ORDINAL : Int = 99

///|
/// Maximum decimal digits accepted for table and row ordinals in a DOCX
/// repeating-region path.
pub const MAX_TEMPLATE_PATH_ORDINAL_DIGITS : Int = 7

///|
/// Which story of a DOCX document a table path addresses. v1 merges only
/// body tables; header/footer paths parse (they are well-formed addresses)
/// and the merge layer refuses them as unsupported.
pub(all) enum TemplateStory {
  BodyStory
  HeaderStory(Int)
  FooterStory(Int)
} derive(Eq, @debug.Debug)

///|
/// Exactly one addressing form per region: a spreadsheet row
/// (`{"sheet": ..., "row": ...}`, structured so sheet names never need a
/// quoting grammar) or a DOCX table-row ordinal path
/// (`{"path": "/docx/body/tbl[N]/tr[M]"}`, the dump grammar). The form must
/// match the merged file's format; the merge layer enforces that.
pub(all) enum TemplateRegionAddress {
  SheetRow(sheet~ : String, row~ : Int)
  TableRow(story~ : TemplateStory, table~ : Int, row~ : Int)
} derive(Eq, @debug.Debug)

///|
/// One repeating region: the template row it addresses and the records to
/// merge, one cloned row per record, in document order.
pub(all) struct TemplateRegion {
  name : String
  address : TemplateRegionAddress
  records : Array[Map[String, TemplateValue]]
} derive(@debug.Debug)

///|
/// A parsed template data document. `regions` is empty for scalar-only
/// documents; iteration order follows the data document.
pub(all) struct TemplateData {
  values : Map[String, TemplateValue]
  regions : Array[TemplateRegion]
} derive(@debug.Debug)

///|
/// Parses ordinal digits from `text[start..)` up to a closing bracket:
/// returns (value, index after "]") or None when the shape is not a
/// bounded positive ordinal. At most seven digits, no leading zero — far
/// above any real ordinal while keeping arithmetic trivially overflow-safe.
fn parse_bracket_ordinal(text : String, start : Int) -> (Int, Int)? {
  if start >= text.length() || text[start] != '[' {
    return None
  }
  let mut index = start + 1
  let mut value = 0
  let mut digits = 0
  while index < text.length() && text[index] is ('0'..='9') {
    if digits == 0 && text[index] == '0' {
      return None
    }
    value = value * 10 + (text[index].to_int() - '0'.to_int())
    digits += 1
    if digits > MAX_TEMPLATE_PATH_ORDINAL_DIGITS {
      return None
    }
    index += 1
  }
  if digits == 0 || index >= text.length() || text[index] != ']' {
    return None
  }
  Some((value, index + 1))
}

///|
/// Parses a region `path` into its structured address. Accepted shapes:
/// `/docx/body/tbl[N]/tr[M]`, `/docx/header[K]/tbl[N]/tr[M]`,
/// `/docx/footer[K]/tbl[N]/tr[M]` with positive ordinals.
fn parse_table_row_path(path : String) -> TemplateRegionAddress? {
  guard path.has_prefix("/docx/") else { return None }
  let mut index = "/docx/".length()
  let story = if path.substring(start=index).has_prefix("body/") {
    index += "body/".length()
    BodyStory
  } else if path.substring(start=index).has_prefix("header") {
    index += "header".length()
    guard parse_bracket_ordinal(path, index) is Some((ordinal, next)) &&
      ordinal <= MAX_TEMPLATE_STORY_ORDINAL &&
      next < path.length() &&
      path[next] == '/' else {
      return None
    }
    index = next + 1
    HeaderStory(ordinal)
  } else if path.substring(start=index).has_prefix("footer") {
    index += "footer".length()
    guard parse_bracket_ordinal(path, index) is Some((ordinal, next)) &&
      ordinal <= MAX_TEMPLATE_STORY_ORDINAL &&
      next < path.length() &&
      path[next] == '/' else {
      return None
    }
    index = next + 1
    FooterStory(ordinal)
  } else {
    return None
  }
  guard path.substring(start=index).has_prefix("tbl") else { return None }
  index += "tbl".length()
  guard parse_bracket_ordinal(path, index) is Some((table, after_table)) &&
    after_table < path.length() &&
    path[after_table] == '/' else {
    return None
  }
  index = after_table + 1
  guard path.substring(start=index).has_prefix("tr") else { return None }
  index += "tr".length()
  guard parse_bracket_ordinal(path, index) is Some((row, after_row)) &&
    after_row == path.length() else {
    return None
  }
  Some(TableRow(story~, table~, row~))
}

///|
/// The largest addressable spreadsheet row (XLSX grid bound; the merge
/// layer still verifies the row against the actual workbook).
pub const MAX_TEMPLATE_SHEET_ROW : Int = 1048576

///|
/// Validates one region object into its address. Exactly one addressing
/// form: `sheet`+`row` together, XOR `path`.
fn parse_region_address(
  name : String,
  entries : Map[String, Json],
) -> TemplateRegionAddress raise TemplateDataError {
  let has_sheet = entries.contains("sheet")
  let has_row = entries.contains("row")
  let has_path = entries.contains("path")
  if has_path && (has_sheet || has_row) {
    raise TemplateDataError(
      "region \"" +
      name +
      "\" mixes addressing forms; use sheet+row or path, not both",
    )
  }
  if has_path {
    guard entries.get("path") is Some(String(path)) else {
      raise TemplateDataError("region \"" + name + "\" path must be a string")
    }
    guard parse_table_row_path(path) is Some(address) else {
      raise TemplateDataError(
        "region \"" +
        name +
        "\" path \"" +
        path +
        "\" is not a table-row path (/docx/body/tbl[N]/tr[M])",
      )
    }
    return address
  }
  if !has_sheet || !has_row {
    raise TemplateDataError(
      "region \"" + name + "\" needs an address: sheet+row together, or path",
    )
  }
  guard entries.get("sheet") is Some(String(sheet)) && sheet.length() > 0 else {
    raise TemplateDataError(
      "region \"" + name + "\" sheet must be a non-empty string",
    )
  }
  guard entries.get("row") is Some(Number(row_value, ..)) else {
    raise TemplateDataError("region \"" + name + "\" row must be a number")
  }
  // the raw pre-scan already rejected any row whose SPELLING is not a
  // plain in-range integer literal (Double rounding erases fractional
  // spellings like 1048576.0000000001 before this point — the same
  // raw-vs-decoded class as escape-spelled keys); this numeric check is
  // defense in depth for programmatically built documents
  let truncated = row_value.to_int64()
  if truncated.to_double() != row_value ||
    truncated < 1L ||
    truncated > MAX_TEMPLATE_SHEET_ROW.to_int64() {
    raise TemplateDataError(row_bounds_message(name))
  }
  SheetRow(sheet~, row=truncated.to_int())
}

///|
fn row_bounds_message(name : String) -> String {
  "region \"" +
  name +
  "\" row must be an integer between 1 and \{MAX_TEMPLATE_SHEET_ROW}"
}

///|
/// Accepts only a plain positive integer literal within the grid: digits
/// with no sign, fraction, exponent, or leading zero, at most seven of
/// them, value in 1..=MAX_TEMPLATE_SHEET_ROW.
fn parse_strict_row_literal(spelling : String) -> Int? {
  if spelling.length() == 0 || spelling.length() > 7 {
    return None
  }
  if spelling[0] == '0' {
    return None
  }
  let mut value = 0
  for unit in spelling {
    guard unit is ('0'..='9') else { return None }
    value = value * 10 + (unit.to_int() - '0'.to_int())
  }
  if value < 1 || value > MAX_TEMPLATE_SHEET_ROW {
    return None
  }
  Some(value)
}

///|
/// The raw lexical gate for region rows, run during the duplicate-key
/// pre-scan (post-parse Doubles cannot recover spellings): when a "row"
/// member is recorded directly inside a region object (frame chain
/// root -> "regions" -> region), the value token that follows must be a
/// plain in-range integer literal. Non-numeric tokens are left for the
/// structured parser's typed errors.
fn region_row_lexical_gate(
  text : String,
) -> (Array[String], String, Int) -> Unit raise TemplateDataError {
  (labels, key, after_key) => {
    // labels[2] == "" means the container is an ARRAY ITEM under regions
    // (array items carry no label) — an array-shaped regions member is a
    // structural error the parser reports honestly; the gate only speaks
    // for real named regions
    guard key == "row" &&
      labels.length() == 3 &&
      labels[1] == "regions" &&
      labels[2] != "" else {
      return
    }
    let mut index = after_key
    while index < text.length() && text[index] is (' ' | '\t' | '\n' | '\r') {
      index += 1
    }
    guard index < text.length() && text[index] == ':' else { return }
    index += 1
    while index < text.length() && text[index] is (' ' | '\t' | '\n' | '\r') {
      index += 1
    }
    let token_start = index
    while index < text.length() &&
          !(text[index] is (',' | '}' | ']' | ' ' | '\t' | '\n' | '\r')) {
      index += 1
    }
    guard index > token_start else { return }
    let first = text[token_start]
    // strings/objects/booleans stay with the structured parser; only
    // number-shaped tokens are judged lexically here
    guard first is ('0'..='9') || first == '-' else { return }
    guard parse_strict_row_literal(text.substring(start=token_start, end=index))
      is Some(_) else {
      raise TemplateDataError(row_bounds_message(labels[2]))
    }
  }
}

///|
/// Parses and validates an `office.template.data/1` document including the
/// optional `regions` member. Scalar `values` behave exactly as
/// `parse_template_data`; regions add: name in the key grammar, exactly one
/// addressing form, a non-empty bounded `records` array of flat scalar
/// records under the same gates as `values`, ΣK across regions bounded, and
/// a disjoint-union rule — any key present both in `values` and in any
/// record is rejected, so region lookup (record ∪ values) is unambiguous.
pub fn parse_template_document(
  text : String,
  max_keys? : Int = MAX_TEMPLATE_KEYS,
  max_value_units? : Int = MAX_TEMPLATE_VALUE_UNITS,
  max_regions? : Int = MAX_TEMPLATE_REGIONS,
  max_region_records? : Int = MAX_TEMPLATE_REGION_RECORDS,
  max_total_region_rows? : Int = MAX_TEMPLATE_TOTAL_REGION_ROWS,
) -> TemplateData raise TemplateDataError {
  check_duplicate_keys(text, on_member=Some(region_row_lexical_gate(text)))
  let document = @json.parse(text) catch {
    _ => raise TemplateDataError("data document is not valid JSON")
  }
  guard document is Object(fields) else {
    raise TemplateDataError("data document must be a JSON object")
  }
  for key, _ in fields {
    if key != "schema" && key != "values" && key != "regions" {
      raise TemplateDataError(
        "unknown top-level member \"" +
        key +
        "\" (expected schema, values, regions)",
      )
    }
  }
  guard fields.get("schema") is Some(String(schema)) else {
    raise TemplateDataError(
      "data document needs \"schema\": \"" + SCHEMA_TEMPLATE_DATA + "\"",
    )
  }
  guard schema == SCHEMA_TEMPLATE_DATA else {
    raise TemplateDataError(
      "unsupported data schema \"" +
      schema +
      "\" (expected " +
      SCHEMA_TEMPLATE_DATA +
      ")",
    )
  }
  guard fields.get("values") is Some(Object(value_entries)) else {
    raise TemplateDataError("data document needs a \"values\" object")
  }
  let values = parse_scalar_entries(
    value_entries, max_keys, max_value_units, "", "values",
  )
  let regions : Array[TemplateRegion] = []
  match fields.get("regions") {
    None => ()
    Some(Object(region_entries)) => {
      if region_entries.size() == 0 {
        raise TemplateDataError(
          "regions must name at least one region when present",
        )
      }
      if region_entries.size() > max_regions {
        raise TemplateDataError(
          "regions carries \{region_entries.size()} entries; the limit is \{max_regions}",
        )
      }
      let mut total_rows = 0
      for name, region_value in region_entries {
        if !template_key_ok(name) {
          raise TemplateDataError(
            "region name \"" +
            name +
            "\" is outside the placeholder key grammar",
          )
        }
        guard region_value is Object(region_fields) else {
          raise TemplateDataError("region \"" + name + "\" must be an object")
        }
        for member, _ in region_fields {
          if member != "sheet" &&
            member != "row" &&
            member != "path" &&
            member != "records" {
            raise TemplateDataError(
              "region \"" +
              name +
              "\" has unknown member \"" +
              member +
              "\" (expected sheet, row, path, records)",
            )
          }
        }
        let address = parse_region_address(name, region_fields)
        guard region_fields.get("records") is Some(Array(record_items)) else {
          raise TemplateDataError(
            "region \"" + name + "\" needs a \"records\" array",
          )
        }
        if record_items.length() == 0 {
          raise TemplateDataError(
            "region \"" +
            name +
            "\" records must not be empty (row deletion is out of scope)",
          )
        }
        if record_items.length() > max_region_records {
          raise TemplateDataError(
            "region \"" +
            name +
            "\" carries \{record_items.length()} records; the limit is \{max_region_records}",
          )
        }
        total_rows += record_items.length()
        if total_rows > max_total_region_rows {
          raise TemplateDataError(
            "regions write \{total_rows} rows in total; the limit is \{max_total_region_rows}",
          )
        }
        let records : Array[Map[String, TemplateValue]] = []
        for record_index, record_item in record_items {
          guard record_item is Object(record_entries) else {
            raise TemplateDataError(
              "region \"" + name + "\" record \{record_index} must be an object",
            )
          }
          let prefix = "region \"" + name + "\" record \{record_index}: "
          records.push(
            parse_scalar_entries(
              record_entries, max_keys, max_value_units, prefix, "record",
            ),
          )
        }
        regions.push({ name, address, records })
      }
      // the disjoint-union rule: a key living in both `values` and any
      // record would make region lookup order observable — reject instead
      for region in regions {
        for record_index, record in region.records {
          for key, _ in record {
            if values.contains(key) {
              raise TemplateDataError(
                "key \"" +
                key +
                "\" appears in values and in region \"" +
                region.name +
                "\" record \{record_index}; region record keys must not collide with values",
              )
            }
          }
        }
      }
    }
    Some(_) =>
      raise TemplateDataError("regions must be an object of named regions")
  }
  { values, regions }
}
