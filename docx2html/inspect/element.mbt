// Builds the `docx.element/1` payload (`docx get <file> <path> --json`) and
// the path-tagged plain-text view (`docx text <file>`). Both share the path
// grammar in paths.mbt.

///|
/// Builds the `docx.element/1` JSON payload for the element at `path`.
pub fn element(
  document : @document.DocumentElement,
  file~ : String,
  path~ : String,
  headers? : Array[@document.HeaderFooterPart] = [],
  footers? : Array[@document.HeaderFooterPart] = [],
) -> Json raise PathError {
  let parsed = @paths.parse_path(path)
  let (container, prefix) = @paths.root_container(
    document, parsed, path, headers, footers,
  )
  let target = if parsed.steps.length() == 0 {
    container
  } else {
    @paths.resolve_steps(container, parsed.steps, path, root_prefix=prefix)
  }
  let normalized = normalized_path(prefix, parsed.steps)
  let out : Map[String, Json] = {
    "schema": Json::string(SCHEMA_ELEMENT),
    "file": Json::string(file),
    "path": Json::string(normalized),
    "kind": Json::string(element_kind_name(target, parsed.root)),
  }
  element_attributes(target, out)
  out["children"] = children_json(target, normalized)
  Json::object(out)
}

///|
fn normalized_path(prefix : String, steps : Array[@paths.PathStep]) -> String {
  let builder = StringBuilder()
  builder.write_string(prefix)
  for step in steps {
    builder.write_string("/\{step.kind}[\{step.index}]")
  }
  builder.to_string()
}

///|
fn element_kind_name(
  element : @document.DocumentElement,
  root : @paths.PathRoot,
) -> String {
  match @paths.segment_kind(element) {
    Some(kind) => kind
    None =>
      match root {
        Body => "body"
        Header(_) => "header"
        Footer(_) => "footer"
      }
  }
}

///|
/// Kind-specific attributes, written into `out`. Only set properties are
/// emitted (never `null`; boolean formatting flags appear only when true).
fn element_attributes(
  element : @document.DocumentElement,
  out : Map[String, Json],
) -> Unit {
  match element {
    Paragraph(properties~, ..) => {
      out["text"] = Json::string(element_text(element))
      set_optional(out, "style_id", properties.style_id)
      set_optional(out, "style_name", properties.style_name)
      match properties.numbering {
        Some(numbering) =>
          out["numbering"] = Json::object({
            "ordered": Json::boolean(numbering.is_ordered),
            "level": count_json(numbering.level),
          })
        None => ()
      }
      set_optional(out, "alignment", properties.alignment)
    }
    Run(properties~, ..) => {
      out["text"] = Json::string(element_text(element))
      set_optional(out, "style_id", properties.style_id)
      set_optional(out, "style_name", properties.style_name)
      set_flag(out, "bold", properties.is_bold)
      set_flag(out, "italic", properties.is_italic)
      set_flag(out, "underline", properties.is_underline)
      set_flag(out, "strikethrough", properties.is_strikethrough)
      set_flag(out, "all_caps", properties.is_all_caps)
      set_flag(out, "small_caps", properties.is_small_caps)
      match properties.vertical_alignment {
        Baseline => ()
        Superscript => out["vertical_alignment"] = Json::string("superscript")
        Subscript => out["vertical_alignment"] = Json::string("subscript")
      }
      set_optional(out, "font", properties.font)
      match properties.font_size {
        Some(size) => out["font_size"] = count_json(size)
        None => ()
      }
      set_optional(out, "highlight", properties.highlight)
    }
    Table(properties~, ..) => {
      set_optional(out, "style_id", properties.style_id)
      set_optional(out, "style_name", properties.style_name)
    }
    TableRow(is_header~, ..) => set_flag(out, "header", is_header)
    TableCell(col_span~, row_span~, ..) => {
      if col_span != 1 {
        out["col_span"] = count_json(col_span)
      }
      if row_span != 1 {
        out["row_span"] = count_json(row_span)
      }
    }
    Hyperlink(href~, anchor~, target_frame~, ..) => {
      out["text"] = Json::string(element_text(element))
      set_optional(out, "href", href)
      set_optional(out, "anchor", anchor)
      set_optional(out, "target_frame", target_frame)
    }
    Image(image) => {
      out["content_type"] = Json::string(image.content_type)
      out["bytes"] = count_json(image.data.length())
      set_optional(out, "alt_text", image.alt_text)
    }
    _ => ()
  }
}

