///|
test "picture parsed on read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [9, 8, 7, 6]
  workbook.add_picture_from_bytes("Sheet1", "A1", img, ".png")
  let parsed = @xlsx.read(@xlsx.write(workbook))
  debug_inspect(
    parsed.get_pictures("Sheet1", "A1").map(image => image.extension),
    content="[\"png\"]",
  )
  inspect(parsed.get_pictures("Sheet1", "A1")[0].data == img, content="true")
}
