///|
pub fn demo_pivot_slicer_bytes() -> Bytes raise @xlsx.XlsxError {
  let workbook = @excel.new_workbook()
  let data = workbook.add_sheet("Data")
  let pivot = workbook.add_sheet("Pivot")
  data.set_col_width(1, 12.0)
  data.set_col_width(2, 12.0)
  data.set_col_width(3, 12.0)
  data.set_col_width(4, 14.0)
  data.set_row(1, ["Region", "Type", "Month", "Sales"])
  let rows = [
    ("East", "A", "Jan", 10.0),
    ("East", "B", "Jan", 12.0),
    ("West", "A", "Jan", 7.0),
    ("West", "B", "Jan", 9.0),
    ("East", "A", "Feb", 11.0),
    ("East", "B", "Feb", 13.0),
    ("West", "A", "Feb", 8.0),
    ("West", "B", "Feb", 10.0),
    ("East", "A", "Mar", 14.0),
    ("East", "B", "Mar", 18.0),
    ("West", "A", "Mar", 9.0),
    ("West", "B", "Mar", 12.0),
  ]
  for i, row in rows {
    let r = 2 + i
    let (region, typ, month, sales) = row
    data.set_cell("A\{r}", region)
    data.set_cell("B\{r}", typ)
    data.set_cell("C\{r}", month)
    data.set_cell_value("D\{r}", Numeric(sales))
  }
  let opts = @xlsx.PivotTableOptions::new("Data!A1:D13", "Pivot!A3:F20")
  opts.rows.push(@xlsx.PivotTableField::new("Region"))
  opts.columns.push(@xlsx.PivotTableField::new("Type"))
  opts.data.push(@xlsx.PivotTableField::new("Sales"))
  let pivot_table = workbook.add_pivot_table(opts)
  pivot.set_cell("A1", "Pivot + Slicer Demo")
  pivot.merge_cells("A1:F1")
  let slicer = @xlsx.SlicerOptions::new(
    "Region",
    "H3",
    "Pivot",
    pivot_table.name,
  )
  slicer.set_caption("Region")
  slicer.set_size(160, 220)
  slicer.set_item_desc(true)
  workbook.add_slicer("Pivot", slicer)
  @excel.write(workbook)
}
