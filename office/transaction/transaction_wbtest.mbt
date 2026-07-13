///|
fn wb_rewrite_content_types(
  data : BytesView,
  marker : String,
  force_store? : Bool = false,
) -> Bytes raise {
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
      compression=if force_store { Store } else { entry.compression() },
      data_descriptor=entry.data_descriptor(),
    )
  }
  @zip.write(result)
}

///|
fn wb_large_candidate(data : BytesView) -> Bytes raise {
  let marker = StringBuilder::new()
  for _ in 0..<(2 * 1024 * 1024) {
    marker.write_char('x')
  }
  let candidate = wb_rewrite_content_types(
    data,
    marker.to_string(),
    force_store=true,
  )
  if candidate.length() <= 1024 * 1024 {
    fail(
      "large transaction candidate must cross the asynchronous write chunk boundary",
    )
  }
  candidate
}

///|
fn wb_archive_retained_cost(bytes : BytesView) -> Int64 raise {
  let archive = @zip.read(bytes)
  bytes.length().to_int64() + archive.retained_size_estimate()
}

///|
fn wb_archive_payload_bytes(bytes : BytesView) -> Int64 raise {
  let archive = @zip.read(bytes)
  let mut total = 0L
  for entry in archive.entries() {
    total = total + entry.data().length().to_int64()
  }
  total
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
    assert_false(name.contains(".office-output-tmp-"))
  }
}

///|
test "transaction path helpers accept host-native and portable separators" {
  let root = if @path.sep == '\\' { "C:\\office" } else { "/office" }
  let mixed = root + "/nested/input.docx"
  let expected_parent = path_text(@path.Path(root).join(Path("nested")))
  assert_eq(path_parent(mixed), expected_parent)
  assert_eq(path_leaf(mixed), "input.docx")
  assert_eq(
    join_path(expected_parent, "output.docx"),
    path_text(@path.Path(expected_parent).join(Path("output.docx"))),
  )
  if @path.sep == '\\' {
    assert_true(filesystem_path(mixed).has_prefix("\\\\?\\C:\\office\\nested"))
  }
}

///|
async fn wb_expect_post_read_cancellation(
  options : TransactionOptions,
  release : String,
) -> Unit {
  @async.with_task_group() <| group => {
    let task = group.spawn(() => {
      transact_with_faults(
        options,
        (_format, bytes, _archive) => transaction_mutation(bytes.to_owned()),
        [],
        no_transaction_faults(),
        post_read_release=release,
      )
    })
    while !@afs.exists(release + ".ready") {
      @async.pause()
    }
    task.cancel()
    wb_write(release, b"release")
    let propagated = try {
      ignore(task.wait())
      false
    } catch {
      error => @async.is_cancellation_error(error)
    }
    assert_true(propagated)
  }
}

///|
fn wb_preservation_report(
  original : BytesView,
  mutation : TransactionMutation,
) -> PreservationReport raise TransactionError {
  check_package_size(original, "input package")
  check_package_size(mutation.bytes, "candidate package")
  let original_archive = wb_read_transaction_archive_with_limits(
    original, "input package", "office.transaction.internal_validation_failure",
    transaction_max_archive_entries, transaction_max_entry_uncompressed_bytes, transaction_max_total_uncompressed_bytes,
  )
  let candidate_archive = wb_read_transaction_archive_with_limits(
    mutation.bytes,
    "candidate package",
    "office.transaction.internal_validation_failure",
    transaction_max_archive_entries,
    transaction_max_entry_uncompressed_bytes,
    transaction_max_total_uncompressed_bytes,
  )
  preservation_report_archives(
    original, mutation, original_archive, candidate_archive,
  )
}

///|
fn wb_read_transaction_archive_with_limits(
  bytes : BytesView,
  phase : String,
  invalid_code : String,
  max_entries : Int,
  max_entry_uncompressed_bytes : Int,
  max_total_uncompressed_bytes : Int,
) -> @zip.Archive raise TransactionError {
  @zip.read_limited(
    bytes,
    max_entries~,
    max_entry_uncompressed_bytes~,
    max_total_uncompressed_bytes~,
  ) catch {
    ResourceLimitExceeded(kind~, limit~, actual~) =>
      raise resource_limit_error(phase, kind, limit, actual)
    _ =>
      raise transaction_error(
        invalid_code,
        "unreadable bounded ZIP package during " + phase,
      )
  }
}

