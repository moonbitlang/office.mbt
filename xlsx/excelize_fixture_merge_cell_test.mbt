///|
#cfg(target="native")
async test "excelize fixture MergeCell.xlsx merge-cells info parity" {
  let workbook = open_file(".repos/excelize/test/MergeCell.xlsx")
  let sheet_name = match workbook.sheet_name(0) {
    Some(value) => value
    None => fail("missing sheet")
  }
  let merges = workbook.get_merge_cells_info(sheet_name)
  inspect(merges.length(), content="4")
  inspect(
    (
      merges[0].get_cell_value(),
      merges[0].get_start_axis(),
      merges[0].get_end_axis(),
    ),
    content="(\"A1\", \"A1\", \"B1\")",
  )
  inspect(
    (
      merges[1].get_cell_value(),
      merges[1].get_start_axis(),
      merges[1].get_end_axis(),
    ),
    content="(\"A2\", \"A2\", \"A3\")",
  )
  inspect(
    (
      merges[2].get_cell_value(),
      merges[2].get_start_axis(),
      merges[2].get_end_axis(),
    ),
    content="(\"A4\", \"A4\", \"B5\")",
  )
  inspect(
    (
      merges[3].get_cell_value(),
      merges[3].get_start_axis(),
      merges[3].get_end_axis(),
    ),
    content="(\"A7\", \"A7\", \"C10\")",
  )
  let merges_no_values = workbook.get_merge_cells_info(
    sheet_name,
    without_values=true,
  )
  inspect(merges_no_values.length(), content="4")
  inspect(merges_no_values[0].get_cell_value(), content="")
}
