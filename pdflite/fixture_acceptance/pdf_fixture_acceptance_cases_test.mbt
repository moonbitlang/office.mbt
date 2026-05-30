///|
async test "checked-in CamlPDF logo fixture reconstructs linearized bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed xref header" {
  fixture_acceptance_assert_xref_header_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed trailer keyword" {
  fixture_acceptance_assert_trailer_keyword_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref row" {
  fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref offset" {
  fixture_acceptance_assert_classic_xref_offset_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref generation" {
  fixture_acceptance_assert_classic_xref_generation_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref object number" {
  fixture_acceptance_assert_classic_xref_object_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref count" {
  fixture_acceptance_assert_classic_xref_count_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream widths" {
  fixture_acceptance_assert_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream index" {
  fixture_acceptance_assert_xref_stream_index_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture tolerates malformed indexed xref stream size" {
  fixture_acceptance_assert_xref_stream_size_entry_tolerates_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
    @ascii.encode("/Size 104\n"),
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream DecodeParms" {
  fixture_acceptance_assert_xref_stream_decodeparms_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs unsupported xref stream DecodeParms predictor" {
  fixture_acceptance_assert_xref_stream_decodeparms_predictor_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream filter" {
  fixture_acceptance_assert_xref_stream_filter_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream type" {
  fixture_acceptance_assert_xref_stream_type_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream marker" {
  fixture_acceptance_assert_xref_stream_marker_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream terminators" {
  fixture_acceptance_assert_xref_stream_endstream_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
  fixture_acceptance_assert_xref_stream_endobj_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream root" {
  fixture_acceptance_assert_xref_stream_root_entry_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
    @ascii.encode("/Root 101 0 R"),
  )
}

///|
async test "checked-in CamlPDF introduction fixture repairs malformed xref stream length" {
  fixture_acceptance_assert_xref_stream_length_entry_repairs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
    @ascii.encode("/Length 271 "),
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs xref stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture repairs malformed object stream length" {
  fixture_acceptance_assert_object_stream_length_repairs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture repairs malformed object stream endstream" {
  fixture_acceptance_assert_object_stream_endstream_repairs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in Pandoc Latin fixture reconstructs malformed bare xref stream widths" {
  fixture_acceptance_assert_bare_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_latin.pdf"),
    2,
  )
}

///|
async test "checked-in Pandoc CJK fixture reconstructs malformed bare xref stream widths" {
  fixture_acceptance_assert_bare_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_cjk.pdf"),
    1,
  )
}

///|
async test "checked-in Pandoc Latin fixture reconstructs object-stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_latin.pdf"),
    2,
  )
}

///|
async test "checked-in Pandoc CJK fixture reconstructs object-stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_cjk.pdf"),
    1,
  )
}

///|
async test "optional cpdf source hello fixture reads and rewrites" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 1)
  }
}

///|
async test "optional cpdf source hello fixture reconstructs bad startxref" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => fixture_acceptance_assert_reconstructs_for_test(bytes, 1)
  }
}

///|
async test "optional cpdf source hello fixture reconstructs malformed classic xref table variants" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_classic_xref_table_variants_reconstruct_for_test(
        bytes, 1,
      )
  }
}

///|
async test "optional cpdf source hello fixture roundtrips CPDFJSON document output" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_cpdfjson_for_test(document)
      fixture_acceptance_assert_cpdf_source_cpdfjson_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_source_cpdfjson_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source logo fixture reconstructs malformed classic xref table variants" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_classic_xref_table_variants_reconstruct_for_test(
        bytes, 1,
      )
  }
}

///|
async test "optional cpdf source top-level PDF corpus reads rewrites and reconstructs" {
  let mut checked = 0
  let mut pages = 0
  for path in fixture_acceptance_cpdf_top_level_pdf_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let expected_pages = fixture_acceptance_cpdf_top_level_expected_pages_for_test(
          path,
        )
        pages += expected_pages
        fixture_acceptance_assert_reads_and_rewrites_for_test(
          bytes, expected_pages,
        )
        fixture_acceptance_assert_reconstructs_for_test(bytes, expected_pages)
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_top_level_pdf_paths_for_test.length(),
    )
    @test.assert_eq(pages, 177)
  }
}

///|
async test "optional cpdf source top-level classic fixtures reconstruct damaged xref headers and trailers" {
  let mut checked = 0
  for path in fixture_acceptance_cpdf_top_level_classic_pdf_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let expected_pages = fixture_acceptance_cpdf_top_level_expected_pages_for_test(
          path,
        )
        fixture_acceptance_assert_xref_header_reconstructs_for_test(
          bytes, expected_pages,
        )
        fixture_acceptance_assert_trailer_keyword_reconstructs_for_test(
          bytes, expected_pages,
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_top_level_classic_pdf_paths_for_test.length(),
    )
  }
}

