///|
/// XLSX bounded row repetition (#207 R2): each region clones its template
/// row once per record through the engine's atomic duplicate_row_to and
/// substitutes per-record values with the shared cell machinery. Strict
/// v1 posture: the workbook must be FORMULA-FREE in the widest sense
/// (stored formulas, table formulas, defined names, charts, sparklines,
/// conditional formats, data validations, pivot/external/query/
/// connection/VML/unknown parts, internal-location links, form controls
/// all refuse) because cloned and shifted formula text is never
/// rewritten — a silently wrong number is worse than a refusal. All
/// preflight runs before ANY mutation; the transaction publishes only a
/// clean merge.

///|
/// The published outcome of one region after a successful merge.
pub(all) struct XlsxRegionOutcome {
  name : String
  /// The region as addressed: canonical sheet + source template row.
  source_location : String
  /// Final coordinates after ALL insertions (upper regions shift lower
  /// ones down).
  output_rows_start : Int
  output_rows_count : Int
  records : Int
  replaced : Int
  escapes_applied : Int
} derive(Eq, @debug.Debug)

///|
/// Result of one strict document-level template transaction.
pub struct XlsxTemplateDocumentResult {
  report : XlsxTemplateReport
  regions : Array[XlsxRegionOutcome]
  scalar_cells_skipped : Int
  transaction : @transaction.TransactionReport
}

///|
priv struct RegionPlan {
  name : String
  sheet : String
  row : Int
  records : Array[Map[String, @template.TemplateValue]]
  /// Distinct placeholder keys discovered on the template row, with the
  /// occurrence count of each (drives per-record missing accounting).
  key_occurrences : Map[String, Int]
}

///|
/// Rows of a plain `A5`/`A5:C9` range, None when unparsable.
fn plain_range_rows(range : String) -> (Int, Int)? {
  fn cell_row(part : String) -> Int? {
    let mut index = 0
    if index < part.length() && part[index] == '$' {
      index += 1
    }
    while index < part.length() && part[index] is ('A'..='Z' | 'a'..='z') {
      index += 1
    }
    if index < part.length() && part[index] == '$' {
      index += 1
    }
    let digit_start = index
    let mut row = 0
    while index < part.length() && part[index] is ('0'..='9') {
      row = row * 10 + (part[index].to_int() - '0'.to_int())
      if row > 1048576 {
        return None
      }
      index += 1
    }
    if index != part.length() || digit_start == index || row < 1 {
      return None
    }
    Some(row)
  }

  match range.find(":") {
    Some(pos) => {
      let left = cell_row(range.substring(start=0, end=pos))
      let right = cell_row(range.substring(start=pos + 1))
      match (left, right) {
        (Some(a), Some(b)) =>
          Some((if a < b { a } else { b }, if a > b { a } else { b }))
        _ => None
      }
    }
    None =>
      match cell_row(range) {
        Some(row) => Some((row, row))
        None => None
      }
  }
}

///|
fn region_location(name : String) -> String {
  "region \"" + name + "\""
}

///|
/// One workbook-wide refusal: the class name plus its first location.
fn push_policy_finding(
  report : XlsxTemplateReport,
  location : String,
  detail : String,
) -> Unit {
  report.unsupported_total += 1
  push_bounded(report.unsupported, location, detail)
}

