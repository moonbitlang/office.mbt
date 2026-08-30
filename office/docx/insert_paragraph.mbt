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
  // R3's mint is CONSERVATIVELY package-global: the structured
  // inventory covers the reachable story parts, but a paraId in a
  // glossary document or any unclassified XML part must also block its
  // value. The PRIMARY sweep strict-parses every XML part, so quote
  // styles, attribute whitespace, and entity encodings are all
  // normalized by the parser; the byte-level sweep stays as a belt for
  // parts the parser refuses. Over-collection only shrinks the mint
  // space, never corrupts it.
  let swept = @word.sweep_archive_para_id_values(self.archive, fresh_budget=() => {
    candidate_xml_budget()
  }) catch {
    error => raise mapped_plan_failure(error)
  }
  for value in swept {
    used.push(value)
  }
  for value in conservative_para_id_sweep(self.archive) {
    used.push(value)
  }
  // The union shares the structured sweep's retention envelope.
  if used.length() > 131072 {
    raise @transaction.transaction_failure(
      "office.docx.resource_limit", "the package carries more paraId occupants than the mint inventory retains; refusing rather than minting blind",
    )
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

///|
/// Byte-level sweep for `paraId="…"` attribute values across EVERY
/// archive part. Purely conservative input to the mint: prefix-blind
/// (any `…paraId="` spelling counts) and judgment-free (whatever sits
/// between the quotes is collected as an occupant).
fn conservative_para_id_sweep(archive : @zip.Archive) -> Array[String] {
  let found : Array[String] = []
  // XML attributes take EITHER quote style; the sweep matches the
  // name+equals and accepts whichever quote follows, closing on the
  // same one.
  let needle : Bytes = "paraId="
  for entry in archive.entries() {
    let bytes = entry.data()
    let mut at = 0
    while at + needle.length() + 1 <= bytes.length() {
      let mut matched = true
      for offset in 0..<needle.length() {
        if bytes[at + offset] != needle[offset] {
          matched = false
          break
        }
      }
      if !matched {
        at += 1
        continue
      }
      let quote = bytes[at + needle.length()]
      if quote != b'"' && quote != b'\'' {
        at += needle.length()
        continue
      }
      let value_start = at + needle.length() + 1
      let mut value_end = value_start
      while value_end < bytes.length() &&
            bytes[value_end] != quote &&
            value_end - value_start < 64 {
        value_end += 1
      }
      // Only a value that actually CLOSED within the bound is an
      // occupant; an unterminated or over-long run is noise.
      if value_end > value_start &&
        value_end < bytes.length() &&
        bytes[value_end] == quote {
        let builder = StringBuilder()
        let mut ascii = true
        for index in value_start..<value_end {
          if bytes[index] >= b'\x80' {
            ascii = false
            break
          }
          builder.write_char(bytes[index].to_int().unsafe_to_char())
        }
        if ascii {
          found.push(builder.to_string())
        }
      }
      at = value_end
    }
  }
  found
}
