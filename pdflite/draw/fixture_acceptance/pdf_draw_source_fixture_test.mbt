///|
fn draw_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn draw_fixture_document_for_test(path : String) -> @pdflite.PdfDocument? {
  let read_result = try? @fs.read_file(draw_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(@pdflite.pdf_read_document_from_bytes(data.binary()))
    Err(_) => None
  }
}

///|
fn draw_fixture_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn draw_fixture_matrix_for_test(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> @pdflite.TransformMatrix {
  { a, b, c, d, e, f }
}

///|
fn draw_fixture_lookup_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  match document.lookup_direct(draw_fixture_name_for_test(key), object) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn draw_fixture_count_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : @pdflite.PdfContentOp,
) -> Int {
  let mut count = 0
  for op in ops {
    if op == expected {
      count += 1
    }
  }
  count
}

///|
fn draw_fixture_assert_no_unknown_ops_for_test(
  path : String,
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Unit raise {
  for op in ops {
    match op {
      Op_Unknown(_) => fail("unexpected unknown content operator in " + path)
      _ => ()
    }
  }
}

///|
fn draw_fixture_page_ops_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfContentOp] raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
}

///|
async test "cpdf source non-image manual fixtures parse without unknown operators" {
  for
    path in [
      ".repos/cpdf-source/manualimages/bez.pdf", ".repos/cpdf-source/manualimages/capjoins.pdf",
      ".repos/cpdf-source/manualimages/clip.pdf", ".repos/cpdf-source/manualimages/colfill.pdf",
      ".repos/cpdf-source/manualimages/dash.pdf", ".repos/cpdf-source/manualimages/fill.pdf",
      ".repos/cpdf-source/manualimages/fontparams.pdf", ".repos/cpdf-source/manualimages/fonts.pdf",
      ".repos/cpdf-source/manualimages/h1.pdf", ".repos/cpdf-source/manualimages/line.pdf",
      ".repos/cpdf-source/manualimages/lines.pdf", ".repos/cpdf-source/manualimages/matrix.pdf",
      ".repos/cpdf-source/manualimages/para.pdf", ".repos/cpdf-source/manualimages/paras.pdf",
      ".repos/cpdf-source/manualimages/pop.pdf", ".repos/cpdf-source/manualimages/stext.pdf",
      ".repos/cpdf-source/manualimages/text.pdf", ".repos/cpdf-source/manualimages/textclip.pdf",
      ".repos/cpdf-source/manualimages/trans.pdf", ".repos/cpdf-source/manualimages/xobj.pdf",
    ] {
    match draw_fixture_document_for_test(path) {
      None => ()
      Some(document) => {
        let ops = draw_fixture_page_ops_for_test(document)
        guard ops.length() > 0 else { fail("expected content ops in " + path) }
        draw_fixture_assert_no_unknown_ops_for_test(path, ops)
      }
    }
  }
}

///|
async test "cpdf source capjoins manual fixture parses line cap join operators" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/capjoins.pdf",
    ) {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_j(1),
        Op_J(1),
        Op_M(1.0),
        Op_w(40.0),
        Op_l(200.0, 200.0),
        Op_l(220.0, 100.0),
        Op_S,
      ])
  }
}

///|
async test "cpdf source bezier and paint manual fixtures parse path operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/bez.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_c(400.0, 600.0, 600.0, 400.0, 300.0, 300.0),
        Op_S,
      ])
  }
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/line.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_l(400.0, 400.0),
        Op_l(400.0, 100.0),
        Op_h,
        Op_S,
      ])
  }
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/fill.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_l(400.0, 400.0),
        Op_l(400.0, 100.0),
        Op_h,
        Op_f,
      ])
  }
}

///|
async test "cpdf source xobject manual fixture parses form resource reuse" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/xobj.pdf") {
    None => ()
    Some(document) => {
      let pages = document.pages_of_pagetree()
      @test.assert_eq(pages.length(), 1)
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_Do(draw_fixture_name_for_test("/X1")),
        Op_RG(1.0, 0.0, 0.0),
        Op_cm(@pdflite.transform_translate(20.0, 20.0)),
        Op_Do(draw_fixture_name_for_test("/X1")),
      ])
      let xobjects = draw_fixture_lookup_for_test(
        document,
        pages[0].resources,
        "/XObject",
      )
      guard draw_fixture_lookup_for_test(document, xobjects, "/X1")
        is PdfStreamObject(form_stream) else {
        fail("expected /X1 form stream")
      }
      @test.assert_eq(
        draw_fixture_lookup_for_test(
          document,
          form_stream.dictionary,
          "/Subtype",
        ),
        PdfNameObject(draw_fixture_name_for_test("/Form")),
      )
      @test.assert_eq(
        draw_fixture_lookup_for_test(document, form_stream.dictionary, "/BBox"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(200),
          PdfInteger(200),
        ]),
      )
      let form_resources = draw_fixture_lookup_for_test(
        document,
        form_stream.dictionary,
        "/Resources",
      )
      @test.assert_eq(
        document.parse_content_ops_with_resources(form_resources, [
          PdfStreamObject(form_stream),
        ]),
        [
          Op_m(150.0, 100.0),
          Op_c(150.0, 127.614237492, 127.614237492, 150.0, 100.0, 150.0),
          Op_c(72.3857625085, 150.0, 50.0, 127.614237492, 50.0, 100.0),
          Op_c(50.0, 72.3857625085, 72.3857625085, 50.0, 100.0, 50.0),
          Op_c(127.614237492, 50.0, 150.0, 72.3857625085, 150.0, 100.0),
          Op_S,
        ],
      )
    }
  }
}

