///|
fn[T] contract_error_code(
  run : () -> T raise @transaction.TransactionError,
) -> String raise {
  try run() catch {
    TransactionError(code~, ..) => code
  } noraise {
    _ => fail("expected contract validation failure")
  }
}

///|
test "transaction options reject unsafe or unbounded paths and permissions" {
  assert_eq(
    contract_error_code(() => @transaction.transaction_options("")),
    "office.transaction.invalid_options",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_options("x".repeat(4097) + ".docx")
    }),
    "office.transaction.invalid_options",
  )
  let malformed = String::from_array([(0xD800).unsafe_to_char()])
  assert_eq(
    contract_error_code(() => @transaction.transaction_options(malformed)),
    "office.transaction.invalid_options",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_options("input\u{0}.docx")
    }),
    "office.transaction.invalid_options",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_options("input.docx", permission=0o1000)
    }),
    "office.transaction.invalid_options",
  )
}

///|
test "validators, findings, and warnings are bounded contracts" {
  let pass : (@office.DocumentFormat, BytesView, @zip.Archive) -> Array[
    @transaction.ValidationFinding,
  ] raise = (_format, _bytes, _archive) => []
  for invalid_name in ["", "not valid", "v".repeat(97)] {
    assert_eq(
      contract_error_code(() => {
        @transaction.transaction_validator(invalid_name, pass)
      }),
      "office.transaction.invalid_contract",
    )
  }
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_identifier("office-portable-opc", (
        _path,
        _bytes,
        _archive,
      ) => Docx)
    }),
    "office.transaction.invalid_contract",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.validation_finding("bad code", "message")
    }),
    "office.transaction.invalid_contract",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.validation_finding("valid.code", "m".repeat(513))
    }),
    "office.transaction.invalid_contract",
  )
  let warning = @office.protocol_warning("valid.warning", "bounded")
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_mutation(b"", warnings=Array::make(65, warning))
    }),
    "office.transaction.invalid_contract",
  )
}

///|
test "mutation failures preserve checked office subsystem codes" {
  let failure = @transaction.transaction_failure(
    "office.raw.invalid_path",
    "invalid bounded raw path",
    details=Json::object({ "offset": Json::number(3) }),
  )
  inspect(failure.to_protocol_error().code, content="office.raw.invalid_path")
  let oversized = @transaction.transaction_failure(
    "office.raw.path_not_found",
    "raw XML path matched no elements",
    details=Json::object({ "path": Json::string("/x".repeat(1_024)) }),
  )
  assert_eq(oversized.to_protocol_error().code, "office.raw.path_not_found")
  assert_eq(oversized.to_protocol_error().details, None)
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_failure("raw.invalid_path", "invalid")
    }),
    "office.transaction.invalid_contract",
  )
}

///|
test "preservation manifests require bounded canonical unique ZIP names" {
  for invalid in ["", "/root.xml", "a\\b.xml", "a//b.xml", "a/../b.xml"] {
    assert_eq(
      contract_error_code(() => {
        @transaction.transaction_mutation_with_manifest(b"", [invalid])
      }),
      "office.transaction.invalid_manifest",
    )
  }
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_mutation_with_manifest(b"", [
        "same.xml", "same.xml",
      ])
    }),
    "office.transaction.invalid_manifest",
  )
  assert_eq(
    contract_error_code(() => {
      @transaction.transaction_mutation_with_manifest(
        b"",
        Array::makei(257, index => "part-\{index}.xml"),
      )
    }),
    "office.transaction.invalid_manifest",
  )
}

///|
test "transaction errors retain stable A2 codes with and without details" {
  let without = @transaction.TransactionError(
    code="office.transaction.example",
    message="example",
    details=None,
  )
  assert_eq(
    Show::to_string(without),
    "transaction error office.transaction.example: example",
  )
  json_inspect(@office.output_failure(without.to_protocol_error()), content={
    "schema": "office.output/1",
    "success": false,
    "error": { "code": "office.transaction.example", "message": "example" },
  })
  let with_details = @transaction.TransactionError(
    code="office.transaction.example",
    message="example",
    details=Some(Json::object({ "stage": Json::string("commit") })),
  )
  json_inspect(@office.output_failure(with_details.to_protocol_error()), content={
    "schema": "office.output/1",
    "success": false,
    "error": {
      "code": "office.transaction.example",
      "message": "example",
      "details": { "stage": "commit" },
    },
  })
  let malformed = @transaction.TransactionError(
    code="foreign.failure",
    message="m".repeat(4_096),
    details=Some(Json::array(Array::make(65, Json::string("detail")))),
  )
  json_inspect(@office.output_failure(malformed.to_protocol_error()), content={
    "schema": "office.output/1",
    "success": false,
    "error": {
      "code": "office.transaction.invalid_contract",
      "message": "TransactionError code is outside the bounded office.* namespace",
    },
  })
}
