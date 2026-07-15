///|
let docx_cli_default_max_output_chars : Int = 1024 * 1024

///|
let docx_cli_hard_max_output_chars : Int = 4 * 1024 * 1024

///|
let docx_cli_default_text_limit : Int = 2000

///|
let docx_cli_hard_text_limit : Int = 10_000

///|
let docx_cli_default_query_limit : Int = 100

///|
let docx_cli_hard_query_limit : Int = 1000

///|
let docx_cli_query_preview_chars : Int = 160

///|
let docx_cli_heading_preview_chars : Int = 512

///|
struct DocxTextRecord {
  path : String
  stability : String
  text : String
}

///|
struct DocxTextResult {
  records : Array[DocxTextRecord]
  matched_total : Int
  offset : Int
  limit : Int
  scanned_elements : Int
}

///|
struct DocxPropertyPredicate {
  name : String
  value : String
}

///|
struct DocxQuerySpec {
  under : String?
  kind : String?
  text : String?
  stable_id : String?
  properties : Array[DocxPropertyPredicate]
  ignore_case : Bool
  offset : Int
  limit : Int
}

///|
struct DocxQueryRecord {
  entry : DocxProjectionEntry
  preview : String
  preview_truncated : Bool
}

///|
struct DocxQueryResult {
  records : Array[DocxQueryRecord]
  matched_total : Int
  offset : Int
  limit : Int
  scanned_elements : Int
  under : String?
}

///|
fn checked_output_limit(maximum : Int) -> Int raise CliFailure {
  if maximum < 1 || maximum > docx_cli_hard_max_output_chars {
    raise docx_cli_failure(
      "office.invalid_arguments",
      "--max-output-chars must be between 1 and \{docx_cli_hard_max_output_chars}",
      details=Json::object({
        "argument": Json::string("max-output-chars"),
        "minimum": Json::number(1),
        "maximum": Json::number(docx_cli_hard_max_output_chars.to_double()),
      }),
    )
  }
  maximum
}

///|
fn ensure_docx_output_limit(
  output : String,
  maximum : Int,
) -> Unit raise CliFailure {
  let mut count = 0
  for _ in output {
    count += 1
    if count > maximum {
      raise docx_resource_failure(
        "serialized output characters",
        maximum,
        actual=count,
      )
    }
  }
}

///|
fn checked_docx_json_output(
  data : Json,
  warnings : Array[@lib.ProtocolWarning],
  maximum : Int,
) -> String raise CliFailure {
  ignore(checked_output_limit(maximum))
  let output = @lib.output_success(data, warnings~).stringify(indent=2)
  ensure_docx_output_limit(output, maximum)
  output
}

///|
fn checked_docx_human_output(
  output : String,
  maximum : Int,
) -> String raise CliFailure {
  ignore(checked_output_limit(maximum))
  ensure_docx_output_limit(output, maximum)
  output
}

///|
fn get_docx_payload(
  projection : DocxProjection,
  entry : DocxProjectionEntry,
  max_output_chars : Int,
) -> Json raise CliFailure {
  let fields = entry_base_json(projection, entry)
  fields["schema"] = Json::string(@lib.SCHEMA_DOCX_ELEMENT)
  fields["file"] = Json::string(projection.file)
  fields["format"] = Json::string("docx")
  match entry.element {
    Some(_) => {
      let text_budget = DocxTextBudget::new(
        "element text characters",
        max_output_chars.min(docx_cli_max_element_text_chars),
      )
      fields["text"] = Json::string(entry_text_with_budget(entry, text_budget))
    }
    None => ()
  }
  Json::object(fields)
}

///|
fn text_record_json(record : DocxTextRecord) -> Json {
  Json::object({
    "path": Json::string(record.path),
    "stability": Json::string(record.stability),
    "text": Json::string(record.text),
  })
}

