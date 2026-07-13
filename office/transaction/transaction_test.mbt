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
fn transaction_zip_u16(bytes : Array[Byte], offset : Int) -> Int {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
fn transaction_zip_u32(bytes : Array[Byte], offset : Int) -> UInt {
  bytes[offset].to_uint() |
  (bytes[offset + 1].to_uint() << 8) |
  (bytes[offset + 2].to_uint() << 16) |
  (bytes[offset + 3].to_uint() << 24)
}

///|
fn transaction_zip_write_u16(
  bytes : Array[Byte],
  offset : Int,
  value : Int,
) -> Unit {
  let raw = value.reinterpret_as_uint()
  bytes[offset] = (raw & 0xFF).to_byte()
  bytes[offset + 1] = ((raw >> 8) & 0xFF).to_byte()
}

///|
fn transaction_zip_write_u32(
  bytes : Array[Byte],
  offset : Int,
  value : UInt,
) -> Unit {
  bytes[offset] = (value & 0xFF).to_byte()
  bytes[offset + 1] = ((value >> 8) & 0xFF).to_byte()
  bytes[offset + 2] = ((value >> 16) & 0xFF).to_byte()
  bytes[offset + 3] = ((value >> 24) & 0xFF).to_byte()
}

///|
fn transaction_zip_push_u16(bytes : Array[Byte], value : Int) -> Unit {
  let raw = value.reinterpret_as_uint()
  bytes.push((raw & 0xFF).to_byte())
  bytes.push(((raw >> 8) & 0xFF).to_byte())
}

///|
fn transaction_zip_push_u32(bytes : Array[Byte], value : UInt) -> Unit {
  bytes.push((value & 0xFF).to_byte())
  bytes.push(((value >> 8) & 0xFF).to_byte())
  bytes.push(((value >> 16) & 0xFF).to_byte())
  bytes.push(((value >> 24) & 0xFF).to_byte())
}

///|
fn transaction_zip_eocd(bytes : Array[Byte]) -> Int raise {
  for offset in (bytes.length() - 22)>=..0 {
    if transaction_zip_u32(bytes, offset) == (0x06054B50 : UInt) {
      return offset
    }
  }
  fail("transaction fixture is missing EOCD")
}

///|
fn transaction_zip_with_descriptors(data : BytesView) -> Bytes raise {
  let source = @zip.read(data)
  let result = @zip.Archive::new()
  for entry in source.entries() {
    result.add(
      entry.name(),
      entry.data(),
      compression=entry.compression(),
      data_descriptor=true,
    )
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
fn transaction_test_filesystem_path(path : String) -> String {
  if @path.sep == '\\' {
    let normalized = path.replace_all(old="/", new="\\")
    let resolved = "\{@path.Path(normalized).resolve()}"
    if resolved.has_prefix("\\\\?\\") {
      resolved
    } else {
      "\\\\?\\" + resolved
    }
  } else {
    path
  }
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
fn assert_identifier_format_error(
  error : @transaction.TransactionError,
  code : String,
  identifier : String,
) -> Unit raise {
  match error {
    TransactionError(code=actual_code, details~, ..) => {
      assert_eq(actual_code, code)
      match details {
        Some(Object(fields)) => {
          assert_eq(fields.get("identifier"), Some(Json::string(identifier)))
          assert_eq(fields.get("validator"), None)
          assert_eq(fields.get("identifier_format"), Some(Json::string("xlsx")))
          assert_eq(fields.get("portable_format"), Some(Json::string("docx")))
        }
        _ => fail("expected structured identifier details")
      }
    }
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
      (_format, _bytes, _archive, _budget) => {
        @transaction.transaction_reuse_original()
      },
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
async test "custom identifier gates pinned input before mutation" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    write_test_file(input, @word.new_blank_docx())
    let mutated = Ref(false)
    let identifier = @transaction.transaction_identifier("bounded-raw-test", (
      _path,
      _bytes,
      _archive,
    ) => {
      raise @transaction.transaction_failure(
        "office.raw.resource_limit", "bounded raw package rejected before generic parsing",
      )
    })
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input),
        (_format, bytes, _archive, _budget) => {
          mutated.val = true
          @transaction.transaction_mutation(bytes)
        },
        identifier~,
      )
    })
    assert_eq(code, "office.raw.resource_limit")
    assert_false(mutated.val)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "custom identifier validates candidates through the same boundary" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    write_test_file(input, @word.new_blank_docx())
    let calls = Ref(0)
    let identifier = @transaction.transaction_identifier("bounded-raw-test", (
      _path,
      _bytes,
      _archive,
    ) => {
      calls.val = calls.val + 1
      if calls.val == 2 {
        raise @transaction.transaction_failure(
          "office.raw.validation_failed", "candidate failed the complete raw boundary",
        )
      }
      Docx
    })
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
        identifier~,
      )
    })
    assert_eq(code, "office.raw.validation_failed")
    assert_eq(calls.val, 2)
    assert_false(@afs.exists(output))
    assert_no_transaction_temp(directory)
  })
}

