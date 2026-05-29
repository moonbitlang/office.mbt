///|
test "pdf_shape_rectangle bounds preserve rectangle coordinates" {
  let path = @shape.pdf_shape_rectangle(10.0, 20.0, 30.0, 40.0)
  @test.assert_eq(path.bounds(), {
    min_x: 10.0,
    min_y: 20.0,
    max_x: 40.0,
    max_y: 60.0,
  })
}
