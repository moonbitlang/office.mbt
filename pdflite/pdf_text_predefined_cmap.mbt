///|
fn pdf_text_predefined_cmap_uses_two_byte_charcodes(name : PdfName) -> Bool {
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
fn pdf_text_predefined_cmap_is_vertical(name : PdfName) -> Bool {
  pdf_text_string_of_name(name).has_suffix("-V")
}

///|
fn pdf_text_predefined_cmap_uses_shift_jis_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("RKSJ")
}

///|
fn pdf_text_predefined_cmap_uses_hojo_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("Hojo-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_japan1_two_byte_charcodes(
  name : PdfName,
) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  pdf_text_predefined_japan1_cid_ranges(name) is Some(_) &&
  !text.contains("RKSJ") &&
  !text.contains("EUC")
}

///|
fn pdf_text_predefined_cmap_uses_ucs2_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("-UCS2-")
}

///|
fn pdf_text_predefined_cmap_uses_utf8_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("-UTF8-")
}

///|
fn pdf_text_predefined_cmap_uses_utf16_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("-UTF16-")
}

///|
fn pdf_text_predefined_cmap_uses_utf32_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (text.contains("-UTF32-") || text.contains("-UCS32-"))
}

///|
fn pdf_text_predefined_cmap_uses_gb_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GB-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbpc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("GBpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_hkscs_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("HKscs-B5")
}

///|
fn pdf_text_predefined_cmap_uses_cns_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("CNS-EUC")
}

///|
fn pdf_text_predefined_cns_euc_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  guard pdf_text_predefined_cmap_uses_cns_euc_charcodes(name) else {
    return None
  }
  if pdf_text_predefined_cmap_is_vertical(name) {
    Some(pdf_text_cns_euc_v_cid_ranges)
  } else {
    Some(pdf_text_cns_euc_h_cid_ranges)
  }
}

///|
fn pdf_text_predefined_cns1_b5_cid_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  guard pdf_text_predefined_cmap_has_text_orientation(text) else { return None }
  if text.contains("ETenms-B5") {
    Some(pdf_text_etenms_b5_cid_ranges)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_cid_ranges)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_cid_ranges)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_cid_ranges)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_cid_ranges)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_cmap_uses_cns1_b5_charcodes(name : PdfName) -> Bool {
  match pdf_text_predefined_cns1_b5_cid_ranges(name) {
    Some(_) => true
    None => false
  }
}

///|
fn pdf_text_predefined_cmap_uses_big5_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5")
}

///|
fn pdf_text_predefined_cmap_uses_b5pc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("B5pc")
}

///|
fn pdf_text_predefined_cmap_uses_uhc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("UHC")
}

///|
fn pdf_text_predefined_cmap_uses_ksc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSC-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_kscpc_euc_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  text.contains("KSCpc-EUC")
}

///|
fn pdf_text_predefined_cmap_uses_gbk2k_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) && text.contains("GBK2K")
}

///|
fn pdf_text_predefined_cmap_uses_gbk_charcodes(name : PdfName) -> Bool {
  let text = pdf_text_string_of_name(name)
  pdf_text_predefined_cmap_has_text_orientation(text) &&
  (text.contains("GBK-EUC") || text.contains("GBKp-EUC"))
}

///|
fn pdf_text_predefined_cmap_uses_mixed_byte_charcodes(name : PdfName) -> Bool {
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

///|
fn pdf_text_predefined_rksj_single_byte_codepoint(code : Int) -> Int? {
  if code >= 0x00 && code <= 0x7F {
    Some(code)
  } else if code >= 0xA1 && code <= 0xDF {
    Some(0xFF61 + code - 0xA1)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_rksj_single_byte_charcode(codepoint : Int) -> Int? {
  if codepoint >= 0x00 && codepoint <= 0x7F {
    Some(codepoint)
  } else if codepoint >= 0xFF61 && codepoint <= 0xFF9F {
    Some(0xA1 + codepoint - 0xFF61)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_pair_table_lookup(
  table : Array[(Int, Int)],
  key : Int,
) -> Int? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1)
    }
  }
  None
}

///|
fn pdf_text_predefined_pair_codepoints_table_lookup(
  table : Array[(Int, Array[Int])],
  key : Int,
) -> Array[Int]? {
  let mut low = 0
  let mut high = table.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = table[mid]
    if key < entry.0 {
      high = mid
    } else if key > entry.0 {
      low = mid + 1
    } else {
      return Some(entry.1.copy())
    }
  }
  None
}

