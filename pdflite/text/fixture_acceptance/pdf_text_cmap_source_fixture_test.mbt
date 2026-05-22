///|
fn text_fixture_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn text_fixture_hello_ops_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfContentOp] raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
}

///|
fn text_fixture_assert_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : @pdflite.PdfContentOp,
) -> Unit raise {
  for op in ops {
    if op == expected {
      break
    }
  } nobreak {
    fail("missing expected content operator")
  }
}

///|
fn text_fixture_assert_hello_text_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let extracted = document.test_extract_text([1])
  @test.assert_eq(@pdflite.pdf_test_extract_text(document, [1]), extracted)
  text_fixture_assert_contains_for_test(
    @utf8.decode_lossy(extracted),
    "Hello, World!",
  )
}

///|
fn text_fixture_source_page_fonts_for_test(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match document.lookup_direct(text_fixture_name_for_test("/Font"), resources) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    Some(_) => fail("expected source page font resources to be a dictionary")
    None => @pdflite.pdf_dictionary([])
  }
}

///|
fn text_fixture_source_font_entry_for_test(
  entries : ArrayView[@pdflite.PdfFontListEntry],
  name : String,
) -> @pdflite.PdfFontListEntry raise {
  for entry in entries {
    if entry.name == name {
      break entry
    }
  } nobreak {
    fail("missing source font entry " + name)
  }
}

///|
fn text_fixture_source_font_table_entry_for_test(
  entries : ArrayView[@pdflite.PdfFontTableEntry],
  code : Int,
) -> @pdflite.PdfFontTableEntry raise {
  for entry in entries {
    if entry.code == code {
      break entry
    }
  } nobreak {
    fail("missing source font table code " + code.to_string())
  }
}

///|
fn text_fixture_usecmap_stream_for_test(
  data : @pdflite.PdfBytes,
  usecmap : Int?,
  compressed : Bool,
) -> @pdflite.PdfObject raise {
  let stream_data = if compressed {
    @pdflite.pdf_flate_encode(data)
  } else {
    data
  }
  let mut stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (text_fixture_name_for_test("/Length"), PdfInteger(stream_data.length())),
    ]),
    StreamGot(stream_data),
  )
  if compressed {
    stream = stream.add_dict_entry(
      text_fixture_name_for_test("/Filter"),
      PdfNameObject(text_fixture_name_for_test("/FlateDecode")),
    )
  }
  match usecmap {
    Some(number) =>
      stream = stream.add_dict_entry(
        text_fixture_name_for_test("/UseCMap"),
        PdfIndirect(number),
      )
    None => ()
  }
  stream
}

///|
fn text_fixture_usecmap_grandbase_cmap_for_test() -> @pdflite.PdfObject raise {
  text_fixture_usecmap_stream_for_test(
    @ascii.encode(
      "1 begincodespacerange\n" +
      "<00><FF>\n" +
      "endcodespacerange\n" +
      "2 beginbfchar\n" +
      "<41><0051>\n" +
      "<45><0045>\n" +
      "endbfchar\n",
    ),
    None,
    false,
  )
}

///|
fn text_fixture_usecmap_base_cmap_for_test(
  usecmap : Int,
) -> @pdflite.PdfObject raise {
  text_fixture_usecmap_stream_for_test(
    @ascii.encode(
      "2 beginbfchar\n" + "<44><0052>\n" + "<43><0043>\n" + "endbfchar\n",
    ),
    Some(usecmap),
    false,
  )
}

///|
fn text_fixture_usecmap_child_cmap_for_test(
  usecmap : Int,
) -> @pdflite.PdfObject raise {
  text_fixture_usecmap_stream_for_test(
    @ascii.encode(
      "2 beginbfchar\n" + "<42><0059>\n" + "<43><005A>\n" + "endbfchar\n",
    ),
    Some(usecmap),
    true,
  )
}

///|
fn text_fixture_usecmap_tounicode_for_test() -> Array[(Int, @pdflite.PdfBytes)] raise {
  [
    (0x42, @pdflite.pdf_bytes_of_int_array([0x00, 0x59])),
    (0x43, @pdflite.pdf_bytes_of_int_array([0x00, 0x5A])),
    (0x44, @pdflite.pdf_bytes_of_int_array([0x00, 0x52])),
    (0x41, @pdflite.pdf_bytes_of_int_array([0x00, 0x51])),
    (0x45, @pdflite.pdf_bytes_of_int_array([0x00, 0x45])),
  ]
}

///|
fn text_fixture_usecmap_text_for_test() -> @pdflite.PdfBytes raise {
  @pdflite.pdf_bytes_of_int_array([0x41, 0x42, 0x43, 0x44, 0x45, 0x46])
}

