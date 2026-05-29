///|
test "pdf_error raises cpdf soft error" {
  let result : Result[Unit, Error] = try? @core.pdf_error("soft")
  guard result is Err(@core.PdfError::SoftError("soft")) else {
    fail("expected SoftError")
  }
}

///|
test "pdf_soft_error and pdf_hard_error raise distinct cpdf errors" {
  let soft : Result[Unit, Error] = try? @core.pdf_soft_error("recoverable")
  guard soft is Err(@core.PdfError::SoftError("recoverable")) else {
    fail("expected SoftError")
  }
  let hard : Result[Unit, Error] = try? @core.pdf_hard_error("fatal")
  guard hard is Err(@core.PdfError::HardError("fatal")) else {
    fail("expected HardError")
  }
}

///|
test "pdf_error_summary explains common parser errors" {
  @test.assert_eq(
    @core.pdf_error_summary(RootExpected),
    "missing or invalid PDF catalog root (RootExpected)",
  )
  @test.assert_eq(
    @core.pdf_error_summary(StartXRefExpected),
    "missing or invalid startxref marker (StartXRefExpected)",
  )
  @test.assert_eq(
    @core.pdf_error_summary(SoftError("recoverable")),
    "recoverable",
  )
}
