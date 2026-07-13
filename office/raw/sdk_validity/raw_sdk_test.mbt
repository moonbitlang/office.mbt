///|
let sdk_word_namespace = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

///|
let sdk_sheet_namespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

///|
async fn sdk_write_raw(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn validate_raw_with_sdk(script : String, path : String) -> Unit {
  let command = "../scripts/\{script} \"\{path}\""
  let (code, stdout, stderr) = @process.collect_output("bash", ["-lc", command])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-UTF-8 stdout>" }
    let err = stderr.text() catch { _ => "<non-UTF-8 stderr>" }
    fail(
      "OpenXML SDK validation failed (exit=\{code}) for \{path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
}

///|
async test "raw transaction outputs pass Microsoft OpenXML validation" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-raw-sdk-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }

    let docx_input = "\{directory}/input.docx"
    let docx_output = "\{directory}/output.docx"
    sdk_write_raw(docx_input, @word.new_blank_docx())
    let docx_request = @raw.raw_edit_request(
      "/document",
      "/w:document/w:body",
      Prepend,
      xml="<w:p xmlns:w=\"\{sdk_word_namespace}\"><w:r><w:t>raw sdk docx</w:t></w:r></w:p>",
    )
    let identifier = @transaction.transaction_identifier("raw-sdk-bounded", (
      path,
      bytes,
    ) => @raw.raw_identify(path, bytes))
    let docx_report = @transaction.transact(
      @transaction.transaction_options(docx_input, output_path=docx_output),
      (_format, bytes) => {
        let mutation = @raw.raw_edit(Docx, bytes, docx_request)
        @transaction.transaction_mutation_with_manifest(
          mutation.candidate_bytes(),
          [mutation.part_name()],
        )
      },
      identifier~,
    )
    assert_true(docx_report.committed)
    assert_true(
      @raw.raw_read(
        docx_output,
        @afs.read_file(docx_output).binary(),
        "/document",
      )
      .xml_text()
      .contains("raw sdk docx"),
    )
    validate_raw_with_sdk("validate_docx.sh", docx_output)

    let xlsx_input = "\{directory}/input.xlsx"
    let xlsx_output = "\{directory}/output.xlsx"
    sdk_write_raw(xlsx_input, @excel.write(@excel.new_file()))
    let xlsx_request = @raw.raw_edit_request(
      "/sheet[1]",
      "/x:worksheet/x:sheetData",
      Append,
      xml="<row xmlns=\"\{sdk_sheet_namespace}\" r=\"1\"><c r=\"A1\" t=\"inlineStr\"><is><t>raw sdk xlsx</t></is></c></row>",
    )
    let xlsx_report = @transaction.transact(
      @transaction.transaction_options(xlsx_input, output_path=xlsx_output),
      (_format, bytes) => {
        let mutation = @raw.raw_edit(Xlsx, bytes, xlsx_request)
        @transaction.transaction_mutation_with_manifest(
          mutation.candidate_bytes(),
          [mutation.part_name()],
        )
      },
      identifier~,
    )
    assert_true(xlsx_report.committed)
    assert_true(
      @raw.raw_read(
        xlsx_output,
        @afs.read_file(xlsx_output).binary(),
        "/sheet[1]",
      )
      .xml_text()
      .contains("raw sdk xlsx"),
    )
    validate_raw_with_sdk("validate_xlsx.sh", xlsx_output)
  }
}
