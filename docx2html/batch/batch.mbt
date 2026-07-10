// The `docx.batch/1` op-script parser and body builder — the consumed
// (input) schema behind `docx batch`. STRICT per the roadmap contract:
// unknown schema, unknown op, unknown key, or a wrong value type fails
// with an error naming the 0-based op index; nothing is repaired. Two
// phases so the pure parts stay pure: `parse_batch` validates the script
// and collects image paths; `build_body` turns the parsed script plus the
// (CLI-loaded) image bytes into writer input.

///|
/// A script that cannot be parsed or applied. Messages are agent-facing
/// and name the op index and key.
pub(all) suberror BatchError {
  BatchError(String)
} derive(Eq)

///|
pub impl Show for BatchError with fn output(self, logger) {
  match self {
    BatchError(message) => logger.write_string(message)
  }
}

///|
/// Schema identifier accepted by `docx batch` scripts.
pub const SCHEMA_BATCH : String = "docx.batch/1"

///|
const MAX_OPS : Int = 10000

///|
priv enum InlineSpec {
  RunSpec(@document.RunProperties, String)
  LinkSpec(
    href~ : String?,
    anchor~ : String?,
    target_frame~ : String?,
    runs~ : Array[InlineSpec]
  )
  ImageSpec(path~ : String, content_type~ : String, alt~ : String?)
}

///|
priv struct CellSpec {
  paragraphs : Array[ParagraphSpec]
  col_span : Int
  row_span : Int
}

///|
priv struct ParagraphSpec {
  style : String?
  align : String?
  list : @document.Numbering?
  inlines : Array[InlineSpec]
}

///|
priv enum OpSpec {
  ParagraphOp(ParagraphSpec)
  TableOp(rows~ : Array[Array[CellSpec]], header_rows~ : Int)
}

///|
/// A parsed, validated batch script.
pub struct BatchScript {
  priv ops : Array[OpSpec]
  priv image_paths : Array[String]
}

///|
/// The image files the script references, in first-use order (deduplicated).
/// The caller loads them and passes the bytes to `build_body`.
pub fn BatchScript::image_paths(self : BatchScript) -> Array[String] {
  self.image_paths
}

///|
/// Number of ops in the script.
pub fn BatchScript::op_count(self : BatchScript) -> Int {
  self.ops.length()
}

///|
/// Parses and strictly validates a `docx.batch/1` script.
pub fn parse_batch(script : Json) -> BatchScript raise BatchError {
  guard script is Object(root) else {
    raise BatchError("the script must be a JSON object")
  }
  check_keys(root, ["schema", "ops"], "the script")
  guard root.get("schema") is Some(String(schema)) else {
    raise BatchError("the script needs \"schema\": \"\{SCHEMA_BATCH}\"")
  }
  if schema != SCHEMA_BATCH {
    raise BatchError(
      "unsupported schema '\{schema}' (this build accepts \{SCHEMA_BATCH})",
    )
  }
  guard root.get("ops") is Some(Array(ops_json)) else {
    raise BatchError("the script needs \"ops\": [...]")
  }
  if ops_json.length() > MAX_OPS {
    raise BatchError(
      "the script has \{ops_json.length()} ops; the cap is \{MAX_OPS}",
    )
  }
  let ops : Array[OpSpec] = []
  let image_paths : Array[String] = []
  let seen_paths : Set[String] = Set([])
  for index, op_json in ops_json {
    let at = "ops[\{index}]"
    guard op_json is Object(op) else {
      raise BatchError("\{at} must be an object")
    }
    check_keys(op, ["op", "params"], at)
    guard op.get("op") is Some(String(op_name)) else {
      raise BatchError("\{at}.op must be a string")
    }
    let params = match op.get("params") {
      Some(Object(params)) => params
      Some(_) => raise BatchError("\{at}.params must be an object")
      None => Map([])
    }
    match op_name {
      "paragraph" =>
        ops.push(
          ParagraphOp(parse_paragraph(params, at, image_paths, seen_paths)),
        )
      "table" => ops.push(parse_table(params, at, image_paths, seen_paths))
      other =>
        raise BatchError(
          "\{at}.op '\{other}' is unknown (known ops: paragraph, table)",
        )
    }
  }
  { ops, image_paths }
}