///|
async test "pending read cancellation reaches dry-run and no-op paths" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    wb_write(input, @word.new_blank_docx())
    wb_expect_post_read_cancellation(
      transaction_options(input),
      "\{directory}/release-noop",
    )
    wb_expect_post_read_cancellation(
      transaction_options(input, dry_run=true),
      "\{directory}/release-dry-run",
    )
    wb_assert_no_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "staging access survives restrictive creation modes" {
  wb_with_transaction_dir(directory => {
    let publication_directory : PublicationDirectory = { path: directory }
    let temp = match
      publication_temp_try_create(
        publication_directory,
        ".office-tmp-restrictive",
        "\{directory}/output.docx",
        initial_permission=0o000,
      ) {
      Some(value) => value
      None => fail("expected unique staging file")
    }
    publication_temp_write(
      temp,
      b"payload",
      fail_after_bytes=None,
      stall_after_bytes=None,
    )
    publication_temp_sync(temp)
    assert_true(publication_temp_identity_matches(temp))
    publication_temp_cleanup(temp, "\{directory}/output.docx")
    wb_assert_no_temp(directory)
  })
}

///|
async test "initial staging cleanup failures are never hidden" {
  wb_with_transaction_dir(directory => {
    let publication_directory : PublicationDirectory = { path: directory }
    let leaf = ".office-tmp-initial-cleanup"
    let output = "\{directory}/output.docx"
    let code = try {
      ignore(
        publication_temp_try_create(
          publication_directory,
          leaf,
          output,
          fail_secure_permission=true,
          fail_cleanup=true,
        ),
      )
      fail("expected initial staging cleanup failure")
    } catch {
      TransactionError(code~, ..) => code
      error => fail("expected TransactionError, received \{error}")
    }
    assert_eq(code, "office.transaction.cleanup_failed")
    let retained = "\{directory}/\{leaf}"
    assert_true(@afs.exists(retained))
    @afs.remove(retained)
    wb_assert_no_temp(directory)
  })
}

///|
async test "initial staging cleanup re-observes pending cancellation" {
  wb_with_transaction_dir(directory => {
    let publication_directory : PublicationDirectory = { path: directory }
    let release = "\{directory}/secure-release"
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        publication_temp_try_create(
          publication_directory,
          ".office-tmp-cancelled-secure",
          "\{directory}/output.docx",
          fail_secure_permission=true,
          secure_release=release,
        )
      })
      while !@afs.exists(release + ".ready") {
        @async.pause()
      }
      task.cancel()
      wb_write(release, b"release")
      let propagated = try {
        ignore(task.wait())
        false
      } catch {
        error => @async.is_cancellation_error(error)
      }
      assert_true(propagated)
    }
    wb_assert_no_temp(directory)
  })
}

///|
async test "atomic new output is exact and create-new" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/payload.bin"
    let payload = b"exact raw payload"
    atomic_write_new(output, payload)
    assert_eq(@afs.read_file(output).binary(), payload)
    let code = try {
      atomic_write_new(output, b"replacement")
      fail("expected existing output to fail")
    } catch {
      TransactionError(code~, ..) => code
      error => fail("expected TransactionError, received \{error}")
    }
    assert_eq(code, "office.transaction.output_exists")
    assert_eq(@afs.read_file(output).binary(), payload)
    wb_assert_no_temp(directory)
  })
}

///|
async test "atomic new output removes staging after write failure" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/payload.bin"
    let code = try {
      atomic_write_new_with_faults(
        output,
        b"partial payload",
        0o600,
        fail_after_bytes=1,
      )
      fail("expected injected write failure")
    } catch {
      TransactionError(code~, ..) => code
      error => fail("expected TransactionError, received \{error}")
    }
    assert_eq(code, "office.transaction.write_failed")
    assert_false(@afs.exists(output))
    wb_assert_no_temp(directory)
  })
}

