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
async fn wb_error_code(run : async () -> TransactionReport) -> String {
  try run() catch {
    TransactionError(code~, ..) => code
    error => fail("expected TransactionError, received \{error}")
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
fn wb_preservation_report(
  original : BytesView,
  mutation : TransactionMutation,
) -> PreservationReport raise TransactionError {
  check_package_size(original, "input package")
  check_package_size(mutation.bytes, "candidate package")
  let original_archive = read_transaction_archive(
    original, "input package", "office.transaction.internal_validation_failure",
  )
  let candidate_archive = read_transaction_archive(
    mutation.bytes,
    "candidate package",
    "office.transaction.internal_validation_failure",
  )
  preservation_report_archives(
    original, mutation, original_archive, candidate_archive,
  )
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
        stall_after_temp: false,
        post_rename_release: None,
        concurrent_replacement: None,
        concurrent_destination: None,
        relocate_parent_to: None,
        deny_cleanup: false,
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
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: None,
          relocate_parent_to: None,
          deny_cleanup: false,
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
async test "task cancellation waits for temporary-file cleanup" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        transact_with_faults(
          transaction_options(input),
          (_format, bytes) => {
            transaction_mutation_with_manifest(
              wb_rewrite_content_types(bytes, "cancelled"),
              ["[Content_Types].xml"],
            )
          },
          [],
          {
            fail_write: false,
            fail_rename: false,
            stall_after_temp: true,
            post_rename_release: None,
            concurrent_replacement: None,
            concurrent_destination: None,
            relocate_parent_to: None,
            deny_cleanup: false,
          },
        )
      })
      let mut observed_temp = false
      for _ in 0..<1_000 {
        for name in @afs.readdir(directory) {
          if name.contains(".office-tmp-") {
            observed_temp = true
          }
        }
        if observed_temp {
          break
        }
        @async.pause()
      }
      assert_true(observed_temp)
      task.cancel()
      let propagated = try {
        ignore(task.wait())
        false
      } catch {
        error => @async.is_cancellation_error(error)
      }
      assert_true(propagated)
    }
    assert_eq(@afs.read_file(input).binary(), original)
    wb_assert_no_temp(directory)
  })
}

///|
async test "post-rename cancellation still returns a committed report" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let release = "\{directory}/release"
    let original = @word.new_blank_docx()
    let candidate = wb_rewrite_content_types(original, "committed")
    wb_write(input, original)
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        transact_with_faults(
          transaction_options(input, output_path=output),
          (_format, _bytes) => {
            transaction_mutation_with_manifest(candidate, [
              "[Content_Types].xml",
            ])
          },
          [],
          {
            fail_write: false,
            fail_rename: false,
            stall_after_temp: false,
            post_rename_release: Some(release),
            concurrent_replacement: None,
            concurrent_destination: None,
            relocate_parent_to: None,
            deny_cleanup: false,
          },
        )
      })
      let mut observed_commit = false
      for _ in 0..<1_000 {
        if @afs.exists(output) {
          observed_commit = true
          break
        }
        @async.pause()
      }
      assert_true(observed_commit)
      task.cancel()
      wb_write(release, b"release")
      let report = task.wait()
      assert_true(report.committed)
      assert_true(report.changed)
    }
    assert_eq(@afs.read_file(input).binary(), original)
    assert_eq(@afs.read_file(output).binary(), candidate)
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
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: Some(concurrent),
          concurrent_destination: None,
          relocate_parent_to: None,
          deny_cleanup: false,
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
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: Some(concurrent),
          relocate_parent_to: None,
          deny_cleanup: false,
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
#cfg(target="native")
async test "native publication stays bound to a relocated parent directory" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let destination_directory = "\{directory}/destination"
    let relocated_directory = "\{directory}/relocated"
    let output = "\{destination_directory}/output.docx"
    let relocated_output = "\{relocated_directory}/output.docx"
    let original = @word.new_blank_docx()
    let candidate = wb_rewrite_content_types(original, "pinned-parent")
    wb_write(input, original)
    @afs.mkdir(destination_directory)
    let report = transact_with_faults(
      transaction_options(input, output_path=output),
      (_format, _bytes) => {
        transaction_mutation_with_manifest(candidate, ["[Content_Types].xml"])
      },
      [],
      {
        fail_write: false,
        fail_rename: false,
        stall_after_temp: false,
        post_rename_release: None,
        concurrent_replacement: None,
        concurrent_destination: None,
        relocate_parent_to: Some(relocated_directory),
        deny_cleanup: false,
      },
    )
    assert_true(report.committed)
    assert_false(@afs.exists(destination_directory))
    assert_eq(@afs.read_file(relocated_output).binary(), candidate)
    assert_eq(@afs.read_file(input).binary(), original)
    wb_assert_no_temp(relocated_directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native cleanup failures are surfaced and remain recoverable" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let destination_directory = "\{directory}/destination"
    let output = "\{destination_directory}/output.docx"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    @afs.mkdir(destination_directory)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input, output_path=output),
        (_format, bytes) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "cleanup-failure"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: true,
          fail_rename: false,
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: None,
          relocate_parent_to: None,
          deny_cleanup: true,
        },
      )
    })
    @afs.chmod(destination_directory, 0o700)
    assert_eq(code, "office.transaction.cleanup_failed")
    for name in @afs.readdir(destination_directory) {
      if name.contains(".office-tmp-") {
        @afs.remove("\{destination_directory}/\{name}")
      }
    }
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    wb_assert_no_temp(destination_directory)
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
  let report = wb_preservation_report(
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
      wb_preservation_report(b"not a zip", transaction_mutation(valid))
    }),
    "office.transaction.internal_validation_failure",
  )
  let added = wb_archive([("a.xml", b"a"), ("added.xml", b"added")])
  assert_eq(
    wb_sync_error_code(() => {
      wb_preservation_report(
        valid,
        transaction_mutation_with_manifest(added, []),
      )
    }),
    "office.transaction.preservation_violation",
  )
  assert_eq(
    wb_sync_error_code(() => {
      wb_preservation_report(
        added,
        transaction_mutation_with_manifest(valid, []),
      )
    }),
    "office.transaction.preservation_violation",
  )
}

///|
test "transaction package and archive materialization limits fail closed" {
  assert_eq(
    wb_sync_error_code(() => {
      check_package_size_with_limit(b"1234", "candidate package", 3)
    }),
    "office.transaction.resource_limit_exceeded",
  )
  let expanded = wb_archive([("large.xml", b"12345678")])
  assert_eq(
    wb_sync_error_code(() => {
      read_transaction_archive_with_limits(
        expanded, "candidate package", "office.transaction.validation_failed", 1,
        4, 4,
      )
      |> ignore
    }),
    "office.transaction.resource_limit_exceeded",
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
