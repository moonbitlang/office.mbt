// `office insert-paragraph` — the N3a transaction. The engine plans
// (and MINTS: a new physical paragraph is the only thing that ever
// receives a new w14:paraId); this file makes the plan a transaction
// with a readback that verifies the minted identity landed where the
// receipt says, and atomic publication with nothing written on any
// refusal.

///|
/// What one insertion transaction did: the minted id and the path the
/// paragraph answers to, both READBACK-VERIFIED before publication.
pub struct DocxInsertParagraphReport {
  priv para_id : String
  priv path : String
}

///|
pub fn DocxInsertParagraphReport::para_id(
  self : DocxInsertParagraphReport,
) -> String {
  self.para_id
}

///|
pub fn DocxInsertParagraphReport::path(
  self : DocxInsertParagraphReport,
) -> String {
  self.path
}

///|
pub struct DocxInsertParagraphResult {
  priv report : DocxInsertParagraphReport
  priv transaction : @transaction.TransactionReport
}

///|
pub fn DocxInsertParagraphResult::report(
  self : DocxInsertParagraphResult,
) -> DocxInsertParagraphReport {
  self.report
}

///|
pub fn DocxInsertParagraphResult::transaction(
  self : DocxInsertParagraphResult,
) -> @transaction.TransactionReport {
  self.transaction
}

///|
/// Queue one paragraph insertion on the session snapshot. The used-id
/// inventory comes from the SAME traversal the delta identity gate
/// trusts, so the mint can never collide with anything the gate would
/// later count.
pub fn DocxEditSession::queue_insert_paragraph(
  self : DocxEditSession,
  at~ : String,
  before~ : Bool,
  content~ : @word.DocxInsertContent,
) -> @word.DocxInsertReceipt raise @transaction.TransactionError {
  let inventory = @word.para_id_inventory_archive_limited(
    self.annotated,
    self.archive,
    candidate_xml_budget(),
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  let used : Array[String] = []
  for _part, values in inventory {
    for value in values {
      used.push(value)
    }
  }
  let (plan, receipt) = @word.plan_docx_paragraph_insertion(
    self.annotated,
    at~,
    before~,
    content~,
    used_para_ids=used,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  receipt
}

///|
/// The insertion readback: the candidate must show the minted id at
/// the planned path with a UNIQUE anchor, and the paragraph's
/// projection must equal the content's joined text. A path that does
/// not resolve, a different id, or a non-unique anchor is a finding —
/// a readback that cannot find what it planted has found a problem.
fn insert_readback_validator(
  expected : Ref[(String, String, String)?],
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-insert-readback", (
    format,
    _bytes,
    archive,
  ) => {
    let findings : Array[@transaction.ValidationFinding] = []
    if format != Docx {
      findings.push(
        @transaction.validation_finding(
          "docx.insert.wrong_format", "insert readback received a non-DOCX candidate",
        ),
      )
      return findings
    }
    guard expected.val is Some((path, para_id, text)) else {
      findings.push(
        @transaction.validation_finding(
          "docx.insert.readback_unplanned", "insert readback ran without a planned expectation",
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
            "docx.insert.readback_unreadable",
            docx_validator_message(
              "candidate could not be re-read for the insert readback: \{docx_error_message(error)}",
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
            "docx.insert.readback_unjudged", "the candidate's paragraph identities could not be judged",
          ),
        )
        return findings
      }
    }
    match anchors.anchor_at(path) {
      Some(anchor) =>
        if anchor.para_id() != Some(para_id) || anchor.status() != "unique" {
          findings.push(
            @transaction.validation_finding(
              "docx.insert.readback_identity",
              docx_validator_message(
                "the inserted paragraph at \{path} does not carry the minted identity uniquely",
              ),
            ),
          )
        }
      None =>
        findings.push(
          @transaction.validation_finding(
            "docx.insert.readback_missing",
            docx_validator_message(
              "the planned insertion path \{path} does not resolve in the candidate",
            ),
          ),
        )
    }
    match @word.docx_paragraph_projection(annotated, story, path~) {
      Some(actual) =>
        if actual != text {
          findings.push(
            @transaction.validation_finding(
              "docx.insert.readback_text",
              docx_validator_message(
                "the inserted paragraph at \{path} reads back differently than planned",
              ),
            ),
          )
        }
      None => ()
    }
    findings
  })
}

///|
/// One complete insertion transaction: plan (mint included), validate
/// the candidate strictly, verify the minted identity by readback, and
/// publish atomically — nothing written on any refusal.
pub async fn transact_docx_insert_paragraph(
  options : @transaction.TransactionOptions,
  at~ : String,
  before~ : Bool,
  content~ : @word.DocxInsertContent,
) -> DocxInsertParagraphResult {
  let collected : Ref[DocxInsertParagraphReport?] = Ref(None)
  let expected : Ref[(String, String, String)?] = Ref(None)
  let readback = insert_readback_validator(expected)
  let transaction = transact_docx(
    options,
    session => {
      let receipt = session.queue_insert_paragraph(at~, before~, content~)
      let joined = StringBuilder()
      for run in content.runs {
        joined.write_string(run.text)
      }
      expected.val = Some(
        (receipt.planned_path(), receipt.para_id(), joined.to_string()),
      )
      collected.val = Some({
        para_id: receipt.para_id(),
        path: receipt.planned_path(),
      })
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the insert transaction returned no report",
    )
  }
  { report, transaction, }
}
