// Parsing and application of `xlsx.batch/1` op scripts (see
// docs/agent-json-schemas.md). Parsing is strict — an unknown op, an
// unknown param key, or a wrong param type fails naming the 0-based op
// index — and application delegates to the same library calls as the
// CLI subcommand twins, so a batch op and its CLI twin cannot drift
// apart. Errors are bare messages; the CLI adds its `error: ` prefix.

///|
/// Scripts are capped well above any real workload; the cap turns a
/// runaway generator into a clean error instead of an OOM.
pub const MAX_BATCH_OPS : Int = 10_000

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
/// ambiguity).
pub enum BatchValue {
  Text(String)
  Number(Double)
  Flag(Bool)
  Clear
} derive(@debug.Debug)

///|
/// One parsed batch operation. Constructor fields mirror the CLI twin's
/// arguments; op names in scripts are the subcommand names.
pub enum BatchOp {
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
} derive(@debug.Debug)

///|
/// The op's script name (also its CLI subcommand name), for error text.
pub fn BatchOp::name(self : BatchOp) -> String {
  match self {
    OpSet(..) => "set"
    OpFormula(..) => "formula"
    OpStyle(..) => "style"
    OpMerge(..) => "merge"
    OpWidth(..) => "width"
    OpFreeze(..) => "freeze"
    OpFilter(..) => "filter"
    OpAddSheet(..) => "add-sheet"
    OpChart(..) => "chart"
  }
}

///|
/// The op vocabulary, for the unknown-op error; adding an op means
/// extending this list, `parse_op`, and `apply_op` together.
let batch_op_names : Array[String] = [
  "set", "formula", "style", "merge", "width", "freeze", "filter", "add-sheet", "chart",
]

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
  for index, item in items {
    ops.push(parse_op(index, item))
  }
  ops
}

///|
fn parse_op(index : Int, item : Json) -> BatchOp raise BatchError {
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
  let reader = ParamReader::{ index, op: name, params, used: {} }
  let op = match name {
    "set" =>
      OpSet(
        sheet=reader.string("sheet"),
        cell=reader.string("cell"),
        value=reader.value("value"),
      )
    "formula" =>
      OpFormula(
        sheet=reader.string("sheet"),
        cell=reader.string("cell"),
        formula=reader.string("formula"),
      )
    "style" =>
      OpStyle(
        sheet=reader.string("sheet"),
        range=reader.string("range"),
        bold=reader.optional_bool("bold"),
        italic=reader.optional_bool("italic"),
        number_format=reader.optional_string("number_format"),
        fill=reader.optional_string("fill"),
        font_color=reader.optional_string("font_color"),
        align=reader.optional_string("align"),
      )
    "merge" =>
      OpMerge(sheet=reader.string("sheet"), range=reader.string("range"))
    "width" =>
      OpWidth(
        sheet=reader.string("sheet"),
        column=reader.string("column"),
        width=reader.number("width"),
      )
    "freeze" =>
      OpFreeze(sheet=reader.string("sheet"), cell=reader.string("cell"))
    "filter" =>
      OpFilter(sheet=reader.string("sheet"), range=reader.string("range"))
    "add-sheet" => OpAddSheet(name=reader.string("name"))
    "chart" =>
      OpChart(
        sheet=reader.string("sheet"),
        anchor=reader.string("anchor"),
        chart_type=reader.optional_string_default("type", "col"),
        categories=reader.string("categories"),
        values=reader.string("values"),
        series_name=reader.optional_string("name"),
        title=reader.optional_string("title"),
      )
    _ =>
      raise op_error(
        index,
        name,
        "unknown op (expected one of: \{batch_op_names.join(", ")})",
      )
  }
  reader.finish()
  op
}

///|
/// Reads typed params for one op, tracking which keys were consumed so
/// `finish` can reject unknown keys with the op's index and name.
priv struct ParamReader {
  index : Int
  op : String
  params : Map[String, Json]
  used : Map[String, Unit]
}

///|
fn ParamReader::take(self : ParamReader, key : String) -> Json? {
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
fn ParamReader::number(
  self : ParamReader,
  key : String,
) -> Double raise BatchError {
  match self.take(key) {
    Some(Number(value, repr~)) => {
      self.check_representable(key, value, repr)
      value
    }
    Some(_) => raise op_error(self.index, self.op, "'\{key}' must be a number")
    None => raise op_error(self.index, self.op, "missing param '\{key}'")
  }
}

///|
/// Core JSON keeps the source text (`repr`) when a literal cannot be
/// represented exactly as a Double (e.g. 1e309 becomes infinity,
/// 9007199254740993 rounds); accepting the sentinel would silently
/// corrupt the workbook, so such numbers are rejected outright.
fn ParamReader::check_representable(
  self : ParamReader,
  key : String,
  value : Double,
  repr : String?,
) -> Unit raise BatchError {
  if repr is Some(_) || value != value || value.is_inf() {
    raise op_error(
      self.index,
      self.op,
      "'\{key}' is not exactly representable as a number",
    )
  }
}

///|
fn ParamReader::value(
  self : ParamReader,
  key : String,
) -> BatchValue raise BatchError {
  match self.take(key) {
    Some(String(text)) => Text(text)
    Some(Number(value, repr~)) => {
      self.check_representable(key, value, repr)
      Number(value)
    }
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
  match op {
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
  }
}
