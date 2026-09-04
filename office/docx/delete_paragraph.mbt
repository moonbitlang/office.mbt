// `office delete-paragraph` — the N3b transaction. The engine plans
// the byte-exact removal and every structural refusal; this file makes
// the plan a transaction with an identity readback — the deleted
// identity is GONE, the successor answers at the path, the story is
// one paragraph shorter — and atomic publication with nothing written
// on any refusal. The paraId delta gate already rules removals
// acceptable: consumed content takes its ids with it.

///|
/// What one deletion transaction did, readback-verified before
/// publication.
pub struct DocxDeleteParagraphReport {
  priv path : String
  priv para_id : String?
  priv anchor_status : String
  priv text : String
  priv successor_para_id : String?
}

///|
pub fn DocxDeleteParagraphReport::path(
  self : DocxDeleteParagraphReport,
) -> String {
  self.path
}

///|
pub fn DocxDeleteParagraphReport::para_id(
  self : DocxDeleteParagraphReport,
) -> String? {
  self.para_id
}

///|
pub fn DocxDeleteParagraphReport::anchor_status(
  self : DocxDeleteParagraphReport,
) -> String {
  self.anchor_status
}

///|
/// The deleted paragraph's full reader projection — the caller's
/// guard against deleting the wrong paragraph by ordinal.
pub fn DocxDeleteParagraphReport::text(
  self : DocxDeleteParagraphReport,
) -> String {
  self.text
}

///|
/// The unique identity now answering at the deleted path, when the
/// successor carries one.
pub fn DocxDeleteParagraphReport::successor_para_id(
  self : DocxDeleteParagraphReport,
) -> String? {
  self.successor_para_id
}

///|
pub struct DocxDeleteParagraphResult {
  priv report : DocxDeleteParagraphReport
  priv transaction : @transaction.TransactionReport
}

///|
pub fn DocxDeleteParagraphResult::report(
  self : DocxDeleteParagraphResult,
) -> DocxDeleteParagraphReport {
  self.report
}

///|
pub fn DocxDeleteParagraphResult::transaction(
  self : DocxDeleteParagraphResult,
) -> @transaction.TransactionReport {
  self.transaction
}

///|
/// Queue one paragraph deletion on the session snapshot. `at` accepts
/// the direct ordinal path or the stable p[id="…"] spelling, resolved
/// against THIS snapshot with the typed para_id refusals.
pub fn DocxEditSession::queue_delete_paragraph(
  self : DocxEditSession,
  at~ : String,
) -> @word.DocxDeleteReceipt raise @transaction.TransactionError {
  let resolved = resolve_stable_replace_scope(self, at)
  let (plan, receipt) = @word.plan_docx_paragraph_deletion(
    self.annotated,
    at=resolved,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  receipt
}

///|
/// The deletion readback: on the candidate, the deleted unique
/// identity appears NOWHERE in the story, the successor's identity
/// answers at the deleted path, and the direct-paragraph count is
/// exactly one less. Anything unreadable or unjudgeable is a finding.
priv struct DeleteReadbackExpectation {
  path : String
  para_id : String?
  successor_para_id : String?
  // The successor's projection at plan time. Identity legs go quiet on
  // a document with no unique paraIds — most producers other than Word
  // emit none — and a count alone cannot tell WHICH paragraph left.
  // Text is the leg that still speaks there.
  successor_text : String?
  old_count : Int
  // Where the cut must land, and what the story must read across it.
  // Projection and identity both go blind when two adjacent paragraphs
  // read alike — deleting either leaves the same text at the same path
  // — so this is the leg that says WHICH paragraph left.
  part : String
  expected_part_length : Int
  joint_offset : Int
  joint : Bytes
}

///|
fn delete_readback_validator(
  expected : Ref[DeleteReadbackExpectation?],
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-delete-readback", (
    format,
    _bytes,
    archive,
  ) => delete_readback_findings(expected.val, format, archive))
}