///|
fn text_fixture_usecmap_font_for_test(tounicode : Int) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      text_fixture_name_for_test("/Subtype"),
      PdfNameObject(text_fixture_name_for_test("/Type1")),
    ),
    (
      text_fixture_name_for_test("/BaseFont"),
      PdfNameObject(text_fixture_name_for_test("/SourceUseCMap")),
    ),
    (text_fixture_name_for_test("/ToUnicode"), PdfIndirect(tounicode)),
  ])
}

///|
fn text_fixture_hello_with_usecmap_tounicode_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let grandbase = output.add_object(
    text_fixture_usecmap_grandbase_cmap_for_test(),
  )
  let base = output.add_object(
    text_fixture_usecmap_base_cmap_for_test(grandbase),
  )
  let child = output.add_object(text_fixture_usecmap_child_cmap_for_test(base))
  let font_number = output.add_object(text_fixture_usecmap_font_for_test(child))
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = text_fixture_source_page_fonts_for_test(
    output,
    pages[0].resources,
  ).add_dict_entry(
    text_fixture_name_for_test("/SourceUseCMap"),
    PdfIndirect(font_number),
  )
  let resources = pages[0].resources.add_dict_entry(
    text_fixture_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(text_fixture_name_for_test("/SourceUseCMap"), 12.0),
      Op_Tj(text_fixture_usecmap_text_for_test()),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn text_fixture_assert_usecmap_tounicode_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  text_fixture_assert_hello_text_for_test(document)
  let expected_codepoints = [0x51, 0x59, 0x5A, 0x52, 0x45, 0x46]
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints(expected_codepoints),
  )
  text_fixture_assert_contains_for_test(
    @utf8.decode_lossy(document.test_extract_text([1])),
    expected_text,
  )
  let ops = text_fixture_hello_ops_for_test(document)
  text_fixture_assert_op_for_test(
    ops,
    Op_Tf(text_fixture_name_for_test("/SourceUseCMap"), 12.0),
  )
  text_fixture_assert_op_for_test(
    ops,
    Op_Tj(text_fixture_usecmap_text_for_test()),
  )
  let source_font = text_fixture_source_font_entry_for_test(
    document.list_fonts([1]),
    "/SourceUseCMap",
  )
  @test.assert_eq(source_font.subtype, "/Type1")
  @test.assert_eq(source_font.basefont, "/SourceUseCMap")
  guard document.read_font(source_font.font) is PdfFontSimple(simple) else {
    fail("expected source UseCMap simple font")
  }
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected source UseCMap descriptor carrying ToUnicode")
  }
  let expected_map = text_fixture_usecmap_tounicode_for_test()
  @test.assert_eq(descriptor.tounicode, Some(expected_map))
  guard document.lookup_direct(
      text_fixture_name_for_test("/ToUnicode"),
      document.direct(source_font.font),
    )
    is Some(tounicode) else {
    fail("missing source UseCMap ToUnicode stream")
  }
  @test.assert_eq(document.parse_cmap(tounicode).map, expected_map)
  @test.assert_eq(
    @pdflite.pdf_parse_cmap(document, tounicode).map,
    expected_map,
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(
    extractor.codepoints_of_text(text_fixture_usecmap_text_for_test()),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x51), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x59), Some(0x42))
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(0x43))
  @test.assert_eq(extractor.charcode_of_codepoint(0x52), Some(0x44))
  @test.assert_eq(extractor.charcode_of_codepoint(0x45), Some(0x45))
  @test.assert_eq(extractor.charcode_of_codepoint(0x43), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x46), None)
  let table = document.font_table("/SourceUseCMap", 1)
  let row_a = text_fixture_source_font_table_entry_for_test(table, 0x41)
  @test.assert_eq(row_a.unicode, "0051")
  @test.assert_eq(row_a.utf8, "Q")
  let row_c = text_fixture_source_font_table_entry_for_test(table, 0x43)
  @test.assert_eq(row_c.unicode, "005A")
  @test.assert_eq(row_c.utf8, "Z")
  let row_d = text_fixture_source_font_table_entry_for_test(table, 0x44)
  @test.assert_eq(row_d.unicode, "0052")
  @test.assert_eq(row_d.utf8, "R")
  @test.assert_eq(@pdflite.pdf_font_table(document, "/SourceUseCMap", 1), table)
}

///|
async test "cpdf source hello fixture composes ToUnicode UseCMap chain" {
  match text_fixture_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let with_usecmap = text_fixture_hello_with_usecmap_tounicode_for_test(
        document,
      )
      text_fixture_assert_usecmap_tounicode_for_test(with_usecmap)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_usecmap,
      )
      text_fixture_assert_usecmap_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = text_fixture_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      text_fixture_assert_usecmap_tounicode_for_test(recovered)
    }
  }
}
