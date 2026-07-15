///|
let docx_cli_max_element_text_chars : Int = 1024 * 1024

///|
let docx_cli_max_query_text_scan_chars : Int = 16 * 1024 * 1024

///|
struct DocxTextBudget {
  resource : String
  maximum : Int
  reported_maximum : Int
  reported_offset : Int
  mut used : Int
}

///|
struct DocxTextCollector {
  maximum : Int
  reported_maximum : Int
  reported_offset : Int
  fail_on_limit : Bool
  resource : String
  output : StringBuilder
  mut used : Int
  mut scanned : Int
  mut pending_newlines : Int
  mut truncated : Bool
}

///|
struct DocxCollectedText {
  text : String
  scanned : Int
  truncated : Bool
}

///|
fn DocxTextBudget::new(resource : String, maximum : Int) -> DocxTextBudget {
  { resource, maximum, reported_maximum: maximum, reported_offset: 0, used: 0 }
}

///|
fn DocxTextBudget::new_reported(
  resource : String,
  maximum : Int,
  reported_maximum : Int,
  reported_offset : Int,
) -> DocxTextBudget {
  { resource, maximum, reported_maximum, reported_offset, used: 0 }
}

///|
fn DocxTextCollector::new_reported(
  resource : String,
  maximum : Int,
  reported_maximum : Int,
  reported_offset : Int,
  fail_on_limit : Bool,
) -> DocxTextCollector {
  {
    maximum,
    reported_maximum,
    reported_offset,
    fail_on_limit,
    resource,
    output: StringBuilder::new(),
    used: 0,
    scanned: 0,
    pending_newlines: 0,
    truncated: false,
  }
}

///|
fn DocxTextCollector::write_output_char(
  self : DocxTextCollector,
  value : Char,
) -> Unit raise CliFailure {
  if self.used >= self.maximum {
    self.truncated = true
    if self.fail_on_limit {
      raise docx_resource_failure(
        self.resource,
        self.reported_maximum,
        actual=self.reported_offset + self.used + 1,
      )
    }
    return
  }
  self.output.write_char(value) |> ignore
  self.used += 1
}

///|
fn DocxTextCollector::flush_pending_newlines(
  self : DocxTextCollector,
) -> Unit raise CliFailure {
  let count = self.pending_newlines
  self.pending_newlines = 0
  for _ in 0..<count {
    self.write_output_char('\n')
    if self.truncated && !self.fail_on_limit {
      break
    }
  }
}

///|
fn DocxTextCollector::write_literal_char(
  self : DocxTextCollector,
  value : Char,
) -> Unit raise CliFailure {
  // Scan accounting is independent of retained output. In particular, a
  // literal LF at the end of a w:t node may later be trimmed from presentation,
  // but it still consumed parser/projection work and must count toward both
  // per-element and aggregate query limits.
  if self.scanned >= self.maximum {
    self.truncated = true
    if self.fail_on_limit {
      raise docx_resource_failure(
        self.resource,
        self.reported_maximum,
        actual=self.reported_offset + self.scanned + 1,
      )
    }
    return
  }
  self.scanned += 1
  self.flush_pending_newlines()
  if self.truncated && !self.fail_on_limit {
    return
  }
  self.write_output_char(value)
}

///|
fn DocxTextCollector::write_literal_string(
  self : DocxTextCollector,
  value : String,
) -> Unit raise CliFailure {
  if self.truncated && !self.fail_on_limit {
    return
  }
  for character in value {
    self.write_literal_char(character)
    if self.truncated && !self.fail_on_limit {
      break
    }
  }
}

///|
fn DocxTextCollector::queue_paragraph_separator(
  self : DocxTextCollector,
) -> Unit {
  // Synthetic paragraph separators are presentation only. Keep them pending so
  // trailing separators remain trimmed, but cap the counter: one value beyond
  // the output ceiling is sufficient to make a later flush fail deterministically.
  if self.pending_newlines <= self.maximum {
    self.pending_newlines += 1
  }
}

