///|
fn wb_rewrite_content_types(data : BytesView, marker : String) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    let payload = if entry.name() == "[Content_Types].xml" {
      let text = @utf8.decode(entry.data(), ignore_bom=true)
      @utf8.encode(text.replace(old="</Types>", new="<!--\{marker}--></Types>"))
    } else {
      entry.data()
    }
    result.add(
      entry.name(),
      payload,
      compression=entry.compression(),
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
async fn wb_with_transaction_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-transaction-wb-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
async fn wb_write(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn wb_error_code(
  run : async () -> TransactionReport raise TransactionError,
) -> String {
  try run() catch {
    TransactionError(code~, ..) => code
  } noraise {
    _ => fail("expected transaction failure")
  }
}

///|
async fn wb_assert_no_temp(directory : String) -> Unit {
  for name in @afs.readdir(directory) {
    assert_false(name.contains(".office-tmp-"))
  }
}

///|
async test "injected write and rename failures clean temporary artifacts" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    let mutate = (_format, bytes) => {
      transaction_mutation_with_manifest(
        wb_rewrite_content_types(bytes, "fault"),
        ["[Content_Types].xml"],
      )
    }
    let write_code = wb_error_code(() => {
      transact_with_faults(transaction_options(input), mutate, [], {
        fail_write: true,
        fail_rename: false,
        concurrent_replacement: None,
      })
    })
    assert_eq(write_code, "office.transaction.write_failed")
    assert_eq(@afs.read_file(input).binary(), original)
    wb_assert_no_temp(directory)
    wb_write(output, original)
    let rename_code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input, output_path=output, overwrite=true),
        mutate,
        [],
        { fail_write: false, fail_rename: true, concurrent_replacement: None },
      )
    })
    assert_eq(rename_code, "office.transaction.commit_failed")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_eq(@afs.read_file(output).binary(), original)
    wb_assert_no_temp(directory)
  })
}

///|
async test "concurrent in-place source change is never overwritten" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    let concurrent = wb_rewrite_content_types(original, "concurrent")
    wb_write(input, original)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input),
        (_format, bytes) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "candidate"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: false,
          fail_rename: false,
          concurrent_replacement: Some(concurrent),
        },
      )
    })
    assert_eq(code, "office.transaction.source_changed")
    assert_eq(@afs.read_file(input).binary(), concurrent)
    wb_assert_no_temp(directory)
  })
}
