///|
let docx_cli_default_max_output_chars : Int = 1024 * 1024

///|
let docx_cli_hard_max_output_chars : Int = 4 * 1024 * 1024

///|
let docx_cli_output_framing_chars : Int = 1

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
struct BoundedDocxPayload {
  data : Json
  budget : DocxOutputBudget
  warnings : Array[@lib.ProtocolWarning]
}

///|
/// Counts compact JSON output before allocation and bounds retained records
/// while they are produced. The counter measures Unicode scalar characters,
/// including the successful command's explicit trailing line feed.
struct DocxOutputBudget {
  maximum : Int
  mut used : Int
}

///|
fn DocxOutputBudget::new(maximum : Int) -> DocxOutputBudget {
  { maximum, used: docx_cli_output_framing_chars }
}

///|
fn DocxOutputBudget::reserve_chars(
  self : DocxOutputBudget,
  count : Int,
) -> Unit raise CliFailure {
  if count < 0 || count > self.maximum - self.used {
    let actual = if count < 0 { self.used } else { self.used + count }
    raise docx_resource_failure(
      "successful command output characters",
      self.maximum,
      actual~,
    )
  }
  self.used += count
}

///|
fn DocxOutputBudget::reserve_plain_text(
  self : DocxOutputBudget,
  value : String,
) -> Unit raise CliFailure {
  for _ in value {
    self.reserve_chars(1)
  }
}

///|
fn DocxOutputBudget::reserve_json_string(
  self : DocxOutputBudget,
  value : String,
) -> Unit raise CliFailure {
  self.reserve_chars(2)
  for character in value {
    let code = character.to_int()
    if character is ('"' | '\\' | '\b' | '\t' | '\n' | '\f' | '\r') {
      self.reserve_chars(2)
    } else if code < 0x20 {
      self.reserve_chars(6)
    } else {
      self.reserve_chars(1)
    }
  }
}

///|
fn DocxOutputBudget::reserve_json(
  self : DocxOutputBudget,
  value : Json,
) -> Unit raise CliFailure {
  match value {
    Null => self.reserve_chars(4)
    True => self.reserve_chars(4)
    False => self.reserve_chars(5)
    Number(number, repr~) =>
      match repr {
        Some(text) => self.reserve_plain_text(text)
        None => self.reserve_plain_text(number.to_string())
      }
    String(text) => self.reserve_json_string(text)
    Array(values) => {
      self.reserve_chars(2)
      for index, item in values {
        if index > 0 {
          self.reserve_chars(1)
        }
        self.reserve_json(item)
      }
    }
    Object(fields) => {
      self.reserve_chars(2)
      let mut index = 0
      for key, item in fields {
        if index > 0 {
          self.reserve_chars(1)
        }
        self.reserve_json_string(key)
        self.reserve_chars(1)
        self.reserve_json(item)
        index += 1
      }
    }
  }
}

///|
fn DocxOutputBudget::reserve_array_item(
  self : DocxOutputBudget,
  value : Json,
  has_previous : Bool,
) -> Unit raise CliFailure {
  // The empty array brackets are included in the outline skeleton. Each
  // retained item adds its compact form and, after the first, one comma.
  if has_previous {
    self.reserve_chars(1)
  }
  self.reserve_json(value)
}

///|
fn DocxOutputBudget::remaining(self : DocxOutputBudget) -> Int {
  self.maximum - self.used
}

///|
fn DocxOutputBudget::reserve_json_field(
  self : DocxOutputBudget,
  name : String,
  value : Json,
  has_previous : Bool,
) -> Unit raise CliFailure {
  if has_previous {
    self.reserve_chars(1)
  }
  self.reserve_json_string(name)
  self.reserve_chars(1)
  self.reserve_json(value)
}

///|
fn DocxOutputBudget::reserve_warning(
  self : DocxOutputBudget,
  warning : @lib.ProtocolWarning,
) -> Unit raise CliFailure {
  self.reserve_chars(1)
  self.reserve_json_field("code", Json::string(warning.code), false)
  self.reserve_json_field("message", Json::string(warning.message), true)
  self.reserve_chars(1)
}

