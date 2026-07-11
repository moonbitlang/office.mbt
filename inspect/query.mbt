// Builds the `xlsx.query/1` payload: the cells on a sheet that match a
// content selector, in the same per-cell shape as `xlsx.cells/1` (so an agent
// can filter — "every formula", "every value over 100" — instead of reading a
// whole range and scanning it itself). Reuses `cell_json`/`raw_json` and the
// style-dedup logic from cells.mbt.

///|
/// A malformed `query` selector. The message names what was wrong; the CLI
/// adds its `error: ` prefix.
pub suberror QueryError {
  QueryError(String)
} derive(@debug.Debug)

///|
pub impl Show for QueryError with fn output(self, logger) {
  match self {
    QueryError(message) => logger.write_string(message)
  }
}

///|
/// The raw-value kind a `type=` predicate matches.
priv enum CellKind {
  KFormula
  KNumber
  KString
  KBool
  KError
}

///|
/// A numeric comparison operator for a `value` predicate.
priv enum NumOp {
  Gt
  Ge
  Lt
  Le
  Eq
  Ne
}

///|
/// One selector predicate. A selector is an AND of these.
priv enum Predicate {
  HasType(CellKind)
  ValueCmp(NumOp, Double)
  HasFormula
  FormulaContains(String)
  TextEquals(String)
  TextContains(String)
}

///|
/// Parses a selector: the literal `cell` optionally followed by one or more
/// `[predicate]` groups, ANDed. `cell` alone matches every populated cell.
fn parse_selector(selector : String) -> Array[Predicate] raise QueryError {
  let text = selector.trim().to_owned()
  if text != "cell" && !text.has_prefix("cell[") {
    raise QueryError(
      "selector must be 'cell' optionally followed by [predicate] groups, e.g. cell[type=formula]",
    )
  }
  let preds = []
  let mut rest = text[4:].to_owned() // after "cell"
  while rest != "" {
    if !rest.has_prefix("[") {
      raise QueryError("expected '[' in selector near '\{rest}'")
    }
    let close = match rest.find("]") {
      Some(index) => index
      None => raise QueryError("selector is missing a closing ']'")
    }
    preds.push(parse_predicate(rest[1:close].to_owned()))
    rest = rest[close + 1:].to_owned()
  }
  preds
}

///|
/// Parses one predicate (the text between `[` and `]`).
fn parse_predicate(raw : String) -> Predicate raise QueryError {
  let body = raw.trim().to_owned()
  if body.has_prefix("type=") {
    match body[5:].to_owned() {
      "formula" => HasType(KFormula)
      "number" => HasType(KNumber)
      "string" => HasType(KString)
      "bool" => HasType(KBool)
      "error" => HasType(KError)
      other =>
        raise QueryError(
          "unknown type '\{other}' (expected one of: formula, number, string, bool, error)",
        )
    }
  } else if body.has_prefix("value") {
    parse_value_predicate(body[5:].to_owned())
  } else if body.has_prefix("formula~=") {
    FormulaContains(require_nonempty("formula~=", body[9:].to_owned()))
  } else if body == "formula" {
    HasFormula
  } else if body.has_prefix("text~=") {
    TextContains(require_nonempty("text~=", body[6:].to_owned()))
  } else if body.has_prefix("text=") {
    TextEquals(require_nonempty("text=", body[5:].to_owned()))
  } else {
    raise QueryError(
      "unknown predicate '\{body}' (expected type=, value<op>, formula, formula~=, text=, or text~=)",
    )
  }
}

///|
/// A predicate's text argument must be non-empty: an empty `text=`/`text~=`/
/// `formula~=` would match every (or no) cell by accident. (It also can't
/// contain `]`, which closes the predicate — see the docs.)
fn require_nonempty(label : String, value : String) -> String raise QueryError {
  if value == "" {
    raise QueryError("\{label} needs a non-empty value")
  }
  value
}

///|
/// Parses the operator + number of a `value` predicate (the text after
/// `value`). Two-character operators are checked before their one-character
/// prefixes so `>=` is not read as `>`.
fn parse_value_predicate(rest : String) -> Predicate raise QueryError {
  let (op, number_text) = if rest.has_prefix(">=") {
    (Ge, rest[2:].to_owned())
  } else if rest.has_prefix("<=") {
    (Le, rest[2:].to_owned())
  } else if rest.has_prefix("!=") {
    (Ne, rest[2:].to_owned())
  } else if rest.has_prefix(">") {
    (Gt, rest[1:].to_owned())
  } else if rest.has_prefix("<") {
    (Lt, rest[1:].to_owned())
  } else if rest.has_prefix("=") {
    (Eq, rest[1:].to_owned())
  } else {
    raise QueryError(
      "a value predicate needs an operator: value> value>= value< value<= value= value!=",
    )
  }
  let number = @string.parse_double(number_text.trim().to_owned()) catch {
    _ =>
      raise QueryError("value predicate expects a number, got '\{number_text}'")
  }
  // `parse_double` accepts `NaN`/`Infinity`; those are not useful bounds (a
  // `!=NaN` would match every numeric cell), so require a finite number.
  if number != number || number.is_inf() {
    raise QueryError(
      "value predicate expects a finite number, got '\{number_text}'",
    )
  }
  ValueCmp(op, number)
}

///|
fn num_matches(op : NumOp, value : Double, bound : Double) -> Bool {
  match op {
    Gt => value > bound
    Ge => value >= bound
    Lt => value < bound
    Le => value <= bound
    Eq => value == bound
    Ne => value != bound
  }
}

