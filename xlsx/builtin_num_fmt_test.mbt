// Blackbox coverage for `builtin_number_format_code`: the reverse table
// covers exactly the ids the value formatter renders with a fixed code, and
// for every covered id, styling a numeric cell with the returned code
// renders identically to styling it with the builtin id (the forward
// mapping in `format_number_builtin`).

///|
/// Renders every value twice on one sheet — column A styled with the
/// builtin id, column B styled with the reverse-mapped code — and returns
/// the two formatted output columns.
fn rendered_columns(
  id : Int,
  values : ArrayView[Double],
) -> (Array[String?], Array[String?]) raise {
  let code = @xlsx.builtin_number_format_code(id).unwrap()
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Fmt"))
  let builtin_style = workbook.add_style(@xlsx.Style::builtin_number_format(id))
  let code_style = workbook.add_style(@xlsx.Style::number_format(code))
  for index, value in values {
    let row = index + 1
    workbook.set_cell_float("Fmt", "A\{row}", value)
    workbook.set_cell_float("Fmt", "B\{row}", value)
    workbook.set_cell_style("Fmt", "A\{row}", builtin_style)
    workbook.set_cell_style("Fmt", "B\{row}", code_style)
  }
  let via_builtin : Array[String?] = []
  let via_code : Array[String?] = []
  for index, _ in values {
    let row = index + 1
    via_builtin.push(workbook.get_cell_value("Fmt", "A\{row}"))
    via_code.push(workbook.get_cell_value("Fmt", "B\{row}"))
  }
  (via_builtin, via_code)
}

///|
let numeric_battery : Array[Double] = [
  0.0, 1.0, -1.0, 0.5, -0.5, 2.5, 0.00456, -0.0001, 1234.5678, -1234.5678, 987654321.98765,
  12345678.9, 1.0e15,
]

///|
let date_serial_battery : Array[Double] = [
  0.25, 1.5, 59.5, 61.0, 25569.0, 44197.5, 44926.75, 73050.123,
]

///|
test "numfmt reverse lookup round-trips the numeric builtin ids" {
  for id in ([1, 2, 3, 4, 9, 10] : Array[Int]) {
    let (via_builtin, via_code) = rendered_columns(id, numeric_battery)
    assert_eq(via_builtin, via_code, msg="builtin id \{id}")
  }
}

///|
test "numfmt reverse lookup round-trips the date builtin ids" {
  for id in ([14, 15, 16, 17, 18, 19, 20, 21, 22] : Array[Int]) {
    let (via_builtin, via_code) = rendered_columns(id, date_serial_battery)
    assert_eq(via_builtin, via_code, msg="builtin id \{id}")
  }
}

///|
test "numfmt rendering anchors for representative ids" {
  let (two, _) = rendered_columns(2, [0.0, -1.0, 2.5, 1234.5678])
  debug_inspect(
    two,
    content=(
      #|[Some("0.00"), Some("-1.00"), Some("2.50"), Some("1234.57")]
    ),
  )
  let (four, _) = rendered_columns(4, [1234.5678, -1234.5678])
  debug_inspect(
    four,
    content=(
      #|[Some("1,234.57"), Some("-1,234.57")]
    ),
  )
  let (fourteen, _) = rendered_columns(14, [44197.5])
  debug_inspect(
    fourteen,
    content=(
      #|[Some("01-01-21")]
    ),
  )
  let (twentytwo, _) = rendered_columns(22, [44197.75])
  debug_inspect(
    twentytwo,
    content=(
      #|[Some("1/1/21 18:00")]
    ),
  )
}

///|
test "numfmt reverse lookup coverage is exactly the fixed-code ids" {
  let covered : Array[Int] = []
  for id in 0..<=500 {
    if @xlsx.builtin_number_format_code(id) is Some(_) {
      covered.push(id)
    }
  }
  debug_inspect(
    covered,
    content="[1, 2, 3, 4, 9, 10, 14, 15, 16, 17, 18, 19, 20, 21, 22]",
  )
  // Ids outside the fixed-code set stay uncovered: General (0), the
  // unimplemented builtins (5-8, 11-13, 23-26, 37-49, 63-66), every
  // culture-dependent language builtin (27-36, 50-62, 67-81), the custom
  // range (>= 164), and out-of-range probes.
  for
    id in (
      [
        -1, 0, 5, 8, 11, 12, 13, 23, 26, 27, 30, 36, 37, 41, 44, 49, 50, 56, 62,
        63, 66, 67, 81, 82, 163, 164, 382,
      ] : Array[Int]) {
    assert_eq(@xlsx.builtin_number_format_code(id), None, msg="id \{id}")
  }
}

///|
test "numfmt equivalence domain edges are pinned: text cells and negative serials" {
  // Text cells: a builtin format leaves text untouched; the equivalent
  // custom code runs the text through its literal pattern. The reverse
  // table's docs scope equivalence to numeric cells; this pins the edge.
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Edge"))
  let builtin_style = workbook.add_style(@xlsx.Style::builtin_number_format(2))
  let code_style = workbook.add_style(@xlsx.Style::number_format("0.00"))
  workbook.set_cell("Edge", "A1", "hello")
  workbook.set_cell("Edge", "B1", "hello")
  workbook.set_cell_style("Edge", "A1", builtin_style)
  workbook.set_cell_style("Edge", "B1", code_style)
  debug_inspect(
    workbook.get_cell_value("Edge", "A1"),
    content="Some(\"hello\")",
  )
  debug_inspect(workbook.get_cell_value("Edge", "B1"), content="Some(\"0.00\")")
  // Negative serials under a date id: the builtin path renders the raw
  // value; the custom-code path prefixes the sign it split off.
  let date_builtin = workbook.add_style(@xlsx.Style::builtin_number_format(14))
  let date_code = workbook.add_style(@xlsx.Style::number_format("mm-dd-yy"))
  workbook.set_cell_float("Edge", "A2", -0.5)
  workbook.set_cell_float("Edge", "B2", -0.5)
  workbook.set_cell_style("Edge", "A2", date_builtin)
  workbook.set_cell_style("Edge", "B2", date_code)
  debug_inspect(workbook.get_cell_value("Edge", "A2"), content="Some(\"-0.5\")")
  debug_inspect(
    workbook.get_cell_value("Edge", "B2"),
    content="Some(\"--0.5\")",
  )
}
