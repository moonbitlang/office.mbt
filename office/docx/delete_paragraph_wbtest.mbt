// The delete readback, driven with DOCTORED expectations against a real
// candidate: a check nothing can make fail is not a check.

///|
/// Build a real published candidate and the plan's own expectation,
/// then hand both to the readback so a test can bend either.
async fn delete_readback_case() -> (
  @zip.Archive,
  @word.DocxAnnotatedResult,
  DeleteReadbackExpectation,
) {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-delrb-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // Two paragraphs that read ALIKE, then a keeper: the regime where
    // projection and identity can say nothing about which one left.
    let source_bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
    ).binary()
    let archive = @zip.read(source_bytes)
    let rebuilt = @zip.Archive()
    for entry in archive.entries() {
      let entry_name = entry.name()
      guard archive.get(entry_name) is Some(payload) else { continue }
      let replaced = if entry_name == "word/document.xml" {
        // Replace the fixture's WHOLE paragraph, so the two paragraphs
        // this test compares are authored here and are byte-for-byte
        // the SAME LENGTH — they read alike and differ only in markup a
        // projection cannot see. The length guard therefore decides
        // nothing, and a `matches` reduced to its length check would
        // accept the neighbour's cut.
        let text = @utf8.decode(payload)
        guard text.find("<w:p ") is Some(open_at) else {
          fail("fixture has no paragraph")
        }
        guard text.find("</w:p>") is Some(close_at) else {
          fail("fixture has no paragraph end")
        }
        let head = text[0:open_at].to_string()
        let tail = text[close_at + 6:].to_string()
        let twins = "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>same</w:t></w:r></w:p>" +
          "<w:p><w:r><w:rPr><w:i/></w:rPr><w:t>same</w:t></w:r></w:p>" +
          "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
        @utf8.encode(head + twins + tail)
      } else {
        payload.to_owned()
      }
      rebuilt.add(entry_name, replaced)
    }
    let input = directory + "/rb-in.docx"
    @afs.write_file(
      input,
      @zip.write_preserving(rebuilt),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/rb-out.docx"
    let result = transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=output),
      at="p[1]",
    )
    // The published candidate, and an expectation rebuilt from the same
    // plan the transaction used.
    let published = @zip.read(@afs.read_file(output).binary())
    let source = @word.read_docx_annotated(@afs.read_file(input).binary())
    let (_, receipt) = @word.plan_docx_paragraph_deletion(source, at="p[1]")
    let cut = receipt.cut()
    ignore(result)
    (
      published,
      source,
      {
        path: receipt.path(),
        para_id: receipt.para_id(),
        successor_para_id: receipt.successor_para_id(),
        successor_text: receipt.successor_text(),
        old_count: @word.docx_direct_body_paragraph_count(source),
        cut,
      },
    )
  }
}

///|
/// The honest expectation passes; every way of being wrong about WHERE
/// the cut landed is caught — including the one text and identity
/// cannot see, where the neighbour reads identically.
async test "the delete readback catches a cut that did not land as planned" {
  let (candidate, source_snapshot, honest) = delete_readback_case()
  assert_eq(delete_readback_findings(Some(honest), Docx, candidate).length(), 0)
  // A cut that removed the NEIGHBOUR instead: the same byte count, the
  // same resulting text at the same path, on a document whose first two
  // paragraphs read alike. Projection and identity cannot tell these
  // apart — the bytes can.
  let (_, neighbour) = @word.plan_docx_paragraph_deletion(
    source_snapshot,
    at="p[2]",
  )
  let wrong_paragraph = { ..honest, cut: neighbour.cut(), }
  let wrong_findings = delete_readback_findings(
    Some(wrong_paragraph),
    Docx,
    candidate,
  )
  assert_eq(wrong_findings.length(), 1)
  assert_eq(wrong_findings[0].code, "docx.delete.readback_cut")
  // The guard that proves the byte loops ran: the two candidate spans
  // are the same length, so a `matches` reduced to its length check
  // would accept the neighbour's cut and this assertion would fail.
  assert_eq(honest.cut.expected_length(), wrong_paragraph.cut.expected_length())
  // Every other leg of the readback, driven the same way.
  let wrong_count = { ..honest, old_count: honest.old_count + 5, }
  let count_findings = delete_readback_findings(
    Some(wrong_count),
    Docx,
    candidate,
  )
  assert_eq(count_findings.length(), 1)
  assert_eq(count_findings[0].code, "docx.delete.readback_count")
  let wrong_successor_text = {
    ..honest,
    successor_text: Some("not what it says"),
  }
  let text_findings = delete_readback_findings(
    Some(wrong_successor_text),
    Docx,
    candidate,
  )
  assert_eq(text_findings.length(), 1)
  assert_eq(text_findings[0].code, "docx.delete.readback_successor_text")
  let ghost_identity = { ..honest, para_id: Some("00000001"), }
  let identity_findings = delete_readback_findings(
    Some(ghost_identity),
    Docx,
    candidate,
  )
  // The deleted identity must be GONE; a document that never carried it
  // satisfies that, so this pins the leg runs rather than a violation.
  assert_eq(identity_findings.length(), 0)
  let wrong_successor_id = { ..honest, successor_para_id: Some("0000BEEF"), }
  let successor_findings = delete_readback_findings(
    Some(wrong_successor_id),
    Docx,
    candidate,
  )
  assert_eq(successor_findings.length(), 1)
  assert_eq(successor_findings[0].code, "docx.delete.readback_successor")
  // A non-DOCX candidate refuses before any leg runs.
  let wrong_format = delete_readback_findings(Some(honest), Xlsx, candidate)
  assert_eq(wrong_format.length(), 1)
  assert_eq(wrong_format[0].code, "docx.delete.wrong_format")
  // A candidate missing the story part entirely.
  let empty = @zip.Archive()
  let missing = delete_readback_findings(Some(honest), Docx, empty)
  // Named exactly: a disjunction would pass on either arm and prove
  // neither.
  assert_eq(missing.length(), 1)
  assert_eq(missing[0].code, "docx.delete.readback_unreadable")
  // No expectation at all is itself a finding: a readback that ran
  // without a plan verified nothing.
  let unplanned = delete_readback_findings(None, Docx, candidate)
  assert_eq(unplanned.length(), 1)
  assert_eq(unplanned[0].code, "docx.delete.readback_unplanned")
}
