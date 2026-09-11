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
        let head = text[0:open_at].to_owned()
        let tail = text[close_at + 6:].to_owned()
        // Identical in length, alike in text, each carrying its own
        // stable identity — so the cut leg has nothing to lean on but
        // bytes, and the identity leg has something real to check.
        let twins = "<w:p w14:paraId=\"0000AAA1\"><w:r><w:rPr><w:b/></w:rPr><w:t>same</w:t></w:r></w:p>" +
          "<w:p w14:paraId=\"0000AAA2\"><w:r><w:rPr><w:i/></w:rPr><w:t>same</w:t></w:r></w:p>" +
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
        predecessor_path: receipt.predecessor_path(),
        predecessor_para_id: receipt.predecessor_para_id(),
        predecessor_text: receipt.predecessor_text(),
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
  // The identity leg, made FALSIFIABLE: claim the deleted paragraph
  // carried the id the SURVIVOR still has. Doctoring with an id nothing
  // carries would pass on any implementation, including one with the
  // leg deleted.
  let surviving_identity = { ..honest, para_id: Some("0000AAA2"), }
  let identity_findings = delete_readback_findings(
    Some(surviving_identity),
    Docx,
    candidate,
  )
  assert_eq(identity_findings.length(), 1)
  assert_eq(identity_findings[0].code, "docx.delete.readback_identity")
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
  // THE PREDECESSOR LEGS. This candidate deleted `p[1]`, so it has no
  // predecessor of its own; the legs are driven by claiming one. Each
  // claim is one a real deletion of `p[2]` would have made, and each is
  // wrong in exactly one way about a paragraph the splice never moved.
  let claims_wrong_text = {
    ..honest,
    predecessor_path: Some("p[1]"),
    predecessor_text: Some("not what p[1] reads as"),
  }
  let predecessor_text_findings = delete_readback_findings(
    Some(claims_wrong_text),
    Docx,
    candidate,
  )
  assert_eq(predecessor_text_findings.length(), 1)
  assert_eq(
    predecessor_text_findings[0].code,
    "docx.delete.readback_predecessor_text",
  )
  // FALSIFIABLE the same way the deleted-identity leg is: the id
  // claimed is one the candidate really carries, just not at this path.
  let claims_wrong_identity = {
    ..honest,
    predecessor_path: Some("p[1]"),
    predecessor_para_id: Some("0000AAA1"),
  }
  let predecessor_findings = delete_readback_findings(
    Some(claims_wrong_identity),
    Docx,
    candidate,
  )
  assert_eq(predecessor_findings.length(), 1)
  assert_eq(predecessor_findings[0].code, "docx.delete.readback_predecessor")
  // A predecessor that is not there at all: silence would mean a
  // deletion that removed BOTH paragraphs read back as verified.
  let claims_absent = {
    ..honest,
    predecessor_path: Some("p[9]"),
    predecessor_text: Some("gone"),
  }
  let absent_findings = delete_readback_findings(
    Some(claims_absent),
    Docx,
    candidate,
  )
  assert_eq(absent_findings.length(), 1)
  assert_eq(absent_findings[0].code, "docx.delete.readback_predecessor_missing")
  // NO expectation means no deletion was queued on the session. This
  // validator is installed on every DOCX transaction — that is what
  // makes the readback belong to the queuing rather than to one verb —
  // so having nothing to say about a comment edit or a format run is
  // the correct answer, not a finding.
  assert_eq(delete_readback_findings(None, Docx, candidate).length(), 0)
  // A candidate whose body has NO paragraph left. The planner proved a
  // paragraph would remain against the SNAPSHOT; only the readback sees
  // the published body, and a structural guarantee checked solely
  // before the edit is not a guarantee.
  let emptied = @zip.Archive()
  for entry in candidate.entries() {
    let name = entry.name()
    guard candidate.get(name) is Some(payload) else { continue }
    let bytes = if name == "word/document.xml" {
      let text = @utf8.decode(payload)
      guard text.find("<w:body>") is Some(open_at) else { fail("no body") }
      guard text.find("</w:body>") is Some(close_at) else { fail("no /body") }
      @utf8.encode(
        text[0:open_at + 8].to_owned() +
        "<w:sectPr/>" +
        text[close_at:].to_owned(),
      )
    } else {
      payload.to_owned()
    }
    emptied.add(name, bytes)
  }
  assert_true(
    delete_readback_findings(Some(honest), Docx, emptied)
    .map(finding => finding.code)
    .contains("docx.delete.readback_no_paragraph"),
  )
  // A candidate that RENAMED its story: the relationship and the
  // content types point at `word/main.xml`, so the re-read succeeds and
  // every identity leg answers — about a part the plan never cut. Both
  // legs that exist to notice that fire together, and neither can be
  // deleted while this passes.
  let moved = @zip.Archive()
  for entry in candidate.entries() {
    let name = entry.name()
    guard candidate.get(name) is Some(payload) else { continue }
    let (renamed, bytes) = if name == "word/document.xml" {
      ("word/main.xml", payload)
    } else if name == "word/_rels/document.xml.rels" {
      ("word/_rels/main.xml.rels", payload)
    } else if name == "_rels/.rels" || name == "[Content_Types].xml" {
      (
        name,
        @utf8.encode(
          @utf8.decode(payload).replace_all(
            old="word/document.xml",
            new="word/main.xml",
          ),
        ),
      )
    } else {
      (name, payload)
    }
    moved.add(renamed, bytes)
  }
  let moved_findings = delete_readback_findings(Some(honest), Docx, moved)
  // In emission order: which story was judged, then what could not be
  // verified about the cut.
  assert_eq(moved_findings.map(finding => finding.code), [
    "docx.delete.readback_story_moved", "docx.delete.readback_cut_unverifiable",
  ])
}
