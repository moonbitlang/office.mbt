///|
fn pdf_text_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_text_static_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_text_slash_name : @core.PdfName = pdf_text_static_name("/")

///|
let pdf_text_times_roman_name : @core.PdfName = pdf_text_static_name(
  "/Times-Roman",
)

///|
let pdf_text_times_new_roman_name : @core.PdfName = pdf_text_static_name(
  "/TimesNewRoman",
)

///|
let pdf_text_times_bold_name : @core.PdfName = pdf_text_static_name(
  "/Times-Bold",
)

///|
let pdf_text_times_new_roman_bold_name : @core.PdfName = pdf_text_static_name(
  "/TimesNewRoman,Bold",
)

///|
let pdf_text_times_italic_name : @core.PdfName = pdf_text_static_name(
  "/Times-Italic",
)

///|
let pdf_text_times_new_roman_italic_name : @core.PdfName = pdf_text_static_name(
  "/TimesNewRoman,Italic",
)

///|
let pdf_text_times_bold_italic_name : @core.PdfName = pdf_text_static_name(
  "/Times-BoldItalic",
)

///|
let pdf_text_times_new_roman_bold_italic_name : @core.PdfName = pdf_text_static_name(
  "/TimesNewRoman,BoldItalic",
)

///|
let pdf_text_helvetica_name : @core.PdfName = pdf_text_static_name("/Helvetica")

///|
let pdf_text_arial_name : @core.PdfName = pdf_text_static_name("/Arial")

///|
let pdf_text_helvetica_bold_name : @core.PdfName = pdf_text_static_name(
  "/Helvetica-Bold",
)

///|
let pdf_text_arial_bold_name : @core.PdfName = pdf_text_static_name(
  "/Arial,Bold",
)

///|
let pdf_text_helvetica_oblique_name : @core.PdfName = pdf_text_static_name(
  "/Helvetica-Oblique",
)

///|
let pdf_text_arial_italic_name : @core.PdfName = pdf_text_static_name(
  "/Arial,Italic",
)

///|
let pdf_text_helvetica_bold_oblique_name : @core.PdfName = pdf_text_static_name(
  "/Helvetica-BoldOblique",
)

///|
let pdf_text_arial_bold_italic_name : @core.PdfName = pdf_text_static_name(
  "/Arial,BoldItalic",
)

///|
let pdf_text_courier_name : @core.PdfName = pdf_text_static_name("/Courier")

///|
let pdf_text_courier_new_name : @core.PdfName = pdf_text_static_name(
  "/CourierNew",
)

///|
let pdf_text_courier_bold_name : @core.PdfName = pdf_text_static_name(
  "/Courier-Bold",
)

///|
let pdf_text_courier_new_bold_name : @core.PdfName = pdf_text_static_name(
  "/CourierNew,Bold",
)

///|
let pdf_text_courier_oblique_name : @core.PdfName = pdf_text_static_name(
  "/Courier-Oblique",
)

///|
let pdf_text_courier_new_italic_name : @core.PdfName = pdf_text_static_name(
  "/CourierNew,Italic",
)

///|
let pdf_text_courier_bold_oblique_name : @core.PdfName = pdf_text_static_name(
  "/Courier-BoldOblique",
)

///|
let pdf_text_courier_new_bold_italic_name : @core.PdfName = pdf_text_static_name(
  "/CourierNew,BoldItalic",
)

///|
let pdf_text_symbol_name : @core.PdfName = pdf_text_static_name("/Symbol")

///|
let pdf_text_zapf_dingbats_name : @core.PdfName = pdf_text_static_name(
  "/ZapfDingbats",
)

///|
let pdf_text_identity_h_name : @core.PdfName = pdf_text_static_name(
  "/Identity-H",
)

///|
let pdf_text_identity_v_name : @core.PdfName = pdf_text_static_name(
  "/Identity-V",
)

///|
let pdf_text_standard_encoding_name : @core.PdfName = pdf_text_static_name(
  "/StandardEncoding",
)

///|
let pdf_text_mac_roman_encoding_name : @core.PdfName = pdf_text_static_name(
  "/MacRomanEncoding",
)

///|
let pdf_text_win_ansi_encoding_name : @core.PdfName = pdf_text_static_name(
  "/WinAnsiEncoding",
)

///|
let pdf_text_mac_expert_encoding_name : @core.PdfName = pdf_text_static_name(
  "/MacExpertEncoding",
)

///|
let pdf_text_font_file_key_name : @core.PdfName = pdf_text_static_name(
  "/FontFile",
)

///|
let pdf_text_font_file2_key_name : @core.PdfName = pdf_text_static_name(
  "/FontFile2",
)

///|
let pdf_text_font_file3_key_name : @core.PdfName = pdf_text_static_name(
  "/FontFile3",
)

///|
let pdf_text_charset_key_name : @core.PdfName = pdf_text_static_name("/CharSet")

///|
let pdf_text_font_descriptor_key_name : @core.PdfName = pdf_text_static_name(
  "/FontDescriptor",
)

///|
let pdf_text_font_bbox_key_name : @core.PdfName = pdf_text_static_name(
  "/FontBBox",
)