///|
fn check_keys(
  object : Map[String, Json],
  allowed : Array[String],
  at : String,
) -> Unit raise BatchError {
  for key, _ in object {
    if allowed.search(key) is None {
      raise BatchError(
        "\{at} has an unknown key '\{key}' (allowed: \{allowed.join(", ")})",
      )
    }
  }
}

///|
fn parse_paragraph(
  params : Map[String, Json],
  at : String,
  image_paths : Array[String],
  seen_paths : Set[String],
) -> ParagraphSpec raise BatchError {
  check_keys(params, ["text", "runs", "style", "align", "list"], at + ".params")
  let style = optional_string(params, "style", at)
  let align = optional_string(params, "align", at)
  let list = match params.get("list") {
    Some(Object(list_json)) => {
      check_keys(list_json, ["ordered", "level"], at + ".params.list")
      let ordered = match list_json.get("ordered") {
        Some(True) => true
        Some(False) => false
        _ => raise BatchError("\{at}.params.list.ordered must be a boolean")
      }
      let level = match list_json.get("level") {
        Some(Number(level, ..)) => level.to_int()
        None => 1
        _ => raise BatchError("\{at}.params.list.level must be a number")
      }
      Some(@document.numbering(ordered, level))
    }
    Some(_) => raise BatchError("\{at}.params.list must be an object")
    None => None
  }
  let inlines : Array[InlineSpec] = []
  match (params.get("text"), params.get("runs")) {
    (Some(_), Some(_)) =>
      raise BatchError("\{at}.params: text and runs are mutually exclusive")
    (Some(String(text)), None) =>
      inlines.push(RunSpec(@document.run_properties(), text))
    (Some(_), None) => raise BatchError("\{at}.params.text must be a string")
    (None, Some(Array(runs))) =>
      for run_index, run_json in runs {
        inlines.push(
          parse_inline(
            run_json,
            "\{at}.params.runs[\{run_index}]",
            image_paths,
            seen_paths,
            allow_links=true,
          ),
        )
      }
    (None, Some(_)) => raise BatchError("\{at}.params.runs must be an array")
    (None, None) => ()
  }
  { style, align, list, inlines }
}

