///|
test "auto filter adds filter database defined name" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.auto_filter("Sheet1", "D4:B1", [])
  let mut found : DefinedName? = None
  for dn in workbook.get_defined_names() {
    if dn.name == "_xlnm._FilterDatabase" && dn.scope == "Sheet1" {
      found = Some(dn)
      break
    }
  }
  match found {
    Some(dn) => inspect(dn.refers_to, content="'Sheet1'!$B$1:$D$4")
    None => fail("missing _xlnm._FilterDatabase defined name")
  }
  let parsed = read(write(workbook))
  let mut found2 : DefinedName? = None
  for dn in parsed.get_defined_names() {
    if dn.name == "_xlnm._FilterDatabase" && dn.scope == "Sheet1" {
      found2 = Some(dn)
      break
    }
  }
  match found2 {
    Some(dn) => inspect(dn.refers_to, content="'Sheet1'!$B$1:$D$4")
    None => fail("missing _xlnm._FilterDatabase defined name after roundtrip")
  }
}

///|
test "auto filter accepts absolute range refs" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.auto_filter("Sheet1", "$A$1:$B$2", [])
  let parsed = read(write(workbook))
  inspect(parsed.get_auto_filter("Sheet1") is Some(_), content="true")
}

///|
test "auto filter invalid sheet name" {
  let workbook = Workbook::new()
  let result : Result[Unit, Error] = try? workbook.auto_filter(
    "Sheet:1",
    "A1:B1",
    [],
  )
  match result {
    Err(XlsxError::InvalidSheetName(msg~)) =>
      inspect(msg, content="sheet name contains invalid characters")
    _ => fail("expected invalid sheet name")
  }
}