///|
async test "custom identifier format errors name the identifier boundary" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let input_identifier = @transaction.transaction_identifier(
      "input-format-identifier",
      (_path, _bytes, _archive) => Xlsx,
    )
    let input_error = transaction_error_value(() => {
      @transaction.transact(
        @transaction.transaction_options(input),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
        identifier=input_identifier,
      )
    })
    assert_identifier_format_error(
      input_error, "office.transaction.invalid_input", "input-format-identifier",
    )
    let calls = Ref(0)
    let candidate_identifier = @transaction.transaction_identifier(
      "candidate-format-identifier",
      (_path, _bytes, _archive) => {
        calls.val = calls.val + 1
        if calls.val == 1 {
          Docx
        } else {
          Xlsx
        }
      },
    )
    let candidate_error = transaction_error_value(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
        identifier=candidate_identifier,
      )
    })
    assert_identifier_format_error(
      candidate_error, "office.transaction.validation_failed", "candidate-format-identifier",
    )
    assert_eq(calls.val, 2)
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "custom identifier cannot replace portable input validation" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let readable_zip = @zip.Archive::new()
    readable_zip.add("not-office.txt", b"readable zip")
    write_test_file(input, @zip.write(readable_zip))
    let identifier_calls = Ref(0)
    let mutated = Ref(false)
    let identifier = @transaction.transaction_identifier("custom-docx", (
      _path,
      _bytes,
      _archive,
    ) => {
      identifier_calls.val = identifier_calls.val + 1
      Docx
    })
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input),
        (_format, bytes, _archive, _budget) => {
          mutated.val = true
          @transaction.transaction_mutation(bytes)
        },
        identifier~,
      )
    })
    assert_eq(code, "office.transaction.invalid_input")
    assert_eq(identifier_calls.val, 1)
    assert_false(mutated.val)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "custom identifier cannot replace portable candidate validation" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let readable_zip = @zip.Archive::new()
    readable_zip.add("not-office.txt", b"readable zip")
    let invalid_candidate = @zip.write(readable_zip)
    let identifier_calls = Ref(0)
    let identifier = @transaction.transaction_identifier("custom-docx", (
      _path,
      _bytes,
      _archive,
    ) => {
      identifier_calls.val = identifier_calls.val + 1
      Docx
    })
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, _bytes, _archive, _budget) => {
          @transaction.transaction_mutation(invalid_candidate)
        },
        identifier~,
      )
    })
    assert_eq(code, "office.transaction.validation_failed")
    assert_eq(identifier_calls.val, 2)
    assert_false(@afs.exists(output))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "transaction callbacks receive isolated forks of one bounded archive" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let identifier_seen = Ref(false)
    let mutation_seen = Ref(false)
    let validator_seen = Ref(false)
    let identifier = @transaction.transaction_identifier("fork-identifier", (
      path,
      _bytes,
      archive,
    ) => {
      assert_true(archive.get("[Content_Types].xml") is Some(_))
      let format = @office.detect_archive_format(path, archive)
      archive.add("identifier-only.bin", b"identifier")
      identifier_seen.val = true
      format
    })
    let validator = @transaction.transaction_validator("fork-validator", (
      _format,
      _bytes,
      archive,
    ) => {
      assert_true(archive.get("identifier-only.bin") is None)
      assert_true(archive.get("mutation-only.bin") is None)
      archive.add("validator-only.bin", b"validator")
      validator_seen.val = true
      []
    })
    let report = @transaction.transact(
      @transaction.transaction_options(input),
      (_format, bytes, archive, _budget) => {
        assert_true(archive.get("identifier-only.bin") is None)
        archive.add("mutation-only.bin", b"mutation")
        mutation_seen.val = true
        @transaction.transaction_mutation(bytes)
      },
      validators=[validator],
      identifier~,
    )
    assert_true(identifier_seen.val)
    assert_true(mutation_seen.val)
    assert_true(validator_seen.val)
    assert_false(report.changed)
    assert_false(report.committed)
    assert_true(report.preservation.whole_file_identical)
    assert_eq(report.validations.length(), 3)
    assert_eq(report.validations[0].name, "fork-identifier")
    assert_eq(report.validations[1].name, "office-portable-opc")
    assert_eq(report.validations[2].name, "fork-validator")
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
      (_format, bytes, _archive, _budget) => {
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
      (_format, bytes, _archive, _budget) => {
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
      (_format, _bytes, _archive, _budget) => {
        @transaction.transaction_reuse_original()
      },
    )
    assert_true(report.committed)
    assert_eq(
      @afs.read_file(transaction_test_filesystem_path(output)).binary(),
      original,
    )
    assert_eq(@afs.read_file(input).binary(), original)
    @afs.remove(transaction_test_filesystem_path(output))
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
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
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
      (_format, bytes, _archive, _budget) => {
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
        (_format, bytes, _archive, _budget) => {
          called = true
          @transaction.transaction_mutation(bytes)
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
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
      )
    })
    assert_eq(alias_code, "office.transaction.output_aliases_input")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
