// Parsing and application of `xlsx.batch/1` op scripts (see
// docs/agent-json-schemas.md). Parsing is strict — an unknown op, an
// unknown param key, or a wrong param type fails naming the 0-based op
// index — and application delegates to the same library calls as the
// CLI subcommand twins, sharing their helpers (build_style,
// chart_type_of, qualify_range). Every cell/range/column reference is
// validated through the strict bounded parser at parse time — one
// deliberate divergence from the `style` subcommand, which passes a bare
// (colon-free) cell name to the workbook untouched. Errors are bare
// messages; the CLI adds its `error: ` prefix.

///|
/// Scripts are capped well above any real workload; the cap turns a
/// runaway generator into a clean error instead of an OOM.
pub const MAX_BATCH_OPS : Int = 10_000

///|
/// Aggregate cap on cells touched by `style` range expansions across one
/// script: the per-range parser caps each range at 100k cells, but 10k
/// such ops would still be a billion mutations — an OOM, not a workload.
pub const MAX_TOTAL_STYLE_CELLS : Int64 = 1_000_000

///|
/// A batch script or op that failed validation or application. The
/// message names the 0-based op index where one is involved.
pub suberror BatchError {
  BatchError(String)
} derive(@debug.Debug)

///|
pub impl Show for BatchError with fn output(self, logger) {
  match self {
    BatchError(message) => logger.write_string(message)
  }
}

///|
/// A `set` op's value: JSON types are honored (no string
/// re-classification; agents use batch precisely to escape that
/// ambiguity). Private: only ever held inside an `OpKind`.
priv enum BatchValue {
  Text(String)
  Number(Double)
  Flag(Bool)
  Clear
}

///|
/// The internal representation of one parsed batch operation. **Private on
/// purpose** — see `BatchOp`. Constructor fields mirror the CLI twin's
/// arguments; op names in scripts are the subcommand names.
priv enum OpKind {
  OpSet(sheet~ : String, cell~ : String, value~ : BatchValue)
  OpFormula(sheet~ : String, cell~ : String, formula~ : String)
  OpStyle(
    sheet~ : String,
    range~ : String,
    bold~ : Bool,
    italic~ : Bool,
    number_format~ : String,
    fill~ : String,
    font_color~ : String,
    align~ : String
  )
  OpMerge(sheet~ : String, range~ : String)
  OpWidth(sheet~ : String, column~ : String, width~ : Double)
  OpFreeze(sheet~ : String, cell~ : String)
  OpFilter(sheet~ : String, range~ : String)
  OpAddSheet(name~ : String)
  OpChart(
    sheet~ : String,
    anchor~ : String,
    chart_type~ : String,
    categories~ : String,
    values~ : String,
    series_name~ : String,
    title~ : String
  )
  OpTable(
    sheet~ : String,
    range~ : String,
    name~ : String,
    style~ : String,
    // Tri-state: the engine defaults for a shown header row and row
    // stripes are `true`, so "unset" must stay distinct from `false`.
    header_row~ : Bool?,
    row_stripes~ : Bool?,
    first_column~ : Bool,
    last_column~ : Bool,
    column_stripes~ : Bool
  )
  // `validation_type`, `operator`, and `error_style` hold the raw script
  // strings; they are mapped to engine enums at apply time (like `chart`'s
  // `type`), so an unknown value fails at apply rather than parse — which is
  // also what keeps the catalog's `full_sample` (every param present) a valid
  // parse.
  OpValidate(
    sheet~ : String,
    range~ : String,
    validation_type~ : String,
    operator~ : String,
    formula1~ : String,
    formula2~ : String,
    values~ : Array[String],
    source~ : String,
    // Tri-state: Excel's friendlier default is to allow blanks, so an
    // omitted `allow_blank` means `true`, distinct from an explicit `false`.
    allow_blank~ : Bool?,
    input_title~ : String,
    input_message~ : String,
    error_title~ : String,
    error_message~ : String,
    error_style~ : String
  )
  // A conditional-formatting rule. `cf_type` is the raw script `type`
  // (validated at apply, like `chart`/`validate`). One op adds one rule to
  // the range; the engine assigns priorities so repeated ops stack.
  OpCf(
    sheet~ : String,
    range~ : String,
    cf_type~ : String,
    criteria~ : String,
    value~ : String,
    min_value~ : String,
    max_value~ : String,
    formula~ : String,
    fill~ : String,
    font_color~ : String,
    // Tri-state so an explicit `false` is distinguishable from "omitted" and
    // can be rejected for a type that does not take the flag (a plain
    // `optional_bool` would collapse the two).
    bold~ : Bool?,
    italic~ : Bool?,
    min_type~ : String,
    mid_type~ : String,
    max_type~ : String,
    mid_value~ : String,
    min_color~ : String,
    mid_color~ : String,
    max_color~ : String,
    bar_color~ : String,
    // The x14 data-bar options: any of these makes the engine emit the
    // extended (x14) data bar instead of the classic one.
    bar_solid~ : Bool?,
    bar_direction~ : String,
    bar_border_color~ : String,
    icon_style~ : String,
    reverse_icons~ : Bool?,
    stop_if_true~ : Bool?
  )
}

