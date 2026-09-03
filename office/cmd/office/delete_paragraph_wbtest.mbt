// The delete-paragraph verb's record contract and budget helper.

///|
/// A REAL report from a real transaction, so the record test exercises
/// the exact object the CLI would emit.
async fn delete_paragraph_wbtest_report() -> (
  @office_docx.DocxDeleteParagraphReport,
  Bool,
  Json,
) {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-delp-wbtest-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // Rebuild the real fixture with a second paragraph so the first is
    // deletable (the fixture's own single paragraph is document-final).
    let source_bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
    ).binary()
    let archive = @zip.read(source_bytes)
    let rebuilt = @zip.Archive()
    for entry in archive.entries() {
      let entry_name = entry.name()
      guard archive.get(entry_name) is Some(payload) else { continue }
      let replaced = if entry_name == "word/document.xml" {
        let text = @utf8.decode(payload)
        @utf8.encode(
          text.replace(
            old="<w:r><w:t>Walking on imported air</w:t></w:r>",
            new="<w:r><w:t>doomed</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r>",
          ),
        )
      } else {
        payload.to_owned()
      }
      rebuilt.add(entry_name, replaced)
    }
    let input = directory + "/in.docx"
    @afs.write_file(
      input,
      @zip.write_preserving(rebuilt),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/out.docx"
    let result = @office_docx.transact_docx_delete_paragraph(
      @transaction.transaction_options(input, output_path=output),
      at="p[1]",
      expect_text="doomed",
    )
    (
      result.report(),
      result.transaction().changed,
      result.transaction().to_json(),
    )
  }
}

///|
/// The capability registry is the contract: the result record may emit
/// only declared keys, and must emit every required one.
async test "delete-paragraph result record declares every field it emits" {
  guard @lib.find_capability_command("delete-paragraph") is Some(command) else {
    fail("expected the delete-paragraph capability")
  }
  let declared = command.outputs.map(field => field.name)
  let (report, changed, transaction) = delete_paragraph_wbtest_report()
  let record = delete_paragraph_report_json(
    "in.docx",
    "out.docx",
    "p[1]",
    Some("doomed"),
    false,
    report,
    changed,
    transaction~,
  )
  guard record is Object(fields) else { fail("expected an object record") }
  for name, _ in fields {
    if !declared.contains(name) {
      fail("undeclared output: " + name)
    }
  }
  for field in command.outputs {
    if field.required && !fields.contains(field.name) {
      fail("missing required output: " + field.name)
    }
  }
  assert_eq(
    fields.get("schema"),
    Some(Json::string("office.docx.delete-paragraph/1")),
  )
  assert_eq(fields.get("format"), Some(Json::string("docx")))
  assert_eq(fields.get("changed"), Some(Json::boolean(true)))
  guard fields.get("deleted") is Some(Object(deleted)) else {
    fail("expected the deleted object")
  }
  assert_eq(deleted.get("path"), Some(Json::string("p[1]")))
  assert_eq(deleted.get("text"), Some(Json::string("doomed")))
  assert_true(deleted.contains("para_id"))
  assert_true(deleted.contains("paragraph_anchor_status"))
}

///|
test "delete-paragraph report budget refuses only over-ceiling records" {
  let small : Json = Json::object({ "note": Json::string("fits") })
  ensure_delete_paragraph_report_budget(small, 4096)
  let mut text = "x"
  while text.length() < 2048 {
    text = text + text
  }
  let fat : Json = Json::object({ "note": Json::string(text) })
  try {
    ensure_delete_paragraph_report_budget(fat, 1024)
    fail("expected the budget refusal")
  } catch {
    error => {
      let message = "\{error}"
      assert_true(
        message.contains("office.delete.report_too_large"),
        msg="got '" + message + "'",
      )
      assert_true(message.contains("nothing was written"))
    }
  }
}