///|
async test "optional cpdf source logo fixture reports catalog view metadata" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(document)
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source transparency fixtures preserve resources" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/trans.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(document)
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source logo fixture draws page marks" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        document,
      )
      let shown = document.show_page_boxes([1])
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document, shown,
      )
      let shown_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        shown,
      )
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(shown_compressed),
      )
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            shown_compressed,
          ),
        ),
      )
      let trimmed = @pdflite.pdf_trim_marks(document, [1])
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document, trimmed,
      )
      let trimmed_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        trimmed,
      )
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(trimmed_compressed),
      )
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            trimmed_compressed,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source fixtures stamp and combine pages" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf"),
    ) {
    (Some(hello_bytes), Some(logo_bytes)) => {
      let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
      let logo = @pdflite.pdf_read_document_from_bytes(logo_bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(hello)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(logo)
      let stamped = hello.stamp_pages(
        [1],
        logo,
        position=PdfPositionBottomLeft(10.0, 20.0),
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(hello, stamped)
      let stamped_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stamped,
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(stamped_compressed),
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            stamped_compressed,
          ),
        ),
      )
      let combined = @pdflite.pdf_combine_pages(hello, logo, scale_to_fit=true)
      fixture_acceptance_assert_cpdf_source_combine_for_test(hello, combined)
      let combined_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        combined,
      )
      fixture_acceptance_assert_cpdf_source_combine_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(combined_compressed),
      )
      fixture_acceptance_assert_cpdf_source_combine_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            combined_compressed,
          ),
        ),
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source hello fixture imposes two-up sheets" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let hello = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(hello)
      let source = @pdflite.pdf_merge_documents([hello, hello], [[1], [1]])
      @test.assert_eq(source.endpage(), 2)
      let imposed = source.impose(2.0, 1.0, line_width=0.5)
      fixture_acceptance_assert_cpdf_source_impose_sheet_for_test(
        source, imposed,
      )
      fixture_acceptance_assert_cpdf_source_impose_sheet_for_test(
        source,
        @pdflite.pdf_impose(source, 2.0, 1.0, line_width=0.5),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        imposed,
      )
      fixture_acceptance_assert_cpdf_source_impose_sheet_for_test(
        source,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected imposed sheet to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      fixture_acceptance_assert_cpdf_source_impose_sheet_for_test(
        source, recovered,
      )
      let twoup = source.twoup()
      fixture_acceptance_assert_cpdf_source_twoup_for_test(source, twoup)
      fixture_acceptance_assert_cpdf_source_twoup_for_test(
        source,
        @pdflite.pdf_twoup(source),
      )
      fixture_acceptance_assert_cpdf_source_twoup_for_test(
        source,
        @pdflite.pdf_read_document_from_bytes(
          @pdflite.pdf_write_document_with_compressed_xref_stream(twoup),
        ),
      )
      let stacked = source.twoup_stack()
      fixture_acceptance_assert_cpdf_source_impose_text_for_test(stacked)
      fixture_acceptance_assert_cpdf_source_impose_text_for_test(
        @pdflite.pdf_twoup_stack(source),
      )
      fixture_acceptance_assert_cpdf_source_impose_text_for_test(
        @pdflite.pdf_read_document_from_bytes(
          @pdflite.pdf_write_document_with_compressed_xref_stream(stacked),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source fixtures stamp logo as Form XObject" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf"),
    ) {
    (Some(hello_bytes), Some(logo_bytes)) => {
      let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
      let logo = @pdflite.pdf_read_document_from_bytes(logo_bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(hello)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(logo)
      let (stamped, name) = hello.stamp_as_xobject([1], logo)
      fixture_acceptance_assert_cpdf_source_stamp_as_xobject_for_test(
        hello, logo, stamped, name,
      )
      let (wrapped, wrapped_name) = @pdflite.pdf_stamp_as_xobject(
        hello,
        [1],
        logo,
      )
      @test.assert_eq(wrapped_name, name)
      fixture_acceptance_assert_cpdf_source_stamp_as_xobject_for_test(
        hello, logo, wrapped, wrapped_name,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stamped,
      )
      fixture_acceptance_assert_cpdf_source_stamp_as_xobject_for_test(
        hello,
        logo,
        @pdflite.pdf_read_document_from_bytes(compressed),
        name,
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected Form XObject stamp to require reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      fixture_acceptance_assert_cpdf_source_stamp_as_xobject_for_test(
        hello, logo, recovered, name,
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source drawing fixtures preserve operator parameters" {
  let mut checked = 0
  for path in fixture_acceptance_cpdf_draw_operator_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path, document,
        )
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path,
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path,
          @pdflite.pdf_read_document_from_bytes(
            fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
          ),
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_draw_operator_paths_for_test.length(),
    )
  }
}

///|
async test "optional cpdf source tweak fixtures remove clipping and reveal text" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/clip.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/clip.pdf", document,
      )
      let unclipped = @pdflite.pdf_remove_clipping(document, [1])
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document, unclipped,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        unclipped,
      )
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/textclip.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/textclip.pdf", document,
      )
      let revealed = document.reveal_hidden_text([1])
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document, revealed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        revealed,
      )
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source tweak fixtures recolor thin and append content" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/colfill.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/colfill.pdf", document,
      )
      let black_lines = @pdflite.pdf_black_lines(
        document,
        [1],
        PdfContentRGB(0.1, 0.2, 0.3),
      )
      fixture_acceptance_assert_cpdf_source_black_lines_for_test(
        document, black_lines,
      )
      fixture_acceptance_assert_cpdf_source_black_lines_for_test(
        document,
        fixture_acceptance_reparse_compressed_for_test(black_lines),
      )
      let black_fills = document.black_fills([1], PdfContentRGB(0.4, 0.5, 0.6))
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document, black_fills,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        black_fills,
      )
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/fontparams.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/fontparams.pdf", document,
      )
      let rewritten = @pdflite.pdf_black_text(
        document,
        [1],
        @colour.pdf_content_black,
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document, rewritten,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        rewritten,
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/capjoins.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/capjoins.pdf", document,
      )
      let rewritten = document.thin_lines([1], -30.0)
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document, rewritten,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        rewritten,
      )
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let appended = @pdflite.pdf_append_page_content(
        document,
        [1],
        @ascii.encode("0.25 g 10 10 20 20 re f"),
        before=true,
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document, appended,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        appended,
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source attachments preserve real source payloads" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md"),
      fixture_acceptance_optional_bytes_for_test(
        ".repos/cpdf-source/Changes.txt",
      ),
    ) {
    (Some(pdf_bytes), Some(readme_payload), Some(changes_payload)) => {
      let document = @pdflite.pdf_read_document_from_bytes(pdf_bytes)
      let attached = document
        .attach_file(
          ".repos/cpdf-source/README.md",
          readme_payload,
          relationship=Some("Source"),
          description=Some("cpdf source README"),
        )
        .attach_file(
          ".repos/cpdf-source/Changes.txt",
          changes_payload,
          page_number=Some(1),
          relationship=Some("/Supplement"),
          description=Some("cpdf source changes"),
        )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        attached, readme_payload, changes_payload,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        attached,
      )
      let compressed_document = @pdflite.pdf_read_document_from_bytes(
        compressed,
      )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        compressed_document, readme_payload, changes_payload,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        recovered, readme_payload, changes_payload,
      )
      let cleaned = recovered.remove_attached_files()
      fixture_acceptance_assert_cpdf_source_attachments_removed_for_test(
        cleaned,
      )
      fixture_acceptance_assert_cpdf_source_attachments_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(cleaned),
      )
    }
    _ => ()
  }
}

