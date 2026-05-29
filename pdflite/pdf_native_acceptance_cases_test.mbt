///|
test "native acceptance suite roundtrips classic and xref-stream documents" {
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 4),
  )
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document_with_xref_stream(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 5),
  )
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document_with_compressed_xref_stream(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 5),
  )
}

///|
test "native acceptance suite extracts ToUnicode text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_text_document_for_test(),
  )
  acceptance_assert_tounicode_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode variation text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_variation_document_for_test(),
  )
  acceptance_assert_tounicode_variation_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_variation_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode parser corner cases through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_parser_corner_document_for_test(),
  )
  acceptance_assert_tounicode_parser_corner_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_parser_corner_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode sequence text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_sequence_document_for_test(),
  )
  acceptance_assert_tounicode_sequence_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_sequence_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type3 ToUnicode text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_text_document_for_test(),
  )
  acceptance_assert_type3_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_text_for_test(reparsed)
}

///|
test "native acceptance suite resolves Type3 nested form resources through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_form_resource_document_for_test(),
  )
  acceptance_assert_type3_form_resource_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_form_resource_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type3 encoded glyph text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_encoded_text_document_for_test(),
  )
  acceptance_assert_type3_encoded_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_encoded_text_for_test(reparsed)
}

///|
test "native acceptance suite preserves Type3 fixture-shaped CharProcs through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_fixture_charproc_document_for_test(),
  )
  acceptance_assert_type3_fixture_charprocs_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_fixture_charprocs_for_test(reparsed)
}

///|
test "native acceptance suite extracts Identity-H CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_h_text_document_for_test(),
  )
  acceptance_assert_identity_h_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_h_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Identity-V CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_v_text_document_for_test(),
  )
  acceptance_assert_identity_v_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_v_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts GBK2K predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_gbk2k_text_document_for_test(),
  )
  acceptance_assert_gbk2k_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_gbk2k_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Big5 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_big5_text_document_for_test(),
  )
  acceptance_assert_big5_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_big5_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts HKSCS predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_hkscs_text_document_for_test(),
  )
  acceptance_assert_hkscs_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_hkscs_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts CNS-EUC predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cns_euc_text_document_for_test(),
  )
  acceptance_assert_cns_euc_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_cns_euc_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts vertical predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_vertical_predefined_cmap_text_document_for_test(),
  )
  acceptance_assert_vertical_predefined_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_vertical_predefined_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite preserves cpdfua source CMap name typo through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_matterhorn_cmap_typo_document_for_test(),
  )
  acceptance_assert_matterhorn_cmap_typo_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_matterhorn_cmap_typo_for_test(reparsed)
}

///|
test "native acceptance suite extracts Unicode predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_unicode_predefined_cmap_document_for_test(),
  )
  acceptance_assert_unicode_predefined_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_unicode_predefined_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Korea1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_korea_cmap_text_document_for_test(),
  )
  acceptance_assert_korea_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_korea_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-GB1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_gb1_cmap_text_document_for_test(),
  )
  acceptance_assert_gb1_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_gb1_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-CNS1 variant predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cns1_variant_cmap_text_document_for_test(),
  )
  acceptance_assert_cns1_variant_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_cns1_variant_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 90msp predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_90msp_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_90msp_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_90msp_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 legacy predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_legacy_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_legacy_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_legacy_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 supplemental predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_supplemental_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_supplemental_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_supplemental_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type0 ToUnicode CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_h_tounicode_text_document_for_test(),
  )
  acceptance_assert_identity_h_tounicode_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_h_tounicode_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts embedded TrueType text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_truetype_text_document_for_test(),
  )
  acceptance_assert_truetype_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_truetype_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts images through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_image_lifecycle_document_for_test(),
  )
  acceptance_assert_image_lifecycle_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_image_lifecycle_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_image_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite builds cpdfimage JBIG2 documents through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_jbig2_source_document_for_test(),
  )
  acceptance_assert_jbig2_source_document_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_jbig2_source_document_for_test(reparsed)
}

///|
test "native acceptance suite reports cpdfcomposition buckets through reader boundaries" {
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    acceptance_composition_source_document_for_test(),
  )
  let parsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_composition_source_document_for_test(
    parsed,
    rendered.length(),
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    parsed,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rerendered)
  acceptance_assert_composition_source_document_for_test(
    reparsed,
    rerendered.length(),
  )
}