///|
fn pdf_text_predefined_japan1_direct_codepoint_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_codepoint_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_codepoint_ranges)
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
    pdf_text_japan1_90pv_rksj_codepoint_sequence_table
  } else {
    pdf_text_japan1_90ms_rksj_codepoint_sequence_table
  }
}

///|
fn pdf_text_predefined_japan1_direct_charcode_ranges(
  name : PdfName,
) -> Array[(Int, Int, Int)]? {
  let text = pdf_text_string_of_name(name)
  if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_charcode_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_charcode_ranges)
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
    Some(pdf_text_japan1_h_cid_ranges)
  } else if text == "/V" {
    Some(pdf_text_japan1_v_cid_ranges)
  } else if text == "/78-H" {
    Some(pdf_text_japan1_78_h_cid_ranges)
  } else if text == "/78-V" {
    Some(pdf_text_japan1_78_v_cid_ranges)
  } else if text == "/78-EUC-H" {
    Some(pdf_text_japan1_78_euc_h_cid_ranges)
  } else if text == "/78-EUC-V" {
    Some(pdf_text_japan1_78_euc_v_cid_ranges)
  } else if text == "/78-RKSJ-H" {
    Some(pdf_text_japan1_78_rksj_h_cid_ranges)
  } else if text == "/78-RKSJ-V" {
    Some(pdf_text_japan1_78_rksj_v_cid_ranges)
  } else if text == "/78ms-RKSJ-H" {
    Some(pdf_text_japan1_78ms_rksj_h_cid_ranges)
  } else if text == "/78ms-RKSJ-V" {
    Some(pdf_text_japan1_78ms_rksj_v_cid_ranges)
  } else if text == "/83pv-RKSJ-H" {
    Some(pdf_text_japan1_83pv_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-H" {
    Some(pdf_text_japan1_90ms_rksj_h_cid_ranges)
  } else if text == "/90ms-RKSJ-V" {
    Some(pdf_text_japan1_90ms_rksj_v_cid_ranges)
  } else if text == "/90msp-RKSJ-H" {
    Some(pdf_text_japan1_90msp_rksj_h_cid_ranges)
  } else if text == "/90msp-RKSJ-V" {
    Some(pdf_text_japan1_90msp_rksj_v_cid_ranges)
  } else if text == "/90pv-RKSJ-H" {
    Some(pdf_text_japan1_90pv_rksj_h_cid_ranges)
  } else if text == "/90pv-RKSJ-V" {
    Some(pdf_text_japan1_90pv_rksj_v_cid_ranges)
  } else if text == "/Add-H" {
    Some(pdf_text_japan1_add_h_cid_ranges)
  } else if text == "/Add-V" {
    Some(pdf_text_japan1_add_v_cid_ranges)
  } else if text == "/Add-RKSJ-H" {
    Some(pdf_text_japan1_add_rksj_h_cid_ranges)
  } else if text == "/Add-RKSJ-V" {
    Some(pdf_text_japan1_add_rksj_v_cid_ranges)
  } else if text == "/EUC-H" {
    Some(pdf_text_japan1_euc_h_cid_ranges)
  } else if text == "/EUC-V" {
    Some(pdf_text_japan1_euc_v_cid_ranges)
  } else if text == "/Ext-H" {
    Some(pdf_text_japan1_ext_h_cid_ranges)
  } else if text == "/Ext-V" {
    Some(pdf_text_japan1_ext_v_cid_ranges)
  } else if text == "/Ext-RKSJ-H" {
    Some(pdf_text_japan1_ext_rksj_h_cid_ranges)
  } else if text == "/Ext-RKSJ-V" {
    Some(pdf_text_japan1_ext_rksj_v_cid_ranges)
  } else if text == "/Hojo-H" {
    Some(pdf_text_japan1_hojo_h_cid_ranges)
  } else if text == "/Hojo-V" {
    Some(pdf_text_japan1_hojo_v_cid_ranges)
  } else if text == "/Hojo-EUC-H" {
    Some(pdf_text_japan1_hojo_euc_h_cid_ranges)
  } else if text == "/Hojo-EUC-V" {
    Some(pdf_text_japan1_hojo_euc_v_cid_ranges)
  } else if text == "/NWP-H" {
    Some(pdf_text_japan1_nwp_h_cid_ranges)
  } else if text == "/NWP-V" {
    Some(pdf_text_japan1_nwp_v_cid_ranges)
  } else if text == "/RKSJ-H" {
    Some(pdf_text_japan1_rksj_h_cid_ranges)
  } else if text == "/RKSJ-V" {
    Some(pdf_text_japan1_rksj_v_cid_ranges)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_gb1_vertical_codepoint_table(
  name : PdfName,
) -> Array[(Int, Int)]? {
  guard pdf_text_predefined_cmap_is_vertical(name) else { return None }
  let text = pdf_text_string_of_name(name)
  if text.contains("GBK2K") {
    Some(pdf_text_gbk2k_vertical_codepoint_table)
  } else if text.contains("GBpc-EUC") {
    Some(pdf_text_gbpc_euc_vertical_codepoint_table)
  } else if text.contains("GBK-EUC") {
    Some(pdf_text_gbk_vertical_codepoint_table)
  } else if text.contains("GBKp-EUC") {
    Some(pdf_text_gbkp_vertical_codepoint_table)
  } else if text.contains("GB-EUC") {
    Some(pdf_text_gb_euc_vertical_codepoint_table)
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
    Some(pdf_text_gbk2k_vertical_charcode_table)
  } else if text.contains("GBpc-EUC") {
    Some(pdf_text_gbpc_euc_vertical_charcode_table)
  } else if text.contains("GBK-EUC") {
    Some(pdf_text_gbk_vertical_charcode_table)
  } else if text.contains("GBKp-EUC") {
    Some(pdf_text_gbkp_vertical_charcode_table)
  } else if text.contains("GB-EUC") {
    Some(pdf_text_gb_euc_vertical_charcode_table)
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
    Some(pdf_text_etenms_b5_vertical_codepoint_table)
  } else if text.contains("HKscs-B5") {
    Some(pdf_text_hkscs_vertical_codepoint_table)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_vertical_codepoint_table)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_vertical_codepoint_table)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_vertical_codepoint_table)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_vertical_codepoint_table)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_vertical_codepoint_table)
  } else if text.contains("B5pc") {
    Some(pdf_text_b5pc_vertical_codepoint_table)
  } else if text.contains("ETen-B5") {
    Some(pdf_text_eten_b5_vertical_codepoint_table)
  } else if text.contains("B5") {
    Some(pdf_text_big5_vertical_codepoint_table)
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
    Some(pdf_text_etenms_b5_vertical_charcode_table)
  } else if text.contains("HKscs-B5") {
    Some(pdf_text_hkscs_vertical_charcode_table)
  } else if text.contains("HKdla-B5") {
    Some(pdf_text_hkdla_b5_vertical_charcode_table)
  } else if text.contains("HKdlb-B5") {
    Some(pdf_text_hkdlb_b5_vertical_charcode_table)
  } else if text.contains("HKgccs-B5") {
    Some(pdf_text_hkgccs_b5_vertical_charcode_table)
  } else if text.contains("HKm314-B5") {
    Some(pdf_text_hkm314_b5_vertical_charcode_table)
  } else if text.contains("HKm471-B5") {
    Some(pdf_text_hkm471_b5_vertical_charcode_table)
  } else if text.contains("B5pc") {
    Some(pdf_text_b5pc_vertical_charcode_table)
  } else if text.contains("ETen-B5") {
    Some(pdf_text_eten_b5_vertical_charcode_table)
  } else if text.contains("B5") {
    Some(pdf_text_big5_vertical_charcode_table)
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
    Some(pdf_text_uhc_vertical_codepoint_table)
  } else if text.contains("KSCpc-EUC") {
    Some(pdf_text_kscpc_euc_vertical_codepoint_table)
  } else if text.contains("KSC-EUC") {
    Some(pdf_text_ksc_euc_vertical_codepoint_table)
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
    Some(pdf_text_uhc_vertical_charcode_table)
  } else if text.contains("KSCpc-EUC") {
    Some(pdf_text_kscpc_euc_vertical_charcode_table)
  } else if text.contains("KSC-EUC") {
    Some(pdf_text_ksc_euc_vertical_charcode_table)
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

///|
fn pdf_text_predefined_cid_range_lookup(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = ranges[mid]
    if code < entry.0 {
      high = mid
    } else if code > entry.1 {
      low = mid + 1
    } else {
      return Some(entry.2 + code - entry.0)
    }
  }
  None
}