///|
fn fixture_acceptance_assert_unicode_data_row_matches_for_test(
  actual : @unicodedata.PdfUnicodeDataEntry,
  expected : @unicodedata.PdfUnicodeDataEntry,
  index : Int,
) -> Unit raise {
  guard actual == expected else {
    fail("UnicodeData row mismatch at " + index.to_string())
  }
}

///|
async test "optional cpdf source UnicodeData table matches embedded table" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/compressor/UnicodeData.txt",
    ) {
    None => ()
    Some(source) => {
      let source_rows = try! @pdflite.pdf_parse_unicode_data(source)
      let embedded_rows = try! @pdflite.pdf_unicode_data()
      @test.assert_eq(source_rows.length(), embedded_rows.length())
      @test.assert_eq(source_rows.length(), 34626)
      for index in [0, 65, source_rows.length() - 1] {
        fixture_acceptance_assert_unicode_data_row_matches_for_test(
          source_rows[index],
          embedded_rows[index],
          index,
        )
      }
      @test.assert_eq(source_rows[0].code_value, "0000")
      @test.assert_eq(source_rows[0].character_name, "<control>")
      @test.assert_eq(source_rows[0].unicode_10_name, "NULL")
      @test.assert_eq(source_rows[65].code_value, "0041")
      @test.assert_eq(source_rows[65].character_name, "LATIN CAPITAL LETTER A")
      @test.assert_eq(
        source_rows[source_rows.length() - 1].code_value,
        "10FFFD",
      )
      @test.assert_eq(
        source_rows[source_rows.length() - 1].character_name,
        "<Plane 16 Private Use, Last>",
      )
    }
  }
}

///|
async test "optional cpdf source README typesets tagged text PDF" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md") {
    None => ()
    Some(readme_payload) => {
      let document = try! @pdflite.pdf_texttopdf_typeset(
        fixture_acceptance_cpdf_source_texttopdf_fontpack_for_test(),
        12.0,
        @geometry.paper_a4,
        readme_payload,
        process_struct_tree=true,
        title=Some("cpdf source README"),
      )
      fixture_acceptance_assert_cpdf_source_readme_texttopdf_for_test(document)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_readme_texttopdf_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_readme_texttopdf_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source README typesets PDF UA2 text PDF" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md") {
    None => ()
    Some(readme_payload) => {
      let title = "cpdf source README PDF/UA-2"
      let document = try! @pdflite.pdf_texttopdf_typeset(
        fixture_acceptance_cpdf_source_texttopdf_fontpack_for_test(),
        12.0,
        @geometry.paper_a4,
        readme_payload,
        subformat=Some(PdfUA2),
        title=Some(title),
      )
      fixture_acceptance_assert_cpdf_source_readme_pdfua2_for_test(
        document, title,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_readme_pdfua2_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        title,
      )
      fixture_acceptance_assert_cpdf_source_readme_pdfua2_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        title,
      )
    }
  }
}