///|
test "native acceptance suite preserves encoded image aliases through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_encoded_image_alias_document_for_test(),
  )
  acceptance_assert_encoded_image_aliases_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_encoded_image_aliases_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_encoded_image_aliases_for_test(reparsed)
}

///|
test "native acceptance suite resolves named image resources through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_named_image_resource_document_for_test(),
  )
  acceptance_assert_named_image_resources_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_named_image_resources_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_named_image_resources_for_test(reparsed)
}

///|
test "native acceptance suite decodes CMYK images through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cmyk_image_document_for_test(),
  )
  acceptance_assert_cmyk_images_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_cmyk_images_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_cmyk_images_for_test(reparsed)
}

///|
test "native acceptance suite decodes alternate image colour spaces through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_alt_image_document_for_test(),
  )
  acceptance_assert_alt_images_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_alt_images_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_alt_images_for_test(reparsed)
}

///|
test "native acceptance suite reads classic and xref-stream incremental revisions" {
  let original = try! @pdflite.pdf_write_document(
    try! acceptance_one_page_document_for_test(),
  )
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  let classic_updated = try! acceptance_add_revision_marker_for_test(
    original_parsed, 90, "classic-update",
  )
  let classic_update = try! @pdflite.pdf_write_document_incremental_update(
    original, classic_updated,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(classic_update), 2)
  let classic_newest = try! @pdflite.pdf_read_document_revision_from_bytes(
    classic_update, 1,
  )
  acceptance_assert_one_page_invariants_for_test(classic_newest, (1, 4))
  acceptance_assert_revision_marker_for_test(
    classic_newest, 90, "classic-update",
  )
  let classic_older = try! @pdflite.pdf_read_document_revision_from_bytes(
    classic_update, 2,
  )
  acceptance_assert_one_page_invariants_for_test(classic_older, (1, 4))
  acceptance_assert_no_revision_marker_for_test(classic_older, 90)

  let xref_original = try! @pdflite.pdf_write_document_with_xref_stream(
    try! acceptance_one_page_document_for_test(),
  )
  let xref_original_parsed = try! @pdflite.pdf_read_document_from_bytes(
    xref_original,
  )
  let xref_updated = try! acceptance_add_revision_marker_for_test(
    xref_original_parsed, 91, "xref-update",
  )
  let xref_update = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    xref_original, xref_updated,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(xref_update), 2)
  let xref_newest = try! @pdflite.pdf_read_document_revision_from_bytes(
    xref_update, 1,
  )
  acceptance_assert_one_page_invariants_for_test(xref_newest, (1, 5))
  acceptance_assert_revision_marker_for_test(xref_newest, 91, "xref-update")
  let xref_older = try! @pdflite.pdf_read_document_revision_from_bytes(
    xref_update, 2,
  )
  acceptance_assert_one_page_invariants_for_test(xref_older, (1, 5))
  acceptance_assert_no_revision_marker_for_test(xref_older, 91)
}

///|
test "native acceptance suite reconstructs compressed xref incremental revisions with bad startxref" {
  let xref_original = @pdflite.pdf_write_document_with_xref_stream(
    acceptance_one_page_document_for_test(),
  )
  let xref_original_parsed = @pdflite.pdf_read_document_from_bytes(
    xref_original,
  )
  let xref_updated = acceptance_add_revision_marker_for_test(
    xref_original_parsed, 93, "xref-bad-startxref-update",
  )
  let xref_update = @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    xref_original, xref_updated,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(xref_update)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  acceptance_assert_revision_marker_for_test(
    recovered, 93, "xref-bad-startxref-update",
  )
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_revision_marker_for_test(
    reparsed, 93, "xref-bad-startxref-update",
  )
}

