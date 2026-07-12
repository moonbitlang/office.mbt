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
        concurrent_destination: None,
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
        {
          fail_write: false,
          fail_rename: true,
          concurrent_replacement: None,
          concurrent_destination: None,
        },
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
          concurrent_destination: None,
        },
      )
    })
    assert_eq(code, "office.transaction.source_changed")
    assert_eq(@afs.read_file(input).binary(), concurrent)
    wb_assert_no_temp(directory)
  })
}

///|
async test "concurrent no-replace destination wins the race" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    let concurrent = wb_rewrite_content_types(original, "concurrent-output")
    wb_write(input, original)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input, output_path=output),
        (_format, bytes) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "candidate-output"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: false,
          fail_rename: false,
          concurrent_replacement: None,
          concurrent_destination: Some(concurrent),
        },
      )
    })
    assert_eq(code, "office.transaction.output_exists")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_eq(@afs.read_file(output).binary(), concurrent)
    wb_assert_no_temp(directory)
  })
}

///|
fn wb_archive(entries : Array[(String, Bytes)]) -> Bytes raise {
  let archive = @zip.Archive::new()
  for entry in entries {
    let (name, bytes) = entry
    archive.add(name, bytes)
  }
  @zip.write(archive)
}

///|
fn[T] wb_sync_error_code(run : () -> T raise TransactionError) -> String raise {
  try run() catch {
    TransactionError(code~, ..) => code
  } noraise {
    _ => fail("expected transaction failure")
  }
}

///|
test "preservation diff classifies every payload transition deterministically" {
  let original = wb_archive([
    ("removed.xml", b"old"),
    ("changed.xml", b"before"),
    ("unchanged.xml", b"same"),
  ])
  let candidate = wb_archive([
    ("added.xml", b"new"),
    ("changed.xml", b"after"),
    ("unchanged.xml", b"same"),
  ])
  let report = preservation_report(
    original,
    transaction_mutation_with_manifest(candidate, [
      "removed.xml", "changed.xml", "added.xml",
    ]),
  )
  assert_false(report.whole_file_identical)
  assert_true(report.manifest_enforced)
  assert_eq(report.changed.length(), 1)
  assert_eq(report.changed[0], "changed.xml")
  assert_eq(report.added.length(), 1)
  assert_eq(report.added[0], "added.xml")
  assert_eq(report.removed.length(), 1)
  assert_eq(report.removed[0], "removed.xml")
  assert_eq(report.unchanged.length(), 1)
  assert_eq(report.unchanged[0], "unchanged.xml")
}

///|
test "preservation comparison fails closed on invalid or undeclared archives" {
  let valid = wb_archive([("a.xml", b"a")])
  assert_eq(
    wb_sync_error_code(() => {
      preservation_report(b"not a zip", transaction_mutation(valid))
    }),
    "office.transaction.internal_validation_failure",
  )
  let added = wb_archive([("a.xml", b"a"), ("added.xml", b"added")])
  assert_eq(
    wb_sync_error_code(() => {
      preservation_report(valid, transaction_mutation_with_manifest(added, []))
    }),
    "office.transaction.preservation_violation",
  )
  assert_eq(
    wb_sync_error_code(() => {
      preservation_report(added, transaction_mutation_with_manifest(valid, []))
    }),
    "office.transaction.preservation_violation",
  )
}

///|
test "transaction output schema is deterministic and nests A2 warnings" {
  let report : TransactionReport = {
    format: Docx,
    input_path: "input.docx",
    output_path: "output.docx",
    mode: Output,
    dry_run: false,
    changed: true,
    committed: true,
    original_size: 10,
    result_size: 12,
    validations: ReadOnlyArray::from_array([
      { name: "office-portable-opc", passed: true, finding_count: 0 },
    ]),
    preservation: {
      whole_file_identical: false,
      manifest_enforced: true,
      changed: ReadOnlyArray::from_array(["word/document.xml"]),
      added: ReadOnlyArray::from_array([]),
      removed: ReadOnlyArray::from_array([]),
      unchanged: ReadOnlyArray::from_array(["[Content_Types].xml"]),
      zip_metadata_policy: "payload policy",
    },
    warnings: ReadOnlyArray::from_array([
      @office.protocol_warning("office.transaction.example", "example warning"),
    ]),
  }
  json_inspect(report.to_output(), content={
    "schema": "office.output/1",
    "success": true,
    "data": {
      "schema": "office.transaction/1",
      "format": "docx",
      "input": "input.docx",
      "output": "output.docx",
      "mode": "output",
      "dry_run": false,
      "changed": true,
      "committed": true,
      "original_size": 10,
      "result_size": 12,
      "validations": [
        { "name": "office-portable-opc", "passed": true, "finding_count": 0 },
      ],
      "preservation": {
        "whole_file_identical": false,
        "manifest_enforced": true,
        "changed": ["word/document.xml"],
        "added": [],
        "removed": [],
        "unchanged_count": 1,
        "zip_metadata_policy": "payload policy",
      },
    },
    "warnings": [
      { "code": "office.transaction.example", "message": "example warning" },
    ],
  })
}