///|
fn pdf_text_predefined_cid_range_lookup_unsigned(
  ranges : ArrayView[(Int, Int, Int)],
  code : Int,
) -> Int? {
  let target = code.reinterpret_as_uint()
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let entry = ranges[mid]
    if target < entry.0.reinterpret_as_uint() {
      high = mid
    } else if target > entry.1.reinterpret_as_uint() {
      low = mid + 1
    } else {
      return Some(entry.2 + code - entry.0)
    }
  }
  None
}

///|
fn pdf_text_lower_packed_charcode(current : Int?, candidate : Int) -> Int? {
  match current {
    Some(value) =>
      if candidate.reinterpret_as_uint() < value.reinterpret_as_uint() {
        Some(candidate)
      } else {
        current
      }
    None => Some(candidate)
  }
}

///|
fn pdf_text_lower_optional_packed_charcode(
  current : Int?,
  candidate : Int?,
) -> Int? {
  match candidate {
    Some(code) => pdf_text_lower_packed_charcode(current, code)
    None => current
  }
}

///|
fn pdf_text_predefined_cid_range_charcode_of_cid(
  ranges : ArrayView[(Int, Int, Int)],
  cid : Int,
) -> Int? {
  let mut found : Int? = None
  for range in ranges {
    let first_cid = range.2
    let last_cid = range.2 + range.1 - range.0
    if cid >= first_cid && cid <= last_cid {
      found = pdf_text_lower_packed_charcode(found, range.0 + cid - first_cid)
    }
  }
  found
}