///|
test "native acceptance suite updates documents through public writer modes" {
  let original = @pdflite.pdf_write_document_with_mode(
    acceptance_one_page_document_for_test(),
    PdfWriteXRefStream,
  )
  let original_parsed = @pdflite.pdf_read_document_from_bytes(original)
  acceptance_assert_one_page_invariants_for_test(original_parsed, (1, 5))

  let updated = acceptance_add_revision_marker_for_test(
    original_parsed, 92, "mode-dispatched-update",
  )
  let rendered = @pdflite.pdf_write_document_incremental_update_with_mode(
    original,
    updated,
    PdfWriteCompressedXRefStream,
  )
  @test.assert_eq(@pdflite.pdf_revisions_from_bytes(rendered), 2)
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("/FlateDecode"),
    ) >
    original.length(),
    true,
  )
  let newest = @pdflite.pdf_read_document_revision_from_bytes(rendered, 1)
  acceptance_assert_one_page_invariants_for_test(newest, (1, 5))
  acceptance_assert_revision_marker_for_test(
    newest, 92, "mode-dispatched-update",
  )
  let older = @pdflite.pdf_read_document_revision_from_bytes(rendered, 2)
  acceptance_assert_one_page_invariants_for_test(older, (1, 5))
  acceptance_assert_no_revision_marker_for_test(older, 92)
}

///|
test "native acceptance suite normalizes object-stream pages through writer" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    acceptance_object_stream_pdf_for_test(),
  )
  acceptance_assert_object_stream_document_for_test(parsed)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_object_stream_document_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs indirect-filter object-stream page trees" {
  let strict = @pdflite.pdf_read_document_from_bytes(
    acceptance_indirect_filtered_object_stream_pdf_for_test(None),
  )
  acceptance_assert_indirect_filtered_object_stream_for_test(strict)

  let malformed = acceptance_indirect_filtered_object_stream_pdf_for_test(
    Some(0),
  )
  let strict_malformed : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict_malformed is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected malformed startxref to require object-stream reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_indirect_filtered_object_stream_for_test(recovered)

  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_indirect_filtered_object_stream_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs prev-chain object-stream page trees" {
  let strict = @pdflite.pdf_read_document_from_bytes(
    acceptance_prev_object_stream_pdf_for_test(None),
  )
  acceptance_assert_prev_object_stream_page_tree_for_test(strict)

  let malformed = acceptance_prev_object_stream_pdf_for_test(Some(0))
  let strict_malformed : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict_malformed is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected bad final startxref to require /Prev-chain reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_prev_object_stream_page_tree_for_test(recovered)

  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_prev_object_stream_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs physical page trees when object-stream bounds are malformed" {
  let bytes = acceptance_bad_first_object_stream_physical_page_tree_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected malformed object-stream bounds to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.version(), (1, 5))
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! recovered.endpage(), 1)
  @test.assert_eq(try! recovered.page_reference_numbers(), [5])
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  @test.assert_eq(try! reparsed.endpage(), 1)
  @test.assert_eq(try! reparsed.page_reference_numbers(), [5])
}

///|
test "native acceptance suite rejects mismatched object-stream root recovery" {
  let bytes = acceptance_mismatched_object_stream_root_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict object-stream root mismatch failure")
  }
  let public : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard public is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected public reader to reject physical fallback after mismatch")
  }
}

///|
test "native acceptance suite rejects unsupported object-stream filters" {
  let bad_filter : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /BadObjectStreamFilter", false,
    ),
  )
  let filter = match bad_filter {
    Err(@pdflite.PdfError::FilterNotSupported(filter)) => filter
    Err(_) => fail("expected unsupported object-stream filter")
    Ok(_) => fail("expected unsupported object-stream filter failure")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadObjectStreamFilter"))

  let bad_decodeparms : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /FlateDecode /DecodeParms /Bad", true,
    ),
  )
  guard bad_decodeparms is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed object-stream DecodeParms failure")
  }

  let bad_predictor : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /FlateDecode /DecodeParms << /Predictor 9 >>", true,
    ),
  )
  guard bad_predictor
    is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported object-stream predictor failure")
  }
  @test.assert_eq(predictor, 9)
}

///|
test "native acceptance suite rejects invalid object-stream data slices" {
  let bytes = acceptance_bad_first_object_stream_entry_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected strict invalid object-stream slice failure")
  }
  let public : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard public is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected public invalid object-stream slice failure")
  }
}

///|
test "native acceptance suite rejects non-xref startxref targets" {
  let non_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_startxref_object_pdf_for_test("7"),
  )
  guard non_stream is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-stream startxref target rejection")
  }

  let wrong_stream_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_startxref_object_pdf_for_test(
      "<< /Length 0 >>\nstream\n\nendstream",
    ),
  )
  guard wrong_stream_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected stream without xref type rejection")
  }

  let explicit_wrong_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    acceptance_xref_stream_pdf_with_type_for_test("/Type /Catalog"),
  )
  guard explicit_wrong_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected explicit wrong xref stream type rejection")
  }

  let non_name_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    acceptance_xref_stream_pdf_with_type_for_test("/Type 99"),
  )
  guard non_name_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-name xref stream type rejection")
  }
}

