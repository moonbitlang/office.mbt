///|
test "cell ref helpers" {
  debug_inspect(@xlsx.split_cell_name("AK74"), content="(\"AK\", 74)")
  debug_inspect(@xlsx.split_cell_name("$b$2"), content="(\"B\", 2)")
  @test.assert_raise(() => @xlsx.split_cell_name("A"))
  inspect(@xlsx.join_cell_name("ak", 74), content="AK74")
  @test.assert_raise(() => @xlsx.join_cell_name("A1", 1))
  inspect(@xlsx.column_name_to_number("AK"), content="37")
  inspect(@xlsx.column_number_to_name(37), content="AK")
  @test.assert_raise(() => @xlsx.column_name_to_number("A1"))
  debug_inspect(@xlsx.cell_name_to_coordinates("Z3"), content="(26, 3)")
  debug_inspect(@xlsx.cell_name_to_coordinates("$C$3"), content="(3, 3)")
  let coords_err : Result[(Int, Int), Error] = Ok(
    @xlsx.cell_name_to_coordinates("A1048577"),
  ) catch {
    e => Err(e)
  }
  inspect(coords_err is Err(_), content="true")
  inspect(@xlsx.coordinates_to_cell_name(1, 1), content="A1")
  inspect(@xlsx.coordinates_to_cell_name(1, 1, abs=true), content="$A$1")
  let coord_name_err : Result[String, Error] = Ok(
    @xlsx.coordinates_to_cell_name(0, 1),
  ) catch {
    e => Err(e)
  }
  inspect(coord_name_err is Err(_), content="true")
}

///|
test "cell ref helpers enforce exact XLSX grid and bounded syntax" {
  inspect(@xlsx.column_name_to_number("XFD"), content="16384")
  inspect(@xlsx.column_number_to_name(16384), content="XFD")
  debug_inspect(
    @xlsx.split_cell_name("$XFD$1048576"),
    content="(\"XFD\", 1048576)",
  )
  inspect(@xlsx.join_cell_name("XFD", 1048576), content="XFD1048576")
  let bad_columns = ["XFE", "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"]
  for name in bad_columns {
    let result : Result[Int, Error] = Ok(@xlsx.column_name_to_number(name)) catch {
      e => Err(e)
    }
    inspect(result is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")
  }
  let bad_numbers = [0, 16385]
  for col in bad_numbers {
    let result : Result[String, Error] = Ok(@xlsx.column_number_to_name(col)) catch {
      e => Err(e)
    }
    inspect(result is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")
  }
  let bad_cells = [
    "XFE1", "A1048577", "A999999999999999999999999999999999999", "$$A1", "A$$1",
    "$A1$",
  ]
  for cell in bad_cells {
    let result : Result[(String, Int), Error] = Ok(@xlsx.split_cell_name(cell)) catch {
      e => Err(e)
    }
    inspect(result is Err(@xlsx.XlsxError::InvalidCellRef(_)), content="true")
  }
}
