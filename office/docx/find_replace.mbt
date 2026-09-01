// `office replace` — the transactional find-and-replace verb (N2b).
//
// The engine plans; this file makes the plan a TRANSACTION: strict
// candidate validation, a readback that compares every affected
// paragraph's full projection against the plan-time expectation, and
// atomic publication with nothing written on any refusal.

///|
/// What one replace transaction did.
pub struct DocxFindReplaceReport {
  priv selected : Array[Int]
  priv replaced : Int
  priv affected_paths : Array[String]
  priv affected : Array[@word.DocxReplaceAffected]
  priv matches : Array[@word.DocxMatch]
  // The scan path a stable `p[id="…"]` scope resolved to, when the
  // request used one — the receipt names both spellings so an agent
  // can re-anchor.
  resolved_within : String?
}

///|
pub fn DocxFindReplaceReport::selected(
  self : DocxFindReplaceReport,
) -> Array[Int] {
  self.selected.copy()
}

///|
pub fn DocxFindReplaceReport::replaced(self : DocxFindReplaceReport) -> Int {
  self.replaced
}

///|
pub fn DocxFindReplaceReport::affected_paths(
  self : DocxFindReplaceReport,
) -> Array[String] {
  self.affected_paths.copy()
}

///|
/// The affected paragraphs with their plan-time expectations and
/// anchor judgments.
pub fn DocxFindReplaceReport::affected(
  self : DocxFindReplaceReport,
) -> Array[@word.DocxReplaceAffected] {
  self.affected.copy()
}

///|
/// The scan path a stable `p[id="…"]` scope resolved to; None when the
/// request's scope was ordinal or absent.
pub fn DocxFindReplaceReport::resolved_within(
  self : DocxFindReplaceReport,
) -> String? {
  self.resolved_within
}

///|
/// The selected candidates, find-shaped, for the matches payload.
pub fn DocxFindReplaceReport::matches(
  self : DocxFindReplaceReport,
) -> Array[@word.DocxMatch] {
  self.matches.map(@word.DocxMatch::copy)
}

///|
pub struct DocxFindReplaceResult {
  report : DocxFindReplaceReport
  transaction : @transaction.TransactionReport
}

///|
pub fn DocxFindReplaceResult::report(
  self : DocxFindReplaceResult,
) -> DocxFindReplaceReport {
  self.report
}

///|
pub fn DocxFindReplaceResult::transaction(
  self : DocxFindReplaceResult,
) -> @transaction.TransactionReport {
  self.transaction
}