///|
test "native acceptance suite decrypts object streams during password reads" {
  let bytes = try! acceptance_encrypted_object_stream_pdf_for_test()
  let no_password : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard no_password is Err(_) else {
    fail("expected encrypted object stream to require password-aware reading")
  }
  let bad_password : Result[@pdflite.PdfDecryptionResult?, Error] = try? @pdflite.pdf_read_document_from_bytes_with_passwords(
    bytes,
    owner_password=Some(acceptance_ascii_for_test("bad-owner")),
  )
  guard bad_password is Err(_) else {
    fail("expected bad password to fail encrypted object-stream expansion")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite reconstructs encrypted object streams with bad startxref" {
  let bytes = acceptance_corrupt_startxref_pointer_for_test(
    acceptance_encrypted_object_stream_pdf_for_test(),
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let partial = @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(partial.first_xref(), 0)
  @test.assert_eq(partial.lookup_object_or_null(2), PdfNull)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite decrypts object streams with blank user password" {
  let bytes = acceptance_encrypted_object_stream_pdf_with_passwords_for_test(
    acceptance_ascii_for_test(""),
    acceptance_ascii_for_test("owner"),
    [PdfNoCopy],
  )
  let default_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(bytes),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(
    default_decrypted,
    [PdfNoCopy],
  )
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(owner_decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite recrypts non-stream encrypted object-stream payloads" {
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let bytes = acceptance_encrypted_object_stream_pdf_for_test()
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(owner_password),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("object-stream-recrypt-added"),
  )
  decrypted.document.add_object_given_number(6, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 16)
    },
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("encrypted object stream"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(roundtrip, [
    PdfNoCopy,
  ])
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), added_object)
}

///|
test "native acceptance suite reconstructs omitted page-tree xrefs" {
  let bytes = acceptance_pdf_with_omitted_page_tree_xrefs_for_test()
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_minimal_page_tree_for_test(parsed)
  let password_wrapper = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(bytes),
  )
  @test.assert_eq(password_wrapper.denied_permissions, [])
  acceptance_assert_minimal_page_tree_for_test(password_wrapper.document)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite normalizes tolerated malformed classic xrefs" {
  let bytes = acceptance_pdf_with_tolerated_malformed_xref_for_test()
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(bytes)
  @test.assert_eq(strict.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(parsed.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(parsed)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite normalizes tokenized and CR-only classic xrefs" {
  let tokenized = acceptance_pdf_with_tokenized_xref_rows_for_test()
  let strict_tokenized = @pdflite.pdf_read_classic_document_from_bytes(
    tokenized,
  )
  @test.assert_eq(strict_tokenized.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict_tokenized)
  let public_tokenized = @pdflite.pdf_read_document_from_bytes(tokenized)
  @test.assert_eq(public_tokenized.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(public_tokenized)

  let cr_only = acceptance_cr_line_endings_for_test(tokenized)
  let strict_cr = @pdflite.pdf_read_classic_document_from_bytes(cr_only)
  @test.assert_eq(strict_cr.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict_cr)
  let public_cr = @pdflite.pdf_read_document_from_bytes(cr_only)
  @test.assert_eq(public_cr.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(public_cr)

  let normalized = @pdflite.pdf_write_document(public_cr)
  let reparsed = @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs malformed feature-rich classic documents" {
  let bytes = @pdflite.pdf_write_document(
    acceptance_document_feature_lifecycle_document_for_test(),
  )
  let corrupted = acceptance_corrupt_first_in_use_xref_offset_for_test(bytes)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected corrupted xref offset to require reconstruction")
  }
  let parsed = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(parsed.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 4))
  let changed = parsed.change_pages(
    parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    changed,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_document_feature_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite merges and extracts pages through reader boundaries" {
  let first = try! acceptance_one_page_document_for_test()
  let second = try! acceptance_one_page_document_for_test()
  second.set_version(1, 7)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  @test.assert_eq(merged.version(), (1, 7))
  acceptance_assert_pages_have_hello_content_for_test(merged, 2)
  let merged_bytes = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    merged,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(merged_bytes)
  @test.assert_eq(parsed.version(), (1, 7))
  acceptance_assert_pages_have_hello_content_for_test(parsed, 2)
  let extracted = try! parsed.pdf_of_pages([2, 1])
  let extracted_bytes = try! @pdflite.pdf_write_document(extracted)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(extracted_bytes)
  acceptance_assert_pages_have_hello_content_for_test(reparsed, 2)
  let page_refs = try! reparsed.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] != page_refs[1], true)
}

