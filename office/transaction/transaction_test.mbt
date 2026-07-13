///|
fn rewrite_content_types(data : BytesView, marker : String) -> Bytes raise {
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
      entry.data()
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
suberror MutationProbeError {
  MutationProbeError
}

///|
suberror ValidatorProbeError {
  ValidatorProbeError
}

///|
async fn with_transaction_test_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-transaction-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
async fn write_test_file(path : String, bytes : Bytes) -> Unit {
  @afs.write_file(path, bytes, create_mode=CreateNew, permission=0o600)
}

///|
async fn assert_no_transaction_temp(directory : String) -> Unit {
  for name in @afs.readdir(directory) {
    assert_false(name.contains(".office-tmp-"))
  }
}

///|
async fn transaction_error_code(
  run : async () -> @transaction.TransactionReport,
) -> String {
  try run() catch {
    @transaction.TransactionError(code~, ..) => code
    error => fail("expected TransactionError, received \{error}")
  } noraise {
    _ => fail("expected transaction failure")
  }
}

///|
async fn transaction_error_value(
  run : async () -> @transaction.TransactionReport,
) -> @transaction.TransactionError {
  try run() catch {
    @transaction.TransactionError(..) as error => error
    error => fail("expected TransactionError, received \{error}")
  } noraise {
    _ => fail("expected transaction failure")
  }
}

///|
async test "in-place no-op validates without replacing source" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
    )
    assert_eq(report.format, Docx)
    assert_eq(report.mode, InPlace)
    assert_false(report.changed)
    assert_false(report.committed)
    assert_true(report.preservation.whole_file_identical)
    assert_eq(report.validations.length(), 1)
    assert_eq(report.validations[0].name, "office-portable-opc")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "dry-run performs mutation validation and preservation without output" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output, dry_run=true),
      (_format, bytes) => {
        @transaction.transaction_mutation_with_manifest(
          rewrite_content_types(bytes, "dry-run"),
          ["[Content_Types].xml"],
        )
      },
    )
    assert_true(report.changed)
    assert_false(report.committed)
    assert_true(report.dry_run)
    assert_eq(report.preservation.changed.length(), 1)
    assert_eq(report.preservation.changed[0], "[Content_Types].xml")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "separate output commits atomically and preserves input" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output),
      (_format, bytes) => {
        @transaction.transaction_mutation_with_manifest(
          rewrite_content_types(bytes, "output"),
          ["[Content_Types].xml"],
          warnings=[
            @office.protocol_warning(
              "office.transaction.test-warning", "test mutation warning",
            ),
          ],
        )
      },
    )
    let written = @afs.read_file(output).binary()
    assert_true(report.changed)
    assert_true(report.committed)
    assert_eq(report.mode, Output)
    assert_eq(@office.detect_format(output, written), Docx)
    assert_eq(@afs.read_file(input).binary(), original)
    assert_true(
      report.to_output().stringify().contains("office.transaction.test-warning"),
    )
    assert_no_transaction_temp(directory)
  })
}