///|
/// A parsed batch operation, **opaque by design**. Callers get these from
/// `parse_script` and hand them to `apply_op`; they cannot construct or
/// pattern-match them. This is deliberate: the op vocabulary grows over
/// time (new `xlsx.batch/1` ops), and hiding the representation keeps
/// adding a variant or a field a source-compatible change instead of a
/// breaking one for every downstream `match`. Discover the current op set
/// programmatically via `capabilities()`.
///
/// A plain (package-private) single-field struct: it appears in the public
/// `parse_script`/`apply_op`/`name` signatures, so it exports as an
/// abstract type — external code holds it but cannot construct or match it.
struct BatchOp(OpKind)

///|
/// The op's script name (also its CLI subcommand name), for error text.
pub fn BatchOp::name(self : BatchOp) -> String {
  match self.0 {
    OpSet(..) => "set"
    OpFormula(..) => "formula"
    OpStyle(..) => "style"
    OpMerge(..) => "merge"
    OpWidth(..) => "width"
    OpFreeze(..) => "freeze"
    OpFilter(..) => "filter"
    OpAddSheet(..) => "add-sheet"
    OpChart(..) => "chart"
    OpTable(..) => "table"
    OpValidate(..) => "validate"
    OpCf(..) => "cf"
  }
}

///|
fn op_error(index : Int, op : String, message : String) -> BatchError {
  BatchError("op \{index} (\{op}): \{message}")
}

///|
/// Parses a full `xlsx.batch/1` script document into ops. Strict: the
/// envelope must be an object holding exactly `schema` and `ops`, the
/// schema string must match, and every op must validate. Zero ops is a
/// valid no-op.
pub fn parse_script(document : Json) -> Array[BatchOp] raise BatchError {
  let root = match document {
    Object(map) => map
    _ => raise BatchError("batch script must be a JSON object")
  }
  for key, _ in root {
    if key != "schema" && key != "ops" {
      raise BatchError("unknown top-level key '\{key}'")
    }
  }
  match root.get("schema") {
    Some(String(schema)) =>
      if schema != @inspect.SCHEMA_BATCH {
        raise BatchError(
          "unsupported schema '\{schema}' (expected \{@inspect.SCHEMA_BATCH})",
        )
      }
    Some(_) => raise BatchError("\"schema\" must be a string")
    None =>
      raise BatchError("missing \"schema\" (expected \{@inspect.SCHEMA_BATCH})")
  }
  let items = match root.get("ops") {
    Some(Array(items)) => items
    Some(_) => raise BatchError("\"ops\" must be an array")
    None => raise BatchError("missing \"ops\" array")
  }
  if items.length() > MAX_BATCH_OPS {
    raise BatchError(
      "script has \{items.length()} ops; max is \{MAX_BATCH_OPS}",
    )
  }
  let ops = []
  let style_cells : Ref[Int64] = Ref(0)
  for index, item in items {
    ops.push(parse_op(index, item, style_cells))
  }
  ops
}

