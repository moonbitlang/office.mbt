///|
/// Regression nets for #338: a valid tracked-changes DOCX that `outline`,
/// `text`, and `dump` all read must also be annotatable, and a package that
/// genuinely outgrows the bounded parse must still be refused — as a resource
/// limit, never as malformed XML.

///|
/// One paragraph's worth of tracked-change markup: a settled run, a deletion,
/// and the insertion that replaced it. This is the shape a redlined document
/// is made of and the densest markup the strict parser meets in practice —
/// every `w:ins`/`w:del` carries `w:id`, `w:author`, and `w:date`, so the
/// token charge per byte is far higher than for ordinary prose.
fn redline_paragraph(index : Int) -> String {
  let deletion_id = index * 2 + 1
  let insertion_id = deletion_id + 1
  "<w:r><w:t xml:space=\"preserve\">Item \{index} baseline </w:t></w:r>" +
  "<w:del w:id=\"\{deletion_id}\" w:author=\"Reviewer\" w:date=\"2026-01-01T00:00:00Z\">" +
  "<w:r><w:delText xml:space=\"preserve\">old\{index}</w:delText></w:r></w:del>" +
  "<w:ins w:id=\"\{insertion_id}\" w:author=\"Reviewer\" w:date=\"2026-01-01T00:00:00Z\">" +
  "<w:r><w:t xml:space=\"preserve\">new\{index}</w:t></w:r></w:ins>"
}

///|
/// Body markup for `count` redlined paragraphs, spliced into the one-paragraph
/// fixture by closing and reopening `w:p` between blocks.
fn redline_runs(count : Int) -> String {
  let markup = StringBuilder()
  for index in 0..<count {
    if index > 0 {
      markup.write_string("</w:p><w:p>")
    }
    markup.write_string(redline_paragraph(index))
  }
  markup.to_string()
}

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  let mut found = 0
  let mut rest = haystack[:]
  while rest.find(needle) is Some(at) {
    found = found + 1
    rest = rest[at + needle.length():]
  }
  found
}

///|
fn single_comment_batch() -> @docx.AnnotationBatch raise {
  @docx.parse_annotation_batch(
    "{\"schema\": \"docx.annotation-batch/1\", \"ops\": [" +
    "{\"op\": \"comment_add\", \"anchor\": {\"at\": \"/docx/body/p[1]\"}, " +
    "\"author\": \"Me\", \"body\": [\"note\"]}]}",
  )
}

///|
/// The bug itself. 2,000 fully redlined paragraphs charge ~240 Ki XML tokens,
/// which the old one-token-per-64-source-bytes ceiling (128 Ki) refused — and
/// refused as "malformed XML in word/document.xml", sending readers hunting
/// for corruption in a perfectly valid package. Everything must now go
/// through: the bounded identifier, the source index, the splice, and the
/// strict package validator that `office validate` also runs.
async test "annotate accepts a heavily redlined DOCX (#338)" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-redline-budget-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "redline.docx", redline_runs(2000))
    let output = directory + "/annotated.docx"
    let result = @docx.transact_docx_annotations(
      @transaction.transaction_options(input, output_path=output),
      single_comment_batch(),
    )
    assert_eq(result.report.ops_applied, 1)
    assert_true(result.report.changed)
    // Every validator the transaction runs — the bounded DOCX identifier, the
    // portable OPC gate, and the strict DOCX package validator behind
    // `office validate` — accepted the published candidate.
    assert_eq(result.transaction.validations.length(), 3)
    for summary in result.transaction.validations {
      assert_true(summary.passed)
      assert_eq(summary.finding_count, 0)
    }
    // The point of the fix: the tracked changes survive annotation intact.
    // The `dump -> replay` workaround in the report reaches the same output
    // size only by discarding every one of these.
    let document = published_document(output)
    assert_eq(count_occurrences(document, "<w:del "), 2000)
    assert_eq(count_occurrences(document, "<w:ins "), 2000)
    assert_eq(count_occurrences(document, "<w:delText "), 2000)
    assert_true(document.contains("w:author=\"Reviewer\""))
    // and the comment landed on the first paragraph
    assert_true(document.contains("commentRangeStart"))
  }
}

///|
/// The guard must stay real. Well past the raised ceiling the package is still
/// refused, under the typed resource-limit code and with a message that says
/// so — no bytes are published.
async test "annotate still refuses a package past the XML budget (#338)" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-redline-over-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let input = edit_fixture(directory, "huge.docx", redline_runs(30000))
    let output = directory + "/never.docx"
    let options = @transaction.transaction_options(input, output_path=output)
    let batch = single_comment_batch()
    try @docx.transact_docx_annotations(options, batch) |> ignore catch {
      @transaction.TransactionError(code~, message~, ..) => {
        assert_eq(code, "office.docx.resource_limit")
        // A budget refusal must name itself as one, never as a defect in the
        // document, and must not be reported as malformed XML.
        assert_true(message.contains("resource limit"))
        assert_false(message.contains("malformed"))
      }
      error => fail("expected TransactionError, received \{error}")
    } noraise {
      _ => fail("expected the XML resource guard to refuse this package")
    }
    assert_false(@afs.exists(output))
  }
}