///|
async test "near-limit destination basenames do not inflate temporary names" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/\{"x".repeat(240)}.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
    )
    assert_true(report.committed)
    assert_eq(@afs.read_file(output).binary(), original)
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "byte-identical separate output still publishes a validated copy" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.xlsx"
    let output = "\{directory}/copy.xlsx"
    let original = @excel.write(@excel.new_file())
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
    )
    assert_false(report.changed)
    assert_true(report.committed)
    assert_eq(@afs.read_file(output).binary(), original)
    assert_eq(@office.detect_format(output, original), Xlsx)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "in-place changed transaction validates before atomic replacement" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input),
      (_format, bytes) => {
        @transaction.transaction_mutation_with_manifest(
          rewrite_content_types(bytes, "in-place"),
          ["[Content_Types].xml"],
        )
      },
    )
    let written = @afs.read_file(input).binary()
    assert_true(report.changed)
    assert_true(report.committed)
    assert_true(written != original)
    assert_eq(@office.detect_format(input, written), Docx)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "existing output and input aliases are refused before mutation" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    write_test_file(output, original)
    let mut called = false
    let exists_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes) => {
          called = true
          @transaction.transaction_mutation(bytes.to_owned())
        },
      )
    })
    assert_eq(exists_code, "office.transaction.output_exists")
    assert_false(called)
    let alias_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=input,
          overwrite=true,
        ),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(alias_code, "office.transaction.output_aliases_input")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "overwrite replaces only the requested output" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    write_test_file(output, original)
    let report = @transaction.transact(
      @transaction.transaction_options(
        input,
        output_path=output,
        overwrite=true,
      ),
      (_format, bytes) => {
        @transaction.transaction_mutation_with_manifest(
          rewrite_content_types(bytes, "overwrite"),
          ["[Content_Types].xml"],
        )
      },
    )
    let written = @afs.read_file(output).binary()
    assert_true(report.committed)
    assert_true(written != original)
    assert_eq(@office.detect_format(output, written), Docx)
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "mutation callback failure leaves source and output untouched" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes) => raise MutationProbeError,
      )
    })
    assert_eq(code, "office.transaction.mutation_failed")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_false(@afs.exists(output))
    assert_no_transaction_temp(directory)
  })
}

///|
async test "structured mutation contract errors are not relabeled" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let code = transaction_error_code(() => {
      @transaction.transact(@transaction.transaction_options(input), (
        _format,
        bytes,
      ) => {
        @transaction.transaction_mutation(bytes.to_owned(), warnings=[
          @office.protocol_warning("bad warning", "message"),
        ])
      })
    })
    assert_eq(code, "office.transaction.invalid_contract")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "callback-raised public errors are normalized at the boundary" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let invalid = transaction_error_value(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes) => {
          raise @transaction.TransactionError(
            code="foreign.failure",
            message="m".repeat(4_096),
            details=Some(
              Json::object({ "payload": Json::string("x".repeat(4_096)) }),
            ),
          )
        },
      )
    })
    match invalid {
      TransactionError(code~, message~, details~) => {
        assert_eq(code, "office.transaction.mutation_failed")
        assert_eq(
          message, "mutation callback raised an invalid TransactionError code",
        )
        assert_true(details is None)
      }
    }
    let oversized = transaction_error_value(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes) => {
          raise @transaction.TransactionError(
            code="office.transaction.callback_failure",
            message="m".repeat(4_096),
            details=Some(Json::array(Array::make(65, Json::string("detail")))),
          )
        },
      )
    })
    match oversized {
      TransactionError(code~, message~, details~) => {
        assert_eq(code, "office.transaction.callback_failure")
        assert_true(message.length() <= 513)
        assert_true(details is None)
      }
    }
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "validator and preservation failures publish nothing" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let validator = @transaction.transaction_validator("docx-deep", (
      _format,
      _bytes,
    ) => {
      [
        @transaction.validation_finding(
          "docx.test.invalid", "injected deep validation finding",
        ),
      ]
    })
    let validation_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes) => {
          @transaction.transaction_mutation(
            rewrite_content_types(bytes, "invalid"),
          )
        },
        validators=[validator],
      )
    })
    assert_eq(validation_code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
    let preservation_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes) => {
          @transaction.transaction_mutation_with_manifest(
            rewrite_content_types(bytes, "undeclared"),
            [],
          )
        },
      )
    })
    assert_eq(preservation_code, "office.transaction.preservation_violation")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "successful and throwing validators run before publication" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let passing = @transaction.transaction_validator("docx-pass", (
      _format,
      _bytes,
    ) => [])
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output, dry_run=true),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      validators=[passing],
    )
    assert_eq(report.validations.length(), 2)
    assert_eq(report.validations[1].name, "docx-pass")
    let throwing = @transaction.transaction_validator("docx-throw", (
      _format,
      _bytes,
    ) => raise ValidatorProbeError)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
        validators=[throwing],
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "validator finding arrays are bounded before serialization" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let excessive = @transaction.transaction_validator("docx-excessive", (
      _format,
      _bytes,
    ) => {
      Array::makei(65, index => {
        @transaction.validation_finding(
          "docx.test.finding",
          "bounded finding \{index}",
        )
      })
    })
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
        validators=[excessive],
      )
    })
    assert_eq(code, "office.transaction.invalid_contract")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "duplicate and excessive validator sets fail before file access" {
  let first = @transaction.transaction_validator("duplicate", (_format, _bytes) => {
    []
  })
  let second = @transaction.transaction_validator("duplicate", (_format, _bytes) => {
    []
  })
  let duplicate_code = transaction_error_code(() => {
    @transaction.transact(
      @transaction.transaction_options("absent.docx"),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      validators=[first, second],
    )
  })
  assert_eq(duplicate_code, "office.transaction.invalid_contract")
  let validators = Array::makei(33, index => {
    @transaction.transaction_validator("validator-\{index}", (_format, _bytes) => {
      []
    })
  })
  let excessive_code = transaction_error_code(() => {
    @transaction.transact(
      @transaction.transaction_options("absent.docx"),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      validators~,
    )
  })
  assert_eq(excessive_code, "office.transaction.invalid_contract")
}