///|
/// The readback's judgment, as a named function so tests can drive
/// DOCTORED expectations against real candidates: a check nothing can
/// make fail is not a check.
fn delete_readback_findings(
  expectation : DeleteReadbackExpectation?,
  format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> Array[@transaction.ValidationFinding] raise {
  let findings : Array[@transaction.ValidationFinding] = []
  if format != Docx {
    findings.push(
      @transaction.validation_finding(
        "docx.delete.wrong_format", "delete readback received a non-DOCX candidate",
      ),
    )
    return findings
  }
  guard expectation is Some(plan) else {
    findings.push(
      @transaction.validation_finding(
        "docx.delete.readback_unplanned", "delete readback ran without a planned expectation",
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
          "docx.delete.readback_unreadable",
          docx_validator_message(
            "candidate could not be re-read for the delete readback: \{docx_error_message(error)}",
          ),
        ),
      )
      return findings
    }
  }
  let story = annotated.main_story_source()
  let anchors = @word.docx_paragraph_anchor_index(annotated, story) catch {
    _ => {
      findings.push(
        @transaction.validation_finding(
          "docx.delete.readback_unjudged", "the candidate's paragraph identities could not be judged",
        ),
      )
      return findings
    }
  }
  match plan.para_id {
    Some(id) =>
      if anchors.paragraphs_with_para_id(id).length() > 0 {
        findings.push(
          @transaction.validation_finding(
            "docx.delete.readback_identity",
            docx_validator_message(
              "the deleted paragraph's identity \{id} still appears in the candidate",
            ),
          ),
        )
      }
    None => ()
  }
  match plan.successor_para_id {
    Some(id) => {
      let answering = match anchors.anchor_at(plan.path) {
        Some(anchor) => anchor.para_id()
        None => None
      }
      if answering != Some(id) {
        findings.push(
          @transaction.validation_finding(
            "docx.delete.readback_successor",
            docx_validator_message(
              "the successor identity does not answer at \{plan.path} in the candidate",
            ),
          ),
        )
      }
    }
    None => ()
  }
  // The text leg: whatever the successor read as before the splice
  // must be what the deleted path reads as after it. This is the
  // check that still has something to say when no paragraph in the
  // document carries a unique identity.
  match plan.successor_text {
    Some(text) => {
      let answering = @word.docx_paragraph_projection(
        annotated,
        story,
        path=plan.path,
      )
      match answering {
        Some(actual) =>
          if actual != text {
            findings.push(
              @transaction.validation_finding(
                "docx.delete.readback_successor_text",
                docx_validator_message(
                  "the paragraph now at \{plan.path} does not read as the successor did before the splice",
                ),
              ),
            )
          }
        None =>
          findings.push(
            @transaction.validation_finding(
              "docx.delete.readback_successor_missing",
              docx_validator_message(
                "no paragraph reads back at \{plan.path} where the successor should be",
              ),
            ),
          )
      }
    }
    None => ()
  }
  // The cut, verified at the bytes: the published part must be
  // exactly the source with the planned span removed, proven at the
  // seam the removal creates.
  match archive.get(plan.part) {
    Some(payload) =>
      if payload.length() != plan.expected_part_length {
        findings.push(
          @transaction.validation_finding(
            "docx.delete.readback_cut_size",
            docx_validator_message(
              "the published story part is \{payload.length()} bytes; removing the planned paragraph leaves \{plan.expected_part_length}",
            ),
          ),
        )
      } else if plan.joint.length() > 0 {
        let mut matched = true
        for offset in 0..<plan.joint.length() {
          let at = plan.joint_offset + offset
          if at < 0 ||
            at >= payload.length() ||
            payload[at] != plan.joint[offset] {
            matched = false
            break
          }
        }
        if !matched {
          findings.push(
            @transaction.validation_finding(
              "docx.delete.readback_cut_position",
              docx_validator_message(
                "the published story part does not read as planned across the cut; the removal did not land where the plan said",
              ),
            ),
          )
        }
      }
    // A candidate without the main story part cannot reach here: the
    // annotated re-read above fails first and returns
    // `readback_unreadable`. Kept as a total match, not as a claim of
    // coverage — no test asserts this arm, because none can reach it.
    None => ()
  }
  let count = @word.docx_direct_body_paragraph_count(annotated) catch {
    _ => {
      findings.push(
        @transaction.validation_finding(
          "docx.delete.readback_uncounted", "the candidate's direct paragraphs could not be counted",
        ),
      )
      return findings
    }
  }
  if count != plan.old_count - 1 {
    findings.push(
      @transaction.validation_finding(
        "docx.delete.readback_count",
        docx_validator_message(
          "the candidate has \{count} direct paragraph(s); the plan expected \{plan.old_count - 1}",
        ),
      ),
    )
  }
  findings
}

///|
/// One complete deletion transaction: resolve, plan (every structural
/// refusal typed), validate the candidate strictly, verify by identity
/// readback, publish atomically — nothing written on any refusal.
///
/// `expect_text`, when given, must equal the target's full reader
/// projection or the transaction refuses before anything is written —
/// the guard for ordinal addressing. `preflight` receives the report
/// inside the transaction, before publication; raising from it refuses
/// the transaction.
pub async fn transact_docx_delete_paragraph(
  options : @transaction.TransactionOptions,
  at~ : String,
  expect_text? : String,
  preflight? : (DocxDeleteParagraphReport) -> Unit raise,
) -> DocxDeleteParagraphResult {
  let collected : Ref[DocxDeleteParagraphReport?] = Ref(None)
  let expected : Ref[DeleteReadbackExpectation?] = Ref(None)
  let readback = delete_readback_validator(expected)
  let transaction = transact_docx(
    options,
    session => {
      let old_count = @word.docx_direct_body_paragraph_count(session.annotated) catch {
        error => raise mapped_plan_failure(error)
      }
      let receipt = session.queue_delete_paragraph(at~)
      match expect_text {
        Some(text) =>
          if receipt.text() != text {
            raise @transaction.transaction_failure(
              "office.delete.expect_text_mismatch",
              "the paragraph at \{receipt.path()} does not read as the expected text; nothing was deleted — re-run `office find` or address by p[id=\"…\"]",
            )
          }
        None => ()
      }
      let cut = receipt.cut()
      expected.val = Some({
        path: receipt.path(),
        para_id: receipt.para_id(),
        successor_para_id: receipt.successor_para_id(),
        successor_text: receipt.successor_text(),
        old_count,
        part: cut.part(),
        expected_part_length: cut.expected_length(),
        joint_offset: cut.offset(),
        joint: cut.joint(),
      })
      let report : DocxDeleteParagraphReport = {
        path: receipt.path(),
        para_id: receipt.para_id(),
        anchor_status: receipt.anchor_status(),
        text: receipt.text(),
        successor_para_id: receipt.successor_para_id(),
      }
      match preflight {
        Some(callback) => callback(report)
        None => ()
      }
      collected.val = Some(report)
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the delete transaction returned no report",
    )
  }
  { report, transaction, }
}