///|
/// The v1 formula-free / artifact policy over the WHOLE workbook plus the
/// per-affected-sheet and template-row checks. Pure read; findings land
/// in the report.
fn region_policy_check(
  workbook : @engine.Workbook,
  plans : Array[RegionPlan],
  report : XlsxTemplateReport,
) -> Unit raise {
  let features = workbook.package_features()
  fn flag(present : Bool, first : String?, what : String) {
    if present {
      let location = match first {
        Some(path) => path
        None => "package"
      }
      push_policy_finding(
        report,
        location,
        what + " is beyond v1 repetition support",
      )
    }
  }

  flag(
    features.external_links,
    features.first_external_link,
    "an external-link part",
  )
  flag(features.query_tables, features.first_query_table, "a query-table part")
  flag(features.connections, features.first_connections, "a connections part")
  flag(features.pivot_parts, features.first_pivot_part, "a pivot part")
  flag(features.vml_present, features.first_vml_part, "VML content")
  flag(
    features.unknown_parts,
    features.first_unknown_part,
    "an unclassified package part",
  )
  match workbook.first_table_with_source_formulas() {
    Some((sheet, table)) =>
      push_policy_finding(
        report,
        sheet,
        "table \"" + table + "\" carries source formulas the rewrite would drop",
      )
    None => ()
  }
  let names = workbook.get_defined_names()
  if names.length() > 0 {
    push_policy_finding(
      report,
      "workbook",
      "defined name \"" +
      names[0].name +
      "\" cannot be adjusted for repetition (v1 requires none)",
    )
  }
  let affected : Set[String] = Set::new()
  for plan in plans {
    affected.add(plan.sheet)
  }
  for worksheet in workbook.sheets() {
    let sheet_name = worksheet.name
    match worksheet.first_stored_formula_cell() {
      Some(reference) =>
        push_policy_finding(
          report,
          "\{sheet_name}!\{reference}",
          "a stored formula cell (v1 repetition requires a formula-free workbook)",
        )
      None => ()
    }
    for image in worksheet.images() {
      if image.hyperlink_type is Location {
        push_policy_finding(
          report,
          "\{sheet_name}!\{image.reference}",
          "an image with an internal-location hyperlink would silently retarget",
        )
        break
      }
    }
    let on_affected = affected.contains(sheet_name)
    for entry in workbook.sheet_row_state_inventory(sheet_name) {
      match entry.class {
        // formula-bearing or reference-bearing classes: workbook-wide
        ChartAnchors =>
          push_policy_finding(
            report, sheet_name, "a chart (charts carry reference-bearing XML)",
          )
        SparklineAnchors =>
          push_policy_finding(
            report, sheet_name, "a sparkline (sources are reference-bearing)",
          )
        ConditionalFormats =>
          push_policy_finding(
            report, sheet_name, "conditional formatting (v1 repetition refuses it wholesale)",
          )
        DataValidations =>
          push_policy_finding(
            report, sheet_name, "data validation (v1 repetition refuses it wholesale)",
          )
        InternalLinkTargets =>
          push_policy_finding(
            report, sheet_name, "a hyperlink with an internal location target",
          )
        FormControlAnchors =>
          push_policy_finding(
            report, sheet_name, "a form control (v1 repetition refuses them wholesale)",
          )
        // static artifacts insertion cannot adjust: affected sheets only
        CommentAnchors =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "a comment on a sheet receiving inserted rows",
            )
          }
        ShapeAnchors =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "a shape on a sheet receiving inserted rows",
            )
          }
        SlicerAnchors =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "a slicer on a sheet receiving inserted rows",
            )
          }
        IgnoredErrorRanges =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "ignored-error ranges on a sheet receiving inserted rows",
            )
          }
        PreservedDrawingAnchors =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "preserved drawing content on a sheet receiving inserted rows",
            )
          }
        UnknownExtensions =>
          if on_affected {
            push_policy_finding(
              report, sheet_name, "unknown worksheet extensions on a sheet receiving inserted rows",
            )
          }
        _ => ()
      }
    }
  }
}

