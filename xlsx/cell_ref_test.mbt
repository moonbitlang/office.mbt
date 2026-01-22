///|
test "cell ref helpers" {
  inspect(split_cell_name("AK74"), content="(\"AK\", 74)")
  inspect(split_cell_name("$b$2"), content="(\"B\", 2)")
  let split_err : Result[(String, Int), Error] = try? split_cell_name("A")
  inspect(split_err is Err(_), content="true")
  inspect(join_cell_name("ak", 74), content="AK74")
  let join_err : Result[String, Error] = try? join_cell_name("A1", 1)
  inspect(join_err is Err(_), content="true")
  inspect(column_name_to_number("AK"), content="37")
  inspect(column_number_to_name(37), content="AK")
  let name_err : Result[Int, Error] = try? column_name_to_number("A1")
  inspect(name_err is Err(_), content="true")
  inspect(cell_name_to_coordinates("Z3"), content="(26, 3)")
  inspect(cell_name_to_coordinates("$C$3"), content="(3, 3)")
  let coords_err : Result[(Int, Int), Error] = try? cell_name_to_coordinates(
    "A1048577",
  )
  inspect(coords_err is Err(_), content="true")
  inspect(coordinates_to_cell_name(1, 1), content="A1")
  inspect(coordinates_to_cell_name(1, 1, abs=true), content="$A$1")
  let coord_name_err : Result[String, Error] = try? coordinates_to_cell_name(
    0, 1,
  )
  inspect(coord_name_err is Err(_), content="true")
}
