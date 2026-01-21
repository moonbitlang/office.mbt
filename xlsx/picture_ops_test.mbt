///|
test "picture get and delete" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img1 : Bytes = [1, 2, 3]
  let img2 : Bytes = [4, 5, 6, 7]
  workbook.add_image("Sheet1", "a1", img1, "png", "image/png")
  workbook.add_image("Sheet1", "B2", img2, "jpg", "image/jpeg")
  inspect(
    workbook.get_pictures("Sheet1", "A1").map(image => image.extension),
    content="[\"png\"]",
  )
  inspect(workbook.get_picture_cells("Sheet1"), content="[\"A1\", \"B2\"]")
  workbook.delete_picture("Sheet1", "A1")
  inspect(
    workbook.get_pictures("Sheet1", "A1").map(image => image.extension),
    content="[]",
  )
  inspect(workbook.get_picture_cells("Sheet1"), content="[\"B2\"]")
}

///|
test "picture delete empty cell" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.delete_picture("Sheet1", "C3")
  inspect(workbook.get_picture_cells("Sheet1"), content="[]")
}
