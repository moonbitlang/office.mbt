///|
fn sdk_rewrite_content_types(data : BytesView, marker : String) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  let mut replaced = false
  for entry in source.entries() {
    let payload = if entry.name() == "[Content_Types].xml" {
      let text = @utf8.decode(entry.data(), ignore_bom=true)
      let updated = text.replace(old="</Types>", new="<!--\{marker}--></Types>")
      if updated == text {
        fail("fixture content types did not contain a closing Types element")
      }
      replaced = true
      @utf8.encode(updated)
    } else {
      entry.data().to_owned()
    }
    result.add(
      entry.name(),
      payload,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  if !replaced {
    fail("fixture did not contain [Content_Types].xml")
  }
  @zip.write(result)
}

///|
async fn sdk_write(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn validate_with_sdk(script : String, path : String) -> Unit {
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
async test "transaction-published DOCX and XLSX pass Microsoft OpenXML validation" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-transaction-sdk-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let docx_input = "\{directory}/input.docx"
    let docx_output = "\{directory}/output.docx"
    sdk_write(docx_input, @word.new_blank_docx())
    let docx_report = @transaction.transact(
      @transaction.transaction_options(docx_input, output_path=docx_output),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation_with_manifest(
          sdk_rewrite_content_types(bytes, "transaction-docx"),
          ["[Content_Types].xml"],
        )
      },
    )
    assert_true(docx_report.committed)
    validate_with_sdk("validate_docx.sh", docx_output)
    let xlsx_input = "\{directory}/input.xlsx"
    let xlsx_output = "\{directory}/output.xlsx"
    sdk_write(xlsx_input, @excel.write(@excel.new_file()))
    let xlsx_report = @transaction.transact(
      @transaction.transaction_options(xlsx_input, output_path=xlsx_output),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation_with_manifest(
          sdk_rewrite_content_types(bytes, "transaction-xlsx"),
          ["[Content_Types].xml"],
        )
      },
    )
    assert_true(xlsx_report.committed)
    validate_with_sdk("validate_xlsx.sh", xlsx_output)
  }
}