///|
fn pdf_text_predefined_unicode_table_charcode(
  unicode_table : ArrayView[Int],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  guard codepoint != 0 else { return None }
  let mut found : Int? = None
  for cid, candidate in unicode_table {
    if candidate == codepoint {
      match
        pdf_text_predefined_cid_range_charcode_of_cid(charcode_ranges, cid) {
        Some(code) => found = pdf_text_lower_packed_charcode(found, code)
        None => ()
      }
    }
  }
  found
}

///|
fn pdf_text_predefined_codepoint_range_charcode(
  codepoint_ranges : ArrayView[(Int, Int, Int)],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found : Int? = None
  for range in codepoint_ranges {
    let first_codepoint = range.2
    let last_codepoint = range.2 + range.1 - range.0
    if codepoint >= first_codepoint && codepoint <= last_codepoint {
      let cid = range.0 + codepoint - first_codepoint
      match
        pdf_text_predefined_cid_range_charcode_of_cid(charcode_ranges, cid) {
        Some(code) => found = pdf_text_lower_packed_charcode(found, code)
        None => ()
      }
    }
  }
  found
}

///|
fn pdf_text_predefined_sequence_table_charcode(
  sequence_table : ArrayView[(Int, Array[Int])],
  charcode_ranges : ArrayView[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  let mut found : Int? = None
  for entry in sequence_table {
    match entry.1 {
      [candidate] if candidate == codepoint =>
        match
          pdf_text_predefined_cid_range_charcode_of_cid(
            charcode_ranges,
            entry.0,
          ) {
          Some(code) => found = pdf_text_lower_packed_charcode(found, code)
          None => ()
        }
      _ => ()
    }
  }
  found
}

///|
fn pdf_text_japan1_codepoints_of_cid(cid : Int) -> Array[Int]? {
  match
    pdf_text_predefined_cid_range_lookup(pdf_text_japan1_codepoint_ranges, cid) {
    Some(codepoint) => Some([codepoint])
    None =>
      pdf_text_predefined_pair_codepoints_table_lookup(
        pdf_text_japan1_codepoint_sequence_table, cid,
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
    pdf_text_japan1_codepoint_ranges, ranges, codepoint,
  )
  found = pdf_text_lower_optional_packed_charcode(
    found,
    pdf_text_predefined_sequence_table_charcode(
      pdf_text_japan1_codepoint_sequence_table, ranges, codepoint,
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

///|
fn pdf_text_cns1_codepoint_of_cid(cid : Int) -> Int? {
  guard cid >= 0 && cid < pdf_text_cns1_unicode_table.length() else {
    return None
  }
  let codepoint = pdf_text_cns1_unicode_table[cid]
  if codepoint == 0 {
    None
  } else {
    Some(codepoint)
  }
}

///|
fn pdf_text_gb1_codepoint_of_cid(cid : Int) -> Int? {
  guard cid >= 0 && cid < pdf_text_gb1_unicode_table.length() else {
    return None
  }
  let codepoint = pdf_text_gb1_unicode_table[cid]
  if codepoint == 0 {
    None
  } else {
    Some(codepoint)
  }
}

///|
fn pdf_text_predefined_cns1_codepoint(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  match pdf_text_predefined_cid_range_lookup(ranges, code) {
    Some(cid) => pdf_text_cns1_codepoint_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_cns1_codepoint_unsigned(
  ranges : Array[(Int, Int, Int)],
  code : Int,
) -> Int? {
  match pdf_text_predefined_cid_range_lookup_unsigned(ranges, code) {
    Some(cid) => pdf_text_cns1_codepoint_of_cid(cid)
    None => None
  }
}

///|
fn pdf_text_predefined_cns1_charcode(
  ranges : Array[(Int, Int, Int)],
  codepoint : Int,
) -> Int? {
  pdf_text_predefined_unicode_table_charcode(
    pdf_text_cns1_unicode_table, ranges, codepoint,
  )
}

///|
fn pdf_text_predefined_cns1_builtin_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  match
    pdf_text_predefined_vertical_codepoint(
      pdf_text_predefined_cns1_vertical_codepoint_table(name),
      code,
    ) {
    Some(codepoint) => Some([codepoint])
    None =>
      match pdf_text_predefined_cns1_b5_cid_ranges(name) {
        Some(ranges) =>
          match pdf_text_predefined_cns1_codepoint(ranges, code) {
            Some(codepoint) => Some([codepoint])
            None => None
          }
        None =>
          if pdf_text_predefined_cmap_uses_hkscs_charcodes(name) {
            match pdf_text_predefined_hkscs_codepoint(code) {
              Some(codepoint) => Some([codepoint])
              None => None
            }
          } else {
            match pdf_text_predefined_cns_euc_cid_ranges(name) {
              Some(ranges) =>
                match
                  pdf_text_predefined_cns1_codepoint_unsigned(ranges, code) {
                  Some(codepoint) => Some([codepoint])
                  None => None
                }
              None =>
                if pdf_text_predefined_cmap_uses_b5pc_charcodes(name) {
                  match pdf_text_predefined_b5pc_codepoint(code) {
                    Some(codepoint) => Some([codepoint])
                    None => None
                  }
                } else if pdf_text_predefined_cmap_uses_big5_charcodes(name) {
                  match pdf_text_predefined_big5_codepoint(code) {
                    Some(codepoint) => Some([codepoint])
                    None => None
                  }
                } else {
                  None
                }
            }
          }
      }
  }
}

///|
fn pdf_text_predefined_cns1_builtin_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  match
    pdf_text_predefined_vertical_charcode(
      pdf_text_predefined_cns1_vertical_charcode_table(name),
      codepoint,
    ) {
    Some(code) => Some(code)
    None =>
      match pdf_text_predefined_cns1_b5_cid_ranges(name) {
        Some(ranges) => pdf_text_predefined_cns1_charcode(ranges, codepoint)
        None =>
          if pdf_text_predefined_cmap_uses_hkscs_charcodes(name) {
            pdf_text_predefined_hkscs_charcode(codepoint)
          } else {
            match pdf_text_predefined_cns_euc_cid_ranges(name) {
              Some(ranges) =>
                pdf_text_predefined_cns1_charcode(ranges, codepoint)
              None =>
                if pdf_text_predefined_cmap_uses_b5pc_charcodes(name) {
                  pdf_text_predefined_b5pc_charcode(codepoint)
                } else if pdf_text_predefined_cmap_uses_big5_charcodes(name) {
                  pdf_text_predefined_big5_charcode(codepoint)
                } else {
                  None
                }
            }
          }
      }
  }
}

///|
fn pdf_text_valid_unicode_codepoint(codepoint : Int) -> Bool {
  codepoint >= 0 &&
  codepoint <= 0x10FFFF &&
  !(codepoint >= 0xD800 && codepoint <= 0xDFFF)
}

///|
fn pdf_text_packed_charcode_length(code : Int) -> Int {
  if code >= 0 && code <= 0xFF {
    1
  } else if code >= 0 && code <= 0xFFFF {
    2
  } else if code >= 0 && code <= 0xFFFFFF {
    3
  } else {
    4
  }
}

///|
fn pdf_text_packed_charcode_bytes(code : Int, length : Int) -> Bytes {
  Bytes::makei(length, fn(index) {
    ((code >> ((length - index - 1) * 8)) & 0xFF).to_byte()
  })
}

///|
fn pdf_text_pack_two_bytes(first : Int, second : Int) -> Int {
  (first << 8) | second
}

///|
fn pdf_text_pack_four_bytes(
  first : Int,
  second : Int,
  third : Int,
  fourth : Int,
) -> Int {
  (((((first << 8) | second) << 8) | third) << 8) | fourth
}

///|
fn pdf_text_pack_bytes_as_charcode(bytes : BytesView) -> Int {
  let mut code = 0
  for byte in bytes {
    code = (code << 8) | byte.to_int()
  }
  code
}

///|
fn pdf_text_predefined_utf8_codepoints(code : Int) -> Array[Int]? {
  let bytes = pdf_text_packed_charcode_bytes(
    code,
    pdf_text_packed_charcode_length(code),
  )
  try pdf_codepoints_of_utf8(bytes) catch {
    _ => None
  } noraise {
    codepoints => Some(codepoints)
  }
}

///|
fn pdf_text_predefined_utf8_charcode(codepoint : Int) -> Int? {
  guard pdf_text_valid_unicode_codepoint(codepoint) else { return None }
  if codepoint <= 0x7F {
    Some(codepoint)
  } else if codepoint <= 0x7FF {
    Some(
      pdf_text_pack_two_bytes(
        0xC0 | (codepoint >> 6),
        0x80 | (codepoint & 0x3F),
      ),
    )
  } else if codepoint <= 0xFFFF {
    Some(
      pdf_text_pack_bytes_as_charcode(
        Bytes::makei(3, fn(index) {
          match index {
            0 => (0xE0 | (codepoint >> 12)).to_byte()
            1 => (0x80 | ((codepoint >> 6) & 0x3F)).to_byte()
            _ => (0x80 | (codepoint & 0x3F)).to_byte()
          }
        }),
      ),
    )
  } else {
    Some(
      pdf_text_pack_four_bytes(
        0xF0 | (codepoint >> 18),
        0x80 | ((codepoint >> 12) & 0x3F),
        0x80 | ((codepoint >> 6) & 0x3F),
        0x80 | (codepoint & 0x3F),
      ),
    )
  }
}

///|
fn pdf_text_predefined_utf16_codepoints(code : Int) -> Array[Int]? {
  if code >= 0 && code <= 0xFFFF {
    if pdf_text_valid_unicode_codepoint(code) {
      Some([code])
    } else {
      None
    }
  } else if pdf_text_packed_charcode_length(code) == 4 {
    let bytes = pdf_text_packed_charcode_bytes(code, 4)
    try pdf_codepoints_of_utf16be(bytes) catch {
      _ => None
    } noraise {
      codepoints => Some(codepoints)
    }
  } else {
    None
  }
}

///|
fn pdf_text_predefined_utf16_charcode(codepoint : Int) -> Int? {
  guard pdf_text_valid_unicode_codepoint(codepoint) else { return None }
  if codepoint <= 0xFFFF {
    Some(codepoint)
  } else {
    let shifted = codepoint - 0x10000
    let high = 0xD800 | (shifted >> 10)
    let low = 0xDC00 | (shifted & 0x3FF)
    Some(pdf_text_pack_four_bytes(high >> 8, high & 0xFF, low >> 8, low & 0xFF))
  }
}

///|
fn pdf_text_predefined_utf32_codepoints(code : Int) -> Array[Int]? {
  if pdf_text_valid_unicode_codepoint(code) {
    Some([code])
  } else {
    None
  }
}

///|
fn pdf_text_predefined_utf32_charcode(codepoint : Int) -> Int? {
  if pdf_text_valid_unicode_codepoint(codepoint) {
    Some(codepoint)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_direct_unicode_codepoints(
  name : PdfName,
  code : Int,
) -> Array[Int]? {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    pdf_text_predefined_utf8_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    pdf_text_predefined_utf16_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    pdf_text_predefined_utf32_codepoints(code)
  } else if pdf_text_predefined_cmap_uses_ucs2_charcodes(name) {
    pdf_text_predefined_utf32_codepoints(code)
  } else {
    None
  }
}

///|
fn pdf_text_predefined_direct_unicode_charcode(
  name : PdfName,
  codepoint : Int,
) -> Int? {
  if pdf_text_predefined_cmap_uses_utf8_charcodes(name) {
    pdf_text_predefined_utf8_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_utf16_charcodes(name) {
    pdf_text_predefined_utf16_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_utf32_charcodes(name) {
    pdf_text_predefined_utf32_charcode(codepoint)
  } else if pdf_text_predefined_cmap_uses_ucs2_charcodes(name) {
    if codepoint <= 0xFFFF && pdf_text_valid_unicode_codepoint(codepoint) {
      Some(codepoint)
    } else {
      None
    }
  } else {
    None
  }
}

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

///|
/// Return true when this CMap consumes text as fixed two-byte character codes.
///
/// Identity CMaps and common UCS2/UTF16 predefined maps are treated as
/// two-byte. Parsed external CMaps are two-byte only when all code spaces have
/// length 2, or when they inherit an identity base with no explicit spaces.
pub fn PdfCMapEncoding::uses_two_byte_codes(self : PdfCMapEncoding) -> Bool {
  match self {
    PdfPredefinedCMap(name) =>
      self.is_identity_h() ||
      self.is_identity_v() ||
      pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
    PdfExternalCMap(_, parsed) =>
      if parsed.codespaces.length() == 0 {
        match parsed.usecmap {
          Some(name) =>
            name == pdf_text_identity_h_name ||
            name == pdf_text_identity_v_name ||
            pdf_text_predefined_cmap_uses_two_byte_charcodes(name)
          None => false
        }
      } else {
        for codespace in parsed.codespaces {
          if codespace.length != 2 {
            break false
          }
        } nobreak {
          true
        }
      }
    _ => false
  }
}