///|
async test "optional cpdf source Changes typesets PDF UA1 text PDF" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/Changes.txt") {
    None => ()
    Some(changes_payload) => {
      let title = "cpdf source Changes PDF/UA-1"
      let document = try! @pdflite.pdf_texttopdf_typeset(
        fixture_acceptance_cpdf_source_texttopdf_fontpack_for_test(),
        11.0,
        @geometry.paper_a4,
        changes_payload,
        subformat=Some(PdfUA1),
        title=Some(title),
      )
      fixture_acceptance_assert_cpdf_source_changes_pdfua1_for_test(
        document, title,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_changes_pdfua1_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        title,
      )
      fixture_acceptance_assert_cpdf_source_changes_pdfua1_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        title,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture chops CropBox-backed page" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let chopped = fixture_acceptance_chop_source_hello_for_test(document)
      fixture_acceptance_assert_cpdf_source_chop_for_test(chopped)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        chopped,
      )
      fixture_acceptance_assert_cpdf_source_chop_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_chop_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture applies page geometry transforms" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let transformed = fixture_acceptance_page_transform_source_hello_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(transformed)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        transformed,
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture pads blank page after source" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let padded = fixture_acceptance_pad_source_hello_for_test(document)
      fixture_acceptance_assert_cpdf_source_pad_for_test(padded)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        padded,
      )
      fixture_acceptance_assert_cpdf_source_pad_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_pad_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture preserves path redaction stub" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let expected_ops = fixture_acceptance_cpdf_source_hello_ops_for_test(
        document,
      )
      let original_pages = document.pages_of_pagetree()
      let redacted = @pdflite.pdf_redact(
        document,
        fixture_acceptance_cpdf_source_redact_path_for_test(),
        [1],
      )
      let redacted_pages = redacted.pages_of_pagetree()
      @test.assert_eq(redacted_pages[0].mediabox, original_pages[0].mediabox)
      @test.assert_eq(redacted_pages[0].rotate, original_pages[0].rotate)
      @test.assert_eq(redacted_pages[0].resources, original_pages[0].resources)
      @test.assert_eq(redacted_pages[0].rest, original_pages[0].rest)
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        redacted, expected_ops,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        redacted,
      )
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        expected_ops,
      )
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        expected_ops,
      )
    }
  }
}

///|
async test "optional cpdf source clip fixture runs native polygon operations" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/clip.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_clip_polygons_for_test(document)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_clip_polygons_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_clip_polygons_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture removes all text" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let stripped = @pdflite.pdf_remove_all_text(document, [1])
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        stripped,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stripped,
      )
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture builds portfolio from real payloads" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md"),
      fixture_acceptance_optional_bytes_for_test(
        ".repos/cpdf-source/Changes.txt",
      ),
    ) {
    (Some(pdf_bytes), Some(readme_payload), Some(changes_payload)) => {
      let mod_date = @ascii.encode("D:20240102030405")
      let document = @pdflite.pdf_read_document_from_bytes(pdf_bytes)
      let portfolio = document.portfolio(
        [
          @portfolio.pdf_portfolio_entry(
            ".repos/cpdf-source/README.md",
            readme_payload,
            relationship=Some("Source"),
            description=Some("cpdf source README"),
          ),
          @portfolio.pdf_portfolio_entry(
            ".repos/cpdf-source/Changes.txt", changes_payload,
          ),
        ],
        mod_date=Some(mod_date),
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        portfolio, readme_payload, changes_payload, mod_date,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        portfolio,
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        readme_payload,
        changes_payload,
        mod_date,
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        readme_payload,
        changes_payload,
        mod_date,
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source hello fixture removes JavaScript markers" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let (action_number, uri_number, stream_number) = fixture_acceptance_add_cpdf_source_javascript_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        document, action_number, uri_number, stream_number,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        action_number,
        uri_number,
        stream_number,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        recovered, action_number, uri_number, stream_number,
      )
      @pdflite.pdf_remove_javascript(recovered)
      fixture_acceptance_assert_cpdf_source_javascript_removed_for_test(
        recovered, action_number, uri_number, stream_number,
      )
      fixture_acceptance_assert_cpdf_source_javascript_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(recovered),
        action_number,
        uri_number,
        stream_number,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture lists injected spot colours" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.list_spot_colours(), [])
      let with_spots = fixture_acceptance_cpdf_source_hello_with_spot_colours_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(with_spots)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_spots,
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture roundtrips optional content groups" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(try! document.read_optional_content_groups(), None)
      @test.assert_eq(try! document.ocg_get_list(), [])
      let witness_number = fixture_acceptance_add_cpdf_source_ocg_witness_for_test(
        document,
      )
      let with_ocg = try! document.write_optional_content_groups(
        fixture_acceptance_cpdf_source_ocg_content_for_test(),
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(with_ocg)
      fixture_acceptance_assert_cpdf_source_ocg_for_test(
        fixture_acceptance_reparse_compressed_for_test(with_ocg),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_ocg,
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
      let replaced = try! @pdflite.pdf_ocg_replace_json(
        try! with_ocg.ocg_list_json(),
        @pdflite.pdf_read_document_from_bytes(bytes),
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(replaced)
      let renamed = with_ocg.ocg_rename(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Renamed Layer"),
      )
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(renamed)
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(
        fixture_acceptance_reparse_compressed_for_test(renamed),
      )
      let wrapper_renamed = @pdflite.pdf_ocg_rename(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Renamed Layer"),
        with_ocg,
      )
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(
        wrapper_renamed,
      )
      let ordered = try! with_ocg.ocg_order_all()
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(ordered)
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(
        try! @pdflite.pdf_ocg_order_all(with_ocg),
      )
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(
        fixture_acceptance_reparse_compressed_for_test(ordered),
      )
      let coalesced = try! with_ocg.ocg_coalesce()
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        coalesced, witness_number,
      )
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        try! @pdflite.pdf_ocg_coalesce(with_ocg),
        witness_number,
      )
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        fixture_acceptance_reparse_compressed_for_test(coalesced),
        witness_number,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture preserves presentation transitions" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let updated = document.presentation(
        [1],
        Some("Split"),
        Some(2.0),
        true,
        false,
        90,
        1.25,
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(updated)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        updated,
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual image fixtures read rewrite and reconstruct" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 1)
        fixture_acceptance_assert_reconstructs_for_test(bytes, 1)
      }
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct damaged xref headers" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) =>
        fixture_acceptance_assert_xref_header_reconstructs_for_test(bytes, 1)
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct damaged trailer keywords" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) =>
        fixture_acceptance_assert_trailer_keyword_reconstructs_for_test(
          bytes, 1,
        )
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct malformed classic xref rows" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_offset_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_generation_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_object_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_count_reconstructs_for_test(
          bytes, 1,
        )
      }
    }
  }
}