///|
fn build_docx_text_result(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  offset : Int,
  limit : Int,
  max_output_chars : Int,
) -> DocxTextResult raise CliFailure {
  let records : Array[DocxTextRecord] = []
  let text_budget = DocxTextBudget::new(
    "text result characters", max_output_chars,
  )
  let mut matched = 0
  for entry in projection.entries {
    let in_scope = match under {
      Some(root) => path_is_within(entry.path, root.path)
      None => true
    }
    if in_scope && entry.kind == "p" {
      if matched >= offset && records.length() < limit {
        records.push({
          path: entry.path,
          stability: selector_stability_text(entry.stability),
          text: entry_text_with_budget(entry, text_budget),
        })
      }
      matched += 1
    }
  }
  {
    records,
    matched_total: matched,
    offset,
    limit,
    scanned_elements: projection.entries.length(),
  }
}

///|
fn docx_text_payload(
  projection : DocxProjection,
  result : DocxTextResult,
  under : String?,
) -> Json {
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_DOCX_TEXT),
    "file": Json::string(projection.file),
    "format": Json::string("docx"),
    "entries": Json::array(result.records.map(text_record_json)),
    "matched_total": Json::number(result.matched_total.to_double()),
    "offset": Json::number(result.offset.to_double()),
    "limit": Json::number(result.limit.to_double()),
    "returned": Json::number(result.records.length().to_double()),
    "truncated": Json::boolean(
      result.offset + result.records.length() < result.matched_total,
    ),
    "scanned_elements": Json::number(result.scanned_elements.to_double()),
  }
  match under {
    Some(path) => fields["under"] = Json::string(path)
    None => ()
  }
  Json::object(fields)
}

///|
fn query_property_json(properties : Map[String, String]) -> Json {
  let fields : Map[String, Json] = Map([])
  for name, value in properties {
    if name == "bold" ||
      name == "italic" ||
      name == "underline" ||
      name == "done" {
      fields[name] = Json::boolean(value == "true")
    } else {
      fields[name] = Json::string(value)
    }
  }
  Json::object(fields)
}

///|
fn query_record_json(record : DocxQueryRecord) -> Json {
  let entry = record.entry
  let fields : Map[String, Json] = {
    "path": Json::string(entry.path),
    "kind": Json::string(entry.kind),
    "role": Json::string(entry.role.name()),
    "stability": Json::string(selector_stability_text(entry.stability)),
    "preview": Json::string(record.preview),
    "preview_truncated": Json::boolean(record.preview_truncated),
    "properties": query_property_json(entry.properties),
  }
  match entry.stable_id {
    Some(id) => fields["id"] = Json::string(id)
    None => ()
  }
  Json::object(fields)
}

///|
fn entry_matches_properties(
  entry : DocxProjectionEntry,
  predicates : Array[DocxPropertyPredicate],
) -> Bool {
  for predicate in predicates {
    if entry.properties.get(predicate.name) != Some(predicate.value) {
      return false
    }
  }
  true
}

///|
fn text_contains(value : String, needle : String, ignore_case : Bool) -> Bool {
  if ignore_case {
    value.to_lower().contains(needle.to_lower())
  } else {
    value.contains(needle)
  }
}

///|
fn build_docx_query_result(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  spec : DocxQuerySpec,
) -> DocxQueryResult raise CliFailure {
  let records : Array[DocxQueryRecord] = []
  let scan_budget = DocxTextBudget::new(
    "query text scan characters", docx_cli_max_query_text_scan_chars,
  )
  let mut matched = 0
  for entry in projection.entries {
    let in_scope = match under {
      Some(root) => path_is_within(entry.path, root.path)
      None => true
    }
    if !in_scope {
      continue
    }
    match spec.kind {
      Some(kind) if entry.kind != kind => continue
      _ => ()
    }
    match spec.stable_id {
      Some(id) if entry.stable_id != Some(id) => continue
      _ => ()
    }
    if !entry_matches_properties(entry, spec.properties) {
      continue
    }
    match spec.text {
      Some(needle) => {
        let value = entry_text_with_budget(entry, scan_budget)
        if !text_contains(value, needle, spec.ignore_case) {
          continue
        }
      }
      None => ()
    }
    if matched >= spec.offset && records.length() < spec.limit {
      let (preview, preview_truncated) = entry_text_prefix(
        entry, docx_cli_query_preview_chars,
      )
      records.push({ entry, preview, preview_truncated })
    }
    matched += 1
  }
  {
    records,
    matched_total: matched,
    offset: spec.offset,
    limit: spec.limit,
    scanned_elements: projection.entries.length(),
    under: under.map(entry => entry.path),
  }
}