///|
/// Whether one predicate holds for a cell.
fn predicate_matches(
  workbook : @xlsx.Workbook,
  sheet : String,
  cell : String,
  pred : Predicate,
) -> Bool raise @xlsx.XlsxError {
  match pred {
    HasType(kind) =>
      match kind {
        KFormula => workbook.get_cell_formula(sheet, cell) is Some(_)
        KNumber => workbook.get_cell_value_raw(sheet, cell) is Some(Numeric(_))
        KString =>
          match workbook.get_cell_value_raw(sheet, cell) {
            Some(String(text)) => text != ""
            _ => false
          }
        KBool => workbook.get_cell_value_raw(sheet, cell) is Some(Bool(_))
        KError => workbook.get_cell_value_raw(sheet, cell) is Some(Error(_))
      }
    ValueCmp(op, bound) =>
      match workbook.get_cell_value_raw(sheet, cell) {
        Some(Numeric(value)) => num_matches(op, value, bound)
        _ => false
      }
    HasFormula => workbook.get_cell_formula(sheet, cell) is Some(_)
    FormulaContains(needle) =>
      match workbook.get_cell_formula(sheet, cell) {
        Some(formula) => formula.contains(needle)
        None => false
      }
    // Exclude the synthetic `String("")` blank (a bare styled cell / uncached
    // formula), consistent with `type=string` — a text predicate must match
    // real stored text, not a cell `cell_json` would report as blank.
    TextEquals(want) =>
      match workbook.get_cell_value_raw(sheet, cell) {
        Some(String(text)) => text != "" && text == want
        _ => false
      }
    TextContains(needle) =>
      match workbook.get_cell_value_raw(sheet, cell) {
        Some(String(text)) => text != "" && text.contains(needle)
        _ => false
      }
  }
}

///|
/// Whether every predicate holds (an empty selector matches any populated
/// cell — `cell_json` still filters out fully-absent cells).
fn cell_matches(
  workbook : @xlsx.Workbook,
  sheet : String,
  cell : String,
  preds : Array[Predicate],
) -> Bool raise @xlsx.XlsxError {
  for pred in preds {
    if !predicate_matches(workbook, sheet, cell, pred) {
      return false
    }
  }
  true
}

///|
/// The rectangle `query` scans: the caller's `--range` when given, else
/// `worksheet`'s live used extent. Returns `None` for an empty sheet (no
/// scan). `worksheet` is resolved by the caller so the missing-sheet error is
/// the same on both paths.
fn query_scan_range(
  worksheet : @xlsx.Worksheet,
  range : String,
) -> CellRange? raise {
  if range != "" {
    return Some(parse_range(range))
  }
  // Live extent (authoritative, like `outline`'s used_range), bounded by the
  // same cap so a sparse sheet with far-flung data can't force a huge scan.
  let max_col = worksheet.max_col()
  let max_row = worksheet.max_row()
  if max_col < 1 || max_row < 1 {
    return None
  }
  let extent : CellRange = {
    col_lo: 1,
    row_lo: 1,
    col_hi: max_col,
    row_hi: max_row,
  }
  if extent.cell_count() > MAX_RANGE_CELLS {
    raise QueryError(
      "used range covers \{extent.cell_count()} cells; max is \{MAX_RANGE_CELLS} — pass --range to narrow the scan",
    )
  }
  Some(extent)
}

///|
/// Builds the `xlsx.query/1` JSON payload: the cells on `sheet` matching
/// `selector`, scanned over `range` (a `--range` argument) or, when `range`
/// is empty, the sheet's used extent. Each match uses the same per-cell shape
/// as `xlsx.cells/1`, with the shared deduplicated `styles` map. Raises
/// `QueryError` for a bad selector, an unknown sheet, or an oversized scan,
/// and `RangeError` for a malformed `--range`.
pub fn query(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet : String,
  range~ : String,
  selector : String,
) -> Json raise {
  let preds = parse_selector(selector)
  // Resolve the sheet once, up front, so a missing sheet reports the same
  // clear error whether or not a `--range` was given.
  let worksheet = match workbook.sheet(sheet) {
    Some(worksheet) => worksheet
    None => raise QueryError("sheet '\{sheet}' not found")
  }
  let matches = []
  let style_order : Array[Int] = []
  let style_seen : Map[Int, Unit] = Map([])
  let scanned = match query_scan_range(worksheet, range) {
    Some(scan) => {
      for row in scan.row_lo..<=scan.row_hi {
        for col in scan.col_lo..<=scan.col_hi {
          let cell = @xlsx.coordinates_to_cell_name(col, row)
          if cell_matches(workbook, sheet, cell, preds) {
            match
              cell_json(
                workbook,
                sheet,
                cell,
                row~,
                col~,
                style_order,
                style_seen,
              ) {
              Some(entry) => matches.push(entry)
              None => ()
            }
          }
        }
      }
      scan.range_ref()
    }
    None => ""
  }
  let styles : Map[String, Json] = Map([])
  for style_id in style_order {
    styles["\{style_id}"] = style_to_json(workbook.get_style(style_id))
  }
  Json::object({
    "schema": Json::string(SCHEMA_QUERY),
    "file": Json::string(file),
    "sheet": Json::string(sheet),
    "range": Json::string(scanned),
    "selector": Json::string(selector),
    "match_count": Json::number(matches.length().to_double()),
    "matches": Json::array(matches),
    "styles": Json::object(styles),
  })
}
