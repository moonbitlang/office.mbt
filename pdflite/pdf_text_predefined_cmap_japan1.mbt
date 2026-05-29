///|
fn pdf_text_predefined_japan1_direct_codepoint_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90ms_rksj_codepoint_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90pv_rksj_codepoint_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_japan1_direct_codepoint_sequence_table(
  name : PdfName,
) -> Array[(Int, Array[Int])] {
  let text = pdf_text_string_of_name(name)
  if text == "/90pv-RKSJ-H" {
    @cmapdata.pdf_text_japan1_90pv_rksj_codepoint_sequence_table
  } else {
    @cmapdata.pdf_text_japan1_90ms_rksj_codepoint_sequence_table
  }
}

///|
fn pdf_text_predefined_japan1_direct_charcode_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90ms_rksj_charcode_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90pv_rksj_charcode_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_japan1_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  guard pdf_text_predefined_cmap_has_text_orientation(text) else { return None }
  if text == "/H" {
    Some(@cmapdata.pdf_text_japan1_h_cid_ranges)
  } else if text == "/V" {
    Some(@cmapdata.pdf_text_japan1_v_cid_ranges)
  } else if text == "/78-H" {
    Some(@cmapdata.pdf_text_japan1_78_h_cid_ranges)
  } else if text == "/78-V" {
    Some(@cmapdata.pdf_text_japan1_78_v_cid_ranges)
  } else if text == "/78-EUC-H" {
    Some(@cmapdata.pdf_text_japan1_78_euc_h_cid_ranges)
  } else if text == "/78-EUC-V" {
    Some(@cmapdata.pdf_text_japan1_78_euc_v_cid_ranges)
  } else if text == "/78-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_78_rksj_h_cid_ranges)
  } else if text == "/78-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_78_rksj_v_cid_ranges)
  } else if text == "/78ms-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_78ms_rksj_h_cid_ranges)
  } else if text == "/78ms-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_78ms_rksj_v_cid_ranges)
  } else if text == "/83pv-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_83pv_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90ms_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_90ms_rksj_v_cid_ranges)
  } else if text == "/90msp-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90msp_rksj_h_cid_ranges)
  } else if text == "/90msp-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_90msp_rksj_v_cid_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_90pv_rksj_h_cid_ranges)
  } else if text == "/90pv-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_90pv_rksj_v_cid_ranges)
  } else if text == "/Add-H" {
    Some(@cmapdata.pdf_text_japan1_add_h_cid_ranges)
  } else if text == "/Add-V" {
    Some(@cmapdata.pdf_text_japan1_add_v_cid_ranges)
  } else if text == "/Add-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_add_rksj_h_cid_ranges)
  } else if text == "/Add-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_add_rksj_v_cid_ranges)
  } else if text == "/EUC-H" {
    Some(@cmapdata.pdf_text_japan1_euc_h_cid_ranges)
  } else if text == "/EUC-V" {
    Some(@cmapdata.pdf_text_japan1_euc_v_cid_ranges)
  } else if text == "/Ext-H" {
    Some(@cmapdata.pdf_text_japan1_ext_h_cid_ranges)
  } else if text == "/Ext-V" {
    Some(@cmapdata.pdf_text_japan1_ext_v_cid_ranges)
  } else if text == "/Ext-RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_ext_rksj_h_cid_ranges)
  } else if text == "/Ext-RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_ext_rksj_v_cid_ranges)
  } else if text == "/Hojo-H" {
    Some(@cmapdata.pdf_text_japan1_hojo_h_cid_ranges)
  } else if text == "/Hojo-V" {
    Some(@cmapdata.pdf_text_japan1_hojo_v_cid_ranges)
  } else if text == "/Hojo-EUC-H" {
    Some(@cmapdata.pdf_text_japan1_hojo_euc_h_cid_ranges)
  } else if text == "/Hojo-EUC-V" {
    Some(@cmapdata.pdf_text_japan1_hojo_euc_v_cid_ranges)
  } else if text == "/NWP-H" {
    Some(@cmapdata.pdf_text_japan1_nwp_h_cid_ranges)
  } else if text == "/NWP-V" {
    Some(@cmapdata.pdf_text_japan1_nwp_v_cid_ranges)
  } else if text == "/RKSJ-H" {
    Some(@cmapdata.pdf_text_japan1_rksj_h_cid_ranges)
  } else if text == "/RKSJ-V" {
    Some(@cmapdata.pdf_text_japan1_rksj_v_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_japan1_codepoints_of_cid(cid : Int) -> Array[Int]? {
  match
    pdf_text_predefined_cid_range_lookup(
      @cmapdata.pdf_text_japan1_codepoint_ranges, cid,
    ) {
    Some(codepoint) => Some([codepoint])
    None =>
      pdf_text_predefined_pair_codepoints_table_lookup(
        @cmapdata.pdf_text_japan1_codepoint_sequence_table, cid,
      )
  }
}

///|
fn pdf_text_predefined_japan1_codepoints(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Array[Int]? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_japan1_codepoints_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_japan1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found = pdf_text_predefined_codepoint_range_charcode(
    @cmapdata.pdf_text_japan1_codepoint_ranges, ranges, codepoint,
  )
  found = pdf_text_lower_optional_packed_charcode(
    found,
    pdf_text_predefined_sequence_table_charcode(
      @cmapdata.pdf_text_japan1_codepoint_sequence_table, ranges, codepoint,
    ),
  )
  found
}

///|
fn pdf_text_predefined_japan1_builtin_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  match pdf_text_predefined_japan1_direct_codepoint_ranges(name) {
    Some(ranges) =>
      match pdf_text_predefined_cid_range_lookup(ranges, code) {
        Some(codepoint) => Some([codepoint])
        None =>
          pdf_text_predefined_pair_codepoints_table_lookup(
            pdf_text_predefined_japan1_direct_codepoint_sequence_table(name),
            code,
          )
      }
    None =>
      match pdf_text_predefined_japan1_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_japan1_codepoints(ranges, code)
        None => None
      }
  }
}

///|
fn pdf_text_predefined_japan1_builtin_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  match pdf_text_predefined_japan1_direct_charcode_ranges(name) {
    Some(ranges) => pdf_text_predefined_cid_range_lookup(ranges, codepoint)
    None =>
      match pdf_text_predefined_japan1_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_japan1_charcode(ranges, codepoint)
        None => None
      }
  }
}
