// Whitebox tests for content operator parsing internals.

///|
fn wbtest_content_name(text : String) -> PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn wbtest_assert_known_content_none(
  operator : String,
  operands : ArrayView[PdfObject],
) -> Unit raise Error {
  @test.assert_eq(
    pdf_content_parse_known_section(operands, @ascii.encode(operator)),
    None,
  )
}

///|
fn wbtest_assert_known_content_some(
  operator : String,
  operands : ArrayView[PdfObject],
  expected : PdfContentOp,
) -> Unit raise Error {
  @test.assert_eq(
    pdf_content_parse_known_section(operands, @ascii.encode(operator)),
    Some(expected),
  )
}

///|
test "private content operator helpers cover malformed operand fallbacks" {
  let name = wbtest_content_name("/N")
  @test.assert_eq(
    pdf_content_tj_array_from_operand(
      PdfArray([
        PdfString(@ascii.encode("A")),
        PdfInteger(-3),
        PdfArray([PdfInteger(1)]),
        PdfReal(2.5),
      ]),
    ),
    Some(PdfArray([PdfString(@ascii.encode("A")), PdfReal(-3.0), PdfReal(2.5)])),
  )
  @test.assert_eq(pdf_content_tj_array_from_operand(PdfInteger(1)), None)

  @test.assert_eq(pdf_content_operand_number([], 0), None)
  @test.assert_eq(pdf_content_operand_int([], 0), None)
  @test.assert_eq(pdf_content_operand_int([PdfReal(1.9)], 0), Some(1))
  @test.assert_eq(pdf_content_operand_name([], 0), None)
  @test.assert_eq(pdf_content_operand_string([], 0), None)
  @test.assert_eq(
    pdf_content_numbers_from_array(PdfArray([PdfReal(1.5), PdfInteger(2)])),
    Some([1.5, 2.0]),
  )
  @test.assert_eq(
    pdf_content_numbers_from_array(PdfArray([PdfNameObject(name)])),
    None,
  )
  @test.assert_eq(pdf_content_numbers_from_array(PdfNull), None)
  @test.assert_eq(
    pdf_content_numbers_from_operands([PdfNameObject(name)]),
    None,
  )
  @test.assert_eq(pdf_content_named_color_operands([]), None)
  @test.assert_eq(
    pdf_content_named_color_operands([PdfInteger(1), PdfNameObject(name)]),
    Some((name, [1.0])),
  )
  @test.assert_eq(pdf_content_matrix_from_operands([PdfInteger(1)]), None)

  let bad_number : ReadOnlyArray[PdfObject] = [PdfNameObject(name)]
  let bad_name : ReadOnlyArray[PdfObject] = [PdfInteger(1)]
  wbtest_assert_known_content_none("j", bad_number)
  wbtest_assert_known_content_none("M", bad_number)
  wbtest_assert_known_content_none("d", [PdfInteger(0)])
  wbtest_assert_known_content_none("d", [PdfNameObject(name), PdfInteger(0)])
  let bad_dash : Result[PdfContentOp?, Error] = try
    pdf_content_parse_known_section(
      [PdfArray([PdfNameObject(name)]), PdfInteger(0)],
      @ascii.encode("d"),
    )
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard bad_dash is Err(PdfError::NumberExpected) else {
    fail("expected PdfError::NumberExpected")
  }
  wbtest_assert_known_content_none("i", bad_number)
  wbtest_assert_known_content_none("cm", [
    PdfInteger(1),
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(1),
    PdfInteger(0),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("Tm", [
    PdfInteger(1),
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(1),
    PdfInteger(0),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("m", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("l", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("c", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
    PdfInteger(5),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("v", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("y", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("re", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("Tc", bad_number)
  wbtest_assert_known_content_none("Tw", bad_number)
  wbtest_assert_known_content_none("Tz", bad_number)
  wbtest_assert_known_content_none("TL", bad_number)
  wbtest_assert_known_content_none("Tf", [PdfInteger(1), PdfInteger(12)])
  wbtest_assert_known_content_none("Tr", bad_number)
  wbtest_assert_known_content_none("Ts", bad_number)
  wbtest_assert_known_content_none("Td", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("TD", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("TJ", [PdfInteger(1)])
  wbtest_assert_known_content_none("'", bad_name)
  wbtest_assert_known_content_none("\"", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("d0", [PdfInteger(1), PdfNameObject(name)])
  wbtest_assert_known_content_none("d1", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
    PdfInteger(5),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("G", bad_number)
  wbtest_assert_known_content_none("g", bad_number)
  wbtest_assert_known_content_none("RG", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("rg", [
    PdfInteger(1),
    PdfInteger(2),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("K", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("k", [
    PdfInteger(1),
    PdfInteger(2),
    PdfInteger(3),
    PdfNameObject(name),
  ])
  wbtest_assert_known_content_none("gs", bad_name)
  wbtest_assert_known_content_none("CS", bad_name)
  wbtest_assert_known_content_none("cs", bad_name)
  wbtest_assert_known_content_some(
    "SC",
    [PdfNameObject(name)],
    Op_SC([0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "sc",
    [PdfNameObject(name)],
    Op_sc([0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "SCN",
    [PdfNameObject(name), PdfNameObject(wbtest_content_name("/Pattern"))],
    Op_SCNName(wbtest_content_name("/Pattern"), [0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_some(
    "scn",
    [PdfNameObject(name), PdfNameObject(wbtest_content_name("/Pattern"))],
    Op_scnName(wbtest_content_name("/Pattern"), [0.0, 0.0, 0.0]),
  )
  wbtest_assert_known_content_none("sh", bad_name)
  wbtest_assert_known_content_none("MP", bad_name)
  wbtest_assert_known_content_none("DP", [PdfInteger(1), PdfDictionary([])])
  wbtest_assert_known_content_none("BMC", bad_name)
  wbtest_assert_known_content_none("BDC", [PdfInteger(1), PdfDictionary([])])
}
