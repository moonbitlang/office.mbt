///|
fn drawing_preservation_test_utf8(
  archive : @zip.Archive,
  path : String,
) -> String raise Error {
  let bytes = match archive.get(path) {
    Some(value) => value
    None => fail("missing archive part: \{path}")
  }
  @encoding/utf8.decode(bytes) catch {
    _ => fail("archive part is not UTF-8: \{path}")
  }
}

///|
fn drawing_preservation_test_position(
  xml : String,
  marker : String,
) -> Int raise Error {
  match xml.find(marker) {
    Some(value) => value
    None => fail("missing drawing marker: \{marker}")
  }
}

///|
fn drawing_preservation_test_count(
  value : StringView,
  needle : StringView,
) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut cursor = 0
  while cursor + needle.length() <= value.length() {
    match value[cursor:].find(needle) {
      Some(offset) => {
        count = count + 1
        cursor = cursor + offset + needle.length()
      }
      None => break
    }
  }
  count
}

///|
fn drawing_preservation_test_fixture(
  include_opaque_relationship : Bool,
) -> Bytes raise Error {
  let workbook = Workbook::new()
  let sheet = workbook.add_sheet("Sheet1")
  sheet.add_shape(Shape::new("A1", "rect", text="known-shape"))
  sheet.add_image(
    "B1",
    b"synthetic image",
    "png",
    "image/png",
    name="Known Image",
  )
  sheet.add_chart(
    "C1",
    (
      #|<?xml version="1.0" encoding="UTF-8"?>
      #|<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart"><c:chart/></c:chartSpace>
      #|
    ),
  )
  let archive = @zip.read(write(workbook))
  let drawing_path = "xl/drawings/drawing1.xml"
  let drawing_rels_path = "xl/drawings/_rels/drawing1.xml.rels"
  let drawing = drawing_preservation_test_utf8(archive, drawing_path)
  let generated = parse_drawing_anchors(drawing)
  let mut image_anchor : String? = None
  let mut chart_anchor : String? = None
  let mut shape_anchor : String? = None
  for anchor in generated {
    if anchor.xml.contains("<xdr:pic>") {
      image_anchor = Some(anchor.xml)
    } else if anchor.xml.contains("<c:chart") {
      chart_anchor = Some(anchor.xml)
    } else if anchor.xml.contains("<xdr:sp>") {
      shape_anchor = Some(anchor.xml)
    }
  }
  let shape = shape_anchor.unwrap_or_else(() => fail("missing shape anchor"))
  let image = image_anchor
    .unwrap_or_else(() => fail("missing image anchor"))
    .replace_all(old="rId1", new="rId5")
    .replace(old="id=\"1\"", new="id=\"5\"")
  let chart = chart_anchor.unwrap_or_else(() => fail("missing chart anchor"))
  // The public writer must honor insertion order even though its individual
  // serializers are organized by object type.
  assert_true(
    drawing_preservation_test_position(drawing, "known-shape") <
    drawing_preservation_test_position(drawing, "<xdr:pic>"),
  )
  assert_true(
    drawing_preservation_test_position(drawing, "<xdr:pic>") <
    drawing_preservation_test_position(drawing, "<c:chart"),
  )
  let opaque_content =
    #|<xdr:oneCellAnchor><xdr:from><xdr:col>3</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="9525" cy="9525"/><xdr:contentPart r:id="rId1"/><xdr:clientData/></xdr:oneCellAnchor>
  let opaque_group =
    #|<xdr:oneCellAnchor><xdr:from><xdr:col>4</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>0</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from><xdr:ext cx="9525" cy="9525"/><xdr:grpSp><xdr:nvGrpSpPr><xdr:cNvPr id="1" name="Opaque Group"/></xdr:nvGrpSpPr><xdr:grpSpPr/></xdr:grpSp><xdr:clientData/></xdr:oneCellAnchor>
  let patched_drawing = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<xdr:wsDr xmlns:xdr=\"http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing\" xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" xmlns:c=\"http://schemas.openxmlformats.org/drawingml/2006/chart\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">\n" +
    shape +
    "\n" +
    opaque_content +
    image +
    "\n" +
    opaque_group +
    chart +
    "\n</xdr:wsDr>"
  assert_true(
    archive.replace(drawing_path, @encoding/utf8.encode(patched_drawing)),
  )
  let original_rels = drawing_preservation_test_utf8(archive, drawing_rels_path)
  let opaque_relationship = if include_opaque_relationship {
    "  <Relationship Id=\"rId1\" Type=\"urn:example:opaque\" Target=\"../../custom/opaque.xml\"/>\n"
  } else {
    ""
  }
  let patched_rels = original_rels
    .replace(old="Id=\"rId1\"", new="Id=\"rId5\"")
    .replace(
      old="</Relationships>",
      new=opaque_relationship + "</Relationships>",
    )
  assert_true(
    archive.replace(drawing_rels_path, @encoding/utf8.encode(patched_rels)),
  )
  archive.add("custom/opaque.xml", b"<opaque>payload</opaque>")
  archive.add("custom/nested/data.bin", b"opaque nested payload")
  archive.add(
    "custom/_rels/opaque.xml.rels",
    @encoding/utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8"?>
        #|<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        #|  <Relationship Id="child" Type="urn:example:child" Target="nested/data.bin"/>
        #|  <Relationship Id="external" Type="urn:example:external" Target="https://example.invalid/resource" TargetMode="External"/>
        #|</Relationships>
        #|
      ),
    ),
  )
  let content_types_path = "[Content_Types].xml"
  let content_types = drawing_preservation_test_utf8(
    archive, content_types_path,
  )
  let patched_content_types = content_types.replace(
    old="</Types>",
    new="<Override PartName=\"/custom/opaque.xml\" ContentType=\"application/vnd.example.opaque+xml\"/>" +
      "<Override PartName=\"/custom/nested/data.bin\" ContentType=\"application/vnd.example.opaque-data\"/>" +
      "</Types>",
  )
  assert_true(
    archive.replace(
      content_types_path,
      @encoding/utf8.encode(patched_content_types),
    ),
  )
  @zip.write(archive)
}