///|
async test "optional cpdf source PNG image fixture reports and extracts image" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_png_image_for_test(document)
      fixture_acceptance_assert_cpdf_png_image_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture reports inline images" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1], inline=true).stringify(), "[]")
      let with_inline = fixture_acceptance_cpdf_source_hello_with_inline_image_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(with_inline)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_inline,
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture reports nested form images" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1]).stringify(), "[]")
      @test.assert_eq(document.image_resolution([1], 1000000.0), [])
      let with_form_image = fixture_acceptance_cpdf_source_hello_with_form_image_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(with_form_image)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_form_image,
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture reads injected Type3 glyph programs" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_type3 = fixture_acceptance_cpdf_source_hello_with_type3_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(with_type3)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_type3,
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts ToUnicode variation text" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_variation = fixture_acceptance_cpdf_source_hello_with_variation_tounicode_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        with_variation,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_variation,
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts ToUnicode parser corners" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_corner = fixture_acceptance_cpdf_source_hello_with_parser_corner_tounicode_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_parser_corner_tounicode_for_test(
        with_corner,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_corner,
      )
      fixture_acceptance_assert_cpdf_source_parser_corner_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_parser_corner_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture composes ToUnicode UseCMap streams" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_usecmap = fixture_acceptance_cpdf_source_hello_with_usecmap_tounicode_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_usecmap_tounicode_for_test(
        with_usecmap,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_usecmap,
      )
      fixture_acceptance_assert_cpdf_source_usecmap_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_usecmap_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture composes ToUnicode UseCMap variation streams" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_variation = fixture_acceptance_cpdf_source_hello_with_usecmap_variation_tounicode_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_usecmap_variation_tounicode_for_test(
        with_variation,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_variation,
      )
      fixture_acceptance_assert_cpdf_source_usecmap_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_usecmap_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Identity predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_identity_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_identity_cmaps_for_test(with_cmaps)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_identity_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_identity_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts UniJIS Unicode predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_unijis_unicode_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_unijis_unicode_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_unijis_unicode_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_unijis_unicode_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture pins UniJIS cpdfcontent Unicode boundary" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_utf8 = fixture_acceptance_cpdf_source_hello_with_unijis_unicode_boundary_text_for_test(
        document,
        "/SourceUniJISUTF8H",
        [0x41, 0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E],
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf8_cpdfcontent_boundary_for_test(
        with_utf8,
      )
      let compressed_utf8 = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_utf8,
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf8_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed_utf8),
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf8_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed_utf8),
        ),
      )
      let with_utf16 = fixture_acceptance_cpdf_source_hello_with_unijis_unicode_boundary_text_for_test(
        document,
        "/SourceUniJISUTF16H",
        [0x30, 0x42, 0xD8, 0x34, 0xDD, 0x1E],
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf16_cpdfcontent_boundary_for_test(
        with_utf16,
      )
      let compressed_utf16 = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_utf16,
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf16_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed_utf16),
      )
      fixture_acceptance_assert_cpdf_source_unijis_utf16_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            compressed_utf16,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts UniAKR predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_uniakr_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts UniKS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_uniks_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Korea1 horizontal CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_korea1_horizontal_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_korea1_horizontal_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_korea1_horizontal_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_korea1_horizontal_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Korea1 vertical CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_korea1_vertical_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Japan1 predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_japan1_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Japan1 base predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_japan1_base_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts rare Japan1 predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_rare_japan1_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_rare_japan1_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_rare_japan1_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_rare_japan1_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts supplemental Japan1 predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_supplemental_japan1_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_supplemental_japan1_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_supplemental_japan1_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_supplemental_japan1_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts GB CNS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_gb_cns_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture pins Korea GB direct Unicode cpdfcontent boundaries" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let akr_cmaps = fixture_acceptance_cpdf_source_hello_with_uniakr_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        akr_cmaps,
      )
      let akr_utf8 = fixture_acceptance_cpdf_source_postpend_boundary_text_for_test(
        akr_cmaps,
        "/SourceAKR8",
        [0xEA, 0xB0, 0x80, 0xEB, 0x82, 0x98],
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf8_cpdfcontent_boundary_for_test(
        akr_utf8,
      )
      let compressed_akr_utf8 = @pdflite.pdf_write_document_with_compressed_xref_stream(
        akr_utf8,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf8_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed_akr_utf8),
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf8_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            compressed_akr_utf8,
          ),
        ),
      )
      let akr_utf32 = fixture_acceptance_cpdf_source_postpend_boundary_text_for_test(
        akr_cmaps,
        "/SourceAKR32",
        [0x00, 0x00, 0xAC, 0x00, 0x00, 0x00, 0xB0, 0x98],
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf32_cpdfcontent_boundary_for_test(
        akr_utf32,
      )
      let compressed_akr_utf32 = @pdflite.pdf_write_document_with_compressed_xref_stream(
        akr_utf32,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf32_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed_akr_utf32),
      )
      fixture_acceptance_assert_cpdf_source_uniakr_utf32_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            compressed_akr_utf32,
          ),
        ),
      )
      let gb_cmaps = fixture_acceptance_cpdf_source_hello_with_gb_cns_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        gb_cmaps,
      )
      let gb_ucs32 = fixture_acceptance_cpdf_source_postpend_boundary_text_for_test(
        gb_cmaps,
        "/SourceGB32H",
        [0x00, 0x00, 0x4E, 0x00, 0x00, 0x00, 0x56, 0xFD],
      )
      fixture_acceptance_assert_cpdf_source_gb_ucs32_cpdfcontent_boundary_for_test(
        gb_ucs32,
      )
      let compressed_gb_ucs32 = @pdflite.pdf_write_document_with_compressed_xref_stream(
        gb_ucs32,
      )
      fixture_acceptance_assert_cpdf_source_gb_ucs32_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed_gb_ucs32),
      )
      fixture_acceptance_assert_cpdf_source_gb_ucs32_cpdfcontent_boundary_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            compressed_gb_ucs32,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts GB1 legacy predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_gb1_legacy_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts CNS1 legacy predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_cns1_legacy_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts vertical GB CNS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_vertical_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(with_cmaps)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture preserves Matterhorn CMap typo" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_matterhorn_cmap_typo_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_matterhorn_cmap_typo_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_matterhorn_cmap_typo_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_matterhorn_cmap_typo_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source PNG image fixture drafts replacement boxes" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_png_image_for_test(document)
      let drafted = @pdflite.pdf_draft(None, true, [1], document)
      fixture_acceptance_assert_cpdf_png_draft_for_test(drafted)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        drafted,
      )
      fixture_acceptance_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source raw sheet PNG creates image document" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/sheet.png",
    ) {
    None => ()
    Some(bytes) => {
      fixture_acceptance_assert_cpdf_sheet_png_pixels_for_test(
        fixture_acceptance_decode_cpdf_sheet_png_pixels_for_test(bytes),
      )
      let document = @pdflite.pdf_image_document_of_png_data(bytes)
      fixture_acceptance_assert_cpdf_sheet_png_image_document_for_test(document)
      fixture_acceptance_assert_cpdf_sheet_png_image_document_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual font fixture reports font tables" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/fonts.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_fonts_fixture_for_test(document)
      fixture_acceptance_assert_cpdf_fonts_fixture_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports embedded fonts" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(document)
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source font mutations remove and copy embedded fonts" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(manual_bytes) =>
      match
        fixture_acceptance_optional_bytes_for_test(
          ".repos/cpdf-source/hello.pdf",
        ) {
        None => ()
        Some(hello_bytes) => {
          let manual = @pdflite.pdf_read_document_from_bytes(manual_bytes)
          let removed = manual.remove_embedded_fonts()
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            removed,
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_remove_fonts(manual),
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            fixture_acceptance_reparse_compressed_for_test(removed),
          )
          let removed_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            removed,
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_read_document_from_bytes(
              fixture_acceptance_corrupt_startxref_pointer_for_test(
                removed_compressed,
              ),
            ),
          )
          let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
          let source_font = fixture_acceptance_cpdf_font_entry_for_test(
            manual.list_fonts(manual.parse_pagespec("")),
            "NimbusSanL-Bold",
          )
          let copied = hello.copy_font_from(
            manual,
            source_font.name,
            source_font.page,
            [1],
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            copied, "NimbusSanL-Bold",
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_copy_font(
              manual,
              source_font.name,
              source_font.page,
              [1],
              hello,
            ),
            "NimbusSanL-Bold",
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            fixture_acceptance_reparse_compressed_for_test(copied),
            "NimbusSanL-Bold",
          )
          let copied_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            copied,
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_read_document_from_bytes(
              fixture_acceptance_corrupt_startxref_pointer_for_test(
                copied_compressed,
              ),
            ),
            "NimbusSanL-Bold",
          )
        }
      }
  }
}