///|
fn parse_inline(
  json : Json,
  at : String,
  image_paths : Array[String],
  seen_paths : Set[String],
  allow_links~ : Bool,
) -> InlineSpec raise BatchError {
  guard json is Object(spec) else {
    raise BatchError("\{at} must be an object")
  }
  if spec.get("link") is Some(link_json) {
    if !allow_links {
      raise BatchError("\{at}: links cannot nest inside links")
    }
    check_keys(spec, ["link"], at)
    guard link_json is Object(link) else {
      raise BatchError("\{at}.link must be an object")
    }
    check_keys(
      link,
      ["href", "anchor", "target_frame", "text", "runs"],
      at + ".link",
    )
    let href = optional_string(link, "href", at + ".link")
    let anchor = optional_string(link, "anchor", at + ".link")
    let target_frame = optional_string(link, "target_frame", at + ".link")
    let runs : Array[InlineSpec] = []
    match (link.get("text"), link.get("runs")) {
      (Some(String(text)), None) =>
        runs.push(RunSpec(@document.run_properties(), text))
      (Some(_), None) => raise BatchError("\{at}.link.text must be a string")
      (None, Some(Array(link_runs))) =>
        for run_index, run_json in link_runs {
          runs.push(
            parse_inline(
              run_json,
              "\{at}.link.runs[\{run_index}]",
              image_paths,
              seen_paths,
              allow_links=false,
            ),
          )
        }
      (None, Some(_)) => raise BatchError("\{at}.link.runs must be an array")
      (Some(_), Some(_)) =>
        raise BatchError("\{at}.link: text and runs are mutually exclusive")
      (None, None) => raise BatchError("\{at}.link needs text or runs")
    }
    return LinkSpec(href~, anchor~, target_frame~, runs~)
  }
  if spec.get("image") is Some(image_json) {
    check_keys(spec, ["image"], at)
    guard image_json is Object(image) else {
      raise BatchError("\{at}.image must be an object")
    }
    check_keys(image, ["path", "content_type", "alt"], at + ".image")
    guard image.get("path") is Some(String(path)) else {
      raise BatchError("\{at}.image.path must be a string")
    }
    let content_type = match
      optional_string(image, "content_type", at + ".image") {
      Some(content_type) => content_type
      None => content_type_for_path(path, at)
    }
    let alt = optional_string(image, "alt", at + ".image")
    if !seen_paths.contains(path) {
      seen_paths.add(path)
      image_paths.push(path)
    }
    return ImageSpec(path~, content_type~, alt~)
  }
  check_keys(
    spec,
    [
      "text", "bold", "italic", "underline", "strike", "all_caps", "small_caps",
      "vertical", "font", "size", "highlight",
    ],
    at,
  )
  guard spec.get("text") is Some(String(text)) else {
    raise BatchError("\{at}.text must be a string")
  }
  let vertical = match optional_string(spec, "vertical", at) {
    Some("superscript") => @document.Superscript
    Some("subscript") => Subscript
    Some(other) =>
      raise BatchError(
        "\{at}.vertical must be 'superscript' or 'subscript' (got '\{other}')",
      )
    None => Baseline
  }
  let size = match spec.get("size") {
    Some(Number(size, ..)) => Some(size.to_int())
    None => None
    _ => raise BatchError("\{at}.size must be a number")
  }
  RunSpec(
    @document.run_properties(
      is_bold=boolean_flag(spec, "bold", at),
      is_italic=boolean_flag(spec, "italic", at),
      is_underline=boolean_flag(spec, "underline", at),
      is_strikethrough=boolean_flag(spec, "strike", at),
      is_all_caps=boolean_flag(spec, "all_caps", at),
      is_small_caps=boolean_flag(spec, "small_caps", at),
      vertical_alignment=vertical,
      font=optional_string(spec, "font", at),
      font_size=size,
      highlight=optional_string(spec, "highlight", at),
    ),
    text,
  )
}

///|
fn content_type_for_path(path : String, at : String) -> String raise BatchError {
  if path.has_suffix(".png") {
    "image/png"
  } else if path.has_suffix(".jpg") || path.has_suffix(".jpeg") {
    "image/jpeg"
  } else if path.has_suffix(".gif") {
    "image/gif"
  } else {
    raise BatchError(
      "\{at}.image: cannot infer the content type from '\{path}'; set content_type",
    )
  }
}

///|
fn parse_table(
  params : Map[String, Json],
  at : String,
  image_paths : Array[String],
  seen_paths : Set[String],
) -> OpSpec raise BatchError {
  check_keys(params, ["rows", "header_rows"], at + ".params")
  let header_rows = match params.get("header_rows") {
    Some(Number(count, ..)) => count.to_int()
    None => 0
    _ => raise BatchError("\{at}.params.header_rows must be a number")
  }
  guard params.get("rows") is Some(Array(rows_json)) else {
    raise BatchError("\{at}.params.rows must be an array of arrays")
  }
  let rows : Array[Array[CellSpec]] = []
  for row_index, row_json in rows_json {
    guard row_json is Array(cells_json) else {
      raise BatchError("\{at}.params.rows[\{row_index}] must be an array")
    }
    let cells : Array[CellSpec] = []
    for cell_index, cell_json in cells_json {
      let cell_where = "\{at}.params.rows[\{row_index}][\{cell_index}]"
      guard cell_json is Object(cell) else {
        raise BatchError("\{cell_where} must be an object")
      }
      check_keys(
        cell,
        ["text", "paragraphs", "col_span", "row_span"],
        cell_where,
      )
      let col_span = span_value(cell, "col_span", cell_where)
      let row_span = span_value(cell, "row_span", cell_where)
      let paragraphs : Array[ParagraphSpec] = []
      match (cell.get("text"), cell.get("paragraphs")) {
        (Some(String(text)), None) =>
          paragraphs.push({
            style: None,
            align: None,
            list: None,
            inlines: [RunSpec(@document.run_properties(), text)],
          })
        (Some(_), None) =>
          raise BatchError("\{cell_where}.text must be a string")
        (None, Some(Array(paragraphs_json))) =>
          for paragraph_index, paragraph_json in paragraphs_json {
            guard paragraph_json is Object(paragraph) else {
              raise BatchError(
                "\{cell_where}.paragraphs[\{paragraph_index}] must be an object",
              )
            }
            paragraphs.push(
              parse_paragraph(
                paragraph,
                "\{cell_where}.paragraphs[\{paragraph_index}]",
                image_paths,
                seen_paths,
              ),
            )
          }
        (None, Some(_)) =>
          raise BatchError("\{cell_where}.paragraphs must be an array")
        (Some(_), Some(_)) =>
          raise BatchError(
            "\{cell_where}: text and paragraphs are mutually exclusive",
          )
        (None, None) => ()
      }
      cells.push({ paragraphs, col_span, row_span })
    }
    rows.push(cells)
  }
  TableOp(rows~, header_rows~)
}