///|
/// Template-row intersection checks plus the grid preflight, per affected
/// sheet. Pure read; findings land in the report.
fn region_sheet_check(
  workbook : @engine.Workbook,
  plans : Array[RegionPlan],
  report : XlsxTemplateReport,
) -> Unit raise {
  // group inserted counts and template rows per sheet
  let inserted_per_sheet : Map[String, Int] = {}
  let rows_per_sheet : Map[String, Array[Int]] = {}
  for plan in plans {
    let inserted = plan.records.length() - 1
    inserted_per_sheet[plan.sheet] = match inserted_per_sheet.get(plan.sheet) {
      Some(count) => count + inserted
      None => inserted
    }
    match rows_per_sheet.get(plan.sheet) {
      Some(rows) => rows.push(plan.row)
      None => rows_per_sheet[plan.sheet] = [plan.row]
    }
  }
  for sheet_name, template_rows in rows_per_sheet {
    guard workbook.sheet(sheet_name) is Some(worksheet) else { continue }
    // multi-row merges intersecting a template row refuse; single-row
    // merges on the row are duplicated by the engine and are fine
    for range in worksheet.merged_cells() {
      match plain_range_rows(range) {
        Some((low, high)) => {
          if low == high {
            continue
          }
          for row in template_rows {
            if row >= low && row <= high {
              push_policy_finding(
                report,
                "\{sheet_name}!\{range}",
                "a multi-row merged range intersects the template row",
              )
              break
            }
          }
        }
        None =>
          push_policy_finding(
            report,
            "\{sheet_name}!\{range}",
            "a merged range with an unreadable extent",
          )
      }
    }
    for table in worksheet.tables() {
      match plain_range_rows(table.range_ref) {
        Some((low, high)) =>
          for row in template_rows {
            if row >= low && row <= high {
              push_policy_finding(
                report,
                "\{sheet_name}!\{table.range_ref}",
                "table \"" + table.name + "\" intersects the template row",
              )
              break
            }
          }
        None =>
          push_policy_finding(
            report,
            sheet_name,
            "table \"" + table.name + "\" has an unreadable extent",
          )
      }
    }
    match worksheet.auto_filter() {
      Some(filter) =>
        match plain_range_rows(filter.range_ref) {
          Some((low, high)) =>
            for row in template_rows {
              if row >= low && row <= high {
                push_policy_finding(
                  report,
                  "\{sheet_name}!\{filter.range_ref}",
                  "the auto-filter range intersects the template row",
                )
                break
              }
            }
          None =>
            push_policy_finding(
              report, sheet_name, "an auto-filter with an unreadable extent",
            )
        }
      None => ()
    }
    // grid preflight over the surviving shifted classes
    let inserted = match inserted_per_sheet.get(sheet_name) {
      Some(count) => count
      None => 0
    }
    if inserted == 0 {
      continue
    }
    let mut max_extent = 0
    for entry in workbook.sheet_row_state_inventory(sheet_name) {
      match entry.handling {
        ShiftedByInsert =>
          match entry.extent {
            RowsUpTo(row) => if row > max_extent { max_extent = row }
            WholeSheet =>
              push_policy_finding(
                report, sheet_name, "row extents on this sheet are not fully determinable",
              )
            Positionless => ()
          }
        StaticOnWrite | DroppedByWriter => ()
      }
    }
    if max_extent > 1048576 - inserted {
      push_policy_finding(
        report,
        sheet_name,
        "inserting \{inserted} rows would push content past the grid",
      )
    }
  }
}

///|
/// Resolves the parsed regions against the workbook and scans each
/// template row: addressing form, sheet resolution, distinct rows,
/// placeholder presence, malformed sites, rich-text refusals, and the
/// per-record missing/unused accounting. Pure read.
fn plan_template_regions(
  workbook : @engine.Workbook,
  data : @template.TemplateData,
  values : Map[String, @template.TemplateValue],
  allow_missing~ : Bool,
  report : XlsxTemplateReport,
  budget : Ref[Int],
) -> Array[RegionPlan] raise {
  let plans : Array[RegionPlan] = []
  let claimed : Set[String] = Set::new()
  for region in data.regions {
    guard region.address is SheetRow(sheet~, row~) else {
      push_policy_finding(
        report,
        region_location(region.name),
        "table-row addressing applies to DOCX merges; this file is XLSX",
      )
      continue
    }
    guard workbook.sheet(sheet) is Some(worksheet) else {
      push_policy_finding(
        report,
        region_location(region.name),
        "sheet \"" + sheet + "\" does not exist in this workbook",
      )
      continue
    }
    let canonical = worksheet.name
    let claim_key = "\{canonical}\u{0}\{row}"
    if claimed.contains(claim_key) {
      push_policy_finding(
        report,
        region_location(region.name),
        "another region already claims \{canonical} row \{row}",
      )
      continue
    }
    claimed.add(claim_key)
    // scan the template row's string cells
    let key_occurrences : Map[String, Int] = {}
    let mut malformed_here = false
    for cell in worksheet.cells {
      if cell.row != row {
        continue
      }
      let location = "\{canonical}!\{cell.reference}"
      if cell.rich_text is Some(_) {
        if cell.value.contains("{{") {
          push_policy_finding(
            report, location, "placeholder inside a rich-text cell would flatten its formatting",
          )
        }
        continue
      }
      guard workbook.get_cell_value_raw(canonical, cell.reference)
        is Some(String(text)) else {
        continue
      }
      if !text.contains("{{") && !text.contains("\\{{") {
        continue
      }
      let scan = @template.scan_placeholders([text], budget)
      for entry in scan.malformed {
        malformed_here = true
        report.malformed_total += 1
        push_bounded(report.malformed, location, entry.reason)
      }
      for matched in scan.matches {
        key_occurrences[matched.key] = match key_occurrences.get(matched.key) {
          Some(count) => count + 1
          None => 1
        }
      }
    }
    if malformed_here {
      continue
    }
    if key_occurrences.size() == 0 {
      push_policy_finding(
        report,
        region_location(region.name),
        "the template row at \{canonical} row \{row} carries no placeholder",
      )
      continue
    }
    // per-record missing and unused accounting (occurrence-weighted
    // missing, mirroring the scalar counters)
    for record_index, record in region.records {
      for key, occurrences in key_occurrences {
        if record.contains(key) || values.contains(key) {
          continue
        }
        report.missing_total += occurrences
        push_bounded(
          report.missing,
          "\{canonical} row \{row}",
          "record \{record_index}: " + key,
        )
      }
      for key, _ in record {
        if !key_occurrences.contains(key) {
          report.unused_total += 1
          if report.unused.length() < template_finding_limit {
            report.unused.push(
              "region " + region.name + " record \{record_index}: " + key,
            )
          }
        }
      }
    }
    plans.push({
      name: region.name,
      sheet: canonical,
      row,
      records: region.records,
      key_occurrences,
    })
  }
  ignore(allow_missing)
  plans
}

