///|
test "data validation wb: data_validation_xml rejects empty sqref" {
  let dv = DataValidation::new(true)
  let result : Result[String, Error] = try? data_validation_xml(dv)
  inspect(result is Err(XlsxError::InvalidDataValidation(_)), content="true")
}

///|
test "data validation wb: data_validation_xml emits showDropDown when enabled" {
  let dv = DataValidation::new(true)
  dv.show_drop_down = true
  dv.set_sqref("A1")
  let xml = data_validation_xml(dv) catch {
    err => fail("data_validation_xml failed: \{err}")
  }
  inspect(xml.contains(" showDropDown=\"1\""), content="true")
}

///|
test "data validation wb: parse requires dataValidation tag" {
  let result : Result[DataValidation, Error] = try? data_validation_from_xml(
    "<foo/>",
  )
  inspect(result is Err(XlsxError::InvalidXml(_)), content="true")
}

///|
test "data validation wb: parse defaults with minimal tag and optional attrs" {
  let dv = data_validation_from_xml("<dataValidation sqref=\"A1\"/>") catch {
    err => fail("data_validation_from_xml failed: \{err}")
  }
  inspect(dv.allow_blank, content="false")
  inspect(dv.validation_type, content="")
  inspect(dv.formula1, content="")

  let dv_show = data_validation_from_xml(
    "<dataValidation sqref=\"A1\" showDropDown=\"1\"/>",
  ) catch {
    err => fail("data_validation_from_xml with showDropDown failed: \{err}")
  }
  inspect(dv_show.show_drop_down, content="true")
}

///|
test "data validation wb: parse requires sqref attribute" {
  let result : Result[DataValidation, Error] = try? data_validation_from_xml(
    "<dataValidation allowBlank=\"1\"/>",
  )
  inspect(result is Err(XlsxError::InvalidXml(_)), content="true")
}
