// Main package file for your library code.
// Put public APIs and shared helpers here.
// Keep blocks small and focused for easy refactors.

///|
pub using @core {
  type PdfCryptType,
  type PdfError,
  type PdfBytes,
  type PdfName,
  type ByteCursor,
  type ByteOutput,
  type BitStream,
  type BitStreamPosition,
  type BitWriter,
  pdf_no_more,
  byte_cursor_of_bytes,
  byte_cursor_of_view,
  bitstream_of_cursor,
  bitstream_of_bytes,
  bitstream_of_view,
  pdf_error,
  pdf_soft_error,
  pdf_hard_error,
  pdf_error_summary,
  pdf_byte_of_int,
  pdf_bytes_of_array_view,
  pdf_bytes_of_view,
  pdf_bytes_copy,
  pdf_bytes_make,
  pdf_bytes_concat_views,
  pdf_bytes_of_int_array,
  pdf_bytes_of_int_arrays,
  pdf_bytes_map_int,
  pdf_int_array_of_bytes,
  pdf_string_of_int_arrays,
  pdf_string_of_int_array,
  pdf_bytes_length,
  pdf_bytes_get,
  pdf_bytes_to_array,
  pdf_bytes_to_fixed_array,
  pdf_name_of_bytes,
  pdf_name_of_view,
  pdf_view_matches_ascii_at,
  pdf_view_equals_ascii,
  pdf_find_last_ascii,
  pdf_startxref_search_view,
  pdf_find_ascii_from,
  pdf_parse_ascii_int_view,
  pdf_count_whitespace_tokens,
  pdf_split_whitespace_tokens,
  pdf_is_whitespace_byte,
  pdf_is_digit_byte,
  pdf_is_newline_byte,
  pdf_is_not_whitespace_byte,
  pdf_is_delimiter_byte,
  pdf_is_whitespace_or_delimiter_byte,
  byte_output_new,
  bit_writer_new,
}

///|
pub using @syntax {
  type ToGet,
  type PdfStreamData,
  type PdfStreamDataCrypt,
  type PdfStream,
  type PdfObject,
  type PdfParsedIndirectObject,
  type PdfLexeme,
  pdf_array,
  pdf_dictionary,
  pdf_recurse_array,
  pdf_recurse_dict,
  pdf_stream,
  stream_to_get,
  pdf_parse_lexemes,
  pdf_parse_single_lexeme_object,
  pdf_parse_object_from_view,
  pdf_parse_object_from_bytes,
  pdf_parse_indirect_object_lexemes,
  pdf_parse_indirect_object_from_bytes,
  pdf_parse_indirect_object_from_view,
  pdf_parse_indirect_objects,
  pdf_cursor_drop_whitespace,
  pdf_cursor_read_until_whitespace_or_delimiter,
  pdf_cursor_read_regular_token_view,
  pdf_cursor_lex_bool,
  pdf_cursor_lex_number,
  pdf_cursor_lex_name,
  pdf_cursor_lex_comment,
  pdf_cursor_lex_hex_string,
  pdf_cursor_lex_keyword,
  pdf_cursor_lex_literal_string,
  pdf_cursor_lex_delimiter,
  pdf_cursor_lex_token,
  pdf_cursor_lex_tokens,
  pdf_lex_single_view,
  pdf_lex_view,
  pdf_lex_bytes,
  pdf_lexeme_debug_name,
  pdf_string_of_lexeme,
  pdf_string_of_lexemes,
}

///|
pub using @colour {
  type PdfDrawColour,
  type PdfContentColour,
  pdf_draw_colour_of_string,
  pdf_content_black,
  pdf_css_colour_value,
  pdf_css_colours,
  pdf_colours,
  pdf_parse_draw_colour,
  pdf_parse_colour,
  pdf_parse_content_colour,
}