///|
async test "optional cpdf source manual content fixtures export content JSON" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      fixture_acceptance_assert_cpdf_text_content_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/xobj.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(document)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source squeeze fixtures transcode streams" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      let decompressed = @pdflite.decompress_pdf(document)
      fixture_acceptance_assert_cpdf_source_decompressed_streams_for_test(
        document, decompressed,
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(decompressed)
      let recompressed = decompressed.recompress()
      fixture_acceptance_assert_cpdf_source_recompressed_streams_for_test(
        document, recompressed,
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(recompressed)
      let squeezed = document.squeeze()
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document, squeezed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        squeezed,
      )
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/xobj.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(document)
      let decompressed = document.decompress()
      fixture_acceptance_assert_cpdf_source_decompressed_streams_for_test(
        document, decompressed,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(decompressed)
      let recompressed = @pdflite.recompress_pdf(decompressed)
      fixture_acceptance_assert_cpdf_source_recompressed_streams_for_test(
        document, recompressed,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(recompressed)
      let squeezed = @pdflite.squeeze(document)
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document, squeezed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        squeezed,
      )
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixtures show bounding box overlays" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      let boxed = document.show_bounding_boxes([1])
      fixture_acceptance_assert_cpdf_text_content_for_test(boxed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, boxed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        boxed,
      )
      let reparsed = @pdflite.pdf_read_document_from_bytes(compressed)
      fixture_acceptance_assert_cpdf_text_content_for_test(reparsed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, reparsed,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(recovered)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, recovered,
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/xobj.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(document)
      let boxed = @pdflite.pdf_show_bounding_boxes(
        document,
        [1],
        light=true,
        fast=true,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(boxed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, boxed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        boxed,
      )
      let reparsed = @pdflite.pdf_read_document_from_bytes(compressed)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(reparsed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, reparsed,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(recovered)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, recovered,
      )
    }
  }
}

///|
async test "optional cpdf source h1 fixture reports structure tree" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/h1.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(document)
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source h1 fixture removes structure tree and marks artifacts" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/h1.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(document)
      let removed = document.remove_struct_tree()
      fixture_acceptance_assert_cpdf_h1_struct_tree_removed_for_test(removed)
      fixture_acceptance_assert_cpdf_h1_struct_tree_removed_for_test(
        @pdflite.pdf_remove_struct_tree(document),
      )
      fixture_acceptance_assert_cpdf_h1_struct_tree_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(
          @pdflite.pdf_write_document_with_compressed_xref_stream(removed),
        ),
      )
      let marked = removed.mark_all_as_artifact()
      fixture_acceptance_assert_cpdf_h1_artifact_marked_for_test(marked)
      fixture_acceptance_assert_cpdf_h1_artifact_marked_for_test(
        @pdflite.pdf_mark_all_as_artifact(removed),
      )
      let marked_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        marked,
      )
      fixture_acceptance_assert_cpdf_h1_artifact_marked_for_test(
        @pdflite.pdf_read_document_from_bytes(marked_compressed),
      )
      fixture_acceptance_assert_cpdf_h1_artifact_marked_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            marked_compressed,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual image fixtures traverse content entries" {
  let mut checked = 0
  let mut glyphs = 0
  let mut images = 0
  let mut paths = 0
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        let (doc_glyphs, doc_images, doc_paths) = fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
          document,
        )
        let (rewritten_glyphs, rewritten_images, rewritten_paths) = fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        let (expected_glyphs, expected_images, expected_paths) = fixture_acceptance_cpdf_manual_image_expected_content_counts_for_test(
          path,
        )
        @test.assert_eq(doc_glyphs, expected_glyphs)
        @test.assert_eq(doc_images, expected_images)
        @test.assert_eq(doc_paths, expected_paths)
        @test.assert_eq(rewritten_glyphs, doc_glyphs)
        @test.assert_eq(rewritten_images, doc_images)
        @test.assert_eq(rewritten_paths, doc_paths)
        glyphs += doc_glyphs
        images += doc_images
        paths += doc_paths
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_manual_image_paths_for_test.length(),
    )
    @test.assert_eq(glyphs, 476)
    @test.assert_eq(images, 1)
    @test.assert_eq(paths, 18)
  }
}

