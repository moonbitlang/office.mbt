///|
test "format_real writes integers plainly and at most five decimals" {
  let cases = [
    0.0,
    1.0,
    -3.0,
    0.5,
    -0.25,
    1.0 / 3.0,
    2.0 / 3.0,
    123.456789,
    0.000004,
    0.000005,
    -0.000001,
    1.0e10,
    1.0 / 0.0,
    0.0 / 0.0,
  ]
  inspect(
    cases.map(@export.format_real).join(" "),
    content="0 1 -3 0.5 -0.25 0.33333 0.66667 123.45679 0 0.00001 0 10000000000 0 0",
  )
}

///|
test "Size and Rect constructors reject invalid geometry" {
  debug_inspect(
    @export.Size::from_wh(1.0, 2.0),
    content=(
      #|Some({ width: 1, height: 2 })
    ),
  )
  debug_inspect(
    @export.Size::from_wh(0.0, 2.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Size::from_wh(1.0, 1.0 / 0.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Rect::from_xywh(1.0, 2.0, 3.0, 4.0),
    content=(
      #|Some({ left: 1, top: 2, right: 4, bottom: 6 })
    ),
  )
  debug_inspect(
    @export.Rect::from_ltrb(5.0, 0.0, 1.0, 1.0),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.Rect::from_ltrb(0.0 / 0.0, 0.0, 1.0, 1.0),
    content=(
      #|None
    ),
  )
  let r = @export.Rect::from_xywh(10.0, 20.0, 30.0, 5.0).unwrap()
  debug_inspect(
    (r.width(), r.height()),
    content=(
      #|(30, 5)
    ),
  )
}

///|
test "Rect union, transform and PDF arrays" {
  let a = @export.Rect::from_ltrb(0.0, 0.0, 10.0, 10.0).unwrap()
  let b = @export.Rect::from_ltrb(5.0, -5.0, 20.0, 8.0).unwrap()
  debug_inspect(
    a.union(b),
    content=(
      #|{ left: 0, top: -5, right: 20, bottom: 10 }
    ),
  )
  // Rotating by 90 degrees and translating.
  let rot = @export.Transform::from_row(0.0, 1.0, -1.0, 0.0, 100.0, 0.0)
  debug_inspect(
    b.transform(rot),
    content=(
      #|{ left: 92, top: 5, right: 105, bottom: 20 }
    ),
  )
  let buf = Buffer()
  @export.write_obj(buf, b.to_pdf())
  inspect(
    buf.to_bytes() |> latin1,
    content=(
      #|[5 -5 20 8]
    ),
  )
}

///|
test "bbox_of_points" {
  debug_inspect(
    @export.bbox_of_points([]),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @export.bbox_of_points([
      @export.Point::from_xy(3.0, -1.0),
      @export.Point::from_xy(-2.0, 4.0),
      @export.Point::from_xy(1.0, 1.0),
    ]),
    content=(
      #|Some({ left: -2, top: -1, right: 3, bottom: 4 })
    ),
  )
}

///|
test "Transform concatenation order, application and inversion" {
  let t = @export.Transform::from_translate(10.0, 20.0)
  let s = @export.Transform::from_scale(2.0, 3.0)
  // pre_concat applies the argument first.
  debug_inspect(
    t.pre_concat(s).apply(1.0, 1.0),
    content=(
      #|{ x: 12, y: 23 }
    ),
  )
  // post_concat applies the receiver first.
  debug_inspect(
    t.post_concat(s).apply(1.0, 1.0),
    content=(
      #|{ x: 22, y: 63 }
    ),
  )
  let m = @export.Transform::from_row(2.0, 1.0, -1.0, 3.0, 5.0, 7.0)
  let inv = m.invert().unwrap()
  let p = m.pre_concat(inv).apply(4.0, -6.0)
  debug_inspect(
    p,
    content=(
      #|{ x: 4, y: -6 }
    ),
  )
  inspect(
    m.pre_concat(inv).is_identity(),
    content=(
      #|true
    ),
  )
  debug_inspect(
    @export.Transform::from_scale(0.0, 1.0).invert(),
    content=(
      #|None
    ),
  )
  inspect(
    @export.Transform::identity().is_identity(),
    content=(
      #|true
    ),
  )
  let buf = Buffer()
  @export.write_obj(buf, m.to_pdf())
  inspect(
    buf.to_bytes() |> latin1,
    content=(
      #|[2 1 -1 3 5 7]
    ),
  )
}

///|
test "PathBuilder segments" {
  let pb = @export.PathBuilder::new()
  // A path without drawing segments is empty.
  debug_inspect(
    pb.finish(),
    content=(
      #|None
    ),
  )
  pb.move_to(0.0, 0.0)
  debug_inspect(
    pb.finish(),
    content=(
      #|None
    ),
  )
  // Consecutive move-tos replace each other.
  pb.move_to(1.0, 1.0)
  pb.line_to(5.0, 1.0)
  pb.quad_to(6.0, 2.0, 5.0, 3.0)
  pb.close()
  pb.close()
  // A segment after a close starts at the start of the closed subpath.
  pb.cubic_to(1.0, 4.0, 2.0, 5.0, 3.0, 6.0)
  pb.move_to(9.0, 9.0)
  let path = pb.finish().unwrap()
  debug_inspect(
    path.segments,
    content=(
      #|[
      #|  MoveTo({ x: 1, y: 1 }),
      #|  LineTo({ x: 5, y: 1 }),
      #|  QuadTo({ x: 6, y: 2 }, { x: 5, y: 3 }),
      #|  Close,
      #|  MoveTo({ x: 1, y: 1 }),
      #|  CubicTo({ x: 1, y: 4 }, { x: 2, y: 5 }, { x: 3, y: 6 }),
      #|]
    ),
  )
  debug_inspect(
    path.bounds(),
    content=(
      #|Some({ left: 1, top: 1, right: 6, bottom: 6 })
    ),
  )
  debug_inspect(
    path.transform(@export.Transform::from_translate(1.0, 0.0)).bounds(),
    content=(
      #|Some({ left: 2, top: 1, right: 7, bottom: 6 })
    ),
  )
}

///|
test "PathBuilder line_to injects a move-to at the origin" {
  let pb = @export.PathBuilder::new()
  pb.line_to(4.0, 2.0)
  debug_inspect(
    pb.finish().unwrap().segments,
    content=(
      #|[MoveTo({ x: 0, y: 0 }), LineTo({ x: 4, y: 2 })]
    ),
  )
}

///|
test "object serialization" {
  let buf = Buffer()
  @export.write_obj(
    buf,
    Dict([
      ("Null", Null),
      ("Bool", Bool(true)),
      ("Int", Int(-7)),
      ("Real", Real(1.25)),
      ("Name", Name("A B#/(x)")),
      ("Str", Str(@export.utf8_bytes("a(b)\\c"))),
      ("Bin", Str(b"\x00\xff")),
      ("Text", TextStr("plain")),
      ("Uni", TextStr("é")),
      ("Arr", Arr([Int(1), Ref(12)])),
    ]),
  )
  inspect(
    latin1(buf.to_bytes()),
    content=(
      #|<</Null null
      #|/Bool true
      #|/Int -7
      #|/Real 1.25
      #|/Name /A#20B#23#2F#28x#29
      #|/Str (a\(b\)\\c)
      #|/Bin <00FF>
      #|/Text (plain)
      #|/Uni <FEFF00E9>
      #|/Arr [1 12 0 R]
      #|>>
    ),
  )
  let buf = Buffer()
  @export.write_name(buf, "Ünï")
  inspect(
    latin1(buf.to_bytes()),
    content=(
      #|/#C3#9Cn#C3#AF
    ),
  )
  debug_inspect(
    @export.utf8_bytes("aé€😀"),
    content=(
      #|<Bytes: [0x61, 0xc3, 0xa9, 0xe2, 0x82, 0xac, 0xf0, 0x9f, 0x98, 0x80]>
    ),
  )
  debug_inspect(
    @export.text_string_bytes("tab\tok"),
    content=(
      #|<Bytes: [0x74, 0x61, 0x62, 0x09, 0x6f, 0x6b]>
    ),
  )
  debug_inspect(
    @export.text_string_bytes("€"),
    content=(
      #|<Bytes: [0xfe, 0xff, 0x20, 0xac]>
    ),
  )
  debug_inspect(
    @export.text_string_bytes("😀"),
    content=(
      #|<Bytes: [0xfe, 0xff, 0xd8, 0x3d, 0xde, 0x00]>
    ),
  )
}

///|
test "write_file produces a parseable classic file" {
  let objects : Map[Int, @export.Indirect] = {
    1: Plain(Dict([("Type", Name("Catalog")), ("Pages", Ref(2))])),
    2: Plain(
      Dict([("Type", Name("Pages")), ("Count", Int(0)), ("Kids", Arr([]))]),
    ),
    4: Stream([("Foo", Int(1))], b"hello"),
  }
  let bytes = @export.write_file("1.5", objects, 4, 1, None, None)
  let text = latin1(bytes)
  inspect(
    text.has_prefix("%PDF-1.5\n%"),
    content=(
      #|true
    ),
  )
  inspect(
    contains(text, "0000000000 65535 f\r\n0000000"),
    content=(
      #|true
    ),
  )
  let p = parse(bytes)
  inspect(
    p.show(p.trailer()),
    content=(
      #|<</Size 5 /Root R>>
    ),
  )
  inspect(
    p.show(p.catalog()),
    content=(
      #|<</Type /Catalog /Pages R>>
    ),
  )
  inspect(
    latin1(p.stream_data(PdfIndirect(4))),
    content=(
      #|hello
    ),
  )
  inspect(
    p.show(p.resolve(PdfIndirect(4))),
    content=(
      #|stream<</Foo 1 /Length 5>>
    ),
  )
}

///|
test "DictBuilder replaces entries in place" {
  let d = @export.DictBuilder::new()
  d.set("A", Int(1))
  d.set("B", Int(2))
  d.set("A", Int(3))
  let buf = Buffer()
  @export.write_obj(buf, d.finish())
  inspect(
    latin1(buf.to_bytes()),
    content=(
      #|<</A 3
      #|/B 2
      #|>>
    ),
  )
  inspect(d.get("C") is None, content="true")
}

///|
test "format_real handles values beyond the five-decimal Int64 range" {
  // `v * 100000` used to overflow an Int64 from about 9.2e13 on, writing
  // garbage like `92233720368547.75807`.
  inspect(
    [1.5e15, -2.5e15 - 1.0, 123456789012345.6, 1.0e20, -1.5e25]
    .map(@export.format_real)
    .join(" "),
    content=(
      #|1500000000000000 -2500000000000001 123456789012346 100000000000000000000 -15000000000000000000000000
    ),
  )
}