async test "lexically equivalent output paths cannot bypass in-place policy" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let nested = "\{directory}/nested"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    @afs.mkdir(nested)
    for
      candidate_path in [
        "\{nested}/../input.docx",
        "\{directory}//./input.docx",
      ] {
      let code = transaction_error_code(() => {
        @transaction.transact(
          @transaction.transaction_options(
            input,
            output_path=candidate_path,
            overwrite=true,
          ),
          (_format, bytes, _archive, _budget) => {
            @transaction.transaction_mutation(bytes)
          },
        )
      })
      assert_eq(code, "office.transaction.output_aliases_input")
    }
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "POSIX source traversal preserves symlink then parent semantics" {
  with_transaction_test_dir(directory => {
    let target = "\{directory}/target"
    let nested = "\{target}/nested"
    let directory_alias = "\{directory}/directory-link"
    let intended = "\{target}/input.docx"
    let decoy = "\{directory}/input.docx"
    let source_path = "\{directory_alias}/../input.docx"
    let original = @word.new_blank_docx()
    @afs.mkdir(target)
    @afs.mkdir(nested)
    write_test_file(intended, original)
    write_test_file(decoy, b"not an Office package")
    @afs.symlink(target=nested, directory_alias)
    let report = @transaction.transact(
      @transaction.transaction_options(source_path, dry_run=true),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
    )
    assert_eq(report.format, Docx)
    assert_false(report.committed)
    assert_eq(@afs.read_file(intended).binary(), original)
    assert_eq(@afs.read_file(decoy).binary(), b"not an Office package")
    assert_no_transaction_temp(target)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "POSIX output traversal preserves symlink then parent semantics" {
  with_transaction_test_dir(directory => {
    let target = "\{directory}/target"
    let nested = "\{target}/nested"
    let directory_alias = "\{directory}/directory-link"
    let input = "\{directory}/input.docx"
    let intended = "\{target}/output.docx"
    let decoy = "\{directory}/output.docx"
    let output_path = "\{directory_alias}/../output.docx"
    let original = @word.new_blank_docx()
    @afs.mkdir(target)
    @afs.mkdir(nested)
    write_test_file(input, original)
    @afs.symlink(target=nested, directory_alias)
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path~),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
    )
    assert_true(report.committed)
    assert_eq(@afs.read_file(intended).binary(), original)
    assert_false(@afs.exists(decoy))
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(target)
  })
}

///|
#cfg(all(target="native", platform="windows"))
async test "Windows current-drive-root input and output paths remain valid" {
  with_transaction_test_dir(directory => {
    guard @env.current_dir() is Some(current)
    let normalized_directory = directory.replace_all(old="/", new="\\")
    let normalized_current = current.replace_all(old="/", new="\\")
    let directory_chars = normalized_directory.to_array()
    let current_chars = normalized_current.to_array()
    guard directory_chars.length() >= 3 &&
      current_chars.length() >= 2 &&
      normalized_directory[:2].to_owned().to_lower() ==
      normalized_current[:2].to_owned().to_lower() &&
      directory_chars[1] == ':' &&
      current_chars[1] == ':' &&
      directory_chars[2] == '\\'
    let root_relative_directory = normalized_directory[2:].to_owned()
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let root_relative_input = "\{root_relative_directory}\\input.docx"
    let root_relative_output = "\{root_relative_directory}\\output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let report = @transaction.transact(
      @transaction.transaction_options(
        root_relative_input,
        output_path=root_relative_output,
      ),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
    )
    assert_true(report.committed)
    assert_eq(@afs.read_file(output).binary(), original)
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(target="wasm")
async test "Wasm relative and absolute aliases resolve to one path" {
  with_transaction_test_dir(directory => {
    guard @env.current_dir() is Some(cwd)
    let input = "\{directory}/input.docx"
    let relative = "\{@path.Path(input).relative(base=Path(cwd))}"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=relative,
          overwrite=true,
        ),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
      )
    })
    assert_eq(code, "office.transaction.output_aliases_input")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(target="wasm")
async test "Wasm rejects ambiguous double-root output aliases" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    guard input.has_prefix("/")
    let ambiguous_alias = "/" + input
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let mut called = false
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(
          input,
          output_path=ambiguous_alias,
          overwrite=true,
        ),
        (_format, bytes, _archive, _budget) => {
          called = true
          @transaction.transaction_mutation(bytes)
        },
      )
    })
    assert_eq(code, "office.transaction.invalid_options")
    assert_false(called)
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
      (_format, bytes, _archive, _budget) => {
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
        (_format, _bytes, _archive, _budget) => raise MutationProbeError,
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
        _archive,
        _budget,
      ) => {
        @transaction.transaction_mutation(bytes, warnings=[
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
        (_format, _bytes, _archive, _budget) => {
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
        (_format, _bytes, _archive, _budget) => {
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
      _archive,
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
        (_format, bytes, _archive, _budget) => {
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
        (_format, bytes, _archive, _budget) => {
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
      _archive,
    ) => [])
    let report = @transaction.transact(
      @transaction.transaction_options(input, output_path=output, dry_run=true),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
      validators=[passing],
    )
    assert_eq(report.validations.length(), 2)
    assert_eq(report.validations[1].name, "docx-pass")
    let throwing = @transaction.transaction_validator("docx-throw", (
      _format,
      _bytes,
      _archive,
    ) => raise ValidatorProbeError)
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
async test "validator callbacks use an immutable invocation snapshot" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let output = "\{directory}/output.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let rejecting = @transaction.transaction_validator("docx-snapshot", (
      _format,
      _bytes,
      _archive,
    ) => {
      [
        @transaction.validation_finding(
          "docx.test.snapshot", "snapshotted validator still ran",
        ),
      ]
    })
    let validators = [rejecting]
    let code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=output),
        (_format, bytes, _archive, _budget) => {
          // Mutating the caller-owned array must not alter this invocation's
          // already-validated contract.
          validators.clear()
          @transaction.transaction_mutation(bytes)
        },
        validators~,
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
      _archive,
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
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
  let first = @transaction.transaction_validator("duplicate", (
    _format,
    _bytes,
    _archive,
  ) => [])
  let second = @transaction.transaction_validator("duplicate", (
    _format,
    _bytes,
    _archive,
  ) => [])
  let duplicate_code = transaction_error_code(() => {
    @transaction.transact(
      @transaction.transaction_options("absent.docx"),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
      validators=[first, second],
    )
  })
  assert_eq(duplicate_code, "office.transaction.invalid_contract")
  let colliding_identifier = @transaction.transaction_identifier("duplicate", (
    _path,
    _bytes,
    _archive,
  ) => Docx)
  let collision_code = transaction_error_code(() => {
    @transaction.transact(
      @transaction.transaction_options("absent.docx"),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
      validators=[first],
      identifier=colliding_identifier,
    )
  })
  assert_eq(collision_code, "office.transaction.invalid_contract")
  let validators = Array::makei(33, index => {
    @transaction.transaction_validator("validator-\{index}", (
      _format,
      _bytes,
      _archive,
    ) => [])
  })
  let excessive_code = transaction_error_code(() => {
    @transaction.transact(
      @transaction.transaction_options("absent.docx"),
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
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
        _archive,
        _budget,
      ) => @transaction.transaction_mutation(bytes))
    })
    assert_eq(missing_code, "office.transaction.file_read_failed")
    let broken = "\{directory}/broken.docx"
    write_test_file(broken, b"not a package")
    let broken_code = transaction_error_code(() => {
      @transaction.transact(@transaction.transaction_options(broken), (
        _format,
        bytes,
        _archive,
        _budget,
      ) => @transaction.transaction_mutation(bytes))
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
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
      )
    })
    assert_eq(directory_code, "office.transaction.invalid_options")
    let missing_parent = "\{directory}/absent/output.docx"
    let parent_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(valid, output_path=missing_parent),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
        (_format, _bytes, _archive, _budget) => {
          @transaction.transaction_mutation(xlsx)
        },
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
        (_format, _bytes, _archive, _budget) => {
          @transaction.transaction_mutation(b"not a zip")
        },
      )
    })
    assert_eq(invalid_code, "office.transaction.validation_failed")
    let wrong_extension = "\{directory}/output.xlsx"
    let extension_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, output_path=wrong_extension),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