///|
test "native acceptance suite runs pdfmergeexample manual merge workflow" {
  let first = acceptance_compressed_roundtrip_for_test(
    acceptance_pdfmergeexample_document_for_test("manual-first", 4, 88),
  )
  let second = acceptance_compressed_roundtrip_for_test(
    acceptance_pdfmergeexample_document_for_test("manual-second", 7, 89),
  )
  let merged = acceptance_pdfmergeexample_workflow_for_test([first, second])
  @test.assert_eq(merged.version(), (1, 7))
  acceptance_assert_text_pages_for_test(merged, [
    "manual-first", "manual-second",
  ])
  @test.assert_eq(
    acceptance_document_contains_object_for_test(
      merged,
      PdfString(acceptance_ascii_for_test("detached-manual-first")),
    ),
    false,
  )
  @test.assert_eq(
    acceptance_document_contains_object_for_test(
      merged,
      PdfString(acceptance_ascii_for_test("detached-manual-second")),
    ),
    false,
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(merged)
  @test.assert_eq(reparsed.version(), (1, 7))
  acceptance_assert_text_pages_for_test(reparsed, [
    "manual-first", "manual-second",
  ])
  let page_refs = reparsed.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] != page_refs[1], true)
}

///|
test "native acceptance suite preserves labels and bookmarks across merge boundary" {
  let first = acceptance_labelled_bookmarked_document_for_test(
    "A-",
    "First",
    PageLabelDecimalArabic,
    1,
  )
  let second = acceptance_labelled_bookmarked_document_for_test(
    "B-",
    "Second",
    PageLabelLowercaseRoman,
    4,
  )
  let expected_labels = @pdflite.pdf_page_label_merge([first, second], [
    [1],
    [1],
  ])
  let merged = @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_numbering=true,
  )
  @test.assert_eq(merged.read_page_labels(), expected_labels)
  acceptance_assert_bookmarks_target_pages_for_test(merged, "First", "Second")
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(merged)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.read_page_labels(), expected_labels)
  acceptance_assert_bookmarks_target_pages_for_test(reparsed, "First", "Second")
}

///|
test "native acceptance suite merges catalog feature lifecycle" {
  let first = acceptance_compressed_roundtrip_for_test(
    acceptance_catalog_merge_document_for_test(
      "first-field", "first-title", 90, false,
    ),
  )
  let second = acceptance_compressed_roundtrip_for_test(
    acceptance_catalog_merge_document_for_test(
      "second-field", "second-title", 90, true,
    ),
  )
  let merged = @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let reparsed = acceptance_compressed_roundtrip_for_test(merged)
  acceptance_assert_catalog_merge_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite extracts pages with structure tree pruning" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_structure_extraction_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let extracted = parsed.pdf_of_pages([1], process_struct_tree=true)
  acceptance_assert_structure_extraction_for_test(extracted)
  let reparsed = acceptance_compressed_roundtrip_for_test(extracted)
  acceptance_assert_structure_extraction_for_test(reparsed)
}

///|
test "native acceptance suite runs page resource lifecycle workflow" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_resource_lifecycle_document_for_test(),
  )
  acceptance_process_resource_lifecycle_forms_for_test(parsed)
  parsed.add_prefix("p")
  acceptance_assert_resource_lifecycle_prefixed_for_test(parsed)
  let prefixed_pages = parsed.pages_of_pagetree()
  let renumbered_pages = parsed.renumber_pages([
    prefixed_pages[0],
    prefixed_pages[0],
  ])
  let changed = parsed.change_pages(renumbered_pages)
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_resource_lifecycle_renumbered_for_test(reparsed)
}

///|
test "native acceptance suite changes resource-heavy pages with mixed references" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_resource_heavy_change_pages_document_for_test(),
  )
  let pages = parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let changed = parsed.change_pages(
    [
      {
        ..pages[0],
        content: [
          @pdflite.pdf_content_stream_of_ops(
            acceptance_change_pages_resource_ops_for_test("After"),
          ),
        ],
      },
    ],
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_resource_heavy_change_pages_for_test(reparsed)
}

