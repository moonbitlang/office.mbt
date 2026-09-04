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
        @utf8.encode(
          @utf8.decode(payload).replace(
            old="<w:r><w:t>Walking on imported air</w:t></w:r>",
            new="<w:r><w:t>same</w:t></w:r></w:p><w:p><w:r><w:t>same</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r>",
          ),
        )
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
