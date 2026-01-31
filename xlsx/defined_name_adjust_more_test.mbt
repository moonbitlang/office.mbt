///|
test "defined name adjust: row insert (cell/row ranges + quoted prefix + invalid refs)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(
    DefinedName::new("R1", "Sheet1!A1:B2", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("R2", "Sheet1!1:3", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("R3", "'Sheet1'!A2", scope="Sheet1"),
  )

  // These are intentionally malformed but should not crash adjustment logic.
  workbook.set_defined_name(
    DefinedName::new("Bad1", "Sheet1!$", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("Bad2", "Sheet1!$0", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("Bad3", "Sheet1!A$", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("Bad4", "Sheet1!A0", scope="Sheet1"),
  )
  workbook.insert_rows("Sheet1", 2, 2)
  let dns = workbook.get_defined_names()
  inspect(dns[0].refers_to, content="Sheet1!A1:B4")
  inspect(dns[1].refers_to, content="Sheet1!1:5")
  inspect(dns[2].refers_to, content="'Sheet1'!A4")
  inspect(dns[3].refers_to, content="Sheet1!$")
  inspect(dns[4].refers_to, content="Sheet1!$0")
  inspect(dns[5].refers_to, content="Sheet1!A$")
  inspect(dns[6].refers_to, content="Sheet1!A0")
}

///|
test "defined name adjust: row remove produces #REF! and adjusts multiple refs" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(DefinedName::new("S1", "Sheet1!A1", scope="Sheet1"))
  workbook.set_defined_name(
    DefinedName::new("S2", "Sheet1!A1:A2", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("S3", "Sheet1!1:2", scope="Sheet1"),
  )
  workbook.set_defined_name(
    DefinedName::new("S4", "Sheet1!A1+Sheet1!A3", scope="Sheet1"),
  )
  workbook.remove_rows("Sheet1", 1, 2)
  let dns = workbook.get_defined_names()
  inspect(dns[0].refers_to, content="Sheet1!#REF!")
  inspect(dns[1].refers_to, content="Sheet1!#REF!")
  inspect(dns[2].refers_to, content="Sheet1!#REF!")
  inspect(dns[3].refers_to, content="Sheet1!#REF!+Sheet1!A1")
}

///|
test "defined name adjust: col insert/remove (cell/col ranges)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(
    DefinedName::new("C1", "Sheet1!A:B", scope="Sheet1"),
  )
  workbook.set_defined_name(DefinedName::new("C2", "Sheet1!B1", scope="Sheet1"))
  workbook.set_defined_name(
    DefinedName::new("C3", "'Sheet1'!B1", scope="Sheet1"),
  )
  workbook.insert_cols("Sheet1", 2, 1)
  let after_insert = workbook.get_defined_names()
  inspect(after_insert[0].refers_to, content="Sheet1!A:C")
  inspect(after_insert[1].refers_to, content="Sheet1!C1")
  inspect(after_insert[2].refers_to, content="'Sheet1'!C1")
  workbook.remove_cols("Sheet1", 2, 1)
  let after_remove = workbook.get_defined_names()
  inspect(after_remove[0].refers_to, content="Sheet1!A:B")
  inspect(after_remove[1].refers_to, content="Sheet1!B1")
  inspect(after_remove[2].refers_to, content="'Sheet1'!B1")
}
