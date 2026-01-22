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

///|
test "picture from bytes add and write" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [9, 8, 7, 6]
  workbook.add_picture_from_bytes("Sheet1", "A1", img, ".png")
  inspect(
    workbook.get_pictures("Sheet1", "A1").map(image => image.extension),
    content="[\"png\"]",
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let stored = match archive.get("xl/media/image1.png") {
    Some(value) => value
    None => fail("missing image1.png")
  }
  inspect(stored == img, content="true")
  let types_xml = match archive.get("[Content_Types].xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing content types")
  }
  inspect(types_xml.contains("Extension=\"png\""), content="true")
}

///|
test "picture from bytes invalid extension" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result = try
    workbook.add_picture_from_bytes("Sheet1", "A1", [1, 2], ".nope")
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(UnsupportedFeature(msg=\"unsupported picture extension\"))",
  )
}