///|
fn DocxTextCollector::visit(
  self : DocxTextCollector,
  element : @document.DocumentElement,
) -> Unit raise CliFailure {
  if self.truncated && !self.fail_on_limit {
    return
  }
  match element {
    Text(value) => self.write_literal_string(value)
    Tab => self.write_literal_char('\t')
    Paragraph(children~, ..) => {
      self.visit_all(children)
      self.queue_paragraph_separator()
      self.queue_paragraph_separator()
    }
    Document(children~, ..)
    | Run(children~, ..)
    | Hyperlink(children~, ..)
    | Table(children~, ..)
    | TableRow(children~, ..)
    | TableCell(children~, ..) => self.visit_all(children)
    Checkbox(_)
    | NoteReference(_)
    | CommentReference(_)
    | Image(_)
    | Break(_)
    | BookmarkStart(_) => ()
  }
}

///|
fn DocxTextCollector::visit_all(
  self : DocxTextCollector,
  elements : Array[@document.DocumentElement],
) -> Unit raise CliFailure {
  for element in elements {
    if self.truncated && !self.fail_on_limit {
      break
    }
    self.visit(element)
  }
}

///|
fn collect_docx_text_counted(
  element : @document.DocumentElement,
  maximum : Int,
  resource : String,
  reported_maximum : Int,
  reported_offset : Int,
  fail_on_limit : Bool,
) -> DocxCollectedText raise CliFailure {
  let collector = DocxTextCollector::new_reported(
    resource, maximum, reported_maximum, reported_offset, fail_on_limit,
  )
  collector.visit(element)
  {
    text: collector.output.to_string().trim_end(chars="\n").to_owned(),
    scanned: collector.scanned,
    truncated: collector.truncated,
  }
}

///|
fn collect_docx_text_prefix(
  element : @document.DocumentElement,
  maximum : Int,
) -> (String, Bool) {
  // Truncating collectors never raise.
  let result = try! collect_docx_text_counted(
    element, maximum, "text preview", maximum, 0, false,
  )
  (result.text, result.truncated)
}

///|
fn entry_text_with_budget(
  entry : DocxProjectionEntry,
  budget : DocxTextBudget,
) -> String raise CliFailure {
  guard entry.element is Some(element) else { return "" }
  let remaining = budget.maximum - budget.used
  if remaining < 0 {
    raise docx_resource_failure(
      budget.resource,
      budget.reported_maximum,
      actual=budget.reported_offset + budget.used,
    )
  }
  let element_limit = remaining.min(docx_cli_max_element_text_chars)
  let (resource, reported_maximum, reported_offset) = if docx_cli_max_element_text_chars <=
    remaining {
    ("element text characters", docx_cli_max_element_text_chars, 0)
  } else {
    (
      budget.resource,
      budget.reported_maximum,
      budget.reported_offset + budget.used,
    )
  }
  let result = collect_docx_text_counted(
    element, element_limit, resource, reported_maximum, reported_offset, true,
  )
  budget.used += result.scanned
  result.text
}

///|
fn entry_text_prefix(
  entry : DocxProjectionEntry,
  maximum : Int,
) -> (String, Bool) {
  match entry.element {
    Some(element) => collect_docx_text_prefix(element, maximum)
    None => ("", false)
  }
}

///|
fn selector_failure(error : @lib.SelectorError) -> CliFailure {
  match error {
    SelectorError(code~, offset~, input~, message~) =>
      docx_cli_failure(
        code,
        message,
        details=Json::object({
          "offset": Json::number(offset.to_double()),
          "input": Json::string(input),
        }),
      )
  }
}

///|
fn selector_not_found(path : String) -> CliFailure {
  docx_cli_failure(
    "office.docx.selector_not_found",
    "DOCX selector did not resolve in this document snapshot",
    details=Json::object({ "selector": Json::string(bounded_text(path, 240)) }),
  )
}

///|
fn find_projection_entry(
  projection : DocxProjection,
  path : String,
) -> DocxProjectionEntry? {
  match projection.entry_index.get(path) {
    Some(index) => projection.entries.get(index)
    None => None
  }
}

