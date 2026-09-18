///|
test "shape workbook sheet name validation" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  workbook.add_shape("Sheet1", @xlsx.Shape::new("A1", "rect"))
  let bad_name : Result[Unit, Error] = Ok(
    workbook.add_shape("Sheet:1", @xlsx.Shape::new("A1", "rect")),
  ) catch {
    e => Err(e)
  }
  inspect(bad_name is Err(@xlsx.XlsxError::InvalidSheetName(_)), content="true")
  let missing : Result[Unit, Error] = Ok(
    workbook.add_shape("SheetN", @xlsx.Shape::new("A1", "rect")),
  ) catch {
    e => Err(e)
  }
  inspect(missing is Err(@xlsx.XlsxError::SheetNotFound(_)), content="true")
}

///|
test "shape new validates basic fields" {
  inspect(
    (Ok(@xlsx.Shape::new("", "rect")) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "")) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", width=0)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", height=-1)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", scale_x=0.0)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", scale_y=-1.0)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", fill_transparency=-1)) catch {
      e => Err(e)
    })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", fill_transparency=101)) catch {
      e => Err(e)
    })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("A1", "rect", line_width=0.0)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.Shape::new("??", "rect")) catch { e => Err(e) })
    is Err(InvalidCellRef(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.ShapeFill::with_values(transparency=-1)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
  inspect(
    (Ok(@xlsx.ShapeFill::with_values(transparency=101)) catch { e => Err(e) })
    is Err(InvalidSheetOperation(_)),
    content="true",
  )
}

///|
test "shape new happy path with options" {
  let line = @xlsx.ShapeLine::with_values(color="FF0000", width=2.0)
  debug_inspect(line.color, content="Some(\"FF0000\")")
  debug_inspect(line.width, content="Some(2)")
  let line2 = @xlsx.ShapeLine::with_values()
  debug_inspect(line2.color, content="None")
  debug_inspect(line2.width, content="None")
  let fill = @xlsx.ShapeFill::with_values(color="00FF00", transparency=25)
  debug_inspect(fill.color, content="Some(\"00FF00\")")
  debug_inspect(fill.transparency, content="Some(25)")
  let fill2 = @xlsx.ShapeFill::with_values()
  debug_inspect(fill2.color, content="None")
  debug_inspect(fill2.transparency, content="None")
  let shape = @xlsx.Shape::new(
    "B2",
    "rect",
    macro_name="Macro1",
    text="Hello",
    width=120,
    height=80,
    scale_x=1.5,
    scale_y=2.0,
    fill_color="00FF00",
    fill_transparency=25,
    line_color="0000FF",
    line_width=1.25,
    name="S1",
    alt_text="Alt",
    print_object=false,
    locked=false,
    positioning=TwoCell,
  )
  inspect(shape.reference, content="B2")
  inspect(shape.cell, content="B2")
  inspect(shape.shape_type, content="rect")
  inspect(shape.macro_alias, content="Macro1")
  inspect(shape.macro_name, content="Macro1")
  inspect(shape.text, content="Hello")
  inspect(shape.width, content="120")
  inspect(shape.height, content="80")
  inspect(shape.scale_x, content="1.5")
  inspect(shape.scale_y, content="2")
  debug_inspect(shape.format.scale_x, content="Some(1.5)")
  debug_inspect(shape.format.scale_y, content="Some(2)")
  debug_inspect(shape.format.name, content="Some(\"S1\")")
  debug_inspect(shape.format.alt_text, content="Some(\"Alt\")")
  debug_inspect(shape.format.print_object, content="Some(false)")
  debug_inspect(shape.format.locked, content="Some(false)")
  debug_inspect(shape.format.positioning, content="Some(TwoCell)")
  debug_inspect(shape.fill.color, content="Some(\"00FF00\")")
  debug_inspect(shape.fill.transparency, content="Some(25)")
  inspect(shape.fill_color, content="00FF00")
  inspect(shape.fill_transparency, content="25")
  debug_inspect(shape.line.color, content="Some(\"0000FF\")")
  debug_inspect(shape.line.width, content="Some(1.25)")
  inspect(shape.line_color, content="0000FF")
  inspect(shape.line_width, content="1.25")
  inspect(shape.name, content="S1")
  inspect(shape.alt_text, content="Alt")
  inspect(shape.print_object, content="false")
  inspect(shape.locked, content="false")
  debug_inspect(shape.positioning, content="TwoCell")
}

///|
/// DrawingML's `ST_ShapeType` (ECMA-376 Part 1, 20.1.10.56) is an enumeration
/// of case-SENSITIVE tokens, and most of them carry a capital. Writing
/// `roundRect` as `roundrect` puts a value outside the enumeration into
/// `<a:prstGeom prst="...">`, which Excel does not recognise.
///
/// Every pre-existing shape test used `rect`, which is unaffected by
/// case-folding — which is exactly why this went unnoticed.
test "preset shape tokens keep their case through write and read" {
  let workbook = @xlsx.Workbook::new()
  ignore(workbook.add_sheet("Sheet1"))
  // One token per spelling hazard in ST_ShapeType: interior capital,
  // leading-abbreviation capital, a multi-hump token, and an all-lowercase
  // control that case-folding could never have broken.
  let tokens = ["roundRect", "rtTriangle", "lightningBolt", "rect"]
  for index, token in tokens {
    workbook.add_shape("Sheet1", @xlsx.Shape::new("A\{index + 1}", token))
  }
  let written = @xlsx.write(workbook)
  let archive = @zip.read(written) catch {
    ZipError(_, message) => fail("zip read failed: \{message}")
  }
  let drawing = match archive.get("xl/drawings/drawing1.xml") {
    Some(value) =>
      @encoding/utf8.decode(value) catch {
        _ => fail("drawing decode failed")
      }
    None => fail("drawing part missing")
  }
  // The serialized attribute must carry the exact token, never a folded one.
  for token in tokens {
    assert_true(drawing.contains("prst=\"\{token}\""))
  }
  for folded in ["roundrect", "rttriangle", "lightningbolt"] {
    assert_false(drawing.contains("prst=\"\{folded}\""))
  }
  // The reader already preserves the token verbatim, so a correct writer
  // makes the pair round-trip.
  let parsed = @xlsx.read(written)
  inspect(
    parsed
    .sheet("Sheet1")
    .unwrap()
    .shapes()
    .map(shape => shape.shape_type)
    .join(","),
    content="roundRect,rtTriangle,lightningBolt,rect",
  )
}
