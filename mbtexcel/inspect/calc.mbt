// Builds the `xlsx.calc/1` payload: a cell's typed *computed* value (the
// result of evaluating its formula), as `{type, value}` — the same shape as
// the `raw` field of `xlsx.cells/1`, but for the computed value rather than
// the stored one. Fills the gap where `get --json` shows a formula with no
// cached value: `calc --json` evaluates it and returns the typed result.

///|
/// Builds the `xlsx.calc/1` JSON payload for `reference` on `sheet`:
/// `{schema, file, sheet, ref, result?}` where `result` is `{type, value}`
/// (type ∈ `number`/`string`/`bool`/`error`). `result` is omitted when the
/// formula computes to an empty result — absence means blank, matching the
/// other read payloads. A genuine formula error is a present result with
/// `type: "error"`; only a missing sheet or malformed reference raises.
pub fn calc(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet : String,
  reference : String,
) -> Json raise {
  let out : Map[String, Json] = {
    "schema": Json::string(SCHEMA_CALC),
    "file": Json::string(file),
    "sheet": Json::string(sheet),
    "ref": Json::string(reference),
  }
  match workbook.calc_cell_typed(sheet, reference) {
    Some(value) => out["result"] = raw_json(value)
    None => ()
  }
  Json::object(out)
}
