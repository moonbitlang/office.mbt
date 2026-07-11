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
/// Bounds mirroring the writer's fail-closed guards, enforced here too so
/// violations are reported with the exact `ops[i]` address instead of a
/// whole-document writer error: Word's font-size cap (write_document.mbt)
/// and Word's 63-column table limit (write_tables.mbt). Row spans are
/// bounded by the table's remaining rows, exactly like the writer.
const MAX_FONT_SIZE_POINTS : Int = 1638

///|
const MAX_GRID_COLUMNS : Int = 63

///|
/// Paragraph styles the writer can serialize (write_document.mbt's
/// is_writable_style_id).
fn is_writable_style(style : String) -> Bool {
  style
  is ("Normal"
  | "Heading1"
  | "Heading2"
  | "Heading3"
  | "Heading4"
  | "Heading5"
  | "Heading6")
}

///|
/// The writer's alignment whitelist (write_document.mbt).
fn is_writable_alignment(align : String) -> Bool {
  align
  is ("left" | "center" | "right" | "both" | "start" | "end" | "distribute")
}

///|
/// The closed ST_HighlightColor enum the writer accepts.
fn is_highlight_color(value : String) -> Bool {
  value
  is ("black"
  | "blue"
  | "cyan"
  | "darkBlue"
  | "darkCyan"
  | "darkGray"
  | "darkGreen"
  | "darkMagenta"
  | "darkRed"
  | "darkYellow"
  | "green"
  | "lightGray"
  | "magenta"
  | "red"
  | "white"
  | "yellow")
}