///|
test "native acceptance suite changes inherited pages with indirect actions" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_inherited_change_pages_document_for_test(),
  )
  let pages = parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let changed = parsed.change_pages(
    [
      {
        ..pages[0],
        content: [
          @pdflite.pdf_content_stream_of_ops(
            acceptance_change_pages_resource_ops_for_test("InheritedAfter"),
          ),
        ],
      },
    ],
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_inherited_change_pages_for_test(reparsed)
}

///|
test "native acceptance suite runs pdfdecomp stream decompression workflow" {
  let source = @pdflite.pdf_write_document_with_xref_stream(
    acceptance_one_page_document_for_test(),
  )
  let parsed = @pdflite.pdf_read_document_from_bytes(source)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  parsed.pdf_decode_streams_until_unknown()
  acceptance_assert_decompressed_partial_filter_stream_for_test(parsed)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(parsed)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_decompressed_partial_filter_stream_for_test(reparsed)
}

///|
test "native acceptance suite runs pdftest content rewrite workflow" {
  let source = acceptance_split_content_document_for_test()
  let bytes = @pdflite.pdf_write_document_with_xref_stream(source)
  let parsed = @pdflite.pdf_read_document_from_bytes(bytes)
  let source_pages = parsed.pages_of_pagetree()
  @test.assert_eq(source_pages.length(), 1)
  @test.assert_eq(source_pages[0].content.length(), 2)
  @test.assert_eq(
    parsed.parse_content_ops(source_pages[0].content),
    acceptance_one_page_ops_for_test(),
  )
  let rewritten = acceptance_pdftest_rewrite_document_for_test(parsed)
  acceptance_assert_pdftest_rewrite_for_test(rewritten)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    rewritten,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_pdftest_rewrite_for_test(reparsed)
}

///|
test "native acceptance suite runs pdfdraft image replacement workflow" {
  let drafted = acceptance_draft_document_for_test(
    acceptance_draft_source_document_for_test(),
  )
  acceptance_assert_drafted_document_for_test(drafted)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    drafted,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_drafted_document_for_test(reparsed)
}

