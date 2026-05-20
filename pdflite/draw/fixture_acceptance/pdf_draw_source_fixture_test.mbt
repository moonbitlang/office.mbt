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
