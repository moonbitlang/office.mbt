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
