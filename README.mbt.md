# bobzhang/mbtexcel

MoonBit port of Excelize for creating and reading XLSX workbooks.

## Quick start

```mbt check
///|
test "workbook roundtrip" {
  let workbook = new_workbook()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_cell("A1", "hello")
  sheet.set_cell_formula("B1", "A1", value="hello")
  let bytes = write(workbook)
  let parsed = read(bytes)
  inspect(parsed.get_cell("Sheet1", "A1"), content="Some(\"hello\")")
  inspect(parsed.get_cell_formula("Sheet1", "B1"), content="Some(\"A1\")")
}

///|
test "row and column helpers" {
  let workbook = new_workbook()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.set_row("Sheet1", 1, ["a", "b", "c"])
  workbook.set_col("Sheet1", 2, ["x", "y"])
  inspect(
    workbook.get_row("Sheet1", 1),
    content=(
      #|["a", "x", "c"]
    ),
  )
  inspect(workbook.get_col("Sheet1", 2), content="[\"x\", \"y\"]")
}
```