///|
/// Executes the planned regions: clones bottom-up per sheet, fills every
/// record row through the shared substitution core, and reports final
/// coordinates. Only runs on a preflight-clean merge.
fn apply_template_regions(
  workbook : @engine.Workbook,
  plans : Array[RegionPlan],
  values : Map[String, @template.TemplateValue],
  report : XlsxTemplateReport,
  budget : Ref[Int],
) -> Array[XlsxRegionOutcome] raise {
  // bottom-up per sheet so pending template rows never shift
  let order = plans.copy()
  order.sort_by((a, b) => {
    if a.sheet == b.sheet {
      b.row - a.row
    } else {
      a.sheet.compare(b.sheet)
    }
  })
  let outcomes : Map[String, XlsxRegionOutcome] = {}
  let mut changed = false
  for plan in order {
    let count = plan.records.length()
    for _ in 1..<count {
      workbook.duplicate_row_to(plan.sheet, plan.row, plan.row + 1)
      changed = true
    }
    guard workbook.sheet(plan.sheet) is Some(worksheet) else { continue }
    let mut replaced = 0
    let mut escapes = 0
    for record_index, record in plan.records {
      let target_row = plan.row + record_index
      // gather the row's string cells first: applying edits while
      // walking the cells array would mutate it mid-iteration
      let row_cells : Array[(String, String)] = []
      for cell in worksheet.cells {
        if cell.row != target_row {
          continue
        }
        if cell.rich_text is Some(_) || cell.formula is Some(_) {
          continue
        }
        match workbook.get_cell_value_raw(plan.sheet, cell.reference) {
          Some(String(text)) =>
            if text.contains("{{") || text.contains("\\{{") {
              row_cells.push((cell.reference, text))
            }
          _ => ()
        }
      }
      for pair in row_cells {
        let (reference, text) = pair
        let outcome = substitute_cell_text(
          text,
          key => {
            match record.get(key) {
              Some(value) => Some(value)
              None => values.get(key)
            }
          },
          budget,
        )
        report.placeholders_found += outcome.placeholders_found
        match outcome.typed_edit {
          Some(value) => {
            replaced += outcome.replaced
            guard workbook.sheet(plan.sheet) is Some(sheet) else { continue }
            sheet.set_cell_value(reference, value)
            changed = true
            continue
          }
          None => ()
        }
        replaced += outcome.replaced
        escapes += outcome.escapes_applied
        match outcome.new_text {
          Some(final_text) => {
            workbook.set_cell(plan.sheet, reference, final_text)
            changed = true
          }
          None => ()
        }
      }
    }
    report.replaced += replaced
    report.escapes_applied += escapes
    outcomes[plan.name] = {
      name: plan.name,
      source_location: "\{plan.sheet} row \{plan.row}",
      output_rows_start: plan.row,
      output_rows_count: count,
      records: count,
      replaced,
      escapes_applied: escapes,
    }
  }
  if changed {
    report.changed = true
    let cleared : Set[String] = Set::new()
    for plan in plans {
      if cleared.contains(plan.sheet) {
        continue
      }
      cleared.add(plan.sheet)
      match workbook.sheet(plan.sheet) {
        Some(worksheet) => worksheet.clear_dimension_ref()
        None => ()
      }
    }
  }
  // final coordinates: regions above shift this one down by their
  // inserted rows
  let results : Array[XlsxRegionOutcome] = []
  for plan in plans {
    guard outcomes.get(plan.name) is Some(outcome) else { continue }
    let mut shift = 0
    for other in plans {
      if other.sheet == plan.sheet && other.row < plan.row {
        shift += other.records.length() - 1
      }
    }
    results.push({
      name: outcome.name,
      source_location: outcome.source_location,
      output_rows_start: plan.row + shift,
      output_rows_count: outcome.output_rows_count,
      records: outcome.records,
      replaced: outcome.replaced,
      escapes_applied: outcome.escapes_applied,
    })
  }
  results
}

