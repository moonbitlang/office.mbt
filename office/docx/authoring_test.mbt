// D3 authoring nets: fresh blank creation and rich script authoring round-trip
// through the reader; refusals leave no output. Reuses with_annotation_dir /
// published_part from annotation_batch_test.mbt (same black-box test package).

///|
async test "create_blank_document publishes a reader-valid package" {
  with_annotation_dir() <| directory => {
    let output = directory + "/blank.docx"
    let options = @transaction.create_transaction_options(output)
    let result = @docx.create_blank_document(options)
    assert_true(result.transaction.committed)
    assert_true(@afs.exists(output))
    // the published package opens through the reader (one empty paragraph body)
    guard published_part(output, "word/document.xml") is Some(document) else {
      fail("published document.xml missing")
    }
    assert_true(document.contains("<w:body>"))
  }
}

///|
async test "author_document folds a rich script and round-trips" {
  with_annotation_dir() <| directory => {
    let output = directory + "/authored.docx"
    let script = @docx.parse_docx_authoring_script(
      (
        #|{"schema": "docx.batch/2", "ops": [
        #|  {"op": "paragraph", "params": {"text": "Report", "style": "Heading1"}},
        #|  {"op": "paragraph", "params": {"runs": [
        #|    {"text": "bold ", "bold": true},
        #|    {"text": "and italic", "italic": true}
        #|  ]}},
        #|  {"op": "paragraph", "params": {"text": "bullet", "list": {"ordered": false, "level": 1}}},
        #|  {"op": "table", "params": {"rows": [[{"text": "A"}, {"text": "B"}]]}},
        #|  {"op": "paragraph", "params": {"runs": [
        #|    {"text": "cite"},
        #|    {"footnote": {"text": "a footnote"}}
        #|  ]}},
        #|  {"op": "comment", "params": {"on": 0, "text": "please revise", "author": "Ada"}}
        #|]}
      ),
    )
    let options = @transaction.create_transaction_options(output)
    let result = @docx.author_document(options, script, Map::new())
    assert_true(result.transaction.committed)
    assert_eq(result.report.comments, 1)
    assert_eq(result.report.footnotes, 1)
    guard published_part(output, "word/document.xml") is Some(document) else {
      fail("published document.xml missing")
    }
    assert_true(document.contains("Report"))
    assert_true(document.contains("bold "))
    // comment + footnote parts materialized
    assert_true(published_part(output, "word/comments.xml") is Some(_))
    assert_true(published_part(output, "word/footnotes.xml") is Some(_))
  }
}

///|
async test "create refuses an existing destination without overwrite" {
  with_annotation_dir() <| directory => {
    let output = directory + "/exists.docx"
    @afs.write_file(
      output,
      b"sentinel",
      create_mode=CreateNew,
      permission=0o600,
    )
    let options = @transaction.create_transaction_options(output)
    let failed = try {
      @docx.create_blank_document(options) |> ignore
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    // the pre-existing file is preserved byte-for-byte
    assert_eq(@afs.read_file(output).binary(), b"sentinel")
  }
}

///|
async test "author_document --dry-run validates without publishing" {
  with_annotation_dir() <| directory => {
    let output = directory + "/dry.docx"
    let script = @docx.parse_docx_authoring_script(
      (
        #|{"schema": "docx.batch/2", "ops": [
        #|  {"op": "paragraph", "params": {"text": "draft"}}
        #|]}
      ),
    )
    let options = @transaction.create_transaction_options(output, dry_run=true)
    let result = @docx.author_document(options, script, Map::new())
    assert_false(result.transaction.committed)
    assert_false(@afs.exists(output))
  }
}

///|
test "parse_docx_authoring_script rejects malformed input" {
  fn expect(text : String, fragment : String) -> Unit raise {
    try @docx.parse_docx_authoring_script(text) |> ignore catch {
      @docx.DocxAuthorParseError(message) =>
        assert_true(message.contains(fragment))
    } noraise {
      _ => fail("expected refusal: " + fragment)
    }
  }

  expect("{", "not valid JSON")
  // a comment op requires the /2 schema
  expect(
    (
      #|{"schema": "docx.batch/1", "ops": [{"op": "comment", "params": {"on": 0, "text": "x", "author": "A"}}]}
    ),
    "docx.batch/2",
  )
  // a non-whitelisted paragraph style is refused at parse
  expect(
    (
      #|{"schema": "docx.batch/2", "ops": [{"op": "paragraph", "params": {"text": "x", "style": "Title"}}]}
    ),
    "known styles",
  )
  // duplicate JSON keys are refused by the strict pre-scan
  expect(
    (
      #|{"schema": "docx.batch/2", "schema": "x", "ops": []}
    ),
    "repeats the key",
  )
}