///|
let pdf_text_ascent_key_name : @core.PdfName = pdf_text_static_name("/Ascent")

///|
let pdf_text_descent_key_name : @core.PdfName = pdf_text_static_name("/Descent")

///|
let pdf_text_avg_width_key_name : @core.PdfName = pdf_text_static_name(
  "/AvgWidth",
)

///|
let pdf_text_max_width_key_name : @core.PdfName = pdf_text_static_name(
  "/MaxWidth",
)

///|
let pdf_text_flags_key_name : @core.PdfName = pdf_text_static_name("/Flags")

///|
let pdf_text_italic_angle_key_name : @core.PdfName = pdf_text_static_name(
  "/ItalicAngle",
)

///|
let pdf_text_cap_height_key_name : @core.PdfName = pdf_text_static_name(
  "/CapHeight",
)

///|
let pdf_text_xheight_key_name : @core.PdfName = pdf_text_static_name("/XHeight")

///|
let pdf_text_stemv_key_name : @core.PdfName = pdf_text_static_name("/StemV")

///|
let pdf_text_subtype_key_name : @core.PdfName = pdf_text_static_name("/Subtype")

///|
let pdf_text_type3_name : @core.PdfName = pdf_text_static_name("/Type3")

///|
let pdf_text_missing_width_key_name : @core.PdfName = pdf_text_static_name(
  "/MissingWidth",
)

///|
let pdf_text_widths_key_name : @core.PdfName = pdf_text_static_name("/Widths")

///|
let pdf_text_first_char_key_name : @core.PdfName = pdf_text_static_name(
  "/FirstChar",
)

///|
let pdf_text_last_char_key_name : @core.PdfName = pdf_text_static_name(
  "/LastChar",
)

///|
let pdf_text_charprocs_key_name : @core.PdfName = pdf_text_static_name(
  "/CharProcs",
)

///|
let pdf_text_resources_key_name : @core.PdfName = pdf_text_static_name(
  "/Resources",
)

///|
let pdf_text_font_matrix_key_name : @core.PdfName = pdf_text_static_name(
  "/FontMatrix",
)

///|
let pdf_text_type1_name : @core.PdfName = pdf_text_static_name("/Type1")

///|
let pdf_text_mmtype1_name : @core.PdfName = pdf_text_static_name("/MMType1")

///|
let pdf_text_true_type_name_value : @core.PdfName = pdf_text_static_name(
  "/TrueType",
)

///|
let pdf_text_base_font_key_name : @core.PdfName = pdf_text_static_name(
  "/BaseFont",
)

///|
let pdf_text_font_name : @core.PdfName = pdf_text_static_name("/Font")

///|
let pdf_text_encoding_key_name : @core.PdfName = pdf_text_static_name(
  "/Encoding",
)

///|
let pdf_text_base_encoding_key_name : @core.PdfName = pdf_text_static_name(
  "/BaseEncoding",
)

///|
let pdf_text_differences_key_name : @core.PdfName = pdf_text_static_name(
  "/Differences",
)

///|
let pdf_text_type0_name : @core.PdfName = pdf_text_static_name("/Type0")

///|
let pdf_text_registry_key_name : @core.PdfName = pdf_text_static_name(
  "/Registry",
)

///|
let pdf_text_ordering_key_name : @core.PdfName = pdf_text_static_name(
  "/Ordering",
)

///|
let pdf_text_supplement_key_name : @core.PdfName = pdf_text_static_name(
  "/Supplement",
)

///|
let pdf_text_w_key_name : @core.PdfName = pdf_text_static_name("/W")

///|
let pdf_text_w2_key_name : @core.PdfName = pdf_text_static_name("/W2")

///|
let pdf_text_dw_key_name : @core.PdfName = pdf_text_static_name("/DW")

///|
let pdf_text_dw2_key_name : @core.PdfName = pdf_text_static_name("/DW2")

///|
let pdf_text_cid_system_info_key_name : @core.PdfName = pdf_text_static_name(
  "/CIDSystemInfo",
)

///|
let pdf_text_descendant_fonts_key_name : @core.PdfName = pdf_text_static_name(
  "/DescendantFonts",
)

///|
let pdf_text_wmode_key_name : @core.PdfName = pdf_text_static_name("/WMode")

///|
let pdf_text_cmap_name_key_name : @core.PdfName = pdf_text_static_name(
  "/CMapName",
)

///|
let pdf_text_cmap_type_key_name : @core.PdfName = pdf_text_static_name(
  "/CMapType",
)

///|
let pdf_text_usecmap_key_name : @core.PdfName = pdf_text_static_name("/UseCMap")

///|
let pdf_text_tounicode_key_name : @core.PdfName = pdf_text_static_name(
  "/ToUnicode",
)

///|
let pdf_text_type_key_name : @core.PdfName = pdf_text_static_name("/Type")

///|
let pdf_text_font_name_key_name : @core.PdfName = pdf_text_static_name(
  "/FontName",
)

///|
let pdf_text_length_key_name : @core.PdfName = pdf_text_static_name("/Length")
