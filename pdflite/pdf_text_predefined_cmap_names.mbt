///|
fn pdf_text_predefined_cmap_uses_two_byte_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  (
    (text.contains("-UCS2-") || text.contains("-UTF16-")) &&
    (text.has_suffix("-H") || text.has_suffix("-V"))
  ) ||
  pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(name)
}

///|
fn pdf_text_predefined_cmap_has_text_orientation(text : String) -> Bool {
  text == "/H" || text == "/V" || text.has_suffix("-H") || text.has_suffix("-V")
}

///|
fn pdf_text_predefined_cmap_is_vertical(name : @core.PdfName) -> Bool {
  pdf_text_string_of_name(name).has_suffix("-V")
}

///|
fn pdf_text_predefined_cmap_uses_shift_jis_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("RKSJ")
}

///|
fn pdf_text_predefined_cmap_uses_hojo_euc_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("Hojo-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  pdf_text_predefined_japan1_cid_ranges(name) is Some(_) &&
  !text.contains("RKSJ") &&
  !text.contains("EUC")
}

///|
fn pdf_text_predefined_cmap_uses_ucs2_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("-UCS2-")
}

///|
fn pdf_text_predefined_cmap_uses_utf8_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("-UTF8-")
}

///|
fn pdf_text_predefined_cmap_uses_utf16_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("-UTF16-")
}

///|
fn pdf_text_predefined_cmap_uses_utf32_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (text.contains("-UTF32-") || text.contains("-UCS32-"))
}

///|
fn pdf_text_predefined_cmap_uses_gb_euc_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GB-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("GBpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_hkscs_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("HKscs-B5")
}

///|
fn pdf_text_predefined_cmap_uses_cns_euc_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("CNS-EUC")
}

///|
fn pdf_text_predefined_cns_euc_cid_ranges(
  name : @core.PdfName,
) -> Array[(Int, Int, Int)]? {
  guard pdf_text_predefined_cmap_uses_cns_euc_charcodes(name) else {
    return None
  }
  if pdf_text_predefined_cmap_is_vertical(name) {
    Some(@cmapdata.pdf_text_cns_euc_v_cid_ranges)
  } else {
    Some(@cmapdata.pdf_text_cns_euc_h_cid_ranges)
  }
}

///|
fn pdf_text_predefined_cns1_b5_cid_ranges(
  name : @core.PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  guard pdf_text_predefined_cmap_has_text_orientation(text) else { return None }
  if text.contains("ETenms-B5") {
    Some(@cmapdata.pdf_text_etenms_b5_cid_ranges)
  } else if text.contains("HKdla-B5") {
    Some(@cmapdata.pdf_text_hkdla_b5_cid_ranges)
  } else if text.contains("HKdlb-B5") {
    Some(@cmapdata.pdf_text_hkdlb_b5_cid_ranges)
  } else if text.contains("HKgccs-B5") {
    Some(@cmapdata.pdf_text_hkgccs_b5_cid_ranges)
  } else if text.contains("HKm314-B5") {
    Some(@cmapdata.pdf_text_hkm314_b5_cid_ranges)
  } else if text.contains("HKm471-B5") {
    Some(@cmapdata.pdf_text_hkm471_b5_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cmap_uses_cns1_b5_charcodes(
  name : @core.PdfName,
) -> Bool {
  match pdf_text_predefined_cns1_b5_cid_ranges(name) {
    Some(_) => true
    None => false
  }
}

///|
fn pdf_text_predefined_cmap_uses_big5_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5")
}

///|
fn pdf_text_predefined_cmap_uses_b5pc_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5pc")
}

///|
fn pdf_text_predefined_cmap_uses_uhc_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("UHC")
}

///|
fn pdf_text_predefined_cmap_uses_ksc_euc_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSC-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSCpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbk2k_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GBK2K")
}

///|
fn pdf_text_predefined_cmap_uses_gbk_charcodes(name : @core.PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (text.contains("GBK-EUC") || text.contains("GBKp-EUC"))
}

///|
fn pdf_text_predefined_cmap_uses_mixed_byte_charcodes(
  name : @core.PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (
    text.contains("-EUC-") ||
    text.has_prefix("/EUC-") ||
    text.contains("Hojo-EUC") ||
    text.contains("RKSJ") ||
    text.contains("B5") ||
    text.contains("UHC") ||
    text.contains("GBK")
  )
}