///|
fn annotation_id_context(
  selector : @lib.OfficeSelector,
) -> (String, String, String)? {
  let segments = selector.segments()
  if segments.length() < 2 {
    return None
  }
  let story = segments[0].name()
  let kind = segments[1].name()
  match segments[1].key_value("id") {
    Some(id) if (story == "comments" && kind == "comment") ||
      ((story == "footnotes" || story == "endnotes") && kind == "note") =>
      Some((story, kind, id))
    _ => None
  }
}

///|
fn reject_unsupported_stable_ids(
  selector : @lib.OfficeSelector,
) -> Unit raise CliFailure {
  for segment in selector.segments() {
    match segment.key_value("id") {
      Some(_) if segment.name() != "note" && segment.name() != "comment" =>
        raise docx_cli_failure(
          "office.docx.unsupported_stable_id",
          "stable id selectors are currently supported only for DOCX notes and comments",
          details=Json::object({
            "selector": Json::string(selector.render()),
            "segment": Json::string(segment.name()),
          }),
        )
      _ => ()
    }
  }
}

///|
fn resolve_projection_selector(
  projection : DocxProjection,
  input : String,
) -> DocxProjectionEntry raise CliFailure {
  let selector = @lib.parse_selector(input) catch {
    error => raise selector_failure(error)
  }
  if selector.document_format() is Xlsx {
    raise docx_cli_failure(
      "office.docx.selector_format_mismatch",
      "DOCX structured reads require a /docx selector",
      details=Json::object({
        "selector": Json::string(selector.render()),
        "expected_format": Json::string("docx"),
        "actual_format": Json::string("xlsx"),
      }),
    )
  }
  if selector.coordinate() is Some(_) {
    raise docx_cli_failure(
      "office.docx.selector_format_mismatch", "DOCX selectors cannot contain spreadsheet coordinates",
    )
  }
  reject_unsupported_stable_ids(selector)
  let canonical = selector.render()
  match annotation_id_context(selector) {
    Some((story, kind, id)) => {
      let parent = "/docx/\{story}"
      let mut matches = 0
      for entry in projection.entries {
        if entry.parent == Some(parent) &&
          entry.kind == kind &&
          entry.stable_id == Some(id) {
          matches += 1
        }
      }
      if matches > 1 {
        raise docx_cli_failure(
          "office.docx.selector_ambiguous_id",
          "annotation id resolves to multiple \{story} items",
          details=Json::object({
            "selector": Json::string(canonical),
            "story": Json::string(story),
            "id": Json::string(id),
            "matches": Json::number(matches.to_double()),
          }),
        )
      }
      if matches == 0 {
        raise selector_not_found(canonical)
      }
    }
    None => ()
  }
  match find_projection_entry(projection, canonical) {
    Some(entry) => entry
    None => raise selector_not_found(canonical)
  }
}

///|
fn path_is_within(path : String, root : String) -> Bool {
  path == root || path.has_prefix(root + "/")
}

///|
fn DocxProjectionRole::name(self : DocxProjectionRole) -> String {
  match self {
    StoryRoot => "story-root"
    AnnotationCollection => "annotation-collection"
    AnnotationItem => "annotation-item"
    ElementNode => "element"
  }
}

///|
fn set_optional_json(
  fields : Map[String, Json],
  name : String,
  value : String?,
) -> Unit {
  match value {
    Some(text) => fields[name] = Json::string(text)
    None => ()
  }
}

///|
fn indent_json(indent : @document.Indent) -> Json {
  let fields : Map[String, Json] = Map([])
  set_optional_json(fields, "start", indent.start)
  set_optional_json(fields, "end", indent.end)
  set_optional_json(fields, "first_line", indent.first_line)
  set_optional_json(fields, "hanging", indent.hanging)
  Json::object(fields)
}

