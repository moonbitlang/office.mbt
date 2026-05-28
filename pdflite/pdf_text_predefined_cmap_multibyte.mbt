///|
fn pdf_text_predefined_gb1_codepoint(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_gb1_codepoint_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_gb1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  pdf_text_predefined_unicode_table_charcode(
    pdf_text_gb1_unicode_table, ranges, codepoint,
  )
}

///|
fn pdf_text_predefined_gbk2k_codepoint(code : Int) -> Int? {
  pdf_text_predefined_gb1_codepoint(pdf_text_gbk2k_cid_ranges, code)
}

///|
fn pdf_text_predefined_gbk2k_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_gb1_charcode(pdf_text_gbk2k_cid_ranges, codepoint)
}

///|
fn pdf_text_predefined_gb_euc_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_gb_euc_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_gb_euc_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_gb_euc_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_gbpc_euc_codepoints(code : Int) -> Array[Int]? {
  pdf_text_predefined_pair_codepoints_table_lookup(
    pdf_text_gbpc_euc_codepoints_table, code,
  )
}

///|
fn pdf_text_predefined_gbpc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_gbpc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_big5_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_big5_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_big5_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_big5_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_b5pc_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_b5pc_codepoint_table, code)
}

///|
fn pdf_text_predefined_b5pc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_b5pc_charcode_table, codepoint)
}

///|
fn pdf_text_predefined_hkscs_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_hkscs_codepoint_table, code)
}

///|
fn pdf_text_predefined_hkscs_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_hkscs_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_uhc_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_uhc_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_uhc_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_uhc_charcode_table, codepoint,
    )
  }
}

///|
fn pdf_text_predefined_ksc_euc_codepoint(code : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(pdf_text_ksc_euc_codepoint_table, code)
}

///|
fn pdf_text_predefined_ksc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_ksc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_kscpc_euc_codepoints(code : Int) -> Array[Int]? {
  pdf_text_predefined_pair_codepoints_table_lookup(
    pdf_text_kscpc_euc_codepoints_table, code,
  )
}

///|
fn pdf_text_predefined_kscpc_euc_charcode(codepoint : Int) -> Int? {
  pdf_text_predefined_pair_table_lookup(
    pdf_text_kscpc_euc_charcode_table, codepoint,
  )
}

///|
fn pdf_text_predefined_gbk_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x80 {
    Some(code)
  } else if code == 0xFF {
    Some(0xF8F5)
  } else {
    pdf_text_predefined_pair_table_lookup(pdf_text_gbk_codepoint_table, code)
  }
}

///|
fn pdf_text_predefined_gbk_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x80 {
    Some(codepoint)
  } else if codepoint == 0xF8F5 {
    Some(0xFF)
  } else {
    pdf_text_predefined_pair_table_lookup(
      pdf_text_gbk_charcode_table, codepoint,
    )
  }
}