///|
/// Plans and queues one find-and-replace over the session snapshot.
pub fn DocxEditSession::queue_find_replace(
  self : DocxEditSession,
  needle~ : String,
  replacement~ : String,
  within? : String,
  nth? : Int,
) -> (@word.DocxReplaceReceipt, String?) raise @transaction.TransactionError {
  // paraId R2b: a stable `p[id="…"]` scope resolves against THIS
  // transaction's snapshot — the same typed refusals as the read
  // surfaces, and never a first carrier or an ordinal guess.
  let resolved_within : String? = match within {
    Some(scope) => Some(resolve_stable_replace_scope(self, scope))
    None => None
  }
  let (plan, receipt) = @word.plan_docx_replacements(
    self.annotated,
    self.annotated.main_story_source(),
    needle~,
    replacement~,
    within?=resolved_within,
    nth?,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  (
    receipt,
    match (within, resolved_within) {
      (Some(requested), Some(resolved)) if requested != resolved =>
        Some(resolved)
      _ => None
    },
  )
}

///|
/// Resolve a replace scope: stable `p[id="…"]` spellings become the
/// carrier's CURRENT scan path; ordinal scopes pass through untouched.
fn resolve_stable_replace_scope(
  session : DocxEditSession,
  scope : String,
) -> String raise @transaction.TransactionError {
  // ANY scope that begins like a stable spelling is judged as one:
  // a near-miss (p[id ="X"], p[id"X"]) must refuse typed, never fall
  // through to the prefix matcher where it matches nothing and an
  // --expect 0 run would publish.
  guard scope.has_prefix("p[id") else { return scope }
  // length >= 8: the shortest VALID spelling is p[id=""] (eight code
  // units) — at seven, p[id="] satisfies both the prefix and the
  // suffix with the SAME quote, and slicing would panic instead of
  // refusing typed.
  guard scope.has_prefix("p[id=\"") &&
    scope.has_suffix("\"]") &&
    scope.length() >= 8 else {
    raise @transaction.transaction_failure(
      "office.docx.para_id_invalid", "a stable scope is spelled p[id=\"XXXXXXXX\"]",
    )
  }
  let raw = scope.substring(start=6, end=scope.length() - 2).to_string()
  let anchors = @word.docx_paragraph_anchor_index(
    session.annotated,
    session.annotated.main_story_source(),
  ) catch {
    _ =>
      raise @transaction.transaction_failure(
        "office.docx.para_id_unavailable", "stable scoping is unavailable for this document",
      )
  }
  match anchors.resolve_para_id_carrier(raw) {
    ResolvedCarrier(paragraph_index) =>
      match anchors.scan_path_of_paragraph(paragraph_index) {
        Some(path) => path
        None =>
          raise @transaction.transaction_failure(
            "office.docx.para_id_unjoined", "the paragraph carrying this id has no addressable path in this snapshot",
          )
      }
    CarrierInvalid =>
      raise @transaction.transaction_failure(
        "office.docx.para_id_invalid", "a paraId is exactly eight hex digits, nonzero, below 0x80000000",
      )
    CarrierNotFound =>
      raise @transaction.transaction_failure(
        "office.docx.para_id_not_found", "no paragraph in the body story carries this id",
      )
    CarrierAmbiguous(_) =>
      raise @transaction.transaction_failure(
        "office.docx.para_id_ambiguous", "this id names more than one paragraph; scope by ordinal path instead — an ambiguous identity never resolves to its first carrier",
      )
    CarrierInMultiPhysical =>
      raise @transaction.transaction_failure(
        "office.docx.para_id_not_addressable", "this id's only carriers are inside revision-joined paragraphs",
      )
  }
}

///|
/// The readback validator: re-read the CANDIDATE and require each
/// affected paragraph's full projection to equal the plan-time
/// expectation.
///
/// The comparison is against the whole paragraph, never a substring —
/// the replacement text may pre-exist elsewhere in the paragraph, and a
/// presence probe would pass on a splice that landed in the wrong place.
/// A path that no longer resolves is a mismatch, not a pass: a readback
/// that cannot find what it is checking has found a problem.
fn replace_readback_validator(
  affected : Ref[Array[@word.DocxReplaceAffected]],
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  // Takes the Ref, not the array: the transaction wants its validators
  // up front, while the affected list only exists after the session
  // closure plans. Reading `.val` at validation time closes that gap
  // without a wrapper — an earlier version wrapped this in a second
  // validator whose failure path returned NO findings, which is a
  // fail-open a validator must never have.
  @transaction.transaction_validator("office-docx-replace-readback", (
    format,
    _bytes,
    archive,
  ) => {
    let findings : Array[@transaction.ValidationFinding] = []
    if format != Docx {
      findings.push(
        @transaction.validation_finding(
          "docx.replace.wrong_format", "replace readback received a non-DOCX candidate",
        ),
      )
      return findings
    }
    let annotated = @word.read_docx_annotated_archive_limited(
      archive,
      candidate_xml_budget(),
    ) catch {
      error => {
        findings.push(
          @transaction.validation_finding(
            "docx.replace.readback_unreadable",
            docx_validator_message(
              "candidate could not be re-read for the replace readback: \{docx_error_message(error)}",
            ),
          ),
        )
        return findings
      }
    }
    let story = annotated.main_story_source()
    // ONE batch for the whole story: resolving a paragraph path costs a
    // pass over the document, so asking per affected paragraph would
    // cost the document once per replacement site.
    let projections = @word.docx_paragraphs_projection(
      annotated,
      story,
      paths=affected.val.map(entry => entry.path()),
    )
    for position, entry in affected.val {
      match projections[position] {
        Some(actual) =>
          if actual != entry.expected() {
            findings.push(
              @transaction.validation_finding(
                "docx.replace.readback_mismatch",
                docx_validator_message(
                  "paragraph \{entry.path()} reads back differently than the plan expected",
                ),
              ),
            )
          }
        None =>
          findings.push(
            @transaction.validation_finding(
              "docx.replace.readback_missing",
              docx_validator_message(
                "paragraph \{entry.path()} no longer resolves in the candidate",
              ),
            ),
          )
      }
    }
    findings
  })
}

///|
/// One complete replace transaction.
///
/// The locked policy points live HERE, not in the engine, because they
/// are caller policy about outcomes rather than facts about documents:
///
/// - `expect` asserts the SELECTED replacement count; a mismatch refuses
///   before anything is published.
/// - zero selected without `allow_zero` refuses; nothing is written.
/// - `expect` combined with `allow_zero` is rejected by the CLI parser
///   as contradictory before this function is reached.
/// - `preflight` lets the caller refuse the transaction over the REPORT
///   it is about to receive (the CLI budgets its JSON output here);
///   raising from it aborts before anything is published.
pub async fn transact_docx_find_replace(
  options : @transaction.TransactionOptions,
  needle~ : String,
  replacement~ : String,
  within? : String,
  nth? : Int,
  expect? : Int,
  allow_zero? : Bool = false,
  preflight? : (DocxFindReplaceReport) -> Unit raise,
) -> DocxFindReplaceResult {
  let collected : Ref[DocxFindReplaceReport?] = Ref(None)
  let affected : Ref[Array[@word.DocxReplaceAffected]] = Ref([])
  let readback = replace_readback_validator(affected)
  let transaction = transact_docx(
    options,
    session => {
      let (receipt, resolved_within) = session.queue_find_replace(
        needle~,
        replacement~,
        within?,
        nth?,
      )
      // `expect` is checked FIRST, so `--expect 0` can hold: an
      // explicit assertion of zero is a satisfiable claim, and letting
      // the generic zero-refusal fire before it made the advertised
      // `--expect 0` impossible to ever pass.
      match expect {
        Some(count) =>
          if receipt.replaced() != count {
            raise @transaction.transaction_failure(
              "office.replace.expect_mismatch",
              "expected \{count} replacement(s) but \{receipt.replaced()} were selected",
            )
          }
        None =>
          if receipt.replaced() == 0 && !allow_zero {
            raise @transaction.transaction_failure(
              "office.replace.no_match", "no candidate matched the needle; pass allow-zero to treat that as success, or expect 0 to assert it",
            )
          }
      }
      affected.val = receipt.affected()
      let report : DocxFindReplaceReport = {
        selected: receipt.selected(),
        replaced: receipt.replaced(),
        affected_paths: receipt.affected().map(entry => entry.path()),
        affected: receipt.affected(),
        matches: receipt.matches(),
        resolved_within,
      }
      // The caller's preflight runs INSIDE the transaction, after the
      // outcome assertions but before validation and publication: a
      // caller that cannot deliver this outcome (an output contract it
      // must honor, say) refuses here, and nothing is written.
      match preflight {
        Some(check) => check(report)
        None => ()
      }
      collected.val = Some(report)
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the replace transaction returned no report",
    )
  }
  { report, transaction, }
}