///|
test "native acceptance suite changes pages after compressed reader boundary" {
  let doc = try! acceptance_one_page_document_for_test()
  let old_numbers = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test("Acceptance"),
      target: DestXYZ(
        TargetPageObject(old_numbers[0]),
        Some(12.0),
        Some(34.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let bytes = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    bookmarked,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  let changed = try! parsed.change_pages(
    try! parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = try! @pdflite.pdf_write_document(changed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  let new_numbers = try! reparsed.page_reference_numbers()
  @test.assert_eq(try! reparsed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: acceptance_ascii_for_test("Acceptance"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(17.0),
        Some(28.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "native acceptance suite changes page count with explicit reference mapping" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_count_change_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let changed = parsed.change_pages(
    [acceptance_count_change_replacement_page_for_test()],
    change_references=true,
    changes=[(2, 1)],
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  acceptance_assert_count_changed_document_for_test(changed)
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_count_changed_document_for_test(reparsed)
}

///|
test "native acceptance suite extracts reused annotations with repaired links" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_reused_annotation_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let extracted = parsed.pdf_of_pages([1, 2])
  acceptance_assert_extracted_reused_annotations_for_test(extracted)
  let reparsed = acceptance_compressed_roundtrip_for_test(extracted)
  acceptance_assert_extracted_reused_annotations_for_test(reparsed)
}

///|
test "native acceptance suite preserves cpdfattach files through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cpdfattach_document_for_test(),
  )
  acceptance_assert_cpdfattach_document_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_cpdfattach_document_for_test(reparsed)
  let cleaned = reparsed.remove_attached_files()
  acceptance_assert_cpdfattach_removed_for_test(cleaned)
  let cleaned_reparsed = acceptance_compressed_roundtrip_for_test(cleaned)
  acceptance_assert_cpdfattach_removed_for_test(cleaned_reparsed)
}

///|
test "native acceptance suite preserves document feature lifecycle" {
  let bytes = @pdflite.pdf_write_document_with_compressed_xref_stream(
    acceptance_document_feature_lifecycle_document_for_test(),
  )
  let parsed = @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  let changed = parsed.change_pages(
    parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = @pdflite.pdf_write_document(changed)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_document_feature_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite reads encrypted AES128 documents through public wrapper" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test("native-acceptance-secret")
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-id"),
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let user_decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    user_decrypted.document,
    (1, 4),
  )
  @test.assert_eq(user_decrypted.document.lookup_object_or_null(60), secret)
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(owner_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    owner_decrypted.document,
    (1, 4),
  )
  @test.assert_eq(owner_decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite preserves unencrypted metadata through AES recrypt" {
  let metadata = acceptance_metadata_bytes_for_test()
  let secret = acceptance_secret_object_for_test("metadata-encrypted-secret")
  let input = acceptance_metadata_encryption_document_for_test(metadata, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoExtract, PdfNoCopy]
  let rendered = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    input,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 8)
    },
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=acceptance_ascii_for_test("native-metadata-encryption-id"),
  )
  @test.assert_eq(acceptance_find_bytes_for_test(rendered, metadata) >= 0, true)
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("metadata-encrypted-secret"),
    ) <
    0,
    true,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_metadata_encryption_for_test(
    decrypted.document,
    metadata,
    secret,
  )
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("metadata-added"),
  )
  decrypted.document.add_object_given_number(64, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 12)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(rerendered, metadata) >= 0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_metadata_encryption_for_test(
    roundtrip.document,
    metadata,
    secret,
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(64), added_object)
}

///|
test "native acceptance suite runs pdfencrypt owner-password workflow" {
  let input = acceptance_one_page_document_for_test()
  let user_password = acceptance_ascii_for_test("")
  let owner_password = acceptance_ascii_for_test("owner-password")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    input,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    mode=PdfWriteClassic,
    file_id=acceptance_ascii_for_test("native-acceptance-pdfencrypt-id"),
  )
  let default_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(encrypted),
  )
  @test.assert_eq(default_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    default_decrypted.document,
    (1, 4),
  )
  let user_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      encrypted,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    user_decrypted.document,
    (1, 4),
  )
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      encrypted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(owner_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    owner_decrypted.document,
    (1, 4),
  )
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed trailers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-trailer-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 21)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-malformed-trailer-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("trailer\n"),
    "trailer\n1\n",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected malformed trailer to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-trailer-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 22)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-malformed-trailer-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted missing-root trailers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-missing-root-trailer-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 23)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-missing-root-trailer-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("trailer\n"),
    "trailer\n<< /Size 999 >>\n",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing-root trailer to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("missing-root-trailer-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-missing-root-trailer-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted catalogs missing from xref" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-catalog-missing-xref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 25)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-catalog-missing-xref-id",
    ),
  )
  let root_number = encrypted.root()
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_mark_classic_xref_entry_free_for_test(
    rendered, root_number,
  )
  let strict = @pdflite.pdf_read_classic_document_from_bytes(malformed)
  @test.assert_eq(strict.root(), root_number)
  let strict_catalog : Result[@pdflite.PdfObject, Error] = try? strict.catalog()
  guard strict_catalog is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing root object to require reconstruction")
  }
  @test.assert_eq(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      user_password=Some(acceptance_ascii_for_test("bad-user")),
    ),
    None,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("catalog-missing-xref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 26)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-catalog-missing-xref-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted page trees missing from xref" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.set_root(1)
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Root"), PdfIndirect(1)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Catalog")),
      ),
      (acceptance_name_for_test("/Pages"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(3)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Page")),
      ),
      (acceptance_name_for_test("/Parent"), PdfIndirect(2)),
      (
        acceptance_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
    ]),
  )
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-page-tree-missing-xref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 27)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-page-tree-missing-xref-id",
    ),
  )
  let encrypt_object_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(acceptance_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encryption object reference")
  }
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_keep_catalog_and_encrypt_xref_entries_for_test(
    rendered, encrypt_object_number,
  )
  let strict = @pdflite.pdf_read_classic_document_from_bytes(malformed)
  @test.assert_eq(strict.root(), 1)
  @test.assert_eq(strict.object_numbers(), [1, encrypt_object_number])
  let strict_pages : Result[Int, Error] = try? strict.endpage()
  guard strict_pages is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected missing page tree to require reconstruction")
  }
  @test.assert_eq(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      user_password=Some(acceptance_ascii_for_test("bad-user")),
    ),
    None,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(decrypted.document.root(), 1)
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("page-tree-missing-xref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 28)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-page-tree-missing-xref-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.root(), 1)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed malformed xref documents" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-reconstructed-secret",
  )
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 3)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-malformed-id"),
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let corrupted = try! acceptance_corrupt_first_in_use_xref_offset_for_test(
    rendered,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected corrupted xref to require malformed reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref markers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-marker-secret",
  )
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let user_password = acceptance_ascii_for_test("user")
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 11)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-xref-marker-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_first_in_use_xref_marker_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref marker to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref subsections" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-subsection-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 12)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-subsection-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_first_xref_subsection_count_for_test(
    rendered,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed xref subsection to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-subsection-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 13)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-subsection-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream metadata" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-index-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 14)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-xref-stream-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/W ["),
    "/Index [0] ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream metadata to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 15)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-index-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream widths" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-width-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 16)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-width-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/W ["),
    "/W [1 4] ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream widths to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-width-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 17)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-width-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream size" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-size-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 18)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-size-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Size "),
    "/Size /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream size to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-size-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 19)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-size-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs malformed xref-stream filters" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-filter-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadXRefFilter"))
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream filters" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-filter-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 20)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-filter-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadXRefFilter"))
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-filter-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 21)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-filter-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs malformed xref-stream decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-decodeparms-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite reconstructs xref-stream unsupported predictor decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-unsupported-predictor-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms << /Predictor 9 >> ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported xref stream DecodeParms predictor")
  }
  @test.assert_eq(predictor, 9)
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-decodeparms-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 22)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-bad-xref-decodeparms-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-decodeparms-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 23)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-decodeparms-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted xref-stream unsupported predictor" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-unsupported-predictor-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-bad-xref-predictor-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms << /Predictor 9 >> ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported encrypted xref stream DecodeParms predictor")
  }
  @test.assert_eq(predictor, 9)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("xref-stream-unsupported-predictor-recrypt-added"),
  )
  decrypted.document.add_object_given_number(62, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 25)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-unsupported-predictor-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(62), added_object)
}