///|
pub using @geometry {
  type PdfUnit,
  type PaperSize,
  type PdfCoordRectangle,
  type Point2,
  type PdfCalculatedPosition,
  type PdfPosition,
  type PdfRectangle,
  type TransformOp,
  type TransformMatrix,
  type TransformDecomposition,
  unit_points,
  unit_inches,
  unit_centimetres,
  unit_millimetres,
  pdf_calculate_position,
  paper_size_make,
  paper_a0,
  paper_a1,
  paper_a2,
  paper_a3,
  paper_a4,
  paper_a5,
  paper_a6,
  paper_a7,
  paper_a8,
  paper_a9,
  paper_a10,
  paper_usletter,
  paper_uslegal,
  transform_string_of_op,
  transform_string_of_ops,
  transform_string_of_transform,
  transform_string_of_matrix,
  point2,
  transform_identity_matrix,
  transform_identity,
  transform_translate,
  transform_matrix_compose,
  transform_scale,
  transform_rotate,
  transform_shear_x,
  transform_shear_y,
  transform_compose_op,
  transform_append,
  transform_apply_matrix,
  transform_matrix_of_op,
  transform_matrix_of_ops,
  transform_matrix_of_transform,
  transform_apply_ops,
  transform_apply,
  transform_matrix_invert,
  transform_decompose,
  transform_recompose,
  transform_recompose_components,
}

///|
pub using @page {
  type PdfPage,
  type PdfPageRotation,
  pdf_page_int_of_rotation,
  pdf_page_rotation_of_int,
  pdf_page_rectangle_of_paper,
  pdf_page_custom,
  pdf_page_blank,
}

///|
pub using @label {
  type PdfPageLabel,
  type PdfPageLabelStyle,
  pdf_page_label_basic,
  pdf_page_label_complete,
  pdf_page_label_of_page_number,
  pdf_page_label_of_single,
  pdf_page_label_style_of_string,
  pdf_page_label_text_of_page_number,
  pdf_page_label_text_of_single,
  pdf_string_of_page_label,
}

///|
pub using @spec {
  pdf_invert_page_range,
  pdf_invert_range,
  pdf_parse_pagespec_for_count,
  pdf_parse_pagespec_without_pdf,
  pdf_string_of_pagespec_for_count,
}

///|
pub using @addtext {
  type PdfAddTextJustification,
  type PdfAddTextLinePlacement,
  type PdfAddTextLineWidths,
  type PdfAddTextPreparedLine,
  type PdfAddTextReplacementValues,
  type PdfAddTextResourceSetup,
  type PdfAddTextRotation,
  type PdfAddTextUrl,
  type PdfAddTextUrlAnnotationGeometry,
  type PdfAddTextUrlLine,
}

///|
pub using @annotation {
  type PdfAnnotation,
  type PdfAnnotationBorder,
  type PdfAnnotationColour,
  type PdfAnnotationStyle,
  type PdfAnnotationSubtype,
  pdf_annotation_make,
  pdf_annotation_make_border,
}

///|
pub using @attachment {type PdfAttachment}

///|
pub using @shape {
  type PdfDrawnPath,
  type PdfPath,
  type PdfPathClosure,
  type PdfPathHole,
  type PdfPathSegment,
  type PdfPathSubpath,
  type PdfPathWindingRule,
  pdf_shape_kappa,
  pdf_kappa,
  pdf_restrict_angle,
  pdf_shape_circle,
  pdf_circle,
  pdf_shape_rectangle,
  pdf_rectangle,
  pdf_path_segment_bounds,
  pdf_path_bounds,
  pdf_path_segment_transform,
  pdf_path_transform,
  pdf_path_segment_content_json,
  pdf_path_subpath_content_json,
  pdf_drawn_path_content_json,
}

///|
pub using @crypt_core {
  type PdfPermission,
  type PdfEncryptionMethod,
  type PdfAesV3RandomField,
  pdf_p_of_permissions,
  pdf_permissions_of_p,
}

///|
pub using @date {
  type PdfDate,
  type PdfStrftimeTime,
  pdf_dummy,
  pdf_string_of_date,
  pdf_date_of_view,
  pdf_date_of_bytes,
  pdf_date_of_string,
  pdf_bytes_of_date,
  pdf_strftime_dummy_time,
  pdf_strftime_with_time,
}

///|
pub using @flate {
  pdf_flate_encode_view_with_level,
  pdf_flate_encode_view,
  pdf_flate_encode_with_level,
  pdf_flate_encode,
  pdf_flate_decode_view,
  pdf_flate_decode,
}