///|
async test "cpdf source clipping and colour manual fixtures parse graphics operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/clip.pdf") {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 13)
      @test.assert_eq(ops[0], Op_m(400.0, 300.0))
      @test.assert_eq(ops[5], Op_W)
      @test.assert_eq(ops[6], Op_n)
      @test.assert_eq(ops[12], Op_f)
    }
  }
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/colfill.pdf",
    ) {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 9)
      @test.assert_eq(ops[0], Op_w(20.0))
      @test.assert_eq(ops[6], Op_G(0.5))
      @test.assert_eq(ops[7], Op_rg(0.2, 0.7, 0.2))
      @test.assert_eq(ops[8], Op_B)
    }
  }
}

///|
async test "cpdf source matrix manual fixture parses save restore transforms" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/matrix.pdf") {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 22)
      @test.assert_eq(ops[5], Op_S)
      @test.assert_eq(ops[6], Op_q)
      @test.assert_eq(
        ops[7],
        Op_cm(
          draw_fixture_matrix_for_test(
            0.955336489126, -0.295520206661, 0.295520206661, 0.955336489126, 0.0,
            0.0,
          ),
        ),
      )
      @test.assert_eq(
        ops[8],
        Op_cm(draw_fixture_matrix_for_test(1.5, 0.0, 0.0, 2.0, 0.0, 0.0)),
      )
      @test.assert_eq(ops[15], Op_Q)
      @test.assert_eq(ops[21], Op_f)
    }
  }
}

///|
async test "cpdf source textclip manual fixture parses clipping text mode" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/textclip.pdf",
    ) {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 19)
      @test.assert_eq(ops[0], Op_Tr(7))
      @test.assert_eq(ops[1], Op_cm(@pdflite.transform_translate(100.0, 200.0)))
      @test.assert_eq(ops[2], Op_TL(55.0))
      @test.assert_eq(draw_fixture_count_op_for_test(ops, Op_Tstar), 2)
      @test.assert_eq(ops[18], Op_f)
    }
  }
}

///|
async test "cpdf source transparency manual fixture exposes extgstate and fill ops" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/trans.pdf") {
    None => ()
    Some(document) => {
      let pages = document.pages_of_pagetree()
      @test.assert_eq(pages.length(), 1)
      let extgstate = draw_fixture_lookup_for_test(
        document,
        pages[0].resources,
        "/ExtGState",
      )
      let graphics_state = draw_fixture_lookup_for_test(
        document, extgstate, "/G1",
      )
      @test.assert_eq(
        draw_fixture_lookup_for_test(document, graphics_state, "/ca"),
        PdfReal(0.5),
      )
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops[0], Op_gs(draw_fixture_name_for_test("/G1")))
      let mut fill_count = 0
      for op in ops {
        if op == Op_f {
          fill_count += 1
        }
      }
      @test.assert_eq(fill_count, 2)
    }
  }
}

///|
async test "cpdf source fontparams manual fixture parses text-state operators" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/fontparams.pdf",
    ) {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_cm(@pdflite.transform_translate(10.0, 20.0)),
        Op_BT,
        Op_Tz(75.0),
        Op_Tc(5.0),
        Op_Tw(20.0),
        Op_Tf(draw_fixture_name_for_test("/F1"), 72.0),
        Op_Tj(@ascii.encode("Different ")),
        Op_Tf(draw_fixture_name_for_test("/F2"), 72.0),
        Op_Tj(@ascii.encode("fonts")),
        Op_Ts(40.0),
        Op_Tf(draw_fixture_name_for_test("/F2"), 36.0),
        Op_Tj(@ascii.encode(" and sizes")),
        Op_ET,
      ])
  }
}

///|
async test "cpdf source dash manual fixture parses dash operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/dash.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_w(20.0),
        Op_d([30.0, 20.0], 0.0),
        Op_l(400.0, 300.0),
        Op_S,
      ])
  }
}

///|
async test "cpdf source text manual fixture parses text section operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/text.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_cm(@pdflite.transform_translate(50.0, 50.0)),
        Op_BT,
        Op_Tf(draw_fixture_name_for_test("/F1"), 144.0),
        Op_Tj(@ascii.encode("Hello")),
        Op_ET,
      ])
  }
}
