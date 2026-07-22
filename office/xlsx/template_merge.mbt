///|
/// The XLSX template merge: substitutes `{{key}}` placeholders in stored
/// string cell values with data from an `office.template.data/1` map.
/// Strict by default — malformed placeholders, unsupported contexts
/// (formula and rich-text cells), and missing keys (unless allowed) each
/// refuse the whole transaction with the findings riding to the caller.
/// Substitution never creates formulas: values land through the literal
/// cell setters, so a data value starting with `=` cannot execute.

///|
/// One bounded finding list entry: a canonical `Sheet1!B2` location plus
/// the key or reason it concerns.
pub(all) struct XlsxTemplateFinding {
  location : String
  detail : String
} derive(Eq, @debug.Debug)

///|
/// The complete merge outcome for one workbook.
pub(all) struct XlsxTemplateReport {
  mut placeholders_found : Int
  mut replaced : Int
  mut escapes_applied : Int
  mut distinct_keys_used : Int
  missing : Array[XlsxTemplateFinding]
  unused : Array[String]
  malformed : Array[XlsxTemplateFinding]
  unsupported : Array[XlsxTemplateFinding]
  locations : Array[XlsxTemplateFinding]
  mut locations_truncated : Bool
  // full occurrence counts per class: the lists above are bounded, so a
  // consumer must be able to tell exactly-64 from more-than-64
  mut missing_total : Int
  mut malformed_total : Int
  mut unsupported_total : Int
  mut unused_total : Int
  mut changed : Bool
} derive(Eq, @debug.Debug)

///|
/// Raised when strict findings refuse publication; the report carries
/// every bounded finding for the caller's failure envelope.
pub suberror XlsxTemplateRefused {
  XlsxTemplateRefused(XlsxTemplateReport)
} derive(@debug.Debug)

///|
let template_finding_limit : Int = 64

///|
/// Total scan work allowance per merge, in code units.
let template_scan_budget : Int = 4 * 1024 * 1024

///|
fn push_bounded(
  findings : Array[XlsxTemplateFinding],
  location : String,
  detail : String,
) -> Unit {
  if findings.length() < template_finding_limit {
    findings.push({ location, detail })
  }
}

///|
/// The outcome of substituting one cell's text: the shared core used by
/// the scalar pass and the region fill so their semantics cannot drift.
priv struct CellSubstitution {
  malformed_reasons : Array[String]
  present_keys : Array[String]
  missing_keys : Array[String]
  mut typed_edit : @engine.CellValue?
  mut new_text : String?
  mut replaced : Int
  mut escapes_applied : Int
  mut placeholders_found : Int
}

///|
/// Scans one string cell value and computes its substitution under a
/// resolver. Mirrors the original scalar semantics exactly: any malformed
/// site freezes the cell; whole-cell single-match substitution keeps the
/// value's native type; otherwise a left-to-right substring rebuild where
/// missing keys leave their literal text (the caller decides whether
/// missing refuses). `new_text` is Some only when the rebuild changed
/// the text.
fn substitute_cell_text(
  text : String,
  resolve : (String) -> @template.TemplateValue?,
  budget : Ref[Int],
) -> CellSubstitution raise {
  let outcome : CellSubstitution = {
    malformed_reasons: [],
    present_keys: [],
    missing_keys: [],
    typed_edit: None,
    new_text: None,
    replaced: 0,
    escapes_applied: 0,
    placeholders_found: 0,
  }
  let scan = @template.scan_placeholders([text], budget)
  outcome.placeholders_found = scan.matches.length()
  for entry in scan.malformed {
    outcome.malformed_reasons.push(entry.reason)
  }
  if scan.malformed.length() > 0 {
    return outcome
  }
  for matched in scan.matches {
    match resolve(matched.key) {
      Some(_) => outcome.present_keys.push(matched.key)
      None => outcome.missing_keys.push(matched.key)
    }
  }
  let units = text.code_units().length()
  if scan.matches.length() == 1 &&
    scan.escapes.length() == 0 &&
    outcome.missing_keys.length() == 0 {
    let only = scan.matches[0]
    if only.span.start_offset == 0 && only.span.end_offset == units {
      match resolve(only.key) {
        Some(NumberValue(number)) => {
          outcome.replaced = 1
          outcome.typed_edit = Some(@engine.CellValue::Numeric(number))
          return outcome
        }
        Some(BoolValue(flag)) => {
          outcome.replaced = 1
          outcome.typed_edit = Some(@engine.CellValue::Bool(flag))
          return outcome
        }
        _ => ()
      }
    }
  }
  let builder = StringBuilder::new()
  let mut cursor = 0
  let mut rewrote = false
  let mut match_index = 0
  let mut escape_index = 0
  while match_index < scan.matches.length() ||
        escape_index < scan.escapes.length() {
    let next_match_at = if match_index < scan.matches.length() {
      scan.matches[match_index].span.start_offset
    } else {
      units + 1
    }
    let next_escape_at = if escape_index < scan.escapes.length() {
      scan.escapes[escape_index].start_offset
    } else {
      units + 1
    }
    if next_match_at < next_escape_at {
      let matched = scan.matches[match_index]
      match_index += 1
      builder.write_string(
        text.substring(start=cursor, end=matched.span.start_offset),
      )
      match resolve(matched.key) {
        Some(value) => {
          builder.write_string(value.render())
          outcome.replaced += 1
          rewrote = true
        }
        None =>
          // allow-missing: the literal placeholder stays
          builder.write_string(
            text.substring(
              start=matched.span.start_offset,
              end=matched.span.end_offset,
            ),
          )
      }
      cursor = matched.span.end_offset
    } else {
      let escape = scan.escapes[escape_index]
      escape_index += 1
      builder.write_string(
        text.substring(start=cursor, end=escape.start_offset),
      )
      builder.write_string("{{")
      outcome.escapes_applied += 1
      rewrote = true
      cursor = escape.end_offset
    }
  }
  builder.write_string(text.substring(start=cursor, end=units))
  if rewrote {
    let final_text = builder.to_string()
    if final_text != text {
      outcome.new_text = Some(final_text)
    }
  }
  outcome
}

