///|
test "cell ref conversions edge cases" {
  inspect(
    cell_ref_to_rc("$A$1"),
    content=(
      #|(1, 1)
    ),
  )
  inspect(
    cell_ref_from(1, 1),
    content=(
      #|A1
    ),
  )
  inspect(
    column_name_to_number("A"),
    content=(
      #|1
    ),
  )
  inspect(
    column_name_to_number("aa"),
    content=(
      #|27
    ),
  )
  inspect(
    column_number_to_name(1),
    content=(
      #|A
    ),
  )
  inspect(
    column_number_to_name(27),
    content=(
      #|AA
    ),
  )
  inspect(
    split_cell_name("$b$12"),
    content=(
      #|("B", 12)
    ),
  )
  inspect(
    join_cell_name("b", 12),
    content=(
      #|B12
    ),
  )
  inspect(
    cell_name_to_coordinates("$XFD$1048576"),
    content=(
      #|(16384, 1048576)
    ),
  )
  inspect(
    coordinates_to_cell_name(1, 1),
    content=(
      #|A1
    ),
  )
  inspect(
    coordinates_to_cell_name(1, 1, abs=true),
    content=(
      #|$A$1
    ),
  )
}

///|
test "cell ref invalid inputs" {
  let bad_refs = [
    "", "$", "1A", "A", "A0", "A-1", "A1!", "!", "$A$", "$$A1", "A$0",
  ]
  for r in bad_refs {
    let result : Result[(Int, Int), Error] = try? cell_ref_to_rc(r)
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let bad_cols = ["", "A1", "A!", "1", "A A"]
  for c in bad_cols {
    let result : Result[Int, Error] = try? column_name_to_number(c)
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let result_neg : Result[String, Error] = try? column_number_to_name(0)
  inspect(
    result_neg is Err(_),
    content=(
      #|true
    ),
  )
  let split_bad = ["", "1", "A0", "A-1", "A!", "A 1"]
  for c in split_bad {
    let result : Result[(String, Int), Error] = try? split_cell_name(c)
    inspect(
      result is Err(_),
      content=(
        #|true
      ),
    )
  }
  let coord_bad : Result[(Int, Int), Error] = try? cell_name_to_coordinates(
    "XFE1",
  )
  inspect(
    coord_bad is Err(_),
    content=(
      #|true
    ),
  )
  let row_oob : Result[(Int, Int), Error] = try? cell_name_to_coordinates(
    "A1048577",
  )
  inspect(
    row_oob is Err(_),
    content=(
      #|true
    ),
  )
  let out_of_range : Result[String, Error] = try? coordinates_to_cell_name(
    16385, 1,
  )
  inspect(
    out_of_range is Err(_),
    content=(
      #|true
    ),
  )
}

///|
test "cell ref row/col guards and split overflow row parse" {
  let from_bad_row : Result[String, Error] = try? cell_ref_from(0, 1)
  inspect(from_bad_row is Err(_), content="true")

  let join_bad_row : Result[String, Error] = try? join_cell_name("A", 0)
  inspect(join_bad_row is Err(_), content="true")

  let huge_row = "A" + "9".repeat(5000)
  let split_overflow : Result[(String, Int), Error] = try? split_cell_name(
    huge_row,
  )
  inspect(split_overflow is Err(_), content="true")
}
