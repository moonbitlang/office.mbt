///|
async fn validate_xlsx_transaction_with_sdk(path : String) -> Unit {
  let (code, stdout, stderr) = @process.collect_output("bash", [
    "../scripts/validate_xlsx.sh", path,
  ])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-UTF-8 stdout>" }
    let err = stderr.text() catch { _ => "<non-UTF-8 stderr>" }
    fail(
      "OpenXML SDK validation failed (exit=\{code}) for \{path}\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
}

///|
async test "transactional XLSX create and batch outputs pass Microsoft OpenXML validation" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-xlsx-sdk-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let created = "\{directory}/created.xlsx"
    let batched = "\{directory}/batched.xlsx"
    let creation = @xlsx.create_workbook(
      @transaction.create_transaction_options(created),
      "Data",
    )
    assert_true(creation.transaction.committed)
    validate_xlsx_transaction_with_sdk(created)

    let script =
      #|{"schema":"xlsx.batch/1","ops":[
      #|  {"op":"set","params":{"sheet":"Data","cell":"A1","value":"Region"}},
      #|  {"op":"set","params":{"sheet":"Data","cell":"B1","value":"Sales"}},
      #|  {"op":"set","params":{"sheet":"Data","cell":"A2","value":"East"}},
      #|  {"op":"set","params":{"sheet":"Data","cell":"B2","value":120}},
      #|  {"op":"set","params":{"sheet":"Data","cell":"A3","value":"West"}},
      #|  {"op":"set","params":{"sheet":"Data","cell":"B3","value":87.5}},
      #|  {"op":"formula","params":{"sheet":"Data","cell":"B4","formula":"=SUM(B2:B3)"}},
      #|  {"op":"style","params":{"sheet":"Data","range":"A1:B1","bold":true,"fill":"4472C4","font_color":"FFFFFF","align":"center"}},
      #|  {"op":"width","params":{"sheet":"Data","column":"A:B","width":14}},
      #|  {"op":"freeze","params":{"sheet":"Data","cell":"A2"}},
      #|  {"op":"filter","params":{"sheet":"Data","range":"A1:B3"}},
      #|  {"op":"chart","params":{"sheet":"Data","anchor":"E2","type":"col","categories":"A2:A3","values":"B2:B3","name":"Sales","title":"By region"}},
      #|  {"op":"cf","params":{"sheet":"Data","range":"B2:B4","type":"3_color_scale","min_color":"F8696B","mid_color":"FFEB84","max_color":"63BE7B"}},
      #|  {"op":"row","params":{"sheet":"Data","action":"height","at":1,"height":22}},
      #|  {"op":"add-sheet","params":{"name":"Summary"}},
      #|  {"op":"set","params":{"sheet":"Summary","cell":"A1","value":"Item"}},
      #|  {"op":"set","params":{"sheet":"Summary","cell":"B1","value":"Count"}},
      #|  {"op":"table","params":{"sheet":"Summary","range":"A1:B4","name":"Items","style":"TableStyleMedium2"}},
      #|  {"op":"validate","params":{"sheet":"Summary","range":"D2:D20","type":"list","values":["Low","High"]}}
      #|]}
    let plan = @xlsx.parse_batch(@utf8.encode(script))
    let batch = @xlsx.transact_batch(
      @transaction.transaction_options(created, output_path=batched),
      plan,
    )
    assert_true(batch.transaction.committed)
    assert_eq(batch.stats.operation_count, 19)
    assert_true(
      batch.transaction
      .warning_records()
      .any(warning => warning.code == "office.xlsx.full_rewrite"),
    )
    validate_xlsx_transaction_with_sdk(batched)

    let reopened = @excel.read(@afs.read_file(batched).binary())
    assert_eq(reopened.get_cell("Data", "A2"), Some("East"))
    assert_eq(reopened.get_cell_formula("Data", "B4"), Some("SUM(B2:B3)"))
    assert_eq(reopened.get_sheet_list(), ["Data", "Summary"])
  }
}