///|
fn assert_drawing_preservation_test_output(
  archive : @zip.Archive,
) -> Unit raise Error {
  let drawing = drawing_preservation_test_utf8(
    archive, "xl/drawings/drawing1.xml",
  )
  let shape_pos = drawing_preservation_test_position(drawing, "known-shape")
  let content_pos = drawing_preservation_test_position(
    drawing, "<xdr:contentPart r:id=\"rId1\"",
  )
  let image_pos = drawing_preservation_test_position(drawing, "<xdr:pic>")
  let group_pos = drawing_preservation_test_position(drawing, "Opaque Group")
  let chart_pos = drawing_preservation_test_position(drawing, "<c:chart")
  assert_true(shape_pos < content_pos)
  assert_true(content_pos < image_pos)
  assert_true(image_pos < group_pos)
  assert_true(group_pos < chart_pos)
  assert_eq(drawing_preservation_test_count(drawing, "<xdr:cNvPr id=\"1\""), 1)
  let drawing_rels = drawing_preservation_test_utf8(
    archive, "xl/drawings/_rels/drawing1.xml.rels",
  )
  assert_true(
    drawing_rels.contains(
      "Id=\"rId1\" Type=\"urn:example:opaque\" Target=\"/xl/preservedDrawingParts/drawing1/part1.bin\"",
    ),
  )
  assert_true(
    drawing_rels.contains(
      "Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\"",
    ),
  )
  assert_true(
    drawing_rels.contains(
      "Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart\"",
    ),
  )
  let opaque_part_path = "xl/preservedDrawingParts/drawing1/part1.bin"
  let nested_part_path = "xl/preservedDrawingParts/drawing1/part2.bin"
  assert_true(
    archive.get(opaque_part_path).unwrap_or(b"") == b"<opaque>payload</opaque>",
  )
  assert_true(
    archive.get(nested_part_path).unwrap_or(b"") == b"opaque nested payload",
  )
  let opaque_rels = drawing_preservation_test_utf8(
    archive, "xl/preservedDrawingParts/drawing1/_rels/part1.bin.rels",
  )
  assert_true(
    opaque_rels.contains(
      "Id=\"child\" Type=\"urn:example:child\" Target=\"/xl/preservedDrawingParts/drawing1/part2.bin\"",
    ),
  )
  assert_true(
    opaque_rels.contains(
      "Id=\"external\" Type=\"urn:example:external\" Target=\"https://example.invalid/resource\" TargetMode=\"External\"",
    ),
  )
  let content_types = drawing_preservation_test_utf8(
    archive, "[Content_Types].xml",
  )
  assert_true(
    content_types.contains(
      "PartName=\"/xl/preservedDrawingParts/drawing1/part1.bin\" ContentType=\"application/vnd.example.opaque+xml\"",
    ),
  )
  assert_true(
    content_types.contains(
      "PartName=\"/xl/preservedDrawingParts/drawing1/part2.bin\" ContentType=\"application/vnd.example.opaque-data\"",
    ),
  )
  assert_true(archive.get("custom/opaque.xml") is None)
}

///|
test "opaque drawing anchors preserve order ids and relationship closure" {
  let parsed = read(drawing_preservation_test_fixture(true))
  let first = @zip.read(write(parsed))
  assert_drawing_preservation_test_output(first)
  // A second read/write cycle proves the isolated projection is itself a
  // complete, readable OPC subgraph rather than a one-shot copy operation.
  let second = @zip.read(write(read(@zip.write(first))))
  assert_drawing_preservation_test_output(second)
}

///|
test "opaque drawing anchors reject missing relationships" {
  try read(drawing_preservation_test_fixture(false)) catch {
    InvalidXml(msg~) =>
      assert_eq(msg, "unsupported drawing relationship missing")
    _ => fail("unexpected opaque drawing relationship error")
  } noraise {
    _ => fail("expected missing opaque drawing relationship rejection")
  }
}