///|
async test "atomic new output cancellation cleans partial staging" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/payload.bin"
    let payload = Bytes::make(2 * 1024 * 1024, b'x')
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        atomic_write_new_with_faults(
          output,
          payload,
          0o600,
          stall_after_bytes=1024 * 1024,
        )
      })
      let mut observed_partial_write = false
      for _ in 0..<1_000 {
        for name in @afs.readdir(directory) {
          if name.contains(".office-output-tmp-") {
            let file = @afs.open(
              "\{directory}/\{name}",
              mode=ReadOnly,
              create_mode=OpenExisting,
              sync=NoSync,
            ) catch {
              _ => continue
            }
            let size = file.size() catch {
              _ => {
                file.close()
                continue
              }
            }
            file.close()
            if size >= (1024 * 1024).to_int64() {
              observed_partial_write = true
            }
          }
        }
        if observed_partial_write {
          break
        }
        @async.pause()
      }
      assert_true(observed_partial_write)
      task.cancel()
      let propagated = try {
        ignore(task.wait())
        false
      } catch {
        error => @async.is_cancellation_error(error)
      }
      assert_true(propagated)
    }
    assert_false(@afs.exists(output))
    wb_assert_no_temp(directory)
  })
}

///|
async test "atomic new output returns success after observed rename" {
  wb_with_transaction_dir(directory => {
    let output = "\{directory}/payload.bin"
    let release = "\{directory}/post-rename-release"
    let payload = b"committed payload"
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        atomic_write_new_with_faults(
          output,
          payload,
          0o600,
          post_rename_release=release,
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
      task.wait()
    }
    assert_eq(@afs.read_file(output).binary(), payload)
    wb_assert_no_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "rename failure restores restrictive staging access for cleanup" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input, output_path=output, permission=0o000),
        (_format, bytes, _archive) => transaction_mutation(bytes.to_owned()),
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
          fail_rename: false,
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: Some(original),
          relocate_parent_to: None,
          deny_cleanup: false,
        },
      )
    })
    assert_eq(code, "office.transaction.output_exists")
    @afs.chmod(output, 0o600)
    assert_eq(@afs.read_file(output).binary(), original)
    wb_assert_no_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "destination inspection permission errors remain structured" {
  wb_with_transaction_dir(directory => {
    let locked = "\{directory}/locked"
    @afs.mkdir(locked, permission=0o700)
    let publication_directory : PublicationDirectory = { path: locked }
    @afs.chmod(locked, 0o000)
    let code = try {
      ignore(
        publication_entry_kind(
          publication_directory,
          "output.docx",
          "\{locked}/output.docx",
        ),
      )
      "no-error"
    } catch {
      TransactionError(code~, ..) => code
      _ => "unstructured-error"
    }
    @afs.chmod(locked, 0o700)
    assert_eq(code, "office.transaction.destination_check_failed")
  })
}