///|
async test "optional cpdf source manual image text fixtures extract exact text" {
  let mut checked = 0
  for path in fixture_acceptance_cpdf_manual_image_text_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path, document,
        )
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path,
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path,
          @pdflite.pdf_read_document_from_bytes(
            fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
          ),
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_manual_image_text_paths_for_test.length(),
    )
  }
}

///|
async test "optional cpdf source manual fixture reads and rewrites" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 175)
  }
}

///|
async test "optional cpdf source manual fixture parses page specifications" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_pagespec_for_test(document)
      fixture_acceptance_assert_cpdf_manual_pagespec_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports info page details and composition" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_reports_for_test(
        document,
        bytes.length(),
      )
      let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_manual_reports_for_test(
        @pdflite.pdf_read_document_from_bytes(rewritten),
        rewritten.length(),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture dumps debug objects" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_debug_objects_for_test(document)
      fixture_acceptance_assert_cpdf_manual_debug_objects_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
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
      fixture_acceptance_assert_cpdf_manual_debug_objects_for_test(recovered)
    }
  }
}

///|
async test "optional cpdf source manual fixture mutates metadata" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      @test.assert_eq(document.metadata(), None)
      let title = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("cpdf source & metadata"),
      )
      let author = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("MoonBit port"),
      )
      let updated = document
        .create_metadata()
        .set_language(@ascii.encode("en-GB"))
        .set_info_entry(
          fixture_acceptance_pdf_name_for_test("/Title"),
          PdfString(title),
          4,
          keep_version=true,
          xmp_also=true,
        )
        .set_info_entry(
          fixture_acceptance_pdf_name_for_test("/Author"),
          PdfString(author),
          4,
          keep_version=true,
          xmp_also=true,
        )
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(updated)
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(
        fixture_acceptance_reparse_compressed_for_test(updated),
      )
      let corrupt_startxref_bytes = fixture_acceptance_corrupt_startxref_pointer_for_test(
        @pdflite.pdf_write_document_with_compressed_xref_stream(updated),
      )
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupt_startxref_bytes),
      )
      let removed = updated.remove_all_metadata()
      fixture_acceptance_assert_cpdf_manual_metadata_removed_for_test(removed)
      fixture_acceptance_assert_cpdf_manual_metadata_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(removed),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports page label fallbacks" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(document)
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture extracts retained pages" {
  let selected_pages : ReadOnlyArray[Int] = [33, 19, 1, 175]
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let without_numbering = document.pdf_of_pages(selected_pages)
      @test.assert_eq(without_numbering.endpage(), 4)
      @test.assert_eq(without_numbering.read_page_labels(), [])
      let extracted = document.pdf_of_pages(
        selected_pages,
        retain_numbering=true,
        process_struct_tree=true,
      )
      fixture_acceptance_assert_cpdf_manual_pdf_of_pages_for_test(extracted)
      fixture_acceptance_assert_cpdf_manual_pdf_of_pages_for_test(
        @pdflite.pdf_of_pages(
          document,
          selected_pages,
          retain_numbering=true,
          process_struct_tree=true,
        ),
      )
      fixture_acceptance_assert_cpdf_manual_pdf_of_pages_for_test(
        fixture_acceptance_reparse_compressed_for_test(extracted),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        extracted,
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected retained page extraction to require reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      fixture_acceptance_assert_cpdf_manual_pdf_of_pages_for_test(recovered)
    }
  }
}