///|
/// Scans and substitutes one workbook in place. The returned report is
/// complete whether or not the caller publishes; `changed` says whether
/// any cell was rewritten. Cells whose (sheet, row) is CLAIMED by a
/// repetition region are skipped entirely — the region pass owns them —
/// with the skip count reported through `skipped_cells`.
fn merge_template_workbook(
  workbook : @engine.Workbook,
  values : Map[String, @template.TemplateValue],
  allow_missing~ : Bool,
  claimed_rows? : Set[String] = Set::new(),
  skipped_cells? : Ref[Int] = Ref::new(0),
  pre_used_keys? : Set[String] = Set::new(),
) -> XlsxTemplateReport raise {
  let budget = Ref::new(template_scan_budget)
  let report : XlsxTemplateReport = {
    placeholders_found: 0,
    replaced: 0,
    escapes_applied: 0,
    distinct_keys_used: 0,
    missing: [],
    unused: [],
    malformed: [],
    unsupported: [],
    locations: [],
    locations_truncated: false,
    missing_total: 0,
    malformed_total: 0,
    unsupported_total: 0,
    unused_total: 0,
    changed: false,
  }
  let used_keys : Set[String] = Set::new()
  // values keys the REGION pass consumes (region placeholders resolve
  // from values whenever the key is absent from records, and the parser
  // bars record/values collisions, so region-present values keys are
  // always used) — without this a values key used only inside a region
  // would be reported unused
  for key in pre_used_keys {
    used_keys.add(key)
  }
  let missing_keys : Set[String] = Set::new()
  // collect edits first, apply after the scan: applying mid-iteration
  // would mutate the cells array being walked
  let text_edits : Array[(String, String, String)] = []
  let typed_edits : Array[(String, String, @engine.CellValue)] = []
  for worksheet in workbook.sheets() {
    let sheet_name = worksheet.name
    for cell in worksheet.cells {
      if claimed_rows.contains("\{sheet_name}\u{0}\{cell.row}") {
        // the region pass owns every cell on a claimed template row
        skipped_cells.val += 1
        continue
      }
      let location = "\{sheet_name}!\{cell.reference}"
      let is_formula = cell.formula is Some(_) ||
        cell.formula_shared_index is Some(_)
      if is_formula {
        // formula text and cached values are never substituted; a
        // brace-carrying formula cell is almost certainly an authoring
        // mistake and silence would ship a broken workbook
        let formula_text = match cell.formula {
          Some(text) => text
          None => ""
        }
        if formula_text.contains("{{") || cell.value.contains("{{") {
          report.unsupported_total += 1
          push_bounded(
            report.unsupported,
            location,
            "placeholder inside a formula cell is not substitutable",
          )
        }
        continue
      }
      if cell.rich_text is Some(_) {
        if cell.value.contains("{{") {
          report.unsupported_total += 1
          push_bounded(
            report.unsupported,
            location,
            "placeholder inside a rich-text cell would flatten its formatting",
          )
        }
        continue
      }
      guard workbook.get_cell_value_raw(sheet_name, cell.reference)
        is Some(String(text)) else {
        continue
      }
      if !text.contains("{{") && !text.contains("\\{{") {
        continue
      }
      let outcome = substitute_cell_text(text, key => values.get(key), budget)
      report.placeholders_found += outcome.placeholders_found
      for reason in outcome.malformed_reasons {
        report.malformed_total += 1
        push_bounded(report.malformed, location, reason)
      }
      if outcome.malformed_reasons.length() > 0 {
        // a cell with any malformed site is never modified
        continue
      }
      for key in outcome.present_keys {
        used_keys.add(key)
        if report.locations.length() < template_finding_limit {
          report.locations.push({ location, detail: key })
        } else {
          report.locations_truncated = true
        }
      }
      for key in outcome.missing_keys {
        missing_keys.add(key)
        report.missing_total += 1
        push_bounded(report.missing, location, key)
      }
      if outcome.missing_keys.length() > 0 && !allow_missing {
        // the transaction will refuse; no edits for this cell
        continue
      }
      match outcome.typed_edit {
        Some(value) => {
          report.replaced += outcome.replaced
          typed_edits.push((sheet_name, cell.reference, value))
          continue
        }
        None => ()
      }
      report.replaced += outcome.replaced
      report.escapes_applied += outcome.escapes_applied
      match outcome.new_text {
        Some(final_text) =>
          text_edits.push((sheet_name, cell.reference, final_text))
        None => ()
      }
    }
  }
  for edit in text_edits {
    let (sheet_name, reference, final_text) = edit
    workbook.set_cell(sheet_name, reference, final_text)
    report.changed = true
  }
  for edit in typed_edits {
    let (sheet_name, reference, value) = edit
    guard workbook.sheet(sheet_name) is Some(sheet) else { continue }
    sheet.set_cell_value(reference, value)
    report.changed = true
  }
  for key, _ in values {
    if !used_keys.contains(key) {
      report.unused_total += 1
      if report.unused.length() < template_finding_limit {
        report.unused.push(key)
      }
    }
  }
  report.distinct_keys_used = used_keys.size()
  ignore(missing_keys)
  report
}

