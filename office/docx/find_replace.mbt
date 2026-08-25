// `office replace` — the transactional find-and-replace verb (N2b).
//
// The engine plans; this file makes the plan a TRANSACTION: strict
// candidate validation, a readback that compares every affected
// paragraph's full projection against the plan-time expectation, and
// atomic publication with nothing written on any refusal.

///|
/// What one replace transaction did.
pub struct DocxFindReplaceReport {
  selected : Array[Int]
  replaced : Int
  affected_paths : Array[String]
  changed : Bool
}

///|
pub fn DocxFindReplaceReport::selected(
  self : DocxFindReplaceReport,
) -> Array[Int] {
  self.selected
}

///|
pub fn DocxFindReplaceReport::replaced(self : DocxFindReplaceReport) -> Int {
  self.replaced
}

///|
pub fn DocxFindReplaceReport::affected_paths(
  self : DocxFindReplaceReport,
) -> Array[String] {
  self.affected_paths
}

///|
pub fn DocxFindReplaceReport::changed(self : DocxFindReplaceReport) -> Bool {
  self.changed
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
) -> @word.DocxReplaceReceipt raise @transaction.TransactionError {
  let (plan, receipt) = @word.plan_docx_replacements(
    self.annotated,
    self.annotated.main_story_source(),
    needle~,
    replacement~,
    within?,
    nth?,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  receipt
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
    for entry in affected.val {
      match
        @word.docx_paragraph_projection(annotated, story, path=entry.path()) {
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
pub async fn transact_docx_find_replace(
  options : @transaction.TransactionOptions,
  needle~ : String,
  replacement~ : String,
  within? : String,
  nth? : Int,
  expect? : Int,
  allow_zero? : Bool = false,
) -> DocxFindReplaceResult {
  let collected : Ref[DocxFindReplaceReport?] = Ref(None)
  let affected : Ref[Array[@word.DocxReplaceAffected]] = Ref([])
  let readback = replace_readback_validator(affected)
  let transaction = transact_docx(
    options,
    session => {
      let receipt = session.queue_find_replace(
        needle~,
        replacement~,
        within?,
        nth?,
      )
      if receipt.replaced() == 0 && !allow_zero {
        raise @transaction.transaction_failure(
          "office.replace.no_match", "no candidate matched the needle; pass allow-zero to treat that as success",
        )
      }
      match expect {
        Some(count) =>
          if receipt.replaced() != count {
            raise @transaction.transaction_failure(
              "office.replace.expect_mismatch",
              "expected \{count} replacement(s) but \{receipt.replaced()} were selected",
            )
          }
        None => ()
      }
      affected.val = receipt.affected()
      collected.val = Some({
        selected: receipt.selected(),
        replaced: receipt.replaced(),
        affected_paths: receipt.affected().map(entry => entry.path()),
        changed: receipt.replaced() > 0,
      })
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the replace transaction returned no report",
    )
  }
  { report, transaction }
}