///|
test "native acceptance suite recrypts reconstructed bad-startxref encrypted documents" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-bad-startxref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 20)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-startxref-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_pages_have_hello_content_for_test(decrypted.document, 1)
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("bad-startxref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-bad-startxref-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_pages_have_hello_content_for_test(roundtrip.document, 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs compressed encrypted documents with bad startxref" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-compressed-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoPrint]
  let rendered = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    doc,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 28)
    },
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-compressed-encrypted-id",
    ),
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("native-acceptance-compressed-encrypted-secret"),
    ) <
    0,
    true,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad compressed xref startxref to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)

  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("compressed-encrypted-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 29)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-compressed-encrypted-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite recrypts encrypted incremental revisions" {
  let original_secret = acceptance_secret_object_for_test(
    "native-acceptance-original",
  )
  let updated_secret = acceptance_secret_object_for_test(
    "native-acceptance-updated",
  )
  let doc = try! acceptance_one_page_document_for_test()
  doc.add_object_given_number(60, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 1)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-recrypt-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  decrypted.document.add_object_given_number(60, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    acceptance_ascii_for_test("owner"),
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 2)
    },
  )
  let updated = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(updated), 2)
  let newest = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
      updated,
      1,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(newest.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(newest.document, (1, 4))
  @test.assert_eq(newest.document.lookup_object_or_null(60), updated_secret)
  let older = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
      updated,
      2,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(older.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(older.document, (1, 4))
  @test.assert_eq(older.document.lookup_object_or_null(60), original_secret)
}

///|
test "native acceptance suite reconstructs encrypted incremental revisions with bad startxref" {
  let original_secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-original",
  )
  let updated_secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-updated",
  )
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let doc = acceptance_one_page_document_for_test()
  doc.add_object_given_number(60, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoEdit]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 30)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-incremental-id"),
  )
  let original = @pdflite.pdf_write_document(encrypted)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(user_password),
    ),
  )
  decrypted.document.add_object_given_number(60, updated_secret)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 31)
    },
  )
  let updated = @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(updated)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let recovered = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(recovered.document, (1, 4))
  @test.assert_eq(recovered.document.lookup_object_or_null(60), updated_secret)

  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-incremental-recrypt-added"),
  )
  recovered.document.add_object_given_number(61, added_object)
  let recovered_recrypted = recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 32)
    },
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered_recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("native-acceptance-malformed-updated"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}
