///|
fn pdf_text_predefined_gb1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("GBK2K") {
    Some(@cmapdata.pdf_text_gbk2k_vertical_codepoint_table)
  } else if text.contains("GBpc-EUC") {
    Some(@cmapdata.pdf_text_gbpc_euc_vertical_codepoint_table)
  } else if text.contains("GBK-EUC") {
    Some(@cmapdata.pdf_text_gbk_vertical_codepoint_table)
  } else if text.contains("GBKp-EUC") {
    Some(@cmapdata.pdf_text_gbkp_vertical_codepoint_table)
  } else if text.contains("GB-EUC") {
    Some(@cmapdata.pdf_text_gb_euc_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_gb1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("GBK2K") {
    Some(@cmapdata.pdf_text_gbk2k_vertical_charcode_table)
  } else if text.contains("GBpc-EUC") {
    Some(@cmapdata.pdf_text_gbpc_euc_vertical_charcode_table)
  } else if text.contains("GBK-EUC") {
    Some(@cmapdata.pdf_text_gbk_vertical_charcode_table)
  } else if text.contains("GBKp-EUC") {
    Some(@cmapdata.pdf_text_gbkp_vertical_charcode_table)
  } else if text.contains("GB-EUC") {
    Some(@cmapdata.pdf_text_gb_euc_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cns1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("ETenms-B5") {
    Some(@cmapdata.pdf_text_etenms_b5_vertical_codepoint_table)
  } else if text.contains("HKscs-B5") {
    Some(@cmapdata.pdf_text_hkscs_vertical_codepoint_table)
  } else if text.contains("HKdla-B5") {
    Some(@cmapdata.pdf_text_hkdla_b5_vertical_codepoint_table)
  } else if text.contains("HKdlb-B5") {
    Some(@cmapdata.pdf_text_hkdlb_b5_vertical_codepoint_table)
  } else if text.contains("HKgccs-B5") {
    Some(@cmapdata.pdf_text_hkgccs_b5_vertical_codepoint_table)
  } else if text.contains("HKm314-B5") {
    Some(@cmapdata.pdf_text_hkm314_b5_vertical_codepoint_table)
  } else if text.contains("HKm471-B5") {
    Some(@cmapdata.pdf_text_hkm471_b5_vertical_codepoint_table)
  } else if text.contains("B5pc") {
    Some(@cmapdata.pdf_text_b5pc_vertical_codepoint_table)
  } else if text.contains("ETen-B5") {
    Some(@cmapdata.pdf_text_eten_b5_vertical_codepoint_table)
  } else if text.contains("B5") {
    Some(@cmapdata.pdf_text_big5_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cns1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("ETenms-B5") {
    Some(@cmapdata.pdf_text_etenms_b5_vertical_charcode_table)
  } else if text.contains("HKscs-B5") {
    Some(@cmapdata.pdf_text_hkscs_vertical_charcode_table)
  } else if text.contains("HKdla-B5") {
    Some(@cmapdata.pdf_text_hkdla_b5_vertical_charcode_table)
  } else if text.contains("HKdlb-B5") {
    Some(@cmapdata.pdf_text_hkdlb_b5_vertical_charcode_table)
  } else if text.contains("HKgccs-B5") {
    Some(@cmapdata.pdf_text_hkgccs_b5_vertical_charcode_table)
  } else if text.contains("HKm314-B5") {
    Some(@cmapdata.pdf_text_hkm314_b5_vertical_charcode_table)
  } else if text.contains("HKm471-B5") {
    Some(@cmapdata.pdf_text_hkm471_b5_vertical_charcode_table)
  } else if text.contains("B5pc") {
    Some(@cmapdata.pdf_text_b5pc_vertical_charcode_table)
  } else if text.contains("ETen-B5") {
    Some(@cmapdata.pdf_text_eten_b5_vertical_charcode_table)
  } else if text.contains("B5") {
    Some(@cmapdata.pdf_text_big5_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_korea1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("UHC") {
    Some(@cmapdata.pdf_text_uhc_vertical_codepoint_table)
  } else if text.contains("KSCpc-EUC") {
    Some(@cmapdata.pdf_text_kscpc_euc_vertical_codepoint_table)
  } else if text.contains("KSC-EUC") {
    Some(@cmapdata.pdf_text_ksc_euc_vertical_codepoint_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_korea1_vertical_charcode_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("UHC") {
    Some(@cmapdata.pdf_text_uhc_vertical_charcode_table)
  } else if text.contains("KSCpc-EUC") {
    Some(@cmapdata.pdf_text_kscpc_euc_vertical_charcode_table)
  } else if text.contains("KSC-EUC") {
    Some(@cmapdata.pdf_text_ksc_euc_vertical_charcode_table)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_vertical_codepoint(
  table : Array[(Int, Int)]?,
  code : Int,
) -> Int? {
  match table {
    Some(table) => pdf_text_predefined_pair_table_lookup(table, code)
    None => None
  }
}

///|
fn pdf_text_predefined_vertical_charcode(
  table : Array[(Int, Int)]?,
  codepoint : Int,
) -> Int? {
  match table {
    Some(table) => pdf_text_predefined_pair_table_lookup(table, codepoint)
    None => None
  }
}
