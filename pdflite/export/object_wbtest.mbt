// White-box tests of the object serialization and other internals.

///|
fn wb_latin1(b : BytesView) -> String {
  let sb = StringBuilder()
  for x in b {
    sb.write_char(x.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
test "format_real writes the shortest digits of the f32 value like pdf-writer" {
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
    cases.map(format_real).join(" "),
    content=(
      #|0 1 -3 0.5 -0.25 0.33333334 0.6666667 123.45679 0.000004 0.000005 -0.000001 10000000000 0 0
    ),
  )
}

///|
test "bbox_of_points" {
  debug_inspect(
    bbox_of_points([]),
    content=(
      #|None
    ),
  )
  debug_inspect(
    bbox_of_points([
      Point::from_xy(3.0, -1.0),
      Point::from_xy(-2.0, 4.0),
      Point::from_xy(1.0, 1.0),
    ]),
    content=(
      #|Some({ left: -2, top: -1, right: 3, bottom: 4 })
    ),
  )
}

///|
test "object serialization" {
  let buf = Buffer()
  write_obj(
    buf,
    Dict([
      ("Null", Null),
      ("Bool", Bool(true)),
      ("Int", Int(-7)),
      ("Real", Real(1.25)),
      ("Name", Name("A B#/(x)")),
      ("Str", Str(utf8_bytes("a(b)\\c"))),
      ("Bin", Str(b"\x00\xff")),
      ("Text", TextStr("plain")),
      ("Uni", TextStr("é")),
      ("Arr", Arr([Int(1), Ref(12)])),
    ]),
  )
  inspect(
    wb_latin1(buf.to_bytes()),
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
  write_name(buf, "Ünï")
  inspect(
    wb_latin1(buf.to_bytes()),
    content=(
      #|/#C3#9Cn#C3#AF
    ),
  )
  debug_inspect(
    utf8_bytes("aé€😀"),
    content=(
      #|<Bytes: [0x61, 0xc3, 0xa9, 0xe2, 0x82, 0xac, 0xf0, 0x9f, 0x98, 0x80]>
    ),
  )
  debug_inspect(
    text_string_bytes("tab\tok"),
    content=(
      #|<Bytes: [0x74, 0x61, 0x62, 0x09, 0x6f, 0x6b]>
    ),
  )
  debug_inspect(
    text_string_bytes("€"),
    content=(
      #|<Bytes: [0xfe, 0xff, 0x20, 0xac]>
    ),
  )
  debug_inspect(
    text_string_bytes("😀"),
    content=(
      #|<Bytes: [0xfe, 0xff, 0xd8, 0x3d, 0xde, 0x00]>
    ),
  )
}

///|
test "write_file produces a parseable classic file" {
  let objects : Map[Int, Indirect] = {
    1: Plain(Dict([("Type", Name("Catalog")), ("Pages", Ref(2))])),
    2: Plain(
      Dict([("Type", Name("Pages")), ("Count", Int(0)), ("Kids", Arr([]))]),
    ),
    4: Stream([("Foo", Int(1))], b"hello"),
  }
  let bytes = write_file("1.5", objects, 4, 1, None, None)
  let text = wb_latin1(bytes)
  inspect(
    text.has_prefix("%PDF-1.5\n%"),
    content=(
      #|true
    ),
  )
  inspect(text.contains("0000000000 65535 f\r\n0000000"), content="true")
  // pdflite's reader understands the file.
  let doc = @pdflite.pdf_read_document_from_bytes(bytes)
  inspect(doc.root, content="1")
  let stream = doc.direct(PdfIndirect(4))
  inspect(
    wb_latin1(@pdflite.pdf_decode_stream(stream).stream_bytes()),
    content="hello",
  )
}

///|
test "DictBuilder replaces entries in place" {
  let d = DictBuilder::new()
  d.set("A", Int(1))
  d.set("B", Int(2))
  d.set("A", Int(3))
  let buf = Buffer()
  write_obj(buf, d.finish())
  inspect(
    wb_latin1(buf.to_bytes()),
    content=(
      #|<</A 3
      #|/B 2
      #|>>
    ),
  )
  inspect(d.get("C") is None, content="true")
}

///|
test "format_real handles large values" {
  // (Never in exponent notation, which PDF doesn't have.)
  inspect(
    [1.5e15, -2.5e15 - 1.0, 123456789012345.6, 1.0e20, -1.5e25]
    .map(format_real)
    .join(" "),
    content=(
      #|1500000000000000 -2500000000000000 123456790000000 100000000000000000000 -15000000000000000000000000
    ),
  )
}

///|
test "validator internals" {
  let v = Validators::{ a: Some(A2_A), ua: Some(UA1), }
  inspect(v.requires_tagging(), content="true")
  inspect(v.requires_codepoint_mappings(), content="true")
  inspect(v.requires_display_doc_title(), content="true")
  inspect(v.requires_annotation_flags(), content="true")
  inspect(v.prohibits_info_dict(), content="false")
  debug_inspect(
    v.prohibits(NoDocumentTitle),
    content=(
      #|Some({ a: None, ua: Some(UA1) })
    ),
  )
  debug_inspect(
    v.prohibits(MissingTagging),
    content=(
      #|Some({ a: Some(A2_A), ua: Some(UA1) })
    ),
  )
  debug_inspect(
    v.prohibits(TooLongArray),
    content=(
      #|None
    ),
  )
  let versions : Array[PdfVersion] = [Pdf14, Pdf15, Pdf16, Pdf17, Pdf20]
  debug_inspect(
    versions.map(v => v.deprecates_cid_set()),
    content=(
      #|[false, false, false, false, true]
    ),
  )
}

///|
/// A name-keyed CFF table (header, Name INDEX "X", Top DICT, empty String
/// and Global Subr INDEXes, Private DICT with one local subroutine, three
/// charstrings).
fn wb_name_keyed_cff() -> Bytes {
  let top : Array[Byte] = []
  // FullName (SID 0), CharStrings, Private.
  for b in [b'\x8B', b'\x02'] {
    top.push(b)
  }
  cff_push_int32(top, 4 + 6 + 2 + 1 + 2 + 19 + 2 + 2 + 4 + 6)
  cff_push_op(top, 17)
  cff_push_int32(top, 4)
  cff_push_int32(top, 4 + 6 + 2 + 1 + 2 + 19 + 2 + 2)
  cff_push_op(top, 18)
  let out : Array[Byte] = [b'\x01', b'\x00', b'\x04', b'\x01']
  for b in [b'\x00', b'\x01', b'\x01', b'\x01', b'\x02', b'X'] {
    out.push(b)
  }
  for b in [b'\x00', b'\x01', b'\x01', b'\x01', (top.length() + 1).to_byte()] {
    out.push(b)
  }
  for b in top {
    out.push(b)
  }
  for b in [b'\x00', b'\x00', b'\x00', b'\x00'] {
    out.push(b)
  }
  // Private DICT: defaultWidthX 0, Subrs at offset 4.
  for b in [b'\x8B', b'\x14', b'\x8F', b'\x13'] {
    out.push(b)
  }
  // Local Subrs: one `return`.
  for b in [b'\x00', b'\x01', b'\x01', b'\x01', b'\x02', b'\x0B'] {
    out.push(b)
  }
  // CharStrings: three `endchar`s.
  for
    b in [
      b'\x00', b'\x03', b'\x01', b'\x01', b'\x02', b'\x03', b'\x04', b'\x0E', b'\x0E',
      b'\x0E',
    ] {
    out.push(b)
  }
  Bytes::from_array(out)
}

///|
test "name-keyed CFF tables are converted to CID-keyed ones" {
  let data = wb_name_keyed_cff()
  let table = cff_table(data, 0, data.length()).unwrap()
  inspect(table.is_cid_keyed(), content="false")
  inspect(table.num_glyphs, content="3")
  let converted = table.to_cid_keyed(data).unwrap()
  let t = cff_table(converted, 0, converted.length()).unwrap()
  inspect(t.is_cid_keyed(), content="true")
  // An identity charset, the original charstrings and strings plus the
  // registry and ordering.
  debug_inspect(
    t.cids(converted),
    content=(
      #|Some([0, 1, 2])
    ),
  )
  inspect(
    converted[t.charstrings.0:t.charstrings.1] ==
    data[table.charstrings.0:table.charstrings.1],
    content="true",
  )
  inspect(
    t.strings.map(r => wb_latin1(converted[r.0:r.1])).join(" "),
    content=(
      #|Adobe Identity
    ),
  )
  // The Top DICT: ROS, the kept FullName, a default FontMatrix and the
  // offsets.
  debug_inspect(
    t.top.map(e => (e.op, e.operands)),
    content=(
      #|[
      #|  (1230, [391, 392, 0]),
      #|  (2, [0]),
      #|  (1207, [0, 0, 0, 0, 0, 0]),
      #|  (1234, [3]),
      #|  (15, [113]),
      #|  (17, [166]),
      #|  (1236, [126]),
      #|  (1237, [118]),
      #|]
    ),
  )
  // The Font DICT refers to a copy of the Private DICT, whose local
  // subroutines follow at the same relative offset.
  let fd_array = cff_operands(t.top, 1236).unwrap()[0]
  let (fds, _) = cff_index(converted, fd_array, converted.length()).unwrap()
  let fd = cff_dict(converted, fds[0].0, fds[0].1).unwrap()
  let private = cff_operands(fd, 18).unwrap()
  inspect(
    converted[private[1]:private[1] + private[0] + 6] == data[38:48],
    content="true",
  )
  // FDSelect format 3: one range with Font DICT 0.
  let fd_select = cff_operands(t.top, 1237).unwrap()[0]
  debug_inspect(
    converted[fd_select:fd_select + 8],
    content=(
      #|<BytesView: [0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x03]>
    ),
  )
}

///|
test "seac detection follows subroutines with all number encodings" {
  // data: [return] [0 0 65 66 endchar] then charstrings calling subroutine
  // 215 (108 + bias 107) with a two-byte number and a hintmask with an
  // implicit vstem before it.
  let data : Bytes = [
    0x0B, 0x8B, 0x8B, 0xCC, 0xCD, 0x0E, 0xF7, 0x00, 0x0A, 0x8B, 0x8C, 0x8B, 0x8C,
    0x13, 0xC0, 0xF7, 0x00, 0x0A, 0x0E, 0xFF, 0x00, 0x01, 0x00, 0x00, 0x0E,
  ]
  let local_subrs = Array::makei(216, i => {
    if i == 215 {
      (1, 6)
    } else {
      (0, 1)
    }
  })
  let programs = CffPrograms::{
    charstrings: [(6, 9), (9, 19), (19, 25)],
    global_subrs: [],
    local_subrs,
  }
  debug_inspect(
    [0, 1, 2].map(g => programs.uses_seac(data, g)),
    content=(
      #|[Some(true), Some(true), Some(false)]
    ),
  )
}

///|
test "seac detection tracks the stack depth through computed values" {
  let programs = [
    // 0 0 65 65 1 add endchar: four operands after `add`.
    [0x8B, 0x8B, 0xCC, 0xCC, 0x8C, 0x0C, 0x0A, 0x0E],
    // 100 2 div endchar: only a (computed) width.
    [0xEF, 0x8D, 0x0C, 0x0C, 0x0E],
    // 0 30 2 div hstem endchar: a computed stem.
    [0x8B, 0xA9, 0x8D, 0x0C, 0x0C, 0x01, 0x0E],
    // 1 2 dup exch drop 7 8 endchar: four operands after stack operators.
    [0x8C, 0x8D, 0x0C, 0x1B, 0x0C, 0x1C, 0x0C, 0x12, 0x92, 0x93, 0x0E],
    // 1 2 3 4 5 6 2 1 roll drop drop endchar: four operands.
    [
      0x8C, 0x8D, 0x8E, 0x8F, 0x90, 0x91, 0x8D, 0x8C, 0x0C, 0x1E, 0x0C, 0x12, 0x0C,
      0x12, 0x0E,
    ],
    // 1 2 3 4 1 put drop endchar: one operand left.
    [0x8C, 0x8D, 0x8E, 0x8F, 0x8C, 0x0C, 0x14, 0x0C, 0x12, 0x0E],
    // Seven operands consumed by `hflex`, then endchar.
    [0x8B, 0x8B, 0x8B, 0x8B, 0x8B, 0x8B, 0x8B, 0x0C, 0x22, 0x0E],
    // random callsubr: a computed subroutine index can't be followed.
    [0x0C, 0x17, 0x0A, 0x0E],
    // drop on an empty stack: malformed.
    [0x0C, 0x12, 0x0E],
  ]
  let data : Array[Byte] = []
  let charstrings = []
  for p in programs {
    let start = data.length()
    for b in p {
      data.push(b.to_byte())
    }
    charstrings.push((start, data.length()))
  }
  let cff = CffPrograms::{ charstrings, global_subrs: [], local_subrs: [], }
  debug_inspect(
    Array::makei(programs.length(), g => {
      cff.uses_seac(Bytes::from_array(data), g)
    }),
    content=(
      #|[
      #|  Some(true),
      #|  Some(false),
      #|  Some(false),
      #|  Some(true),
      #|  Some(true),
      #|  Some(false),
      #|  Some(false),
      #|  Some(true),
      #|  None,
      #|]
    ),
  )
}

///|
test "streams get exactly one Length" {
  let objects : Map[Int, Indirect] = {
    1: Stream([("Length", Int(99)), ("Foo", Int(1))], b"abc"),
  }
  let text = wb_latin1(write_file("1.7", objects, 1, 1, None, None))
  inspect(text.contains("<</Foo 1\n/Length 3\n>>"), content="true")
}

///|
test "format_real keeps small values and never writes exponents" {
  inspect(
    [0.000001, 1.0e-7, -2.5e-9, 1.0e-40, 3.0e39, 0.1, 1.0e-6 * 3.0]
    .map(format_real)
    .join(" "),
    content=(
      #|0.000001 0.0000001 -0.0000000025 0.0000000000000000000000000000000000000001 3000000000000000000000000000000000000000 0.1 0.000003
    ),
  )
}