///|
fn span_value(
  cell : Map[String, Json],
  key : String,
  at : String,
) -> Int raise BatchError {
  match cell.get(key) {
    Some(Number(value, ..)) => value.to_int()
    None => 1
    _ => raise BatchError("\{at}.\{key} must be a number")
  }
}

///|
fn optional_string(
  object : Map[String, Json],
  key : String,
  at : String,
) -> String? raise BatchError {
  match object.get(key) {
    Some(String(value)) => Some(value)
    None => None
    _ => raise BatchError("\{at}.\{key} must be a string")
  }
}

///|
fn boolean_flag(
  object : Map[String, Json],
  key : String,
  at : String,
) -> Bool raise BatchError {
  match object.get(key) {
    Some(True) => true
    Some(False) => false
    None => false
    _ => raise BatchError("\{at}.\{key} must be a boolean")
  }
}

///|
/// Builds writer input from the parsed script and the loaded image bytes
/// (keyed by the exact paths `image_paths` returned).
pub fn BatchScript::build_body(
  self : BatchScript,
  images : Map[String, Bytes],
) -> Array[@document.DocumentElement] raise BatchError {
  let body : Array[@document.DocumentElement] = []
  for op in self.ops {
    match op {
      ParagraphOp(spec) => body.push(build_paragraph(spec, images))
      TableOp(rows~, header_rows~) => {
        let row_elements : Array[@document.DocumentElement] = []
        for row_index, cells in rows {
          let cell_elements : Array[@document.DocumentElement] = []
          for cell in cells {
            let cell_paragraphs : Array[@document.DocumentElement] = []
            for paragraph in cell.paragraphs {
              cell_paragraphs.push(build_paragraph(paragraph, images))
            }
            cell_elements.push(
              @document.table_cell(
                cell_paragraphs,
                col_span=cell.col_span,
                row_span=cell.row_span,
              ),
            )
          }
          row_elements.push(
            @document.table_row(
              cell_elements,
              is_header=row_index < header_rows,
            ),
          )
        }
        body.push(@document.table(row_elements))
      }
    }
  }
  body
}

///|
fn build_paragraph(
  spec : ParagraphSpec,
  images : Map[String, Bytes],
) -> @document.DocumentElement raise BatchError {
  let inlines : Array[@document.DocumentElement] = []
  for inline in spec.inlines {
    inlines.push(build_inline(inline, images))
  }
  @document.paragraph(
    inlines,
    properties=@document.paragraph_properties(
      style_id=spec.style,
      alignment=spec.align,
      numbering=spec.list,
    ),
  )
}

///|
fn build_inline(
  spec : InlineSpec,
  images : Map[String, Bytes],
) -> @document.DocumentElement raise BatchError {
  match spec {
    RunSpec(properties, text) =>
      @document.run([@document.text(text)], properties~)
    LinkSpec(href~, anchor~, target_frame~, runs~) => {
      let children : Array[@document.DocumentElement] = []
      for inner in runs {
        children.push(build_inline(inner, images))
      }
      @document.hyperlink(children, href~, anchor~, target_frame~)
    }
    ImageSpec(path~, content_type~, alt~) =>
      match images.get(path) {
        Some(data) =>
          @document.run([@document.image(content_type, data, alt_text=alt)])
        None => raise BatchError("image bytes for '\{path}' were not provided")
      }
  }
}