///|
fn docx_query_payload(
  projection : DocxProjection,
  result : DocxQueryResult,
  spec : DocxQuerySpec,
) -> Json {
  let filters : Map[String, Json] = {
    "properties": Json::array(
      spec.properties.map(predicate => {
        Json::object({
          "name": Json::string(predicate.name),
          "value": Json::string(predicate.value),
        })
      }),
    ),
    "ignore_case": Json::boolean(spec.ignore_case),
  }
  match spec.kind {
    Some(value) => filters["kind"] = Json::string(value)
    None => ()
  }
  match spec.text {
    Some(value) => filters["text"] = Json::string(value)
    None => ()
  }
  match spec.stable_id {
    Some(value) => filters["id"] = Json::string(value)
    None => ()
  }
  match spec.under {
    Some(value) => filters["under"] = Json::string(value)
    None => ()
  }
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_DOCX_QUERY),
    "file": Json::string(projection.file),
    "format": Json::string("docx"),
    "filters": Json::object(filters),
    "matches": Json::array(result.records.map(query_record_json)),
    "matched_total": Json::number(result.matched_total.to_double()),
    "offset": Json::number(result.offset.to_double()),
    "limit": Json::number(result.limit.to_double()),
    "returned": Json::number(result.records.length().to_double()),
    "truncated": Json::boolean(
      result.offset + result.records.length() < result.matched_total,
    ),
    "scanned_elements": Json::number(result.scanned_elements.to_double()),
  }
  match result.under {
    Some(path) => fields["under"] = Json::string(path)
    None => ()
  }
  Json::object(fields)
}

///|
fn heading_level(element : @document.DocumentElement) -> Int? {
  guard element is Paragraph(properties~, ..) else { return None }
  match properties.style_id {
    Some(id) => {
      let lower = id.to_lower()
      if lower.has_prefix("heading") && lower.length() == 8 {
        let unit = lower[7]
        if unit is ('1'..='6') {
          return Some(unit.to_int() - '0'.to_int())
        }
      }
    }
    None => ()
  }
  match properties.style_name {
    Some(name) => {
      let lower = name.to_lower()
      if lower.has_prefix("heading ") && lower.length() == 9 {
        let unit = lower[8]
        if unit is ('1'..='6') {
          return Some(unit.to_int() - '0'.to_int())
        }
      }
      None
    }
    None => None
  }
}

///|
fn outline_style_record(entry : DocxProjectionEntry) -> Json? {
  let style_id = entry.properties.get("style_id")
  let style_name = entry.properties.get("style_name")
  if style_id is None && style_name is None {
    return None
  }
  let fields : Map[String, Json] = { "kind": Json::string(entry.kind) }
  match style_id {
    Some(value) => fields["id"] = Json::string(value)
    None => ()
  }
  match style_name {
    Some(value) => fields["name"] = Json::string(value)
    None => ()
  }
  Some(Json::object(fields))
}

///|
fn section_ref_json(reference : @document.SectionRef) -> Json {
  Json::object({
    "variant": Json::string(reference.variant),
    "part": Json::number((reference.part + 1).to_double()),
  })
}

///|
fn section_json(section : @document.DocumentSection) -> Json {
  let fields : Map[String, Json] = {
    "headers": Json::array(section.headers.map(section_ref_json)),
    "footers": Json::array(section.footers.map(section_ref_json)),
  }
  match section.ends_after_paragraph {
    Some(index) =>
      fields["ends_after_paragraph"] = Json::number(index.to_double())
    None => ()
  }
  Json::object(fields)
}