///|
fn parse_op(
  index : Int,
  item : Json,
  style_cells : Ref[Int64],
) -> BatchOp raise BatchError {
  let entry = match item {
    Object(map) => map
    _ => raise BatchError("op \{index}: must be a JSON object")
  }
  let name = match entry.get("op") {
    Some(String(name)) => name
    Some(_) => raise BatchError("op \{index}: \"op\" must be a string")
    None => raise BatchError("op \{index}: missing \"op\" name")
  }
  for key, _ in entry {
    if key != "op" && key != "params" {
      raise op_error(index, name, "unknown key '\{key}'")
    }
  }
  let params = match entry.get("params") {
    Some(Object(map)) => map
    Some(_) => raise op_error(index, name, "\"params\" must be an object")
    None => raise op_error(index, name, "missing \"params\" object")
  }
  // Gate on the catalog before dispatch: an op is parseable iff it is
  // advertised by `capabilities`, so a dispatch arm without a catalog
  // entry is unreachable and the two cannot drift.
  if !is_known_op(name) {
    raise op_error(
      index,
      name,
      "unknown op (expected one of: \{accepted_op_names().join(", ")})",
    )
  }
  // The reader is told the op's advertised param names; reading a param
  // outside that set aborts (see `take`). So the params a parser arm reads
  // are exactly the catalog's — param-level drift is impossible too.
  let reader = ParamReader::{
    index,
    op: name,
    params,
    used: Map([]),
    declared: op_param_names(name),
  }
  let op = match name {
    "set" =>
      OpSet(
        sheet=reader.string("sheet"),
        cell=reader.cell("cell"),
        value=reader.value("value"),
      )
    "formula" =>
      OpFormula(
        sheet=reader.string("sheet"),
        cell=reader.cell("cell"),
        formula=reader.string("formula"),
      )
    "style" => {
      let (range, cells) = reader.range("range")
      style_cells.val = style_cells.val + cells
      if style_cells.val > MAX_TOTAL_STYLE_CELLS {
        raise op_error(
          index,
          name,
          "style ranges expand past \{MAX_TOTAL_STYLE_CELLS} total cells",
        )
      }
      OpStyle(
        sheet=reader.string("sheet"),
        range~,
        bold=reader.optional_bool("bold"),
        italic=reader.optional_bool("italic"),
        number_format=reader.optional_string("number_format"),
        fill=reader.optional_string("fill"),
        font_color=reader.optional_string("font_color"),
        align=reader.optional_string("align"),
      )
    }
    "merge" =>
      OpMerge(sheet=reader.string("sheet"), range=reader.colon_range("range"))
    "width" =>
      OpWidth(
        sheet=reader.string("sheet"),
        column=reader.column("column"),
        width=reader.number("width"),
      )
    "freeze" => OpFreeze(sheet=reader.string("sheet"), cell=reader.cell("cell"))
    "filter" =>
      OpFilter(sheet=reader.string("sheet"), range=reader.colon_range("range"))
    "add-sheet" => OpAddSheet(name=reader.string("name"))
    "chart" =>
      OpChart(
        sheet=reader.string("sheet"),
        anchor=reader.cell("anchor"),
        chart_type=reader.optional_string_default("type", "col"),
        categories=reader.series_range("categories"),
        values=reader.series_range("values"),
        series_name=reader.optional_string("name"),
        title=reader.optional_string("title"),
      )
    "table" =>
      OpTable(
        sheet=reader.string("sheet"),
        range=reader.table_range("range"),
        name=reader.optional_string("name"),
        style=reader.optional_string("style"),
        header_row=reader.tristate_bool("header_row"),
        row_stripes=reader.tristate_bool("row_stripes"),
        first_column=reader.optional_bool("first_column"),
        last_column=reader.optional_bool("last_column"),
        column_stripes=reader.optional_bool("column_stripes"),
      )
    "validate" =>
      OpValidate(
        sheet=reader.string("sheet"),
        range=reader.sqref("range"),
        validation_type=reader.string("type"),
        operator=reader.optional_string("operator"),
        formula1=reader.optional_string("formula1"),
        formula2=reader.optional_string("formula2"),
        values=reader.string_array("values"),
        source=reader.optional_string("source"),
        allow_blank=reader.tristate_bool("allow_blank"),
        input_title=reader.optional_string("input_title"),
        input_message=reader.optional_string("input_message"),
        error_title=reader.optional_string("error_title"),
        error_message=reader.optional_string("error_message"),
        error_style=reader.optional_string("error_style"),
      )
    "cf" =>
      OpCf(
        sheet=reader.string("sheet"),
        range=reader.sqref("range"),
        cf_type=reader.string("type"),
        criteria=reader.optional_string("criteria"),
        value=reader.optional_string("value"),
        min_value=reader.optional_string("min_value"),
        max_value=reader.optional_string("max_value"),
        formula=reader.optional_string("formula"),
        fill=reader.optional_string("fill"),
        font_color=reader.optional_string("font_color"),
        bold=reader.tristate_bool("bold"),
        italic=reader.tristate_bool("italic"),
        min_type=reader.optional_string("min_type"),
        mid_type=reader.optional_string("mid_type"),
        max_type=reader.optional_string("max_type"),
        mid_value=reader.optional_string("mid_value"),
        min_color=reader.optional_string("min_color"),
        mid_color=reader.optional_string("mid_color"),
        max_color=reader.optional_string("max_color"),
        bar_color=reader.optional_string("bar_color"),
        bar_solid=reader.tristate_bool("bar_solid"),
        bar_direction=reader.optional_string("bar_direction"),
        bar_border_color=reader.optional_string("bar_border_color"),
        icon_style=reader.optional_string("icon_style"),
        reverse_icons=reader.tristate_bool("reverse_icons"),
        stop_if_true=reader.tristate_bool("stop_if_true"),
      )
    _ =>
      raise op_error(
        index,
        name,
        "unknown op (expected one of: \{accepted_op_names().join(", ")})",
      )
  }
  reader.finish()
  BatchOp(op)
}

///|
/// Reads typed params for one op, tracking which keys were consumed so
/// `finish` can reject unknown keys with the op's index and name.
priv struct ParamReader {
  index : Int
  op : String
  params : Map[String, Json]
  used : Map[String, Unit]
  /// The op's advertised param names (from the capability catalog).
  declared : Array[String]
}

///|
fn ParamReader::take(self : ParamReader, key : String) -> Json? {
  // A parser arm may only read params the catalog advertises. Reading an
  // undeclared param is a programming error (the catalog and parser have
  // drifted), not a user error — abort so every parse of that op fails
  // loudly rather than silently accepting an undocumented param.
  if !self.declared.contains(key) {
    abort("batch: op '\{self.op}' reads undeclared param '\{key}'")
  }
  self.used[key] = ()
  self.params.get(key)
}

///|
fn ParamReader::string(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  match self.take(key) {
    Some(String(value)) => value
    Some(_) => raise op_error(self.index, self.op, "'\{key}' must be a string")
    None => raise op_error(self.index, self.op, "missing param '\{key}'")
  }
}

///|
fn ParamReader::optional_string(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  self.optional_string_default(key, "")
}

