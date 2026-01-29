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
test "picture dimension parsing (bmp/tiff/ico)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // Minimal BMP header with width=10, height=20.
  let bmp : Bytes = [
    0x42, 0x4D, 0x3A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x36, 0x00, 0x00,
    0x00, 0x28, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  // Minimal little-endian TIFF with width=5, height=7.
  let tiff : Bytes = [
    0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x01, 0x04,
    0x00, 0x01, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01, 0x01, 0x04, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  // Minimal ICO with first entry width=16, height=16.
  let ico : Bytes = [
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x10, 0x10, 0x00, 0x00, 0x01, 0x00, 0x20,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00, 0x00, 0x00,
  ]
  workbook.add_picture_from_bytes("Sheet1", "A1", bmp, ".bmp")
  workbook.add_picture_from_bytes("Sheet1", "B2", tiff, ".tiff")
  workbook.add_picture_from_bytes("Sheet1", "C3", ico, ".ico")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  // bmp 10x20
  inspect(drawing_xml.contains("cx=\"95250\""), content="true")
  inspect(drawing_xml.contains("cy=\"190500\""), content="true")
  // tiff 5x7
  inspect(drawing_xml.contains("cx=\"47625\""), content="true")
  inspect(drawing_xml.contains("cy=\"66675\""), content="true")
  // ico 16x16
  inspect(drawing_xml.contains("cx=\"152400\""), content="true")
  inspect(drawing_xml.contains("cy=\"152400\""), content="true")
}

///|
test "picture dimension parsing (svg)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let svg_text = "<svg width=\"11\" height=\"13\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
  let svg_bytes = @encoding/utf8.encode(svg_text)
  workbook.add_picture_from_bytes("Sheet1", "A1", svg_bytes, ".svg")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  inspect(drawing_xml.contains("cx=\"104775\""), content="true")
  inspect(drawing_xml.contains("cy=\"123825\""), content="true")
}

///|
test "picture dimension parsing (emf/wmf)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // Minimal EMF header with rclFrame width=2540 (.01mm) and height=1270 (.01mm)
  // => 1.0in x 0.5in => 96px x 48px.
  let emf : Bytes = [
    0x01, 0x00, 0x00, 0x00, 0x58, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEC, 0x09, 0x00, 0x00, 0xF6, 0x04, 0x00,
    0x00, 0x20, 0x45, 0x4D, 0x46, 0x00, 0x00, 0x00, 0x00,
  ]
  // Minimal WMF placeable header with bbox 0..1440 x 0..720 and inch=1440
  // => 1.0in x 0.5in => 96px x 48px.
  let wmf : Bytes = [
    0xD7, 0xCD, 0xC6, 0x9A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA0, 0x05, 0xD0,
    0x02, 0xA0, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  workbook.add_picture_from_bytes("Sheet1", "A1", emf, ".emf")
  workbook.add_picture_from_bytes("Sheet1", "B2", wmf, ".wmf")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  // 96px x 48px => 914400 x 457200 EMU.
  inspect(drawing_xml.contains("cx=\"914400\""), content="true")
  inspect(drawing_xml.contains("cy=\"457200\""), content="true")
}

///|
test "picture dimension parsing (emz/wmz)" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // Same test payloads as emf/wmf, but gzip-compressed.
  let emf : Bytes = [
    0x01, 0x00, 0x00, 0x00, 0x58, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xEC, 0x09, 0x00, 0x00, 0xF6, 0x04, 0x00,
    0x00, 0x20, 0x45, 0x4D, 0x46, 0x00, 0x00, 0x00, 0x00,
  ]
  let wmf : Bytes = [
    0xD7, 0xCD, 0xC6, 0x9A, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA0, 0x05, 0xD0,
    0x02, 0xA0, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  let emz = @zip.gzip(emf[:]) catch { err => fail("gzip emf failed: \{err}") }
  let wmz = @zip.gzip(wmf[:]) catch { err => fail("gzip wmf failed: \{err}") }
  workbook.add_picture_from_bytes("Sheet1", "A1", emz, ".emz")
  workbook.add_picture_from_bytes("Sheet1", "B2", wmz, ".wmz")
  let bytes = write(workbook)
  let archive = @zip.read(bytes) catch {
    err => fail("zip read failed: \{err}")
  }
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing1.xml utf8 decode failed")
      }
    None => fail("missing drawing1.xml")
  }
  // 96px x 48px => 914400 x 457200 EMU.
  inspect(drawing_xml.contains("cx=\"914400\""), content="true")
  inspect(drawing_xml.contains("cy=\"457200\""), content="true")
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

///|
test "picture options write drawing and rels" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [9, 1, 2, 3]
  workbook.add_picture_from_bytes(
    "Sheet1",
    "C3",
    img,
    ".png",
    offset_x=10,
    offset_y=20,
    scale_x=0.5,
    scale_y=2.0,
    hyperlink="https://example.com",
    hyperlink_type=HyperlinkType::External,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:col>2</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(
    drawing_xml.contains("<xdr:colOff>95250</xdr:colOff>"),
    content="true",
  )
  inspect(
    drawing_xml.contains("<xdr:rowOff>190500</xdr:rowOff>"),
    content="true",
  )
  inspect(drawing_xml.contains("cx=\"952500\""), content="true")
  inspect(drawing_xml.contains("cy=\"3048000\""), content="true")
  inspect(drawing_xml.contains("<a:hlinkClick r:id=\"rId2\"/>"), content="true")
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }
  inspect(drawing_rels.contains("https://example.com"), content="true")
  inspect(drawing_rels.contains("TargetMode=\"External\""), content="true")
}

