///|
test "ignored errors wb: ignored_error_xml rejects empty sqref" {
  let bad : Result[String, Error] = Ok(
    ignored_error_xml({
      sqref: "",
      eval_error: false,
      two_digit_text_year: false,
      number_stored_as_text: false,
      formula: false,
      formula_range: false,
      unlocked_formula: false,
      empty_cell_reference: false,
      list_data_validation: false,
      calculated_column: false,
    }),
  ) catch {
    e => Err(e)
  }
  inspect(bad is Err(XlsxError::InvalidSheetOperation(_)), content="true")
}

///|
test "ignored errors wb: parse non-self-closing ignoredError tag" {
  let parsed = parse_ignored_errors(
    "<ignoredErrors><ignoredError sqref=\"A1\"></ignoredError></ignoredErrors>",
  ) catch {
    err => fail("parse_ignored_errors failed: \{err}")
  }
  inspect(parsed.length(), content="1")
  inspect(parsed[0].sqref, content="A1")
}

///|
test "ignored errors wb: parse requires sqref attribute" {
  let missing_sqref : Result[Array[IgnoredError], Error] = Ok(
    parse_ignored_errors(
      "<ignoredErrors><ignoredError evalError=\"1\"/></ignoredErrors>",
    ),
  ) catch {
    e => Err(e)
  }
  inspect(missing_sqref is Err(XlsxError::InvalidXml(_)), content="true")
}
