///|
fn defined_name_refers_to(workbook : @xlsx.Workbook, name : String) -> String {
  let mut refers_to = ""
  for dn in workbook.get_defined_names() {
    if dn.name == name {
      refers_to = dn.refers_to
    }
  }
  refers_to
}

///|
test "defined name adjust: insert cols shifts cell range" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Range", "Sheet1!$A$1:$B$2"))
  workbook.insert_cols("Sheet1", 1, 1)
  inspect(
    defined_name_refers_to(workbook, "Range"),
    content=(
      #|Sheet1!$B$1:$C$2
    ),
  )
}

///|
test "defined name adjust: remove rows can yield #REF!" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Gone", "Sheet1!$A$1:$A$2"))
  workbook.remove_rows("Sheet1", 1, 2)
  inspect(
    defined_name_refers_to(workbook, "Gone"),
    content=(
      #|Sheet1!#REF!
    ),
  )
}

///|
test "defined name adjust: remove cols adjusts column range refs" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Cols", "Sheet1!$A:$C"))
  workbook.remove_cols("Sheet1", 2, 1)
  inspect(
    defined_name_refers_to(workbook, "Cols"),
    content=(
      #|Sheet1!$A:$B
    ),
  )
}

///|
test "defined name adjust: quoted sheet name and multiple refs" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("O'Brien"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Quoted", "'O''Brien'!$C$1"))
  workbook.set_defined_name(
    @xlsx.DefinedName::new("Expr", "O'Brien!A1+O'Brien!B2"),
  )
  workbook.insert_rows("O'Brien", 1, 1)
  inspect(
    defined_name_refers_to(workbook, "Quoted"),
    content=(
      #|'O''Brien'!$C$2
    ),
  )
  inspect(
    defined_name_refers_to(workbook, "Expr"),
    content=(
      #|O'Brien!A2+O'Brien!B3
    ),
  )
}

///|
test "defined name adjust: insert rows shifts row range refs" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("Rows", "Sheet1!$1:$3"))
  workbook.insert_rows("Sheet1", 2, 2)
  inspect(
    defined_name_refers_to(workbook, "Rows"),
    content=(
      #|Sheet1!$1:$5
    ),
  )
}

///|
test "defined name adjust: invalid col refs are preserved" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("BadCols", "Sheet1!$A1:$C"))
  workbook.insert_cols("Sheet1", 1, 1)
  inspect(
    defined_name_refers_to(workbook, "BadCols"),
    content=(
      #|Sheet1!$A1:$C
    ),
  )
}

///|
test "defined name adjust: invalid row refs are preserved" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("BadRows", "Sheet1!1:A"))
  workbook.insert_rows("Sheet1", 1, 1)
  inspect(
    defined_name_refers_to(workbook, "BadRows"),
    content=(
      #|Sheet1!1:A
    ),
  )
}

///|
test "defined name adjust: out-of-grid and overflowing refs are preserved" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_defined_name(@xlsx.DefinedName::new("BadCol", "Sheet1!XFE1"))
  workbook.set_defined_name(
    @xlsx.DefinedName::new(
      "HugeCol", "Sheet1!ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ1",
    ),
  )
  workbook.set_defined_name(
    @xlsx.DefinedName::new(
      "HugeRow", "Sheet1!A999999999999999999999999999999999999",
    ),
  )
  workbook.insert_rows("Sheet1", 1, 1)
  inspect(defined_name_refers_to(workbook, "BadCol"), content="Sheet1!XFE1")
  inspect(
    defined_name_refers_to(workbook, "HugeCol"),
    content="Sheet1!ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ1",
  )
  inspect(
    defined_name_refers_to(workbook, "HugeRow"),
    content="Sheet1!A999999999999999999999999999999999999",
  )
}