///|
fn ParamReader::optional_string_default(
  self : ParamReader,
  key : String,
  default : String,
) -> String raise BatchError {
  match self.take(key) {
    Some(String(value)) => value
    Some(_) => raise op_error(self.index, self.op, "'\{key}' must be a string")
    None => default
  }
}

///|
fn ParamReader::optional_bool(
  self : ParamReader,
  key : String,
) -> Bool raise BatchError {
  match self.take(key) {
    Some(True) => true
    Some(False) => false
    Some(_) =>
      raise op_error(self.index, self.op, "'\{key}' must be true or false")
    None => false
  }
}

///|
/// A bool that stays absent when the param is omitted, for engine options
/// whose default is not `false` (a shown header row, row stripes): `None`
/// keeps the engine default, `Some(v)` overrides it. Distinct from
/// `optional_bool`, which collapses "omitted" into `false`.
fn ParamReader::tristate_bool(
  self : ParamReader,
  key : String,
) -> Bool? raise BatchError {
  match self.take(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    Some(_) =>
      raise op_error(self.index, self.op, "'\{key}' must be true or false")
    None => None
  }
}

///|
fn ParamReader::number(
  self : ParamReader,
  key : String,
) -> Double raise BatchError {
  match self.take(key) {
    Some(Number(value, repr~)) => self.normalize_number(key, value, repr)
    Some(_) => raise op_error(self.index, self.op, "'\{key}' must be a number")
    None => raise op_error(self.index, self.op, "missing param '\{key}'")
  }
}

///|
/// Numbers follow standard JSON semantics: a literal parses to the
/// nearest IEEE-754 double, spelling-independent. Core JSON stores an
/// integer literal beyond the JS-safe range as an infinity sentinel plus
/// the source text in `repr`, so the real value is recovered by
/// re-parsing `repr`. What is rejected is the corruption class —
/// literals whose VALUE is not finite (1e309 overflows to infinity;
/// storing it would write "Inf" into the sheet).
fn ParamReader::normalize_number(
  self : ParamReader,
  key : String,
  value : Double,
  repr : String?,
) -> Double raise BatchError {
  let resolved = match repr {
    Some(text) => @string.parse_double(text) catch { _ => value }
    None => value
  }
  if resolved != resolved || resolved.is_inf() {
    raise op_error(self.index, self.op, "'\{key}' must be a finite JSON number")
  }
  resolved
}

///|
fn ParamReader::value(
  self : ParamReader,
  key : String,
) -> BatchValue raise BatchError {
  match self.take(key) {
    Some(String(text)) => Text(text)
    Some(Number(value, repr~)) =>
      Number(self.normalize_number(key, value, repr))
    Some(True) => Flag(true)
    Some(False) => Flag(false)
    Some(Null) => Clear
    Some(_) =>
      raise op_error(
        self.index,
        self.op,
        "'\{key}' must be a string, number, bool, or null",
      )
    None => raise op_error(self.index, self.op, "missing param '\{key}'")
  }
}

///|
/// A param that must be a single in-grid cell reference (`B2`, `$B$2`).
fn ParamReader::cell(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let text = self.string(key)
  let range = @inspect.parse_range(text) catch {
    _ =>
      raise op_error(
        self.index,
        self.op,
        "'\{key}' is not a valid cell reference: '\{text}'",
      )
  }
  // The downstream cell APIs take a bare cell name: `A1:A1` covers one
  // cell but is still range syntax, so reject on the spelling too.
  if text.contains(":") || range.cell_count() != 1 {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' must be a single cell, not a range: '\{text}'",
    )
  }
  text
}

///|
/// A param that must be an `A1:B2`-style range WITH a colon (merge and
/// filter reject bare cells at apply time; fail at parse time instead).
fn ParamReader::colon_range(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let (text, _) = self.range(key)
  if !text.contains(":") {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' must be an A1:B2-style range: '\{text}'",
    )
  }
  text
}

///|
/// A range param for a table: an `A1:B2` colon range validated for in-grid
/// syntax but WITHOUT the 100k-cell expansion cap that `range`/`colon_range`
/// apply. A table never enumerates its cells (the engine derives columns
/// from the header row only), so an ordinary large table range must be
/// accepted rather than rejected as an expansion. Also rejects a single-row
/// range on the last grid row, which the engine expands downward by one row
/// and would push off the grid — caught here with a clear message instead of
/// failing deep in apply.
fn ParamReader::table_range(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let text = self.string(key)
  let range = @inspect.parse_range_unbounded(text) catch {
    _ =>
      raise op_error(
        self.index,
        self.op,
        "'\{key}' is not a valid cell or range reference: '\{text}'",
      )
  }
  if !text.contains(":") {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' must be an A1:B2-style range: '\{text}'",
    )
  }
  // 1_048_576 is the last grid row; a single-row range there has no room for
  // the data row the engine appends.
  if range.row_lo == range.row_hi && range.row_hi >= 1_048_576 {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' is a single-row range on the last grid row, leaving no room for a data row: '\{text}'",
    )
  }
  text
}

