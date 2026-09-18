// Builds the `xlsx.lint/1` payload: formula problems found by *recomputing*
// each formula cell. Today it reports every formula that evaluates to an
// error (`#DIV/0!`, `#REF!`, `#NAME?`, …) — the author→verify half of the
// agent loop, and something `query`'s stored-value scan cannot find for a
// formula with no cached value. The `kind` discriminator leaves room for more
// checks (e.g. cached-vs-recomputed disagreement) additively.

///|
/// Builds the `xlsx.lint/1` JSON payload: `{schema, file, finding_count,
/// findings}` where each finding is `{kind, sheet, ref, code, formula?}`.
/// Scans every sheet's non-empty formula cells (or only `sheet` when
/// non-empty), recomputes each, and reports those that evaluate to an error,
/// in workbook-sheet order then stored-cell order.
///
/// Shared-/array-formula *slave* cells are not visited (their text lives on
/// the master and the engine does not expand slaves), so an error that would
/// only manifest in a slave's translated formula is not reported. A missing
/// named sheet, or a structural problem while evaluating, raises
/// `@xlsx.XlsxError` (aborting the whole lint) rather than being reported as a
/// finding.
pub fn lint(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet? : String = "",
) -> Json raise {
  // Resolve `--sheet` to its CANONICAL name: the engine's sheet lookup is
  // case-insensitive, so `--sheet data` must lint the sheet named `Data`
  // rather than pass the existence check and then be skipped by a
  // case-sensitive filter. An unknown name surfaces the canonical
  // `SheetNotFound` via a pure read probe (inspect cannot construct the
  // engine's read-only error directly).
  let target : String? = if sheet == "" {
    None
  } else {
    ignore(workbook.get_cell_formula(sheet, "A1"))
    match workbook.sheet(sheet) {
      Some(worksheet) => Some(worksheet.name())
      None => None
    }
  }
  let findings = []
  for worksheet in workbook.sheets() {
    let name = worksheet.name()
    match target {
      Some(only) => if name != only { continue }
      None => ()
    }
    for reference in worksheet.formula_refs() {
      match workbook.calc_cell_typed(name, reference) {
        Some(Error(code)) => {
          let finding : Map[String, Json] = {
            "kind": Json::string("formula_error"),
            "sheet": Json::string(name),
            "ref": Json::string(reference),
            "code": Json::string(code),
          }
          match workbook.get_cell_formula(name, reference) {
            Some(formula) => finding["formula"] = Json::string(formula)
            None => ()
          }
          findings.push(Json::object(finding))
        }
        _ => ()
      }
    }
  }
  Json::object({
    "schema": Json::string(SCHEMA_LINT),
    "file": Json::string(file),
    "finding_count": Json::number(findings.length().to_double()),
    "findings": Json::array(findings),
  })
}