///|
fn DocxOutputBudget::reserve_success_envelope(
  self : DocxOutputBudget,
  data : Json,
  warnings : Array[@lib.ProtocolWarning],
) -> Unit raise CliFailure {
  self.reserve_chars(1)
  self.reserve_json_field("schema", Json::string("office.output/1"), false)
  self.reserve_json_field("success", Json::boolean(true), true)
  self.reserve_json_field("data", data, true)
  if !warnings.is_empty() {
    self.reserve_chars(1)
    self.reserve_json_string("warnings")
    self.reserve_chars(2)
    for index, warning in warnings {
      if index > 0 {
        self.reserve_chars(1)
      }
      self.reserve_warning(warning)
    }
    self.reserve_chars(1)
  }
  self.reserve_chars(1)
}

///|
fn DocxOutputBudget::reserve_json_string_body(
  self : DocxOutputBudget,
  value : String,
) -> Unit raise CliFailure {
  for character in value {
    let code = character.to_int()
    if character is ('"' | '\\' | '\b' | '\t' | '\n' | '\f' | '\r') {
      self.reserve_chars(2)
    } else if code < 0x20 {
      self.reserve_chars(6)
    } else {
      self.reserve_chars(1)
    }
  }
}

///|
fn DocxOutputBudget::reserve_nonnegative_integer_growth(
  self : DocxOutputBudget,
  value : Int,
) -> Unit raise CliFailure {
  let mut remaining = value
  let mut digits = 1
  while remaining >= 10 {
    remaining /= 10
    digits += 1
  }
  // Payload skeletons use zero as a one-character placeholder.
  self.reserve_chars(digits - 1)
}

///|
fn DocxOutputBudget::reserve_boolean_growth_from_true(
  self : DocxOutputBudget,
  value : Bool,
) -> Unit raise CliFailure {
  // `true` is the four-character skeleton placeholder; `false` needs one more.
  if !value {
    self.reserve_chars(1)
  }
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
  let mut count = docx_cli_output_framing_chars
  for _ in output {
    count += 1
    if count > maximum {
      raise docx_resource_failure(
        "successful command output characters",
        maximum,
        actual=count,
      )
    }
  }
}

///|
fn bounded_docx_payload(
  data : Json,
  warnings : Array[@lib.ProtocolWarning],
  maximum : Int,
) -> BoundedDocxPayload raise CliFailure {
  ignore(checked_output_limit(maximum))
  let budget = DocxOutputBudget::new(maximum)
  budget.reserve_success_envelope(data, warnings)
  { data, budget, warnings }
}

///|
fn checked_docx_json_output(
  payload : BoundedDocxPayload,
) -> String raise CliFailure {
  let envelope = @lib.output_success(payload.data, warnings=payload.warnings)
  // Compact output makes the preflight count exact and avoids indentation
  // overhead that would otherwise need a second allocation-sized pass.
  let output = envelope.stringify()
  ensure_docx_output_limit(output, payload.budget.maximum)
  let mut actual = 0
  for _ in output {
    actual += 1
  }
  if actual + docx_cli_output_framing_chars != payload.budget.used {
    raise docx_cli_failure(
      "office.docx.output_accounting_mismatch",
      "internal DOCX output accounting did not match serialization",
      details=Json::object({
        "accounted": Json::number(payload.budget.used.to_double()),
        "actual": Json::number(
          (actual + docx_cli_output_framing_chars).to_double(),
        ),
      }),
    )
  }
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
) -> BoundedDocxPayload raise CliFailure {
  let children : Array[Json] = []
  let fields = entry_base_json(entry, children)
  fields["schema"] = Json::string(@lib.SCHEMA_DOCX_ELEMENT)
  fields["file"] = Json::string(projection.file)
  fields["format"] = Json::string("docx")
  match entry.element {
    Some(_) => fields["text"] = Json::string("")
    None => ()
  }
  let skeleton = Json::object(fields)
  let bounded = bounded_docx_payload(
    skeleton,
    projection.warnings,
    max_output_chars,
  )
  for path in entry.children {
    let child = child_reference_json(projection, path)
    bounded.budget.reserve_array_item(child, !children.is_empty())
    children.push(child)
  }
  match entry.element {
    Some(_) => {
      let text_budget = DocxTextBudget::new_reported(
        "successful command output characters",
        bounded.budget.remaining(),
        bounded.budget.maximum,
        bounded.budget.used,
      )
      let text = entry_text_with_budget(entry, text_budget)
      bounded.budget.reserve_json_string_body(text)
      fields["text"] = Json::string(text)
    }
    None => ()
  }
  {
    data: Json::object(fields),
    budget: bounded.budget,
    warnings: bounded.warnings,
  }
}

