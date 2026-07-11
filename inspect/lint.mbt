// Builds the `xlsx.lint/1` payload: formula problems found by *recomputing*
// each formula cell. Today it reports every formula that evaluates to an
// error (`#DIV/0!`, `#REF!`, `#NAME?`, …) — the author→verify half of the
// agent loop, and something `query`'s stored-value scan cannot find for a
// formula with no cached value. The `kind` discriminator leaves room for more
// checks (e.g. cached-vs-recomputed disagreement) additively.

///|
/// Builds the `xlsx.lint/1` JSON payload: `{schema, file, finding_count,
/// findings}` where each finding is `{kind, sheet, ref, code, formula?}`.
/// Scans every sheet's formula cells (or only `sheet` when non-empty),
/// recomputes each, and reports those that evaluate to an error. Raises
/// `@xlsx.XlsxError` for a named sheet that does not exist or a structural
/// problem while evaluating.
pub fn lint(
  workbook : @xlsx.Workbook,
  file~ : String,
  sheet? : String = "",
) -> Json raise {
  // Surface the canonical `SheetNotFound` for an unknown `--sheet` — a pure
  // read probe that raises on a missing sheet and is harmless on a real one
  // (inspect cannot construct the engine's read-only error directly).
  if sheet != "" {
    ignore(workbook.get_cell_formula(sheet, "A1"))
  }
  let findings = []
  for worksheet in workbook.sheets() {
    let name = worksheet.name()
    if sheet != "" && name != sheet {
      continue
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