///|
priv enum InlineSpec {
  RunSpec(@document.RunProperties, String)
  LinkSpec(
    href~ : String?,
    anchor~ : String?,
    target_frame~ : String?,
    runs~ : Array[InlineSpec]
  )
  ImageSpec(
    path~ : String,
    content_type~ : String,
    alt~ : String?,
    at~ : String
  )
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
/// The script address (`ops[i]...image`) that first references `path`,
/// so callers can attribute file-loading failures to the exact op.
pub fn BatchScript::image_reference(
  self : BatchScript,
  path : String,
) -> String? {
  fn scan_inlines(inlines : Array[InlineSpec]) -> String? {
    for inline in inlines {
      match inline {
        ImageSpec(path=candidate, at~, ..) if candidate == path =>
          return Some(at)
        LinkSpec(runs~, ..) =>
          if scan_inlines(runs) is Some(found) {
            return Some(found)
          }
        _ => ()
      }
    }
    None
  }
  fn scan_paragraphs(paragraphs : Array[ParagraphSpec]) -> String? {
    for paragraph in paragraphs {
      if scan_inlines(paragraph.inlines) is Some(found) {
        return Some(found)
      }
    }
    None
  }
  for op in self.ops {
    let found = match op {
      ParagraphOp(spec) => scan_inlines(spec.inlines)
      TableOp(rows~, ..) => {
        let mut in_table : String? = None
        for cells in rows {
          for cell in cells {
            if scan_paragraphs(cell.paragraphs) is Some(found) {
              in_table = Some(found)
              break
            }
          }
          if in_table is Some(_) {
            break
          }
        }
        in_table
      }
    }
    if found is Some(_) {
      return found
    }
  }
  None
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
          ParagraphOp(
            parse_paragraph(params, at + ".params", image_paths, seen_paths),
          ),
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
  // `at` is the address of the paragraph object itself ("ops[3].params",
  // "ops[3].params.rows[0][1].paragraphs[2]") so every message below
  // points at the exact JSON node.
  check_keys(params, ["text", "runs", "style", "align", "list"], at)
  let style = match optional_string(params, "style", at) {
    Some(style) => {
      if !is_writable_style(style) {
        raise BatchError(
          "\{at}.style '\{style}' is unknown (known styles: Normal, Heading1..Heading6)",
        )
      }
      Some(style)
    }
    None => None
  }
  let align = match optional_string(params, "align", at) {
    Some(align) => {
      if !is_writable_alignment(align) {
        raise BatchError(
          "\{at}.align '\{align}' is unknown (known: left, center, right, both, start, end, distribute)",
        )
      }
      Some(align)
    }
    None => None
  }
  let list = match params.get("list") {
    Some(Object(list_json)) => {
      check_keys(list_json, ["ordered", "level"], at + ".list")
      let ordered = match list_json.get("ordered") {
        Some(True) => true
        Some(False) => false
        Some(_) => raise BatchError("\{at}.list.ordered must be a boolean")
        None =>
          raise BatchError(
            "\{at}.list needs \"ordered\" (true = numbered, false = bulleted)",
          )
      }
      let level = int_value(
        list_json,
        "level",
        at + ".list",
        min=1,
        max=9,
        default=1,
      )
      Some(@document.numbering(ordered, level))
    }
    Some(_) => raise BatchError("\{at}.list must be an object")
    None => None
  }
  let inlines : Array[InlineSpec] = []
  match (params.get("text"), params.get("runs")) {
    (Some(_), Some(_)) =>
      raise BatchError("\{at}: text and runs are mutually exclusive")
    (Some(String(text)), None) => {
      check_text(text, at + ".text")
      inlines.push(RunSpec(@document.run_properties(), text))
    }
    (Some(_), None) => raise BatchError("\{at}.text must be a string")
    (None, Some(Array(runs))) => {
      if runs.length() == 0 {
        raise BatchError(
          "\{at}.runs must not be empty (use \"text\": \"\" for a blank paragraph)",
        )
      }
      for run_index, run_json in runs {
        inlines.push(
          parse_inline(
            run_json,
            "\{at}.runs[\{run_index}]",
            image_paths,
            seen_paths,
            allow_links=true,
          ),
        )
      }
    }
    (None, Some(_)) => raise BatchError("\{at}.runs must be an array")
    (None, None) =>
      raise BatchError(
        "\{at} needs text or runs (use \"text\": \"\" for a blank paragraph)",
      )
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
    let href = checked_attribute(
      optional_string(link, "href", at + ".link"),
      at + ".link.href",
    )
    let anchor = checked_attribute(
      optional_string(link, "anchor", at + ".link"),
      at + ".link.anchor",
    )
    let target_frame = checked_attribute(
      optional_string(link, "target_frame", at + ".link"),
      at + ".link.target_frame",
    )
    // The writer requires exactly one of href/anchor (it folds both into
    // the reader's href-fragment representation); enforce here so the
    // error carries the link's address.
    match (href, anchor) {
      (Some(_), Some(_)) =>
        raise BatchError(
          "\{at}.link: href and anchor are mutually exclusive (put a fragment in the href instead)",
        )
      (None, None) => raise BatchError("\{at}.link needs an href or an anchor")
      _ => ()
    }
    let runs : Array[InlineSpec] = []
    match (link.get("text"), link.get("runs")) {
      (Some(String(text)), None) => {
        check_text(text, at + ".link.text")
        runs.push(RunSpec(@document.run_properties(), text))
      }
      (Some(_), None) => raise BatchError("\{at}.link.text must be a string")
      (None, Some(Array(link_runs))) => {
        if link_runs.length() == 0 {
          raise BatchError("\{at}.link.runs must not be empty")
        }
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
    if !(content_type is ("image/png" | "image/jpeg" | "image/gif")) {
      raise BatchError(
        "\{at}.image.content_type '\{content_type}' is unsupported (image/png, image/jpeg, image/gif)",
      )
    }
    let alt = checked_attribute(
      optional_string(image, "alt", at + ".image"),
      at + ".image.alt",
    )
    match alt {
      Some(text) if text.trim(chars=" \t") == "" =>
        raise BatchError("\{at}.image.alt must not be blank")
      _ => ()
    }
    if !seen_paths.contains(path) {
      seen_paths.add(path)
      image_paths.push(path)
    }
    return ImageSpec(path~, content_type~, alt~, at=at + ".image")
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
  check_text(text, at + ".text")
  let vertical = match optional_string(spec, "vertical", at) {
    Some("superscript") => @document.Superscript
    Some("subscript") => Subscript
    Some(other) =>
      raise BatchError(
        "\{at}.vertical must be 'superscript' or 'subscript' (got '\{other}')",
      )
    None => Baseline
  }
  let size = if spec.get("size") is Some(_) {
    Some(
      int_value(spec, "size", at, min=1, max=MAX_FONT_SIZE_POINTS, default=0),
    )
  } else {
    None
  }
  let highlight = match optional_string(spec, "highlight", at) {
    Some(highlight) => {
      if highlight == "none" {
        raise BatchError(
          "\{at}.highlight: omit the key instead of 'none' (the reader normalizes 'none' to absent, so it cannot round-trip)",
        )
      }
      if !is_highlight_color(highlight) {
        raise BatchError(
          "\{at}.highlight '\{highlight}' is not an ST_HighlightColor name (yellow, green, cyan, red, ...)",
        )
      }
      Some(highlight)
    }
    None => None
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
      font=checked_attribute(optional_string(spec, "font", at), at + ".font"),
      font_size=size,
      highlight~,
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
  guard params.get("rows") is Some(Array(rows_json)) else {
    raise BatchError("\{at}.params.rows must be an array of arrays")
  }
  if rows_json.length() == 0 {
    raise BatchError("\{at}.params.rows must not be empty")
  }
  let header_rows = int_value(
    params,
    "header_rows",
    at + ".params",
    min=0,
    max=rows_json.length(),
    default=0,
  )
  let rows : Array[Array[CellSpec]] = []
  for row_index, row_json in rows_json {
    guard row_json is Array(cells_json) else {
      raise BatchError("\{at}.params.rows[\{row_index}] must be an array")
    }
    if cells_json.length() == 0 {
      raise BatchError(
        "\{at}.params.rows[\{row_index}] must have at least one cell",
      )
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
      let col_span = int_value(
        cell,
        "col_span",
        cell_where,
        min=1,
        max=MAX_GRID_COLUMNS,
        default=1,
      )
      // The writer requires a span to fit the remaining rows; mirroring
      // that bound here keeps the ops[i] address on the error.
      let row_span = int_value(
        cell,
        "row_span",
        cell_where,
        min=1,
        max=rows_json.length() - row_index,
        default=1,
      )
      let paragraphs : Array[ParagraphSpec] = []
      match (cell.get("text"), cell.get("paragraphs")) {
        (Some(String(text)), None) => {
          check_text(text, cell_where + ".text")
          paragraphs.push({
            style: None,
            align: None,
            list: None,
            inlines: [RunSpec(@document.run_properties(), text)],
          })
        }
        (Some(_), None) =>
          raise BatchError("\{cell_where}.text must be a string")
        (None, Some(Array(paragraphs_json))) => {
          if paragraphs_json.length() == 0 {
            raise BatchError(
              "\{cell_where}.paragraphs must not be empty (use \"text\": \"\" for a blank cell)",
            )
          }
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
        }
        (None, Some(_)) =>
          raise BatchError("\{cell_where}.paragraphs must be an array")
        (Some(_), Some(_)) =>
          raise BatchError(
            "\{cell_where}: text and paragraphs are mutually exclusive",
          )
        (None, None) =>
          raise BatchError(
            "\{cell_where} needs text or paragraphs (use \"text\": \"\" for a blank cell)",
          )
      }
      cells.push({ paragraphs, col_span, row_span })
    }
    rows.push(cells)
  }
  TableOp(rows~, header_rows~)
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
/// An exact integer in [min, max]. Fractional, non-finite, and
/// out-of-range numbers fail — `2.9` must never silently become `2`.
fn int_value(
  object : Map[String, Json],
  key : String,
  at : String,
  min~ : Int,
  max~ : Int,
  default~ : Int,
) -> Int raise BatchError {
  match object.get(key) {
    Some(Number(value, ..)) => {
      let as_int = value.to_int()
      if value != value || as_int.to_double() != value {
        raise BatchError("\{at}.\{key} must be an integer (got \{value})")
      }
      if as_int < min || as_int > max {
        raise BatchError("\{at}.\{key} must be between \{min} and \{max}")
      }
      as_int
    }
    None => default
    _ => raise BatchError("\{at}.\{key} must be a number")
  }
}

///|
/// Run/paragraph text: rejects raw line breaks and the other C0 controls
/// (tab excepted) that the writer fails closed on, so the error carries
/// the script address instead of a whole-document writer message.
fn check_text(text : String, at : String) -> Unit raise BatchError {
  for unit in text {
    let code = unit.to_int()
    if code < 0x20 && unit != '\t' {
      raise BatchError(
        "\{at} contains an unserializable control character (code \{code}); text cannot hold raw line breaks",
      )
    }
    // Iteration combines surrogate pairs, so a surrogate here is unpaired;
    // those and U+FFFE/U+FFFF are outside XML 1.0's character set.
    if (code >= 0xD800 && code <= 0xDFFF) || code == 0xFFFE || code == 0xFFFF {
      raise BatchError(
        "\{at} contains a character XML cannot represent (code \{code}: unpaired surrogate or U+FFFE/U+FFFF)",
      )
    }
  }
}

///|
/// Attribute-destined strings (href, anchor, target_frame, font, alt):
/// must be non-empty and free of ALL C0 controls (XML attribute-value
/// normalization mutates even tab/CR/LF).
fn checked_attribute(value : String?, at : String) -> String? raise BatchError {
  match value {
    Some(text) => {
      if text == "" {
        raise BatchError("\{at} must not be empty")
      }
      for unit in text {
        let code = unit.to_int()
        if code < 0x20 {
          raise BatchError(
            "\{at} contains a control character that cannot survive XML attribute normalization",
          )
        }
        if (code >= 0xD800 && code <= 0xDFFF) ||
          code == 0xFFFE ||
          code == 0xFFFF {
          raise BatchError(
            "\{at} contains a character XML cannot represent (code \{code}: unpaired surrogate or U+FFFE/U+FFFF)",
          )
        }
      }
      Some(text)
    }
    None => None
  }
}

///|
priv struct ScanFrame {
  is_object : Bool
  keys : Set[String]
  mut expecting_key : Bool
  // Last decoded key of this object (addresses child containers/values).
  mut pending_key : String
  // Element index for array frames (addresses child containers).
  mut index : Int
  // How this frame is addressed from its parent: a key, "[i]", or "" (root).
  entry : String
}

///|
/// Renders the innermost frame's JSON path plus an optional leaf key —
/// "ops[3].params", "ops[3].params.rows[0][1].col_span".
fn render_scan_path(frames : Array[ScanFrame], leaf : String?) -> String {
  let builder = StringBuilder::new()
  for frame in frames {
    if frame.entry == "" {
      continue
    }
    if !frame.entry.has_prefix("[") && !builder.is_empty() {
      builder.write_string(".")
    }
    builder.write_string(frame.entry)
  }
  match leaf {
    Some(key) => {
      if !builder.is_empty() {
        builder.write_string(".")
      }
      builder.write_string(key)
    }
    None => ()
  }
  if builder.is_empty() {
    "the script"
  } else {
    builder.to_string()
  }
}

///|
/// Lexes the JSON string starting AFTER its opening quote, returning the
/// DECODED value and the index just past the closing quote (None when
/// unterminated — @json.parse's error to report). Escapes are decoded so
/// escape-equivalent key spellings compare equal; escaped surrogate pairs
/// recombine to one astral char exactly like raw pairs; unpaired
/// surrogates fold to U+FFFD under BOTH spellings so equivalence is
/// preserved for duplicate detection.
fn lex_json_string(units : ArrayView[UInt16], start : Int) -> (String, Int?) {
  let builder = StringBuilder::new()
  let length = units.length()
  let mut cursor = start
  fn hex4(at : Int) -> Int? {
    if at + 4 > length {
      return None
    }
    let mut value = 0
    for offset in 0..<4 {
      let c = units[at + offset].to_int()
      let digit = if c >= '0'.to_int() && c <= '9'.to_int() {
        c - '0'.to_int()
      } else if c >= 'a'.to_int() && c <= 'f'.to_int() {
        c - 'a'.to_int() + 10
      } else if c >= 'A'.to_int() && c <= 'F'.to_int() {
        c - 'A'.to_int() + 10
      } else {
        return None
      }
      value = value * 16 + digit
    }
    Some(value)
  }
  fn write_code(code : Int) -> Unit {
    match code.to_char() {
      Some(ch) => builder.write_char(ch)
      None => builder.write_char('\u{FFFD}')
    }
  }
  while cursor < length {
    let unit = units[cursor].to_int()
    if unit == '"'.to_int() {
      return (builder.to_string(), Some(cursor + 1))
    }
    if unit == '\\'.to_int() {
      if cursor + 1 >= length {
        return ("", None)
      }
      let escape = units[cursor + 1].to_int()
      if escape == 'u'.to_int() {
        match hex4(cursor + 2) {
          Some(code) => {
            if code >= 0xD800 &&
              code <= 0xDBFF &&
              cursor + 7 < length &&
              units[cursor + 6].to_int() == '\\'.to_int() &&
              units[cursor + 7].to_int() == 'u'.to_int() {
              match hex4(cursor + 8) {
                Some(low) if low >= 0xDC00 && low <= 0xDFFF => {
                  write_code(0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00))
                  cursor += 12
                  continue
                }
                _ => ()
              }
            }
            write_code(code)
            cursor += 6
          }
          None => {
            // Malformed \u escape: @json.parse reports it; keep scanning.
            builder.write_char('u')
            cursor += 2
          }
        }
      } else {
        let decoded = if escape == 'n'.to_int() {
          '\n'
        } else if escape == 't'.to_int() {
          '\t'
        } else if escape == 'r'.to_int() {
          '\r'
        } else if escape == 'b'.to_int() {
          '\u{08}'
        } else if escape == 'f'.to_int() {
          '\u{0C}'
        } else if escape == '"'.to_int() {
          '"'
        } else if escape == '\\'.to_int() {
          '\\'
        } else if escape == '/'.to_int() {
          '/'
        } else {
          // Invalid escape: @json.parse reports it; keep scanning.
          '?'
        }
        builder.write_char(decoded)
        cursor += 2
      }
      continue
    }
    // Raw text: recombine surrogate pairs (astral chars are two UTF-16
    // units); fold unpaired surrogates.
    if unit >= 0xD800 && unit <= 0xDBFF && cursor + 1 < length {
      let low = units[cursor + 1].to_int()
      if low >= 0xDC00 && low <= 0xDFFF {
        write_code(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00))
        cursor += 2
        continue
      }
    }
    write_code(unit)
    cursor += 1
  }
  ("", None)
}

///|
/// Strict lexical validation of the raw script text, run BEFORE
/// `@json.parse` (the CLI always does; programmatic `parse_batch(Json)`
/// callers holding original text should too). Two rules the parsed `Json`
/// tree cannot express:
///
/// - **Duplicate keys** are refused, addressed with the object's path.
///   `@json.parse` is last-wins per ECMA-404, which would let
///   `{"op": "table", "op": "paragraph"}` silently drop half an op. Keys
///   compare DECODED, so `"op"` duplicates `"op"`.
/// - **Numbers must be plain decimal integers.** Every numeric field in
///   docx.batch/1 is an integer, and a `Json` Double cannot distinguish
///   `1` from `0.999999999999999999999999` — fractions and exponents are
///   rejected at the lexeme, before precision is lost.
///
/// Structure is tracked per `{`/`[` frame; malformed JSON is left for
/// `@json.parse` to diagnose.
pub fn check_script_text(text : String) -> Unit raise BatchError {
  let units = text.code_units()
  let length = units.length()
  let frames : Array[ScanFrame] = []
  let mut index = 0
  fn frame_entry() -> String {
    match frames.last() {
      Some(parent) =>
        if parent.is_object {
          parent.pending_key
        } else {
          "[\{parent.index}]"
        }
      None => ""
    }
  }
  while index < length {
    let unit = units[index].to_int()
    if unit == '{'.to_int() || unit == '['.to_int() {
      frames.push({
        is_object: unit == '{'.to_int(),
        keys: Set([]),
        expecting_key: unit == '{'.to_int(),
        pending_key: "",
        index: 0,
        entry: frame_entry(),
      })
      index += 1
    } else if unit == '}'.to_int() || unit == ']'.to_int() {
      let _ = frames.pop()
      index += 1
    } else if unit == ','.to_int() {
      match frames.last() {
        Some(frame) =>
          if frame.is_object {
            frame.expecting_key = true
          } else {
            frame.index += 1
          }
        None => ()
      }
      index += 1
    } else if unit == ':'.to_int() {
      match frames.last() {
        Some(frame) if frame.is_object => frame.expecting_key = false
        _ => ()
      }
      index += 1
    } else if unit == '"'.to_int() {
      let (value, next) = lex_json_string(units, index + 1)
      match next {
        Some(next_index) => {
          match frames.last() {
            Some(frame) if frame.is_object && frame.expecting_key => {
              if frame.keys.contains(value) {
                raise BatchError(
                  "\{render_scan_path(frames, None)} repeats the key \"\{value}\" (strict scripts must not rely on last-wins parsing)",
                )
              }
              frame.keys.add(value)
              frame.pending_key = value
            }
            _ => ()
          }
          index = next_index
        }
        None => return
      }
    } else if unit == '-'.to_int() ||
      (unit >= '0'.to_int() && unit <= '9'.to_int()) {
      let start = index
      let mut cursor = index
      let mut plain_integer = true
      while cursor < length {
        let c = units[cursor].to_int()
        if c == '.'.to_int() || c == 'e'.to_int() || c == 'E'.to_int() {
          plain_integer = false
          cursor += 1
        } else if c == '-'.to_int() ||
          c == '+'.to_int() ||
          (c >= '0'.to_int() && c <= '9'.to_int()) {
          cursor += 1
        } else {
          break
        }
      }
      if !plain_integer {
        let lexeme_builder = StringBuilder::new()
        for at in start..<cursor {
          match units[at].to_int().to_char() {
            Some(ch) => lexeme_builder.write_char(ch)
            None => ()
          }
        }
        let leaf = match frames.last() {
          Some(frame) if frame.is_object => Some(frame.pending_key)
          _ => None
        }
        raise BatchError(
          "\{render_scan_path(frames, leaf)} must be a plain decimal integer — docx.batch/1 has no fractional fields (got '\{lexeme_builder.to_string()}')",
        )
      }
      index = cursor
    } else {
      index += 1
    }
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
    ImageSpec(path~, content_type~, alt~, at~) =>
      match images.get(path) {
        Some(data) =>
          @document.run([@document.image(content_type, data, alt_text=alt)])
        None =>
          raise BatchError(
            "\{at}.path: image bytes for '\{path}' were not provided",
          )
      }
  }
}