async test "transaction rejects alternate ZIP interpretations before publication" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    let raw = original.to_array()
    let eocd = transaction_zip_eocd(raw)
    let central_size = transaction_zip_u32(raw, eocd + 12).reinterpret_as_int()
    let central_offset = transaction_zip_u32(raw, eocd + 16).reinterpret_as_int()
    let local_offset = transaction_zip_u32(raw, central_offset + 42).reinterpret_as_int()
    let invalid : Array[Bytes] = []

    let decoy_eocd = raw.copy()
    transaction_zip_write_u16(decoy_eocd, eocd + 20, 22)
    transaction_zip_push_u32(decoy_eocd, (0x06054B50 : UInt))
    for _ in 0..<9 {
      transaction_zip_push_u16(decoy_eocd, 0)
    }
    invalid.push(Bytes::from_array(decoy_eocd))

    let wrong_central_size = raw.copy()
    transaction_zip_write_u32(
      wrong_central_size,
      eocd + 12,
      (central_size - 1).reinterpret_as_uint(),
    )
    invalid.push(Bytes::from_array(wrong_central_size))

    let wrong_central_count = raw.copy()
    transaction_zip_write_u16(wrong_central_count, eocd + 8, 0)
    transaction_zip_write_u16(wrong_central_count, eocd + 10, 0)
    invalid.push(Bytes::from_array(wrong_central_count))

    let wrong_local_method = raw.copy()
    let central_method = transaction_zip_u16(raw, central_offset + 10)
    transaction_zip_write_u16(
      wrong_local_method,
      local_offset + 8,
      if central_method == 0 {
        8
      } else {
        0
      },
    )
    invalid.push(Bytes::from_array(wrong_local_method))

    let wrong_local_name = raw.copy()
    wrong_local_name[local_offset + 30] = (wrong_local_name[local_offset + 30].to_uint() ^
    1).to_byte()
    invalid.push(Bytes::from_array(wrong_local_name))

    let wrong_local_size = raw.copy()
    transaction_zip_write_u32(
      wrong_local_size,
      local_offset + 22,
      transaction_zip_u32(raw, local_offset + 22) + 1,
    )
    invalid.push(Bytes::from_array(wrong_local_size))

    let descriptor_bytes = transaction_zip_with_descriptors(original).to_array()
    let descriptor_eocd = transaction_zip_eocd(descriptor_bytes)
    let descriptor_central = transaction_zip_u32(
      descriptor_bytes,
      descriptor_eocd + 16,
    ).reinterpret_as_int()
    let descriptor_local = transaction_zip_u32(
      descriptor_bytes,
      descriptor_central + 42,
    ).reinterpret_as_int()
    let descriptor_offset = descriptor_local +
      30 +
      transaction_zip_u16(descriptor_bytes, descriptor_local + 26) +
      transaction_zip_u16(descriptor_bytes, descriptor_local + 28) +
      transaction_zip_u32(descriptor_bytes, descriptor_central + 20).reinterpret_as_int()
    descriptor_bytes[descriptor_offset + 4] = (descriptor_bytes[descriptor_offset +
    4].to_uint() ^
    1).to_byte()
    invalid.push(Bytes::from_array(descriptor_bytes))

    for candidate in invalid {
      let code = transaction_error_code(() => {
        @transaction.transact(
          @transaction.transaction_options(input, dry_run=true),
          (_format, _bytes, _archive, _budget) => {
            @transaction.transaction_mutation(candidate)
          },
        )
      })
      assert_eq(code, "office.transaction.validation_failed")
    }

    let oversized_zip32 = raw.copy()
    transaction_zip_write_u32(
      oversized_zip32,
      central_offset + 24,
      (0x80000000 : UInt),
    )
    let resource_code = transaction_error_code(() => {
      @transaction.transact(
        @transaction.transaction_options(input, dry_run=true),
        (_format, _bytes, _archive, _budget) => {
          @transaction.transaction_mutation(Bytes::from_array(oversized_zip32))
        },
      )
    })
    assert_eq(resource_code, "office.transaction.resource_limit_exceeded")
    assert_eq(@afs.read_file(input).binary(), original)
    assert_no_transaction_temp(directory)
  })
}

///|
#cfg(all(target="native", not(platform="windows")))
async test "POSIX final permissions do not make staging unverifiable" {
  with_transaction_test_dir(directory => {
    let input = "\{directory}/input.docx"
    let original = @word.new_blank_docx()
    write_test_file(input, original)
    for item in [(0o000, "none"), (0o200, "write-only")] {
      let (permission, suffix) = item
      let output = "\{directory}/\{suffix}.docx"
      let report = @transaction.transact(
        @transaction.transaction_options(input, output_path=output, permission~),
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
      )
      assert_true(report.committed)
      assert_true(@afs.exists(output))
      // Restore test access only after publication; success up to here proves
      // verification, chmod, and rename worked with the requested restrictive
      // final mode.
      @afs.chmod(output, 0o600)
      assert_eq(@afs.read_file(output).binary(), original)
    }
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
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
        (_format, bytes, _archive, _budget) => {
          @transaction.transaction_mutation(bytes)
        },
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
      (_format, bytes, _archive, _budget) => {
        @transaction.transaction_mutation(bytes)
      },
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