///|
fn text_record_json(entry : DocxProjectionEntry, text : String) -> Json {
  Json::object({
    "path": Json::string(entry.path),
    "stability": Json::string(selector_stability_text(entry.stability)),
    "text": Json::string(text),
  })
}

///|
fn docx_text_payload(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  under_path : String?,
  offset : Int,
  limit : Int,
  max_output_chars : Int,
) -> BoundedDocxPayload raise CliFailure {
  let entries : Array[Json] = []
  let fields : Map[String, Json] = {
    "schema": Json::string(@lib.SCHEMA_DOCX_TEXT),
    "file": Json::string(projection.file),
    "format": Json::string("docx"),
    "entries": Json::array(entries),
    // Dynamic non-negative integers use a one-character zero placeholder.
    "matched_total": Json::number(0),
    "offset": Json::number(offset.to_double()),
    "limit": Json::number(limit.to_double()),
    "returned": Json::number(0),
    // `true` is the shorter boolean spelling; false growth is charged later.
    "truncated": Json::boolean(true),
    "scanned_elements": Json::number(projection.entries.length().to_double()),
  }
  match under_path {
    Some(path) => fields["under"] = Json::string(path)
    None => ()
  }
  let bounded = bounded_docx_payload(
    Json::object(fields),
    projection.warnings,
    max_output_chars,
  )
  let mut matched = 0
  for entry in projection.entries {
    let in_scope = match under {
      Some(root) => path_is_within(entry.path, root.path)
      None => true
    }
    if in_scope && entry.kind == "p" {
      if matched >= offset && entries.length() < limit {
        let text_budget = DocxTextBudget::new_reported(
          "successful command output characters",
          bounded.budget.remaining(),
          bounded.budget.maximum,
          bounded.budget.used,
        )
        let text = entry_text_with_budget(entry, text_budget)
        let json = text_record_json(entry, text)
        bounded.budget.reserve_array_item(json, !entries.is_empty())
        entries.push(json)
      }
      matched += 1
    }
  }
  let returned = entries.length()
  let truncated = offset + returned < matched
  bounded.budget.reserve_nonnegative_integer_growth(matched)
  bounded.budget.reserve_nonnegative_integer_growth(returned)
  bounded.budget.reserve_boolean_growth_from_true(truncated)
  fields["matched_total"] = Json::number(matched.to_double())
  fields["returned"] = Json::number(returned.to_double())
  fields["truncated"] = Json::boolean(truncated)
  {
    data: Json::object(fields),
    budget: bounded.budget,
    warnings: bounded.warnings,
  }
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
fn query_record_json(
  entry : DocxProjectionEntry,
  preview : String,
  preview_truncated : Bool,
) -> Json {
  let fields : Map[String, Json] = {
    "path": Json::string(entry.path),
    "kind": Json::string(entry.kind),
    "role": Json::string(entry.role.name()),
    "stability": Json::string(selector_stability_text(entry.stability)),
    "preview": Json::string(preview),
    "preview_truncated": Json::boolean(preview_truncated),
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
fn entry_matches_query(
  entry : DocxProjectionEntry,
  under : DocxProjectionEntry?,
  spec : DocxQuerySpec,
  scan_budget : DocxTextBudget,
) -> Bool raise CliFailure {
  let in_scope = match under {
    Some(root) => path_is_within(entry.path, root.path)
    None => true
  }
  if !in_scope {
    return false
  }
  match spec.kind {
    Some(kind) if entry.kind != kind => return false
    _ => ()
  }
  match spec.stable_id {
    Some(id) if entry.stable_id != Some(id) => return false
    _ => ()
  }
  if !entry_matches_properties(entry, spec.properties) {
    return false
  }
  match spec.text {
    Some(needle) => {
      let value = entry_text_with_budget(entry, scan_budget)
      text_contains(value, needle, spec.ignore_case)
    }
    None => true
  }
}

///|
fn docx_query_payload(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  spec : DocxQuerySpec,
  max_output_chars : Int,
) -> BoundedDocxPayload raise CliFailure {
  let filter_properties : Array[Json] = []
  let filters : Map[String, Json] = {
    "properties": Json::array(filter_properties),
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
    "matches": Json::array([]),
    "matched_total": Json::number(0),
    "offset": Json::number(spec.offset.to_double()),
    "limit": Json::number(spec.limit.to_double()),
    "returned": Json::number(0),
    "truncated": Json::boolean(true),
    "scanned_elements": Json::number(projection.entries.length().to_double()),
  }
  match spec.under {
    Some(path) => fields["under"] = Json::string(path)
    None => ()
  }
  let matches : Array[Json] = []
  fields["matches"] = Json::array(matches)
  let bounded = bounded_docx_payload(
    Json::object(fields),
    projection.warnings,
    max_output_chars,
  )
  for predicate in spec.properties {
    let record = Json::object({
      "name": Json::string(predicate.name),
      "value": Json::string(predicate.value),
    })
    bounded.budget.reserve_array_item(record, !filter_properties.is_empty())
    filter_properties.push(record)
  }
  let scan_budget = DocxTextBudget::new(
    "query text scan characters", docx_cli_max_query_text_scan_chars,
  )
  let mut matched = 0
  for entry in projection.entries {
    if !entry_matches_query(entry, under, spec, scan_budget) {
      continue
    }
    if matched >= spec.offset && matches.length() < spec.limit {
      let (preview, preview_truncated) = entry_text_prefix(
        entry, docx_cli_query_preview_chars,
      )
      let record = query_record_json(entry, preview, preview_truncated)
      bounded.budget.reserve_array_item(record, !matches.is_empty())
      matches.push(record)
    }
    matched += 1
  }
  let returned = matches.length()
  let truncated = spec.offset + returned < matched
  bounded.budget.reserve_nonnegative_integer_growth(matched)
  bounded.budget.reserve_nonnegative_integer_growth(returned)
  bounded.budget.reserve_boolean_growth_from_true(truncated)
  fields["matched_total"] = Json::number(matched.to_double())
  fields["returned"] = Json::number(returned.to_double())
  fields["truncated"] = Json::boolean(truncated)
  {
    data: Json::object(fields),
    budget: bounded.budget,
    warnings: bounded.warnings,
  }
}

///|
fn docx_heading_level(element : @document.DocumentElement) -> Int? {
  guard element is Paragraph(properties~, ..) else { return None }
  @docx_inspect.heading_level(properties)
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
fn outline_style_value_is_new(
  seen : Map[String, Set[String]],
  kind : String,
  value : String,
) -> Bool {
  let values = match seen.get(kind) {
    Some(values) => values
    None => {
      let values : Set[String] = Set([])
      seen[kind] = values
      values
    }
  }
  if values.contains(value) {
    false
  } else {
    values.add(value)
    true
  }
}

///|
fn section_ref_json(reference : @document.SectionRef) -> Json {
  Json::object({
    "variant": Json::string(reference.variant),
    "part": Json::number((reference.part + 1).to_double()),
  })
}

///|
fn bounded_section_json(
  section : @document.DocumentSection,
  budget : DocxOutputBudget,
  has_previous : Bool,
) -> Json raise CliFailure {
  let headers : Array[Json] = []
  let footers : Array[Json] = []
  let fields : Map[String, Json] = {
    "headers": Json::array(headers),
    "footers": Json::array(footers),
  }
  match section.ends_after_paragraph {
    Some(index) =>
      fields["ends_after_paragraph"] = Json::number(index.to_double())
    None => ()
  }
  budget.reserve_array_item(Json::object(fields), has_previous)
  for reference in section.headers {
    let record = section_ref_json(reference)
    budget.reserve_array_item(record, !headers.is_empty())
    headers.push(record)
  }
  for reference in section.footers {
    let record = section_ref_json(reference)
    budget.reserve_array_item(record, !footers.is_empty())
    footers.push(record)
  }
  Json::object(fields)
}

///|
fn reader_diagnostics(
  projection : DocxProjection,
  retention_budget? : DocxOutputBudget,
) -> Array[Json] raise CliFailure {
  let values : Array[Json] = []
  for message in projection.annotated.result().messages {
    let (severity, text) = match message {
      Warning(value) => ("warning", value)
      Error(value) => ("error", value)
    }
    let record = Json::object({
      "severity": Json::string(severity),
      "message": Json::string(bounded_text(text, 512)),
    })
    match retention_budget {
      Some(budget) => budget.reserve_array_item(record, !values.is_empty())
      None => ()
    }
    values.push(record)
  }
  values
}

///|
fn docx_outline_payload(
  projection : DocxProjection,
  max_output_chars? : Int = docx_cli_default_max_output_chars,
) -> BoundedDocxPayload raise CliFailure {
  ignore(checked_output_limit(max_output_chars))
  let counts : Map[String, Int] = Map([])
  let mut footnotes = 0
  let mut endnotes = 0
  for entry in projection.entries {
    counts[entry.kind] = counts.get(entry.kind).unwrap_or(0) + 1
    if entry.kind == "note" && entry.parent == Some("/docx/footnotes") {
      footnotes += 1
    } else if entry.kind == "note" && entry.parent == Some("/docx/endnotes") {
      endnotes += 1
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
  let stories : Array[Json] = []
  let headings : Array[Json] = []
  let images : Array[Json] = []
  let styles : Array[Json] = []
  let sections : Array[Json] = []
  let seen_style_ids : Map[String, Set[String]] = Map([])
  let seen_style_names : Map[String, Set[String]] = Map([])
  let result = projection.annotated.result()
  let diagnostics : Array[Json] = []
  // Charge the exact compact envelope with empty variable-length arrays first.
  // Every retained array item below is charged before insertion.
  let skeleton = Json::object({
    "schema": Json::string(@lib.SCHEMA_DOCX_OUTLINE),
    "file": Json::string(projection.file),
    "format": Json::string("docx"),
    "scanned_elements": Json::number(projection.entries.length().to_double()),
    "counts": Json::object(count_fields),
    "stories": Json::array([]),
    "headings": Json::array([]),
    "styles_in_use": Json::array([]),
    "images": Json::array([]),
    "sections": Json::array([]),
    "diagnostics": Json::array([]),
  })
  let bounded = bounded_docx_payload(
    skeleton,
    projection.warnings,
    max_output_chars,
  )
  for entry in projection.entries {
    if entry.role is (StoryRoot | AnnotationCollection) {
      let record = Json::object({
        "path": Json::string(entry.path),
        "kind": Json::string(entry.kind),
        "children": Json::number(entry.children.length().to_double()),
        "stability": Json::string(selector_stability_text(entry.stability)),
        "source": entry.source,
      })
      bounded.budget.reserve_array_item(record, !stories.is_empty())
      stories.push(record)
    }
    match entry.element {
      Some(element) => {
        match docx_heading_level(element) {
          Some(level) => {
            let (text, truncated) = entry_text_prefix(
              entry, docx_cli_heading_preview_chars,
            )
            let record = Json::object({
              "path": Json::string(entry.path),
              "level": Json::number(level.to_double()),
              "text": Json::string(text),
              "text_truncated": Json::boolean(truncated),
            })
            bounded.budget.reserve_array_item(record, !headings.is_empty())
            headings.push(record)
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
          let record = Json::object(fields)
          bounded.budget.reserve_array_item(record, !images.is_empty())
          images.push(record)
        }
        let retain_style = match entry.properties.get("style_id") {
          Some(id) => outline_style_value_is_new(seen_style_ids, entry.kind, id)
          None =>
            match entry.properties.get("style_name") {
              Some(name) =>
                outline_style_value_is_new(seen_style_names, entry.kind, name)
              None => false
            }
        }
        if retain_style {
          match outline_style_record(entry) {
            Some(style) => {
              bounded.budget.reserve_array_item(style, !styles.is_empty())
              styles.push(style)
            }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  for section in result.sections {
    sections.push(
      bounded_section_json(section, bounded.budget, !sections.is_empty()),
    )
  }
  diagnostics.append(
    reader_diagnostics(projection, retention_budget=bounded.budget),
  )
  {
    data: Json::object({
      "schema": Json::string(@lib.SCHEMA_DOCX_OUTLINE),
      "file": Json::string(projection.file),
      "format": Json::string("docx"),
      "scanned_elements": Json::number(projection.entries.length().to_double()),
      "counts": Json::object(count_fields),
      "stories": Json::array(stories),
      "headings": Json::array(headings),
      "styles_in_use": Json::array(styles),
      "images": Json::array(images),
      "sections": Json::array(sections),
      "diagnostics": Json::array(diagnostics),
    }),
    budget: bounded.budget,
    warnings: bounded.warnings,
  }
}

///|
struct DocxHumanWriter {
  maximum : Int
  output : StringBuilder
  mut used : Int
  mut lines : Int
}

///|
fn DocxHumanWriter::new(maximum : Int) -> DocxHumanWriter raise CliFailure {
  ignore(checked_output_limit(maximum))
  {
    maximum,
    output: StringBuilder::new(),
    used: docx_cli_output_framing_chars,
    lines: 0,
  }
}

///|
fn DocxHumanWriter::remaining(self : DocxHumanWriter) -> Int {
  self.maximum - self.used
}

///|
fn DocxHumanWriter::write_char(
  self : DocxHumanWriter,
  value : Char,
) -> Unit raise CliFailure {
  if self.used >= self.maximum {
    raise docx_resource_failure(
      "successful command output characters",
      self.maximum,
      actual=self.used + 1,
    )
  }
  self.output.write_char(value) |> ignore
  self.used += 1
}

///|
fn DocxHumanWriter::write_plain(
  self : DocxHumanWriter,
  value : String,
) -> Unit raise CliFailure {
  for character in value {
    self.write_char(character)
  }
}

///|
fn DocxHumanWriter::write_terminal_safe(
  self : DocxHumanWriter,
  value : String,
  single_line? : Bool = false,
) -> Unit raise CliFailure {
  for character in value {
    if single_line && character is ('\n' | '\r') {
      self.write_char(' ')
      continue
    }
    match character {
      '\n' => self.write_plain("\\n")
      '\r' => self.write_plain("\\r")
      '\t' => self.write_plain("\\t")
      _ => {
        let code = character.to_int()
        if code < 0x20 || code == 0x7f || (code >= 0x80 && code <= 0x9f) {
          self.write_plain("\\u")
          self.write_char(terminal_hex_digit((code >> 12) & 0xf))
          self.write_char(terminal_hex_digit((code >> 8) & 0xf))
          self.write_char(terminal_hex_digit((code >> 4) & 0xf))
          self.write_char(terminal_hex_digit(code & 0xf))
        } else {
          self.write_char(character)
        }
      }
    }
  }
}

///|
fn DocxHumanWriter::begin_line(self : DocxHumanWriter) -> Unit raise CliFailure {
  if self.lines > 0 {
    self.write_char('\n')
  }
  self.lines += 1
}

///|
fn DocxHumanWriter::finish(self : DocxHumanWriter) -> String {
  self.output.to_string()
}

///|
fn DocxHumanWriter::write_warnings(
  self : DocxHumanWriter,
  warnings : Array[@lib.ProtocolWarning],
) -> Unit raise CliFailure {
  for warning in warnings {
    self.begin_line()
    self.write_plain("# warning ")
    self.write_terminal_safe(warning.code)
    self.write_plain(": ")
    self.write_terminal_safe(warning.message)
  }
}

///|
fn docx_text_human(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  offset : Int,
  limit : Int,
  warnings : Array[@lib.ProtocolWarning],
  maximum? : Int = docx_cli_hard_max_output_chars,
) -> String raise CliFailure {
  let output = DocxHumanWriter::new(maximum)
  let mut matched = 0
  let mut returned = 0
  for entry in projection.entries {
    let in_scope = match under {
      Some(root) => path_is_within(entry.path, root.path)
      None => true
    }
    if in_scope && entry.kind == "p" {
      if matched >= offset && returned < limit {
        output.begin_line()
        output.write_terminal_safe(entry.path)
        output.write_char('\t')
        let text_budget = DocxTextBudget::new_reported(
          "successful command output characters",
          output.remaining(),
          output.maximum,
          output.used,
        )
        let text = entry_text_with_budget(entry, text_budget)
        output.write_terminal_safe(text, single_line=true)
        returned += 1
      }
      matched += 1
    }
  }
  output.write_warnings(warnings)
  output.finish()
}

///|
fn docx_query_human(
  projection : DocxProjection,
  under : DocxProjectionEntry?,
  spec : DocxQuerySpec,
  warnings : Array[@lib.ProtocolWarning],
  maximum? : Int = docx_cli_hard_max_output_chars,
) -> String raise CliFailure {
  let output = DocxHumanWriter::new(maximum)
  let scan_budget = DocxTextBudget::new(
    "query text scan characters", docx_cli_max_query_text_scan_chars,
  )
  let mut matched = 0
  let mut returned = 0
  for entry in projection.entries {
    if !entry_matches_query(entry, under, spec, scan_budget) {
      continue
    }
    if matched >= spec.offset && returned < spec.limit {
      let (preview, _) = entry_text_prefix(entry, docx_cli_query_preview_chars)
      output.begin_line()
      output.write_terminal_safe(entry.path)
      output.write_char('\t')
      output.write_terminal_safe(entry.kind)
      output.write_char('\t')
      output.write_terminal_safe(preview, single_line=true)
      returned += 1
    }
    matched += 1
  }
  output.begin_line()
  output.write_plain(
    "# matched \{matched}; returned \{returned}; offset \{spec.offset}",
  )
  output.write_warnings(warnings)
  output.finish()
}

///|
fn docx_get_human(
  entry : DocxProjectionEntry,
  text : String,
  warnings : Array[@lib.ProtocolWarning],
  maximum? : Int = docx_cli_hard_max_output_chars,
) -> String raise CliFailure {
  let output = DocxHumanWriter::new(maximum)
  output.begin_line()
  if text == "" {
    output.write_terminal_safe(entry.path)
    output.write_char('\t')
    output.write_terminal_safe(entry.kind)
  } else {
    output.write_terminal_safe(text)
  }
  output.write_warnings(warnings)
  output.finish()
}

///|
fn docx_outline_human(
  projection : DocxProjection,
  maximum? : Int = docx_cli_hard_max_output_chars,
) -> String raise CliFailure {
  let counts : Map[String, Int] = Map([])
  let output = DocxHumanWriter::new(maximum)
  output.begin_line()
  output.write_plain("docx: ")
  output.write_plain(raw_human_text(projection.file, 160))
  output.begin_line()
  output.write_plain("scanned elements: \{projection.entries.length()}")
  for entry in projection.entries {
    counts[entry.kind] = counts.get(entry.kind).unwrap_or(0) + 1
    if entry.role is (StoryRoot | AnnotationCollection) {
      output.begin_line()
      output.write_terminal_safe(entry.path)
      output.write_char('\t')
      output.write_terminal_safe(entry.kind)
      output.write_plain("\t\{entry.children.length()} children")
    }
  }
  output.begin_line()
  output.write_plain(
    "paragraphs: \{counts.get("p").unwrap_or(0)}; tables: \{counts.get("tbl").unwrap_or(0)}; images: \{counts.get("image").unwrap_or(0)}; comments: \{counts.get("comment").unwrap_or(0)}; footnotes/endnotes: \{counts.get("note").unwrap_or(0)}",
  )
  for entry in projection.entries {
    match entry.element {
      Some(element) =>
        match docx_heading_level(element) {
          Some(level) => {
            let (text, truncated) = entry_text_prefix(
              entry, docx_cli_heading_preview_chars,
            )
            output.begin_line()
            output.write_plain("heading \{level}\t")
            output.write_terminal_safe(entry.path)
            output.write_char('\t')
            output.write_terminal_safe(text, single_line=true)
            if truncated {
              output.write_plain("…")
            }
          }
          None => ()
        }
      None => ()
    }
  }
  output.write_warnings(projection.warnings)
  output.finish()
}