///|
async test "missing invalid and misdirected files use stable policy codes" {
  with_transaction_test_dir(directory => {
    let missing = "\{directory}/missing.docx"
    let missing_code = transaction_error_code(() => {
      @transaction.transact(@transaction.transaction_options(missing), (
        _format,
        bytes,
      ) => @transaction.transaction_mutation(bytes.to_owned()))
    })
    assert_eq(missing_code, "office.transaction.file_read_failed")
    let broken = "\{directory}/broken.docx"
    write_test_file(broken, b"not a package")
    let broken_code = transaction_error_code(() => {
      @transaction.transact(@transaction.transaction_options(broken), (
        _format,
        bytes,
      ) => @transaction.transaction_mutation(bytes.to_owned()))
    })
    assert_eq(broken_code, "office.transaction.invalid_input")
    let valid = "\{directory}/valid.docx"
    write_test_file(valid, @word.new_blank_docx())
    let output_directory = "\{directory}/destination.docx"
    @afs.mkdir(output_directory)
    let directory_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          valid,
          output_path=output_directory,
          overwrite=true,
        ),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(directory_code, "office.transaction.invalid_options")
    let missing_parent = "\{directory}/absent/output.docx"
    let parent_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(valid, output_path=missing_parent),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(parent_code, "office.transaction.destination_parent_failed")
    assert_no_transaction_temp(directory)
  })
}

///|
async test "candidate cannot change the transaction format" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.xlsx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let xlsx = @excel.write(@excel.new_file())
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes) => @transaction.transaction_mutation(xlsx),
      )
    })
    assert_eq(code, "office.transaction.format_changed")
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "invalid candidate format and extension fail closed" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let invalid_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes) => @transaction.transaction_mutation(b"not a zip"),
      )
    })
    assert_eq(invalid_code, "office.transaction.validation_failed")
    let wrong_extension = "\{directory}/output.xlsx"
    let extension_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=wrong_extension),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(extension_code, "office.transaction.validation_failed")
    assert_false(@afs.exists(output))
    assert_false(@afs.exists(wrong_extension))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native output symlink aliases cannot bypass in-place policy" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let alias_path = "\{directory}/alias.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    @afs.symlink(target=input, alias_path)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=alias_path,
          overwrite=true,
        ),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(code, "office.transaction.output_aliases_input")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "native output symlink validation uses the resolved target extension" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let target = "\{directory}/target.xlsx"
    let alias_path = "\{directory}/alias.docx"
    let original = @word.new_blank_docx()
    let target_original = @excel.write(@excel.new_file())
    write_test_file(input, original)
    write_test_file(target, target_original)
    @afs.symlink(target~, alias_path)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=alias_path,
          overwrite=true,
        ),
        (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_eq(@afs.read_file(target).binary(), target_original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(target="wasm")
async test "Wasm commits disclose portable path and durability limits" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output),
      (_format, bytes) => @transaction.transaction_mutation(bytes.to_owned()),
    )
    let mut disclosed = false
    for warning in report.warnings {
      if warning.code == "office.transaction.wasm_commit_semantics" {
        disclosed = true
      }
    }
    assert_true(disclosed)
  })
}