///|
test "picture options via GraphicOptions" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let img : Bytes = [9, 1, 2, 3]
  let opts = GraphicOptions::with_values(
    offset_x=10,
    offset_y=20,
    scale_x=0.5,
    scale_y=2.0,
    hyperlink="https://example.com",
    hyperlink_type=HyperlinkType::External,
    name="Logo",
    alt_text="Excel Logo",
    lock_aspect_ratio=true,
    print_object=false,
    locked=false,
    positioning=PicturePositioning::Absolute,
  )
  workbook.add_picture_from_bytes_with_options(
    "Sheet1", "C3", img, ".png", opts,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:col>2</xdr:col>"), content="true")
  inspect(drawing_xml.contains("<xdr:row>2</xdr:row>"), content="true")
  inspect(
    drawing_xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(drawing_xml.contains("name=\"Logo\""), content="true")
  inspect(drawing_xml.contains("descr=\"Excel Logo\""), content="true")
  inspect(drawing_xml.contains("noChangeAspect=\"1\""), content="true")
  inspect(drawing_xml.contains("fLocksWithSheet=\"0\""), content="true")
  inspect(drawing_xml.contains("fPrintsWithSheet=\"0\""), content="true")
  inspect(drawing_xml.contains("<a:hlinkClick"), content="true")
  let drawing_rels = match archive.get("xl/drawings/_rels/drawing1.xml.rels") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing rels")
  }
  inspect(drawing_rels.contains("https://example.com"), content="true")
  inspect(drawing_rels.contains("TargetMode=\"External\""), content="true")
}

///|
test "picture clientData flags" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    [9, 9],
    ".png",
    locked=false,
    print_object=false,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("fLocksWithSheet=\"0\""), content="true")
  inspect(drawing_xml.contains("fPrintsWithSheet=\"0\""), content="true")
}

///|
test "picture name and alt text" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    [9, 9],
    ".png",
    name="Logo",
    alt_text="Excel Logo",
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("name=\"Logo\""), content="true")
  inspect(drawing_xml.contains("descr=\"Excel Logo\""), content="true")
}

///|
test "picture lock aspect ratio" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    [9, 9],
    ".png",
    lock_aspect_ratio=true,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<a:picLocks"), content="true")
  inspect(drawing_xml.contains("noChangeAspect=\"1\""), content="true")
}

///|
test "picture positioning twoCell" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    [9, 9],
    ".png",
    positioning=PicturePositioning::TwoCell,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("<xdr:twoCellAnchor>"), content="true")
  inspect(drawing_xml.contains("<xdr:oneCellAnchor>"), content="false")
}

///|
test "picture positioning absolute" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_picture_from_bytes(
    "Sheet1",
    "A1",
    [9, 9],
    ".png",
    positioning=PicturePositioning::Absolute,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(
    drawing_xml.contains("<xdr:twoCellAnchor editAs=\"absolute\">"),
    content="true",
  )
  inspect(drawing_xml.contains("<xdr:oneCellAnchor>"), content="false")
}

///|
async test "picture autofit preserves aspect" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_col_width(1, 1.0)
  sheet.set_row_height(1, 10.0)
  workbook.add_picture("Sheet1", "A1", "excelize/logo.png", auto_fit=true)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("cx=\"76200\""), content="true")
  inspect(drawing_xml.contains("cy=\"76200\""), content="true")
}

///|
async test "picture autofit ignore aspect" {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.set_col_width(1, 1.0)
  sheet.set_row_height(1, 10.0)
  workbook.add_picture(
    "Sheet1",
    "A1",
    "excelize/logo.png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let drawing_xml = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) => @encoding/utf8.decode(value)
    None => fail("missing drawing")
  }
  inspect(drawing_xml.contains("cx=\"76200\""), content="true")
  inspect(drawing_xml.contains("cy=\"114300\""), content="true")
}

///|
test "picture options validation" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let result = try
    workbook.add_picture_from_bytes("Sheet1", "A1", [1, 2], ".png", offset_x=-1)
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result,
    content="Err(InvalidSheetOperation(msg=\"picture offset must be >= 0\"))",
  )
  let result2 = try
    workbook.add_picture_from_bytes(
      "Sheet1",
      "A1",
      [1, 2],
      ".png",
      hyperlink="https://example.com",
    )
  catch {
    err => Err(err)
  } noraise {
    _ => Ok(())
  }
  inspect(
    result2,
    content="Err(InvalidHyperlink(msg=\"picture hyperlink type missing\"))",
  )
}

///|
async test "picture from file path" {
  let workbook = Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  let stamp = @env.now().to_string()
  let path = "mbtexcel_picture_\{stamp}.png"
  @async/fs.write_file(path, b"img", create=0o644) catch {
    err => fail("write image failed: \{err}")
  }
  workbook.add_picture("Sheet1", "A1", path)
  let bytes = write(workbook)
  let archive = @zip.read(bytes)
  let stored = match archive.get("xl/media/image1.png") {
    Some(value) => value
    None => fail("missing image1.png")
  }
  inspect(stored == b"img", content="true")
  @async/fs.remove(path) catch {
    err => fail("remove image failed: \{err}")
  }
}