///|
async test "optional cpdf source manual fixture stamps addtext replacements" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let stamped = fixture_acceptance_cpdf_manual_stamped_for_test(document)
      fixture_acceptance_assert_cpdf_manual_addtext_for_test(stamped)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stamped,
      )
      fixture_acceptance_assert_cpdf_manual_addtext_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
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
      fixture_acceptance_assert_cpdf_manual_addtext_for_test(recovered)
    }
  }
}

///|
async test "optional cpdf source manual fixture removes stamped addtext" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let stamped = fixture_acceptance_cpdf_manual_stamped_for_test(document)
      fixture_acceptance_assert_cpdf_manual_addtext_for_test(stamped)
      let stripped = stamped.remove_added_text([1, 19, 175])
      fixture_acceptance_assert_cpdf_manual_added_text_removed_for_test(
        stripped,
      )
      fixture_acceptance_assert_cpdf_manual_added_text_removed_for_test(
        @pdflite.pdf_remove_added_text(stamped, [1, 19, 175]),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stripped,
      )
      fixture_acceptance_assert_cpdf_manual_added_text_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(
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
      fixture_acceptance_assert_cpdf_manual_added_text_removed_for_test(
        recovered,
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture extracts selected text" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(document)
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports embedded images" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_images_for_test(document)
      fixture_acceptance_assert_cpdf_manual_images_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture exports annotation JSON" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_annotations_for_test(document)
      fixture_acceptance_assert_cpdf_manual_annotations_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture lists bookmarks" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(document)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      let rebuilt = try! document
        .remove_bookmarks()
        .add_bookmarks(document.read_bookmarks(preserve_actions=true))
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(rebuilt)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(
        fixture_acceptance_reparse_compressed_for_test(rebuilt),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture mutates bookmark open state and title" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let opened = try! document.bookmarks_open_to_level(1)
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        opened,
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        try! @pdflite.pdf_bookmarks_open_to_level(1, document),
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        fixture_acceptance_reparse_compressed_for_test(opened),
      )
      let opened_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        opened,
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            opened_compressed,
          ),
        ),
      )
      let titled = try! document.add_bookmark_title(
        "/tmp/cpdfmanual.pdf", false,
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(titled)
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        try! @pdflite.pdf_add_bookmark_title(
          "/tmp/cpdfmanual.pdf", false, document,
        ),
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        fixture_acceptance_reparse_compressed_for_test(titled),
      )
      let titled_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        titled,
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            titled_compressed,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture builds table of contents" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_toc_for_test(document)
      fixture_acceptance_assert_cpdf_manual_toc_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      let bookmarked = fixture_acceptance_cpdf_manual_toc_bookmark_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_manual_toc_bookmark_roundtrip_for_test(
        bookmarked,
      )
      fixture_acceptance_assert_cpdf_manual_toc_bookmark_roundtrip_for_test(
        fixture_acceptance_reparse_compressed_for_test(bookmarked),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reconstructs bad startxref" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => fixture_acceptance_assert_reconstructs_for_test(bytes, 175)
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream widths" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_widths_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream index" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_index_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode("/Index [0 1844]"),
      )
  }
}

///|
async test "optional cpdf source manual fixture tolerates malformed indexed xref stream size" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_size_entry_tolerates_for_test(
        bytes,
        175,
        @ascii.encode("/Size 1844"),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream index and size" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_index_and_size_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode("/Index [0 1844]"),
        @ascii.encode("/Size 1844"),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream type" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_type_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream marker" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_marker_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream terminators" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      fixture_acceptance_assert_xref_stream_endstream_reconstructs_for_test(
        bytes, 175,
      )
      fixture_acceptance_assert_xref_stream_endobj_reconstructs_for_test(
        bytes, 175,
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream root" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_root_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode("/Root 1841 0 R"),
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed xref stream length" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_length_entry_repairs_for_test(
        bytes,
        175,
        @ascii.encode("/Length 4551"),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream DecodeParms" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_decodeparms_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode(
          "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
        ),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs unsupported xref stream DecodeParms predictor" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_decodeparms_predictor_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode(
          "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
        ),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream count" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_count_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream first" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_first_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed object stream length" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_length_repairs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream filter" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_filter_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream DecodeParms" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_decodeparms_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs unsupported object stream DecodeParms predictor" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_decodeparms_predictor_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream marker" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_marker_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed object stream endstream" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_endstream_repairs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream endobj" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_endobj_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream filter" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_filter_reconstructs_for_test(
        bytes, 175,
      )
  }
}