///|
/// Result of one strict XLSX template transaction.
pub struct XlsxTemplateResult {
  report : XlsxTemplateReport
  transaction : @transaction.TransactionReport
}

///|
/// Merges template data into an existing XLSX package through the shared
/// Office transaction boundary. Strict findings (malformed placeholders,
/// unsupported contexts, missing keys without `allow_missing`) raise
/// `XlsxTemplateRefused` with the full report and nothing is published.
/// A merge that changes nothing reuses the source bytes exactly.
pub async fn transact_template(
  options : @transaction.TransactionOptions,
  values : Map[String, @template.TemplateValue],
  allow_missing~ : Bool,
) -> XlsxTemplateResult {
  let collected : Ref[XlsxTemplateReport?] = Ref::new(None)
  let validator = xlsx_transaction_validator()
  let identifier = xlsx_transaction_identifier()
  let report = @transaction.transact(
    options,
    (format, _bytes, archive, budget) => {
      if !(format is Xlsx) {
        raise xlsx_transaction_failure(
          "office.xlsx.format_mismatch",
          "office template requires an XLSX package, received \{format.name()}",
        )
      }
      let workbook = read_transaction_workbook(archive)
      let merge = merge_template_workbook(workbook, values, allow_missing~) catch {
        @template.TemplateScanBudgetExceeded(_) =>
          raise xlsx_transaction_failure(
            "office.xlsx.resource_limit", "template scan work exceeds the configured ceiling",
          )
        error => raise error
      }
      collected.val = Some(merge)
      if merge.malformed.length() > 0 ||
        merge.unsupported.length() > 0 ||
        (merge.missing.length() > 0 && !allow_missing) {
        // the transaction layer wraps callback errors, so the typed
        // refusal is re-derived from the collected report after transact
        // fails — this raise only aborts publication
        raise xlsx_transaction_failure(
          "office.xlsx.template_refused", "strict template findings refuse publication",
        )
      }
      if merge.changed {
        let candidate = serialize_transaction_workbook(workbook, budget)
        @transaction.transaction_mutation(candidate, warnings=[
          full_rewrite_warning(),
        ])
      } else {
        @transaction.transaction_reuse_original()
      }
    },
    validators=[validator],
    identifier~,
  ) catch {
    error =>
      // a strict refusal aborted the transaction from inside the
      // callback; surface it typed with the full report
      match collected.val {
        Some(merge) if merge.malformed.length() > 0 ||
          merge.unsupported.length() > 0 ||
          (merge.missing.length() > 0 && !allow_missing) =>
          raise XlsxTemplateRefused(merge)
        _ => raise error
      }
  }
  guard collected.val is Some(merge) else {
    raise xlsx_transaction_failure(
      "office.xlsx.template_internal", "the merge produced no report",
    )
  }
  { report: merge, transaction: report }
}