///|
async test "injected write and rename failures clean temporary artifacts" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    let mutate = (_format, bytes, _archive) => {
      transaction_mutation_with_manifest(
        wb_rewrite_content_types(bytes, "fault"),
        ["[Content_Types].xml"],
      )
    }
    let write_code = wb_error_code(() => {
      transact_with_faults(transaction_options(input), mutate, [], {
        fail_write: true,
        fail_write_after_bytes: None,
        stall_write_after_bytes: None,
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
    let partial_code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input),
        (_format, bytes, _archive) => {
          transaction_mutation_with_manifest(wb_large_candidate(bytes), [
            "[Content_Types].xml",
          ])
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: Some(1024 * 1024),
          stall_write_after_bytes: None,
          fail_rename: false,
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: None,
          relocate_parent_to: None,
          deny_cleanup: false,
        },
      )
    })
    assert_eq(partial_code, "office.transaction.write_failed")
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
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
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
    let candidate = wb_large_candidate(original)
    wb_write(input, original)
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        transact_with_faults(
          transaction_options(input),
          (_format, _bytes, _archive) => {
            transaction_mutation_with_manifest(candidate, [
              "[Content_Types].xml",
            ])
          },
          [],
          {
            fail_write: false,
            fail_write_after_bytes: None,
            stall_write_after_bytes: Some(1024 * 1024),
            fail_rename: false,
            stall_after_temp: false,
            post_rename_release: None,
            concurrent_replacement: None,
            concurrent_destination: None,
            relocate_parent_to: None,
            deny_cleanup: false,
          },
        )
      })
      let mut observed_partial_write = false
      for _ in 0..<1_000 {
        for name in @afs.readdir(directory) {
          if name.contains(".office-tmp-") {
            let temp_path = "\{directory}/\{name}"
            let file = @afs.open(
              temp_path,
              mode=ReadOnly,
              create_mode=OpenExisting,
              sync=NoSync,
            ) catch {
              _ => continue
            }
            let size = file.size() catch {
              _ => {
                file.close()
                continue
              }
            }
            file.close()
            if size >= (1024 * 1024).to_int64() {
              observed_partial_write = true
            }
          }
        }
        if observed_partial_write {
          break
        }
        @async.pause()
      }
      assert_true(observed_partial_write)
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
async test "cancellation during ordinary-failure cleanup is re-observed" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let release = "\{directory}/cleanup-release"
    let original = @word.new_blank_docx()
    wb_write(input, original)
    @async.with_task_group() <| group => {
      let task = group.spawn(() => {
        transact_with_faults(
          transaction_options(input, output_path=output),
          (_format, bytes, _archive) => transaction_mutation(bytes.to_owned()),
          [],
          {
            fail_write: true,
            fail_write_after_bytes: None,
            stall_write_after_bytes: None,
            fail_rename: false,
            stall_after_temp: false,
            post_rename_release: None,
            concurrent_replacement: None,
            concurrent_destination: None,
            relocate_parent_to: None,
            deny_cleanup: false,
          },
          cleanup_release=release,
        )
      })
      while !@afs.exists(release + ".ready") {
        @async.pause()
      }
      task.cancel()
      wb_write(release, b"release")
      let propagated = try {
        ignore(task.wait())
        false
      } catch {
        error => @async.is_cancellation_error(error)
      }
      assert_true(propagated)
    }
    assert_eq(@afs.read_file(input).binary(), original)
    assert_false(@afs.exists(output))
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
          (_format, _bytes, _archive) => {
            transaction_mutation_with_manifest(candidate, [
              "[Content_Types].xml",
            ])
          },
          [],
          {
            fail_write: false,
            fail_write_after_bytes: None,
            stall_write_after_bytes: None,
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
        (_format, bytes, _archive) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "candidate"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
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
        (_format, bytes, _archive) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "candidate-output"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
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
async test "async publication fails closed when parent relocation is attempted" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let destination_directory = "\{directory}/destination"
    let relocated_directory = "\{directory}/relocated"
    let output = "\{destination_directory}/output.docx"
    let original = @word.new_blank_docx()
    let candidate = wb_rewrite_content_types(original, "pinned-parent")
    wb_write(input, original)
    @afs.mkdir(destination_directory)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input, output_path=output),
        (_format, _bytes, _archive) => {
          transaction_mutation_with_manifest(candidate, ["[Content_Types].xml"])
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
          fail_rename: false,
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: None,
          concurrent_destination: None,
          relocate_parent_to: Some(relocated_directory),
          deny_cleanup: false,
        },
      )
    })
    if @path.sep == '\\' {
      // Windows rejects renaming a directory while the transaction holds an
      // open child staging handle. The fault must fail before publication and
      // the staging file must still be cleaned from the original directory.
      assert_eq(code, "office.transaction.commit_failed")
      assert_true(@afs.exists(destination_directory))
      wb_assert_no_temp(destination_directory)
    } else {
      assert_eq(code, "office.transaction.cleanup_failed")
      assert_false(@afs.exists(destination_directory))
    }
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
  })
}