///|
/// Merges a full template data document (scalar values plus repetition
/// regions) into an existing XLSX package through the shared transaction
/// boundary. With no regions this behaves exactly like
/// `transact_template`. Strict findings refuse with `XlsxTemplateRefused`
/// and nothing is published.
pub async fn transact_template_document(
  options : @transaction.TransactionOptions,
  data : @template.TemplateData,
  allow_missing~ : Bool,
) -> XlsxTemplateDocumentResult {
  let collected : Ref[XlsxTemplateReport?] = Ref::new(None)
  let region_outcomes : Ref[Array[XlsxRegionOutcome]] = Ref::new([])
  let skipped_cells : Ref[Int] = Ref::new(0)
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
      let scan_budget = Ref::new(template_scan_budget)
      let preflight : XlsxTemplateReport = {
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
      let plans = if data.regions.length() > 0 {
        let planned = plan_template_regions(
          workbook,
          data,
          data.values,
          allow_missing~,
          preflight,
          scan_budget,
        ) catch {
          @template.TemplateScanBudgetExceeded(_) =>
            raise xlsx_transaction_failure(
              "office.xlsx.resource_limit", "template scan work exceeds the configured ceiling",
            )
          error => raise error
        }
        region_policy_check(workbook, planned, preflight)
        region_sheet_check(workbook, planned, preflight)
        planned
      } else {
        []
      }
      let claimed : Set[String] = Set::new()
      for plan in plans {
        claimed.add("\{plan.sheet}\u{0}\{plan.row}")
      }
      let merge = merge_template_workbook(
        workbook,
        data.values,
        allow_missing~,
        claimed_rows=claimed,
        skipped_cells~,
      ) catch {
        @template.TemplateScanBudgetExceeded(_) =>
          raise xlsx_transaction_failure(
            "office.xlsx.resource_limit", "template scan work exceeds the configured ceiling",
          )
        error => raise error
      }
      // fold the preflight findings into the single report
      merge.placeholders_found += preflight.placeholders_found
      merge.missing_total += preflight.missing_total
      merge.malformed_total += preflight.malformed_total
      merge.unsupported_total += preflight.unsupported_total
      merge.unused_total += preflight.unused_total
      for finding in preflight.missing {
        push_bounded(merge.missing, finding.location, finding.detail)
      }
      for finding in preflight.malformed {
        push_bounded(merge.malformed, finding.location, finding.detail)
      }
      for finding in preflight.unsupported {
        push_bounded(merge.unsupported, finding.location, finding.detail)
      }
      for key in preflight.unused {
        if merge.unused.length() < template_finding_limit {
          merge.unused.push(key)
        }
      }
      collected.val = Some(merge)
      if merge.malformed_total > 0 ||
        merge.unsupported_total > 0 ||
        (merge.missing_total > 0 && !allow_missing) {
        raise xlsx_transaction_failure(
          "office.xlsx.template_refused", "strict template findings refuse publication",
        )
      }
      if plans.length() > 0 {
        region_outcomes.val = apply_template_regions(
          workbook,
          plans,
          data.values,
          merge,
          scan_budget,
        ) catch {
          @template.TemplateScanBudgetExceeded(_) =>
            raise xlsx_transaction_failure(
              "office.xlsx.resource_limit", "template scan work exceeds the configured ceiling",
            )
          error => raise error
        }
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
      match collected.val {
        Some(merge) if merge.malformed_total > 0 ||
          merge.unsupported_total > 0 ||
          (merge.missing_total > 0 && !allow_missing) =>
          raise XlsxTemplateRefused(merge)
        _ => raise error
      }
  }
  guard collected.val is Some(merge) else {
    raise xlsx_transaction_failure(
      "office.xlsx.template_internal", "the merge produced no report",
    )
  }
  {
    report: merge,
    regions: region_outcomes.val,
    scalar_cells_skipped: skipped_cells.val,
    transaction: report,
  }
}
