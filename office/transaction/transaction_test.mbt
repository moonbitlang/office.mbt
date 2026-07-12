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
  run : async () -> @transaction.TransactionReport raise @transaction.TransactionError,
) -> String {
  try run() catch {
    TransactionError(code~, ..) => code
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