///|
fn element_text(element : @document.DocumentElement) -> String {
  element.to_raw_text().trim_end(chars="\n").to_owned()
}

///|
fn set_optional(out : Map[String, Json], key : String, value : String?) -> Unit {
  match value {
    Some(text) => out[key] = Json::string(text)
    None => ()
  }
}

///|
fn set_flag(out : Map[String, Json], key : String, value : Bool) -> Unit {
  if value {
    out[key] = Json::boolean(true)
  }
}

///|
/// One `{kind, path}` entry per addressable direct child, in document
/// order, with 1-based per-kind indices.
fn children_json(
  element : @document.DocumentElement,
  parent_path : String,
) -> Json {
  let entries = []
  let counters : Map[String, Int] = Map([])
  for child in @paths.element_children(element) {
    match @paths.segment_kind(child) {
      Some(kind) => {
        let index = counters.get(kind).unwrap_or(0) + 1
        counters[kind] = index
        entries.push(
          Json::object({
            "kind": Json::string(kind),
            "path": Json::string("\{parent_path}/\{kind}[\{index}]"),
          }),
        )
      }
      None => ()
    }
  }
  Json::array(entries)
}

///|
/// The path-tagged plain-text view: one line per paragraph, at any nesting
/// depth, each prefixed with its full path — `[/body/p[1]] Hello`. Empty
/// paragraphs are emitted too (their paths are how an agent learns valid
/// indices).
pub fn text_lines(
  document : @document.DocumentElement,
  headers? : Array[@document.HeaderFooterPart] = [],
  footers? : Array[@document.HeaderFooterPart] = [],
) -> Array[String] {
  let lines = []
  let children = match document {
    Document(children~, ..) => children
    other => [other]
  }
  collect_text_lines(children, "/body", lines)
  // Header/footer stories follow the body, each under its own path root, so
  // every emitted path resolves via `get`.
  for index, part in headers {
    collect_text_lines(part.body, "/header[\{index + 1}]", lines)
  }
  for index, part in footers {
    collect_text_lines(part.body, "/footer[\{index + 1}]", lines)
  }
  lines
}

///|
fn collect_text_lines(
  children : Array[@document.DocumentElement],
  parent_path : String,
  lines : Array[String],
) -> Unit {
  let counters : Map[String, Int] = Map([])
  for child in children {
    match @paths.segment_kind(child) {
      Some(kind) => {
        let index = counters.get(kind).unwrap_or(0) + 1
        counters[kind] = index
        let path = "\{parent_path}/\{kind}[\{index}]"
        match child {
          // Literal newlines inside w:t (crafted files; Word itself uses
          // w:br) would break the one-line-per-paragraph format that path
          // scraping depends on — flatten them to spaces in this view only.
          Paragraph(..) =>
            lines.push("[\{path}] \{single_line(element_text(child))}")
          // Paragraphs never nest inside paragraphs in this AST; only
          // containers (tables and their parts) are descended into.
          Table(..) | TableRow(..) | TableCell(..) =>
            collect_text_lines(@paths.element_children(child), path, lines)
          _ => ()
        }
      }
      None => ()
    }
  }
}

///|
fn single_line(text : String) -> String {
  if text.find("\n") is None && text.find("\r") is None {
    return text
  }
  let builder = StringBuilder()
  for unit in text {
    if unit is ('\n' | '\r') {
      builder.write_char(' ')
    } else {
      builder.write_char(unit)
    }
  }
  builder.to_string()
}