///|
#cfg(target="native")
async test "async in-place recheck fails closed on source-parent relocation" {
  wb_with_transaction_dir(directory => {
    let source_directory = "\{directory}/source"
    let relocated_directory = "\{directory}/relocated-source"
    let input = "\{source_directory}/input.docx"
    let relocated_input = "\{relocated_directory}/input.docx"
    let original = @word.new_blank_docx()
    let candidate = wb_rewrite_content_types(original, "pinned-source")
    let decoy = wb_rewrite_content_types(original, "replacement-decoy")
    @afs.mkdir(source_directory)
    wb_write(input, original)
    let code = wb_error_code(() => {
      transact_with_faults(
        transaction_options(input),
        (_format, _bytes, _archive) => {
          transaction_mutation_with_manifest(candidate, ["[Content_Types].xml"])
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
          fail_rename: false,
          stall_after_temp: false,
          post_rename_release: None,
          concurrent_replacement: Some(decoy),
          concurrent_destination: None,
          relocate_parent_to: Some(relocated_directory),
          deny_cleanup: false,
        },
      )
    })
    if @path.sep == '\\' {
      // As above, Windows denies the injected directory rename while the
      // staging child is open, so no replacement source is created.
      assert_eq(code, "office.transaction.commit_failed")
      assert_false(@afs.exists(relocated_input))
      assert_eq(@afs.read_file(input).binary(), original)
    } else {
      assert_eq(code, "office.transaction.cleanup_failed")
      assert_eq(@afs.read_file(relocated_input).binary(), original)
      assert_eq(@afs.read_file(input).binary(), decoy)
    }
    wb_assert_no_temp(source_directory)
  })
}

///|
async test "temporary substitution is never published or silently cleaned" {
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
        (_format, bytes, _archive) => {
          transaction_mutation_with_manifest(
            wb_rewrite_content_types(bytes, "cleanup-failure"),
            ["[Content_Types].xml"],
          )
        },
        [],
        {
          fail_write: false,
          fail_write_after_bytes: None,
          stall_write_after_bytes: None,
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
      wb_read_transaction_archive_with_limits(
        expanded, "candidate package", "office.transaction.validation_failed", 1,
        4, 4,
      )
      |> ignore
    }),
    "office.transaction.resource_limit_exceeded",
  )
}

///|
async test "aggregate materialization budget rejects candidate without publication" {
  wb_with_transaction_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    let candidate = wb_rewrite_content_types(original, "x".repeat(256 * 1024))
    wb_write(input, original)
    let original_cost = wb_archive_retained_cost(original)
    let candidate_payload = wb_archive_payload_bytes(candidate)
    let candidate_preflight = transaction_archive_preflight_overhead(candidate)
    // The candidate fits this injected limit by itself, but not while the
    // original archive remains live. This distinguishes a transaction-wide
    // budget from independent per-parse limits without a giant test fixture.
    let live_limit = candidate_preflight +
      candidate_payload +
      original_cost / 2L
    assert_true(live_limit - candidate_preflight >= candidate_payload)
    assert_true(
      live_limit - original_cost - candidate_preflight < candidate_payload,
    )
    ignore(
      read_transaction_archive(
        candidate, "isolated candidate", "office.transaction.validation_failed",
        0L, live_limit,
      ),
    )
    let failure = try {
      ignore(
        transact_with_identifier_and_faults(
          transaction_options(input, output_path=output),
          (_format, _bytes, _archive) => {
            transaction_mutation_with_manifest(candidate, [
              "[Content_Types].xml",
            ])
          },
          [],
          None,
          no_transaction_faults(),
          materialization_limit=live_limit,
          materialization_reserve=0L,
        ),
      )
      fail("expected aggregate materialization rejection")
    } catch {
      TransactionError(..) as error => error
      error => fail("expected TransactionError, received \{error}")
    }
    match failure {
      TransactionError(code~, details~, ..) => {
        assert_eq(code, "office.transaction.resource_limit_exceeded")
        match details {
          Some(Object(fields)) => {
            assert_eq(
              fields.get("phase"),
              Some(Json::string("candidate package")),
            )
            assert_eq(
              fields.get("kind"),
              Some(Json::string("live_materialized_bytes")),
            )
          }
          _ => fail("expected structured materialization details")
        }
      }
    }
    assert_eq(@afs.read_file(input).binary(), original)
    assert_false(@afs.exists(output))
    wb_assert_no_temp(directory)
  })
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