///|
pub using @codec {
  pdf_ascii_hex_encode_view,
  pdf_ascii_hex_encode,
  pdf_ascii_hex_decode_view,
  pdf_ascii_hex_decode,
  pdf_ascii85_encode_view,
  pdf_ascii85_encode,
  pdf_ascii85_decode_view,
  pdf_ascii85_decode,
  pdf_lzw_decode_view_prefix,
  pdf_lzw_decode_view,
  pdf_lzw_decode,
  pdf_cursor_read_jpeg_data,
  pdf_get_jpeg_data,
  pdf_jpeg_dimensions_view,
  pdf_jpeg_dimensions,
  pdf_jpeg_backup_dimensions_view,
  pdf_jpeg_backup_dimensions,
  pdf_run_length_encode_view,
  pdf_run_length_encode,
  pdf_run_length_decode_view,
  pdf_run_length_decode,
}

///|
pub using @content {
  type PdfContentOp,
  pdf_content_begin_artifact,
  pdf_content_end_artifact,
  pdf_content_add_artifacts,
}

///|
pub using @path {
  type PdfContentClippingOpResult,
  type PdfContentPartialPath,
  type PdfContentPartialPathState,
  type PdfContentPathOpResult,
  pdf_content_no_partial_path,
  pdf_content_apply_path_op,
  pdf_content_apply_clipping_op,
}

///|
pub using @destination {type PdfDestination, type PdfTargetPage}

///|
pub using @bookmark {
  type PdfBookmark,
  type PdfBookmarkColour,
  pdf_bookmark_black,
}

///|
pub using @composition {type PdfCompositionEntry}

///|
pub using @portfolio {type PdfPortfolioEntry, pdf_portfolio_entry}

///|
pub using @ocg {
  type PdfOcg,
  type PdfOcgAppDict,
  type PdfOcgConfig,
  type PdfOcgEvent,
  type PdfOcgListMode,
  type PdfOcgState,
  type PdfOcgUsage,
  type PdfOptionalContent,
  pdf_ocg_default_config,
}

///|
pub using @metadata {
  pdf_adobe,
  pdf_dc,
  pdf_metadata_adobe,
  pdf_metadata_adobe_namespace,
  pdf_metadata_dc,
  pdf_metadata_dc_namespace,
  pdf_metadata_pdfe,
  pdf_metadata_pdfe_namespace,
  pdf_metadata_pdfaid,
  pdf_metadata_pdfaid_namespace,
  pdf_metadata_pdfuaid,
  pdf_metadata_pdfuaid_namespace,
  pdf_metadata_pdfvtid,
  pdf_metadata_pdfvtid_namespace,
  pdf_metadata_pdfxid,
  pdf_metadata_pdfxid_namespace,
  pdf_metadata_rdf,
  pdf_metadata_rdf_namespace,
  pdf_metadata_xmp,
  pdf_metadata_xmp_namespace,
  pdf_pdfe,
  pdf_pdfaid,
  pdf_pdfuaid,
  pdf_pdfvtid,
  pdf_pdfxid,
  pdf_rdf,
  pdf_xmp,
  type PdfMetadataEncoding,
  type PdfMetadataXmlAttribute,
  type PdfMetadataXmlDocument,
  type PdfMetadataXmlName,
  type PdfMetadataXmlTag,
  type PdfMetadataXmlTree,
}

///|
pub using @afm {type PdfAfmData, pdf_read_afm}

///|
pub using @font {
  type PdfFontListEntry,
  type PdfFontTableEntry,
  type PdfMissingFontEntry,
}

///|
pub using @truetype {
  type PdfTrueTypeCMapGlyph,
  type PdfTrueTypeDescriptorMetrics,
  type PdfTrueTypeGlyphByteRange,
  type PdfTrueTypeMetrics,
  type PdfTrueTypeParsedSubset,
  type PdfTrueTypeSubsetPartition,
  type PdfTrueTypeSubsetTable,
  type PdfTrueTypeTableRecord,
}

///|
pub using @unicodedata {type PdfUnicodeDataEntry}

///|
pub using @reader {
  type PdfVersion,
  type ObjectStreamReference,
  type PdfClassicXRefEntry,
  type PdfClassicXRefIndex,
  type PdfXRefSection,
  pdf_default_version,
  pdf_read_header_from_cursor,
  pdf_read_header_from_view,
  pdf_read_header_from_bytes,
  pdf_classic_xref_lookup,
  pdf_classic_xref_index,
  pdf_classic_xrefs_add_newer_first_with_seen,
  pdf_cursor_consume_ascii,
  pdf_read_startxref_position,
  pdf_xref_token_in_use,
  pdf_cursor_read_classic_xref_entries,
}

///|
pub using @writer {
  type PdfWriteEncryption,
  type PdfWriteMode,
  pdf_write_encryption,
}
