// The format verb's record contract and budget helper, in isolation.

///|
/// A REAL report from a real transaction, so the record test exercises
/// the exact object the CLI would emit.
async fn format_wbtest_report() -> (@office_docx.DocxFormatReport, Bool, Json) {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-format-wbtest-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let source_bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
    ).binary()
    let input = directory + "/in.docx"
    @afs.write_file(
      input,
      source_bytes,
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/out.docx"
    let result = @office_docx.transact_docx_format(
      @transaction.transaction_options(input, output_path=output),
      format=@docx.docx_direct_format(bold=true),
      text="imported",
    )
    (
      result.report(),
      result.transaction().changed,
      result.transaction().to_json(),
    )
  }
}

///|
/// The capability registry is the contract: the result record may emit
/// only declared keys, and must emit every required one.
async test "format result record declares every field it emits" {
  guard @lib.find_capability_command("format") is Some(command) else {
    fail("expected the format capability")
  }
  let declared = command.outputs.map(field => field.name)
  let (report, changed, transaction) = format_wbtest_report()
  let record = format_report_json(
    "in.docx",
    "out.docx",
    Some("imported"),
    None,
    None,
    None,
    Some(true),
    None,
    None,
    None,
    None,
    false,
    false,
    report,
    changed,
    transaction~,
  )
  guard record is Object(fields) else { fail("expected an object record") }
  for name, _ in fields {
    if !declared.contains(name) {
      fail("undeclared output: " + name)
    }
  }
  for field in command.outputs {
    if field.required && !fields.contains(field.name) {
      fail("missing required output: " + field.name)
    }
  }
  assert_eq(fields.get("schema"), Some(Json::string("office.docx.format/1")))
  assert_eq(fields.get("format"), Some(Json::string("docx")))
  assert_eq(fields.get("mode"), Some(Json::string("text")))
  assert_eq(fields.get("bold"), Some(Json::boolean(true)))
  assert_eq(fields.get("italic"), Some(Json::null()))
  assert_eq(fields.get("changed"), Some(Json::boolean(true)))
  guard fields.get("spans") is Some(Array(spans)) else {
    fail("expected spans array")
  }
  assert_eq(spans.length(), 1)
  guard spans[0] is Object(span) else { fail("expected a span object") }
  assert_true(span.contains("path"))
  assert_true(span.contains("start"))
  assert_true(span.contains("end"))
}

///|
test "format report budget refuses only over-ceiling records" {
  let small : Json = Json::object({ "note": Json::string("fits") })
  ensure_format_report_budget(small, 4096)
  let mut text = "x"
  while text.length() < 2048 {
    text = text + text
  }
  let fat : Json = Json::object({ "note": Json::string(text) })
  try {
    ensure_format_report_budget(fat, 1024)
    fail("expected the budget refusal")
  } catch {
    error => {
      let message = "\{error}"
      assert_true(
        message.contains("office.format.report_too_large"),
        msg="got '" + message + "'",
      )
      assert_true(message.contains("nothing was written"))
    }
  }
}

///|
/// The on/off grammar and the range grammar, at the request boundary.
test "format request grammar refuses what it cannot mean" {
  guard decimal_prefix_value("12") is Some(12) else { fail("decimal") }
  guard decimal_prefix_value("") is None else { fail("empty") }
  guard decimal_prefix_value("1a") is None else { fail("mixed") }
  guard decimal_prefix_value("99999999") is None else { fail("wide") }
}

///|
/// `--in` must be canonical before it may act as a prefix: a truncated
/// scope would silently widen the selection past the bracket boundary
/// the engine's prefix test relies on.
test "format scope validation admits only canonical spellings" {
  format_validate_scope("p[3]")
  format_validate_scope("tbl[1]/tr[1]/tc[1]/p[1]")
  format_validate_scope("p[id=\"1A2B3C4D\"]")
  for
    bad in [
      "", "p[1", "p[", "p[0]", "p]1[", "p[1]/", "P[1]", "body/p[1]", "p[id=oops",
      "p[id=\"\"]", "p[id=\"AB\"]/r[1]", "p[id=\"A\"B\"]", "p[id=\"\"A\"]", "p[id=\"]X\"]",
      "bogus[1]", "tbl[1]/x[1]", "tbl[1]/p[id=\"1A2B3C4D\"]", "p[01]", "p[]", "r[1]",
      "hyperlink[1]", "tr[1]", "tc[1]", "p[1]/p[1]", "tbl[1]/tc[1]", "tbl[1]/tr[1]/p[1]",
      "p[1]/tbl[1]",
    ] {
    let mut refused = false
    format_validate_scope(bad) catch {
      CliFailure(_) => refused = true
    }
    assert_true(refused, msg="expected a refusal for '" + bad + "'")
  }
}

///|
/// The reserve's boundary: a record that fits inside the ceiling minus
/// the measured reserve passes, and the reserve itself is a few
/// kilobytes, not a blanket block of the ceiling.
test "format report reserve is measured and tight" {
  let reserve = format_report_transaction_reserve(
    "a/reasonably/long/input/path/document.docx", "a/reasonably/long/output/path/document-formatted.docx",
  )
  assert_true(reserve < 8192, msg="reserve is \{reserve}")
  assert_true(reserve > 1024, msg="reserve is \{reserve}")
  // The largest fitting record: just under ceiling minus reserve.
  let ceiling = 65536
  let mut filler = "x"
  while filler.length() < ceiling - reserve - 64 {
    filler = filler + filler
  }
  let fitting : Json = Json::object({
    "note": Json::string(
      filler[:ceiling - reserve - 64].to_owned(),
    ),
  })
  ensure_format_report_budget(fitting, ceiling - reserve)
}