///|
/// A single-region reference a data validation applies to (`A1` or `A1:B2`),
/// validated for in-grid syntax but WITHOUT the 100k-cell cap — a validation
/// commonly covers a whole column (`A2:A1048576`) and never enumerates its
/// cells. (Space-separated multi-region sqrefs are not accepted here; add one
/// validation op per region.)
fn ParamReader::sqref(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let text = self.string(key)
  ignore(
    @inspect.parse_range_unbounded(text) catch {
      _ =>
        raise op_error(
          self.index,
          self.op,
          "'\{key}' is not a valid cell or range reference: '\{text}'",
        )
    },
  )
  text
}

///|
/// An optional array-of-strings param (an empty array when omitted). Every
/// element must be a JSON string.
fn ParamReader::string_array(
  self : ParamReader,
  key : String,
) -> Array[String] raise BatchError {
  match self.take(key) {
    Some(Array(items)) => {
      let out = []
      for item in items {
        match item {
          String(text) => out.push(text)
          _ =>
            raise op_error(
              self.index,
              self.op,
              "'\{key}' must be an array of strings",
            )
        }
      }
      out
    }
    Some(_) =>
      raise op_error(
        self.index,
        self.op,
        "'\{key}' must be an array of strings",
      )
    None => []
  }
}

///|
/// A param that must be an in-grid cell or `A1:B2`-style range; returns
/// the text plus the parsed cell count (for the aggregate work budget).
fn ParamReader::range(
  self : ParamReader,
  key : String,
) -> (String, Int64) raise BatchError {
  let text = self.string(key)
  let range = @inspect.parse_range(text) catch {
    RangeTooLarge(_) as err => raise op_error(self.index, self.op, "\{err}")
    _ =>
      raise op_error(
        self.index,
        self.op,
        "'\{key}' is not a valid cell or range reference: '\{text}'",
      )
  }
  (text, range.cell_count())
}

///|
/// A param that must be a column (`A`) or an ascending column range
/// (`A:C`), letters only — exactly what the width APIs accept at apply
/// time (no `$` anchors, no digits, no descending ranges).
fn ParamReader::column(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let text = self.string(key)
  match text.find(":") {
    None => ignore(self.column_number(key, text, text))
    Some(index) => {
      let lo = self.column_number(key, text[:index].to_owned(), text)
      let hi = self.column_number(key, text[index + 1:].to_owned(), text)
      if lo > hi {
        raise op_error(
          self.index,
          self.op,
          "'\{key}' is not a valid column or column range: '\{text}'",
        )
      }
    }
  }
  text
}

///|
fn ParamReader::column_number(
  self : ParamReader,
  key : String,
  letters : String,
  full : String,
) -> Int raise BatchError {
  if letters.length() < 1 || letters.length() > 3 {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' is not a valid column or column range: '\{full}'",
    )
  }
  let mut col = 0
  for i in 0..<letters.length() {
    let c = letters[i].to_int()
    let upper = if c >= 'a'.to_int() && c <= 'z'.to_int() { c - 32 } else { c }
    if upper < 'A'.to_int() || upper > 'Z'.to_int() {
      raise op_error(
        self.index,
        self.op,
        "'\{key}' is not a valid column or column range: '\{full}'",
      )
    }
    col = col * 26 + (upper - 'A'.to_int() + 1)
  }
  if col > 16384 {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' is not a valid column or column range: '\{full}'",
    )
  }
  col
}

///|
/// A chart series range: an optional `Sheet!` qualification followed by a
/// cell range. Only the range part is validated; the sheet name is the
/// workbook's concern.
fn ParamReader::series_range(
  self : ParamReader,
  key : String,
) -> String raise BatchError {
  let text = self.string(key)
  let range_part = match text.rev_find("!") {
    Some(index) => {
      // The optional qualification before the last '!' must itself be a
      // plausible sheet ref: non-empty and free of further '!' — else
      // "!A1:A2" or "Data!A1!B1:B2" would flow into the chart formula.
      let sheet_part = text[:index].to_owned()
      if sheet_part == "" || sheet_part.contains("!") {
        raise op_error(
          self.index,
          self.op,
          "'\{key}' is not a valid series range: '\{text}'",
        )
      }
      text[index + 1:].to_owned()
    }
    None => text
  }
  // Validate exactly what will be emitted: `parse_range` accepts correctly
  // placed `$` anchors, so misplaced ones (`A$B1`) must fail here rather
  // than reach the chart XML.
  ignore(
    @inspect.parse_range(range_part) catch {
      _ =>
        raise op_error(
          self.index,
          self.op,
          "'\{key}' is not a valid series range: '\{text}'",
        )
    },
  )
  text
}

///|
fn ParamReader::finish(self : ParamReader) -> Unit raise BatchError {
  for key, _ in self.params {
    if !self.used.contains(key) {
      raise op_error(self.index, self.op, "unknown param '\{key}'")
    }
  }
}