///|
fn reader_diagnostics(projection : DocxProjection) -> Json {
  let values : Array[Json] = []
  for message in projection.annotated.result().messages {
    let (severity, text) = match message {
      Warning(value) => ("warning", value)
      Error(value) => ("error", value)
    }
    values.push(
      Json::object({
        "severity": Json::string(severity),
        "message": Json::string(bounded_text(text, 512)),
      }),
    )
  }
  Json::array(values)
}

///|
fn docx_outline_payload(projection : DocxProjection) -> Json {
  let counts : Map[String, Int] = Map([])
  let mut footnotes = 0
  let mut endnotes = 0
  let stories : Array[Json] = []
  let headings : Array[Json] = []
  let images : Array[Json] = []
  let styles : Array[Json] = []
  let seen_styles : Set[String] = Set([])
  for entry in projection.entries {
    counts[entry.kind] = counts.get(entry.kind).unwrap_or(0) + 1
    if entry.kind == "note" && entry.parent == Some("/docx/footnotes") {
      footnotes += 1
    } else if entry.kind == "note" && entry.parent == Some("/docx/endnotes") {
      endnotes += 1
    }
    if entry.role is (StoryRoot | AnnotationCollection) {
      stories.push(
        Json::object({
          "path": Json::string(entry.path),
          "kind": Json::string(entry.kind),
          "children": Json::number(entry.children.length().to_double()),
          "stability": Json::string(selector_stability_text(entry.stability)),
          "source": entry.source,
        }),
      )
    }
    match entry.element {
      Some(element) => {
        match heading_level(element) {
          Some(level) => {
            let (text, truncated) = entry_text_prefix(
              entry, docx_cli_heading_preview_chars,
            )
            headings.push(
              Json::object({
                "path": Json::string(entry.path),
                "level": Json::number(level.to_double()),
                "text": Json::string(text),
                "text_truncated": Json::boolean(truncated),
              }),
            )
          }
          None => ()
        }
        if element is Image(image) {
          let fields : Map[String, Json] = {
            "path": Json::string(entry.path),
            "content_type": Json::string(image.content_type),
            "bytes": Json::number(image.data.length().to_double()),
          }
          set_optional_json(fields, "alt_text", image.alt_text)
          images.push(Json::object(fields))
        }
        match outline_style_record(entry) {
          Some(style) => {
            let key = style.stringify()
            if !seen_styles.contains(key) {
              seen_styles.add(key)
              styles.push(style)
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  let count_fields : Map[String, Json] = {
    "body_stories": Json::number(counts.get("body").unwrap_or(0).to_double()),
    "headers": Json::number(counts.get("header").unwrap_or(0).to_double()),
    "footers": Json::number(counts.get("footer").unwrap_or(0).to_double()),
    "footnotes": Json::number(footnotes.to_double()),
    "endnotes": Json::number(endnotes.to_double()),
    "comments": Json::number(counts.get("comment").unwrap_or(0).to_double()),
    "paragraphs": Json::number(counts.get("p").unwrap_or(0).to_double()),
    "runs": Json::number(counts.get("r").unwrap_or(0).to_double()),
    "tables": Json::number(counts.get("tbl").unwrap_or(0).to_double()),
    "rows": Json::number(counts.get("tr").unwrap_or(0).to_double()),
    "cells": Json::number(counts.get("tc").unwrap_or(0).to_double()),
    "hyperlinks": Json::number(counts.get("hyperlink").unwrap_or(0).to_double()),
    "images": Json::number(counts.get("image").unwrap_or(0).to_double()),
  }
  let result = projection.annotated.result()
  Json::object({
    "schema": Json::string(@lib.SCHEMA_DOCX_OUTLINE),
    "file": Json::string(projection.file),
    "format": Json::string("docx"),
    "scanned_elements": Json::number(projection.entries.length().to_double()),
    "counts": Json::object(count_fields),
    "stories": Json::array(stories),
    "headings": Json::array(headings),
    "styles_in_use": Json::array(styles),
    "images": Json::array(images),
    "sections": Json::array(result.sections.map(section_json)),
    "diagnostics": reader_diagnostics(projection),
  })
}

///|
fn single_line_text(value : String) -> String {
  if !value.contains("\n") && !value.contains("\r") {
    return value
  }
  let output = StringBuilder::new()
  for character in value {
    if character is ('\n' | '\r') {
      output.write_char(' ') |> ignore
    } else {
      output.write_char(character) |> ignore
    }
  }
  output.to_string()
}

///|
fn human_warning_lines(warnings : Array[@lib.ProtocolWarning]) -> Array[String] {
  let lines : Array[String] = []
  for warning in warnings {
    lines.push(
      "# warning \{warning.code}: \{terminal_safe_text(warning.message)}",
    )
  }
  lines
}

///|
fn docx_text_human(
  result : DocxTextResult,
  warnings : Array[@lib.ProtocolWarning],
) -> String {
  let lines : Array[String] = []
  for record in result.records {
    lines.push(
      "\{terminal_safe_text(record.path)}\t\{terminal_safe_text(single_line_text(record.text))}",
    )
  }
  lines.append(human_warning_lines(warnings))
  lines.join("\n")
}

///|
fn docx_query_human(
  result : DocxQueryResult,
  warnings : Array[@lib.ProtocolWarning],
) -> String {
  let lines : Array[String] = []
  for record in result.records {
    lines.push(
      "\{terminal_safe_text(record.entry.path)}\t\{terminal_safe_text(record.entry.kind)}\t\{terminal_safe_text(single_line_text(record.preview))}",
    )
  }
  lines.push(
    "# matched \{result.matched_total}; returned \{result.records.length()}; offset \{result.offset}",
  )
  lines.append(human_warning_lines(warnings))
  lines.join("\n")
}

///|
fn docx_get_human(
  entry : DocxProjectionEntry,
  text : String,
  warnings : Array[@lib.ProtocolWarning],
) -> String {
  let primary = if text == "" {
    "\{terminal_safe_text(entry.path)}\t\{terminal_safe_text(entry.kind)}"
  } else {
    terminal_safe_text(text)
  }
  let lines = [primary]
  lines.append(human_warning_lines(warnings))
  lines.join("\n")
}

///|
fn docx_outline_human(projection : DocxProjection) -> String {
  let counts : Map[String, Int] = Map([])
  let lines : Array[String] = [
    "docx: \{raw_human_text(projection.file, 160)}",
    "scanned elements: \{projection.entries.length()}",
  ]
  for entry in projection.entries {
    counts[entry.kind] = counts.get(entry.kind).unwrap_or(0) + 1
    if entry.role is (StoryRoot | AnnotationCollection) {
      lines.push(
        "\{terminal_safe_text(entry.path)}\t\{terminal_safe_text(entry.kind)}\t\{entry.children.length()} children",
      )
    }
  }
  lines.push(
    "paragraphs: \{counts.get("p").unwrap_or(0)}; tables: \{counts.get("tbl").unwrap_or(0)}; images: \{counts.get("image").unwrap_or(0)}; comments: \{counts.get("comment").unwrap_or(0)}; footnotes/endnotes: \{counts.get("note").unwrap_or(0)}",
  )
  for entry in projection.entries {
    match entry.element {
      Some(element) =>
        match heading_level(element) {
          Some(level) => {
            let (text, truncated) = entry_text_prefix(
              entry, docx_cli_heading_preview_chars,
            )
            let suffix = if truncated { "…" } else { "" }
            lines.push(
              "heading \{level}\t\{terminal_safe_text(entry.path)}\t\{terminal_safe_text(single_line_text(text))}\{suffix}",
            )
          }
          None => ()
        }
      None => ()
    }
  }
  lines.append(human_warning_lines(projection.warnings))
  lines.join("\n")
}