///|
fn element_properties_json(element : @document.DocumentElement) -> Json {
  let fields : Map[String, Json] = Map([])
  match element {
    Paragraph(properties~, ..) => {
      set_optional_json(fields, "style_id", properties.style_id)
      set_optional_json(fields, "style_name", properties.style_name)
      set_optional_json(fields, "alignment", properties.alignment)
      match properties.numbering {
        Some(numbering) =>
          fields["numbering"] = Json::object({
            "ordered": Json::boolean(numbering.is_ordered),
            "level": Json::number(numbering.level.to_double()),
          })
        None => ()
      }
      let indentation = indent_json(properties.indent)
      if indentation.stringify() != "{}" {
        fields["indent"] = indentation
      }
    }
    Run(properties~, ..) => {
      set_optional_json(fields, "style_id", properties.style_id)
      set_optional_json(fields, "style_name", properties.style_name)
      fields["bold"] = Json::boolean(properties.is_bold)
      fields["italic"] = Json::boolean(properties.is_italic)
      fields["underline"] = Json::boolean(properties.is_underline)
      fields["strikethrough"] = Json::boolean(properties.is_strikethrough)
      fields["all_caps"] = Json::boolean(properties.is_all_caps)
      fields["small_caps"] = Json::boolean(properties.is_small_caps)
      let vertical = match properties.vertical_alignment {
        Baseline => "baseline"
        Superscript => "superscript"
        Subscript => "subscript"
      }
      fields["vertical_alignment"] = Json::string(vertical)
      set_optional_json(fields, "font", properties.font)
      match properties.font_size {
        Some(size) => fields["font_size"] = Json::number(size.to_double())
        None => ()
      }
      set_optional_json(fields, "highlight", properties.highlight)
    }
    Table(properties~, ..) => {
      set_optional_json(fields, "style_id", properties.style_id)
      set_optional_json(fields, "style_name", properties.style_name)
    }
    TableRow(is_header~, ..) => fields["header"] = Json::boolean(is_header)
    TableCell(col_span~, row_span~, ..) => {
      fields["col_span"] = Json::number(col_span.to_double())
      fields["row_span"] = Json::number(row_span.to_double())
    }
    Hyperlink(href~, anchor~, target_frame~, ..) => {
      set_optional_json(fields, "href", href)
      set_optional_json(fields, "anchor", anchor)
      set_optional_json(fields, "target_frame", target_frame)
    }
    Image(image) => {
      fields["content_type"] = Json::string(image.content_type)
      fields["bytes"] = Json::number(image.data.length().to_double())
      set_optional_json(fields, "alt_text", image.alt_text)
    }
    _ => ()
  }
  Json::object(fields)
}

///|
fn entry_properties_json(entry : DocxProjectionEntry) -> Json {
  match entry.element {
    Some(element) => element_properties_json(element)
    None => Json::empty_object()
  }
}

///|
fn child_reference_json(projection : DocxProjection, path : String) -> Json {
  match find_projection_entry(projection, path) {
    Some(entry) => {
      let fields : Map[String, Json] = {
        "path": Json::string(entry.path),
        "kind": Json::string(entry.kind),
        "stability": Json::string(selector_stability_text(entry.stability)),
      }
      match entry.stable_id {
        Some(id) => fields["id"] = Json::string(id)
        None => ()
      }
      Json::object(fields)
    }
    None =>
      Json::object({
        "path": Json::string(path),
        "kind": Json::string("unknown"),
        "stability": Json::string("snapshot-relative"),
      })
  }
}

///|
fn entry_base_json(
  entry : DocxProjectionEntry,
  children : Array[Json],
) -> Map[String, Json] {
  let fields : Map[String, Json] = {
    "path": Json::string(entry.path),
    "kind": Json::string(entry.kind),
    "role": Json::string(entry.role.name()),
    "stability": Json::string(selector_stability_text(entry.stability)),
    "source": entry.source,
  }
  match entry.parent {
    Some(path) => fields["parent"] = Json::string(path)
    None => ()
  }
  match entry.stable_id {
    Some(id) => fields["id"] = Json::string(id)
    None => ()
  }
  fields["children"] = Json::array(children)
  fields["properties"] = entry_properties_json(entry)
  fields["metadata"] = entry.metadata
  fields
}