///|
/// Applies one op to the in-memory workbook, delegating to the exact
/// same library calls as the op's CLI twin. Never touches the
/// filesystem; the caller owns open/write and all-or-nothing semantics.
pub fn apply_op(workbook : @xlsx.Workbook, op : BatchOp) -> Unit raise {
  match op.0 {
    OpSet(sheet~, cell~, value~) =>
      match value {
        Text(text) => workbook.set_cell(sheet, cell, text)
        Number(number) =>
          // An integral JSON number becomes an integer cell, like the
          // CLI's classifier; 42 must not become "42.0".
          if number == number.floor() &&
            number >= -2147483648.0 &&
            number <= 2147483647.0 {
            workbook.set_cell_int(sheet, cell, number.to_int())
          } else {
            workbook.set_cell_float(sheet, cell, number)
          }
        Flag(flag) => workbook.set_cell_bool(sheet, cell, flag)
        Clear => workbook.set_cell(sheet, cell, "")
      }
    OpFormula(sheet~, cell~, formula~) => {
      // Accept the formula with or without a leading '=' (stored
      // without it), like the `formula` subcommand.
      let stored = if formula.has_prefix("=") {
        formula[1:].to_owned()
      } else {
        formula
      }
      workbook.set_cell_formula(sheet, cell, stored)
    }
    OpStyle(
      sheet~,
      range~,
      bold~,
      italic~,
      number_format~,
      fill~,
      font_color~,
      align~
    ) => {
      let style = build_style(
        bold~,
        italic~,
        number_format~,
        fill~,
        font_color~,
        align~,
      )
      let style_id = workbook.new_style(style)
      for cell in @inspect.parse_range(range).cells() {
        workbook.set_cell_style(sheet, cell, style_id)
      }
    }
    OpMerge(sheet~, range~) => workbook.merge_cells(sheet, range)
    OpWidth(sheet~, column~, width~) =>
      if column.contains(":") {
        workbook.set_col_width_range(sheet, column, width)
      } else {
        workbook.set_col_width(
          sheet,
          @xlsx.column_name_to_number(column),
          width,
        )
      }
    OpFreeze(sheet~, cell~) => {
      // Freeze every row above and every column left of `cell`, like
      // the `freeze` subcommand.
      let (col, row) = @xlsx.cell_name_to_coordinates(cell)
      workbook.set_panes(
        sheet,
        @xlsx.Panes::with_values(
          freeze=true,
          x_split=col - 1,
          y_split=row - 1,
          top_left_cell=cell,
        ),
      )
    }
    OpFilter(sheet~, range~) => workbook.auto_filter(sheet, range, [])
    OpAddSheet(name~) => ignore(workbook.add_sheet(name))
    OpChart(
      sheet~,
      anchor~,
      chart_type~,
      categories~,
      values~,
      series_name~,
      title~
    ) => {
      if categories == "" || values == "" {
        raise BatchError("chart requires non-empty 'categories' and 'values'")
      }
      let chart = @xlsx.ChartOptions::new(chart_type_of(chart_type))
      if title != "" {
        chart.title = title
      }
      chart.series.push(
        @xlsx.ChartSeries::new(
          qualify_range(sheet, categories),
          qualify_range(sheet, values),
          name=series_name,
        ),
      )
      workbook.add_chart_with_options(sheet, anchor, chart)
    }
    OpTable(
      sheet~,
      range~,
      name~,
      style~,
      header_row~,
      row_stripes~,
      first_column~,
      last_column~,
      column_stripes~
    ) => {
      // Column names come from the header row of `range` (the engine
      // auto-names blanks/duplicates), so the script sets headers first,
      // then this op. An empty `name` lets the engine assign `Table<n>`;
      // an empty `style` keeps its default. `header_row`/`row_stripes`
      // pass through as `Bool?` so an omitted flag keeps the engine default.
      let options = @xlsx.TableOptions::new(range)
      if name != "" {
        options.set_name(name)
      }
      if style != "" {
        options.set_style_name(style)
      }
      options.set_show_header_row(header_row)
      options.set_show_row_stripes(row_stripes)
      options.set_show_first_column(first_column)
      options.set_show_last_column(last_column)
      options.set_show_column_stripes(column_stripes)
      ignore(workbook.add_table(sheet, options))
    }
    OpValidate(
      sheet~,
      range~,
      validation_type~,
      operator~,
      formula1~,
      formula2~,
      values~,
      source~,
      allow_blank~,
      input_title~,
      input_message~,
      error_title~,
      error_message~,
      error_style~
    ) => {
      // Validate every enum-valued string up front, independent of whether
      // the type uses it, so an unknown value is always rejected rather than
      // silently ignored: `error_style` here, and `operator` in each branch
      // (rejected outright where the type does not take one).
      let error_style_enum = validation_error_style_of(error_style)
      // Omitted allow_blank means "allow" (Excel's friendlier default).
      let allow = match allow_blank {
        Some(flag) => flag
        None => true
      }
      let dv = @xlsx.DataValidation::new(allow)
      dv.set_sqref(range)
      match validation_type {
        // A dropdown: inline `values` win over a `source` range; one of the
        // two is required. The comparison params do not apply.
        "list" => {
          reject_unused_validate_params(
            validation_type,
            operator~,
            formula1~,
            formula2~,
          )
          if !values.is_empty() {
            // The engine joins the values with commas and quotes the result,
            // so a value carrying a comma would split into two options and a
            // leading '=' would be read as a formula — reject both and steer
            // the caller to `source`.
            check_inline_list_values(values)
            dv.set_drop_list(values)
          } else if source != "" {
            dv.set_sqref_drop_list(source)
          } else {
            raise BatchError(
              "validate: type 'list' requires 'values' or 'source'",
            )
          }
        }
        // A boolean formula. Excel ignores the operator for custom rules, so
        // pass a fixed placeholder to satisfy the engine setter; the operator
        // and formula2 params do not apply.
        "custom" => {
          reject_unused_validate_params(
            validation_type,
            operator~,
            formula1="",
            formula2~,
          )
          reject_list_only_validate_params(validation_type, values~, source~)
          if formula1 == "" {
            raise BatchError("validate: type 'custom' requires 'formula1'")
          }
          dv.set_range(TextValue(formula1), TextValue(""), Custom, Between)
        }
        // A comparison against one or two bounds.
        "whole" | "decimal" | "date" | "time" | "textLength" => {
          reject_list_only_validate_params(validation_type, values~, source~)
          if operator == "" {
            raise BatchError(
              "validate: type '\{validation_type}' requires 'operator'",
            )
          }
          if formula1 == "" {
            raise BatchError(
              "validate: type '\{validation_type}' requires 'formula1'",
            )
          }
          let op = validation_operator_of(operator)
          // The two-bound operators need an upper bound; the one-bound
          // operators must not carry a stray one.
          let two_bound = operator == "between" || operator == "notBetween"
          if two_bound && formula2 == "" {
            raise BatchError(
              "validate: operator '\{operator}' requires 'formula2'",
            )
          }
          if !two_bound && formula2 != "" {
            raise BatchError(
              "validate: operator '\{operator}' does not take 'formula2'",
            )
          }
          dv.set_range(
            TextValue(formula1),
            TextValue(formula2),
            validation_type_of(validation_type),
            op,
          )
        }
        other =>
          raise BatchError(
            "validate: unknown type '\{other}' (expected one of: list, whole, decimal, date, time, textLength, custom)",
          )
      }
      // An error alert or an input prompt is added only when the script
      // provides text for it.
      if error_message != "" || error_title != "" {
        dv.set_error(error_style_enum, error_title, error_message)
      }
      if input_message != "" || input_title != "" {
        dv.set_input(input_title, input_message)
      }
      workbook.add_data_validation(sheet, dv)
    }
    OpCf(
      sheet~,
      range~,
      cf_type~,
      criteria~,
      value~,
      min_value~,
      max_value~,
      formula~,
      fill~,
      font_color~,
      bold~,
      italic~,
      min_type~,
      mid_type~,
      max_type~,
      mid_value~,
      min_color~,
      mid_color~,
      max_color~,
      bar_color~,
      bar_solid~,
      bar_direction~,
      bar_border_color~,
      icon_style~,
      reverse_icons~,
      stop_if_true~
    ) => {
      if !is_supported_cf_type(cf_type) {
        raise BatchError(
          "cf: unknown type '\{cf_type}' (expected one of: cell, formula, 2_color_scale, 3_color_scale, data_bar, icon_set)",
        )
      }
      // Reject any mode-specific param the chosen type does not use.
      let present : Array[(String, Bool)] = [
        ("criteria", criteria != ""),
        ("value", value != ""),
        ("min_value", min_value != ""),
        ("max_value", max_value != ""),
        ("formula", formula != ""),
        ("fill", fill != ""),
        ("font_color", font_color != ""),
        // A tri-state flag counts as supplied whether it was true or an
        // explicit false, so an unused flag is rejected either way.
        ("bold", bold is Some(_)),
        ("italic", italic is Some(_)),
        ("min_type", min_type != ""),
        ("mid_type", mid_type != ""),
        ("max_type", max_type != ""),
        ("mid_value", mid_value != ""),
        ("min_color", min_color != ""),
        ("mid_color", mid_color != ""),
        ("max_color", max_color != ""),
        ("bar_color", bar_color != ""),
        ("bar_solid", bar_solid is Some(_)),
        ("bar_direction", bar_direction != ""),
        ("bar_border_color", bar_border_color != ""),
        ("icon_style", icon_style != ""),
        ("reverse_icons", reverse_icons is Some(_)),
        ("stop_if_true", stop_if_true is Some(_)),
      ]
      let allowed = cf_allowed_params(cf_type)
      for entry in present {
        let (pname, is_set) = entry
        if is_set && !allowed.contains(pname) {
          raise BatchError("cf: type '\{cf_type}' does not take '\{pname}'")
        }
      }
      let bold_on = bold is Some(true)
      let italic_on = italic is Some(true)
      let opt = @xlsx.ConditionalFormatOptions::new(cf_type)
      if stop_if_true is Some(true) {
        opt.set_stop_if_true(true)
      }
      // The rule types (cell/formula) paint a dxf highlight, which needs at
      // least one attribute to be meaningful.
      let style_set = fill != "" || font_color != "" || bold_on || italic_on
      match cf_type {
        "cell" => {
          if criteria == "" {
            raise BatchError("cf: type 'cell' requires 'criteria'")
          }
          check_cf_cell_criteria(criteria)
          if !style_set {
            raise BatchError(
              "cf: type 'cell' requires a highlight (fill, font_color, bold, or italic)",
            )
          }
          opt.set_criteria(criteria)
          let crit = criteria.to_lower()
          let is_between = crit == "between" ||
            crit == "not between" ||
            crit == "notbetween"
          if is_between {
            if min_value == "" || max_value == "" {
              raise BatchError(
                "cf: a '\{criteria}' rule requires 'min_value' and 'max_value'",
              )
            }
            if value != "" {
              raise BatchError(
                "cf: a '\{criteria}' rule takes 'min_value'/'max_value', not 'value'",
              )
            }
            opt.set_min_value(min_value)
            opt.set_max_value(max_value)
          } else {
            if value == "" {
              raise BatchError("cf: type 'cell' requires 'value'")
            }
            if min_value != "" || max_value != "" {
              raise BatchError(
                "cf: only a between/notBetween rule takes 'min_value'/'max_value'",
              )
            }
            opt.set_value(value)
          }
        }
        "formula" => {
          if formula == "" {
            raise BatchError("cf: type 'formula' requires 'formula'")
          }
          if !style_set {
            raise BatchError(
              "cf: type 'formula' requires a highlight (fill, font_color, bold, or italic)",
            )
          }
          // The engine reads the expression from `criteria`.
          opt.set_criteria(formula)
        }
        "2_color_scale" => {
          if min_color == "" || max_color == "" {
            raise BatchError(
              "cf: type '2_color_scale' requires 'min_color' and 'max_color'",
            )
          }
          check_cf_color("min_color", min_color)
          check_cf_color("max_color", max_color)
          check_cfvo_type("min_type", min_type)
          check_cfvo_type("max_type", max_type)
          if min_type != "" {
            opt.set_min_type(min_type)
          }
          if min_value != "" {
            opt.set_min_value(min_value)
          }
          opt.set_min_color(min_color)
          if max_type != "" {
            opt.set_max_type(max_type)
          }
          if max_value != "" {
            opt.set_max_value(max_value)
          }
          opt.set_max_color(max_color)
        }
        "3_color_scale" => {
          if min_color == "" || mid_color == "" || max_color == "" {
            raise BatchError(
              "cf: type '3_color_scale' requires 'min_color', 'mid_color', and 'max_color'",
            )
          }
          check_cf_color("min_color", min_color)
          check_cf_color("mid_color", mid_color)
          check_cf_color("max_color", max_color)
          check_cfvo_type("min_type", min_type)
          check_cfvo_type("mid_type", mid_type)
          check_cfvo_type("max_type", max_type)
          if min_type != "" {
            opt.set_min_type(min_type)
          }
          if min_value != "" {
            opt.set_min_value(min_value)
          }
          opt.set_min_color(min_color)
          if mid_type != "" {
            opt.set_mid_type(mid_type)
          }
          if mid_value != "" {
            opt.set_mid_value(mid_value)
          }
          opt.set_mid_color(mid_color)
          if max_type != "" {
            opt.set_max_type(max_type)
          }
          if max_value != "" {
            opt.set_max_value(max_value)
          }
          opt.set_max_color(max_color)
        }
        "data_bar" => {
          check_cfvo_type("min_type", min_type)
          check_cfvo_type("max_type", max_type)
          if bar_color != "" {
            check_cf_color("bar_color", bar_color)
            opt.set_bar_color(bar_color)
          }
          if min_type != "" {
            opt.set_min_type(min_type)
          }
          if min_value != "" {
            opt.set_min_value(min_value)
          }
          if max_type != "" {
            opt.set_max_type(max_type)
          }
          if max_value != "" {
            opt.set_max_value(max_value)
          }
          // x14 extended-bar options. Any of these makes the engine emit the
          // extended (x14) data bar (solid fill / gradient axis / border /
          // direction) instead of the classic one.
          if bar_solid is Some(true) {
            opt.set_bar_solid(true)
          }
          if bar_direction != "" {
            if bar_direction != "leftToRight" && bar_direction != "rightToLeft" {
              raise BatchError(
                "cf: bar_direction '\{bar_direction}' is not valid (expected leftToRight or rightToLeft)",
              )
            }
            opt.set_bar_direction(bar_direction)
          }
          if bar_border_color != "" {
            check_cf_color("bar_border_color", bar_border_color)
            opt.set_bar_border_color(bar_border_color)
          }
        }
        "icon_set" => {
          if icon_style == "" {
            raise BatchError("cf: type 'icon_set' requires 'icon_style'")
          }
          check_cf_icon_style(icon_style)
          opt.set_icon_style(icon_style)
          if reverse_icons is Some(true) {
            opt.set_reverse_icons(true)
          }
        }
        _ => ()
      }
      if style_set {
        // fill != "" implies style_set, so validating here covers every
        // supplied highlight color.
        if fill != "" {
          check_cf_color("fill", fill)
        }
        if font_color != "" {
          check_cf_color("font_color", font_color)
        }
        let style = build_style(
          bold=bold_on,
          italic=italic_on,
          number_format="",
          fill~,
          font_color~,
          align="",
        )
        opt.set_format(Some(workbook.new_conditional_style(style)))
      }
      workbook.set_conditional_format(sheet, range, [opt])
    }
  }
}
