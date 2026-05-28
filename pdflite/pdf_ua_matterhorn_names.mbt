///|
let pdf_ua_matterhorn_artifact_name : PdfName = pdf_ua_name("/Artifact")

///|
fn pdf_ua_matterhorn_artifact() -> PdfName {
  pdf_ua_matterhorn_artifact_name
}

///|
let pdf_ua_matterhorn_span_name : PdfName = pdf_ua_name("/Span")

///|
fn pdf_ua_matterhorn_span() -> PdfName {
  pdf_ua_matterhorn_span_name
}

///|
let pdf_ua_matterhorn_annot_name : PdfName = pdf_ua_name("/Annot")

///|
fn pdf_ua_matterhorn_annot() -> PdfName {
  pdf_ua_matterhorn_annot_name
}

///|
let pdf_ua_matterhorn_form_name : PdfName = pdf_ua_name("/Form")

///|
fn pdf_ua_matterhorn_form() -> PdfName {
  pdf_ua_matterhorn_form_name
}

///|
let pdf_ua_matterhorn_type0_name : PdfName = pdf_ua_name("/Type0")

///|
fn pdf_ua_matterhorn_type0() -> PdfName {
  pdf_ua_matterhorn_type0_name
}

///|
let pdf_ua_matterhorn_cid_font_type2_name : PdfName = pdf_ua_name(
  "/CIDFontType2",
)

///|
fn pdf_ua_matterhorn_cid_font_type2() -> PdfName {
  pdf_ua_matterhorn_cid_font_type2_name
}

///|
let pdf_ua_matterhorn_cid_font_type0_name : PdfName = pdf_ua_name(
  "/CIDFontType0",
)

///|
fn pdf_ua_matterhorn_cid_font_type0() -> PdfName {
  pdf_ua_matterhorn_cid_font_type0_name
}

///|
let pdf_ua_matterhorn_identity_name : PdfName = pdf_ua_name("/Identity")

///|
fn pdf_ua_matterhorn_identity() -> PdfName {
  pdf_ua_matterhorn_identity_name
}

///|
let pdf_ua_matterhorn_identity_h_name : PdfName = pdf_ua_name("/Identity-H")

///|
fn pdf_ua_matterhorn_identity_h() -> PdfName {
  pdf_ua_matterhorn_identity_h_name
}

///|
let pdf_ua_matterhorn_identity_v_name : PdfName = pdf_ua_name("/Identity-V")

///|
fn pdf_ua_matterhorn_identity_v() -> PdfName {
  pdf_ua_matterhorn_identity_v_name
}

///|
let pdf_ua_matterhorn_tabs_key_name : PdfName = pdf_ua_name("/Tabs")

///|
fn pdf_ua_matterhorn_tabs_key() -> PdfName {
  pdf_ua_matterhorn_tabs_key_name
}

///|
let pdf_ua_matterhorn_adobe_name : PdfName = pdf_ua_name("/Adobe")

///|
fn pdf_ua_matterhorn_adobe() -> PdfName {
  pdf_ua_matterhorn_adobe_name
}

///|
let pdf_ua_matterhorn_gb1_name : PdfName = pdf_ua_name("/GB1")

///|
let pdf_ua_matterhorn_cns1_name : PdfName = pdf_ua_name("/CNS1")

///|
let pdf_ua_matterhorn_japan1_name : PdfName = pdf_ua_name("/Japan1")

///|
let pdf_ua_matterhorn_korea1_name : PdfName = pdf_ua_name("/Korea1")

///|
let pdf_ua_matterhorn_cmap_names : Array[PdfName] = [
  pdf_ua_name("/GB-EUC-H"),
  pdf_ua_name("/GB-EUC-V"),
  pdf_ua_name("/GBpc-EUC-H"),
  pdf_ua_name("/GBpc-EUC-V"),
  pdf_ua_name("/GBK-EUC-H"),
  pdf_ua_name("/GBK-EUC-V"),
  pdf_ua_name("/GBKp-EUC-H"),
  pdf_ua_name("/GBKp-EUC-V"),
  pdf_ua_name("/GBK2K-H"),
  pdf_ua_name("/GBK2K-V"),
  pdf_ua_name("/UniGB-UCS32-H"),
  pdf_ua_name("/UniGB-UCS32-V"),
  pdf_ua_name("/UniGB-UTF16-H"),
  pdf_ua_name("/UniGB-UTF16-V"),
  pdf_ua_name("/B5pc-H"),
  pdf_ua_name("/B5pc-V"),
  pdf_ua_name("/HKscs-B5-H"),
  pdf_ua_name("/HKscs-B5-V"),
  pdf_ua_name("/ETen-B5-H"),
  pdf_ua_name("/ETen-B5-V"),
  pdf_ua_name("/ETenms-B5-H"),
  pdf_ua_name("/ETenms-B5-V"),
  pdf_ua_name("/CNS-EUC-H"),
  pdf_ua_name("/CNS-EUC-V"),
  pdf_ua_name("/UniCNS-UCS2-H"),
  pdf_ua_name("/UniCNS-UCS2-V"),
  pdf_ua_name("/UniCNS-UTF16-H"),
  pdf_ua_name("/UniCNS-UTF16-V"),
  pdf_ua_name("/83pv-RKSJ-H"),
  pdf_ua_name("/90ms-RKSJ-H"),
  pdf_ua_name("/90ms-RKSJ-V"),
  pdf_ua_name("/90msp-RKSJ-H"),
  pdf_ua_name("/90msp-RKSJ-V"),
  pdf_ua_name("/90pv-RKSJ-H"),
  pdf_ua_name("/Add-RKSJ-H"),
  pdf_ua_name("/Add-RKSJ-V"),
  pdf_ua_name("/EUC-H"),
  pdf_ua_name("/EUC-V"),
  pdf_ua_name("/Ext-RKSJ-H"),
  pdf_ua_name("/Ext-RKSJ-V"),
  pdf_ua_name("/H"),
  pdf_ua_name("/V"),
  pdf_ua_name("/UniJIS-UCS2-H"),
  pdf_ua_name("/UniJIS-UCS2-V"),
  pdf_ua_name("/UniJIS-UCS2-HW-H"),
  pdf_ua_name("/UniJIS-UCS2-HW-V"),
  pdf_ua_name("/UniJIS-UTF16-H"),
  pdf_ua_name("/UniJIS-UTF16-V"),
  pdf_ua_name("/KSC-EUC-H"),
  pdf_ua_name("/KSC-EUC-V"),
  pdf_ua_name("/KSCms-UHC-H"),
  pdf_ua_name("/KSCms-UHC-V"),
  pdf_ua_name("/KSCms-UHC-HW-H"),
  // cpdf source spells the vertical half-width name this way in cmap_names.
  pdf_ua_name("/KSCms-UHS-HW-V"),
  pdf_ua_name("/KSCpc-EUC-H"),
  pdf_ua_name("/UniKS-UCS2-H"),
  pdf_ua_name("/UniKS-UCS2-V"),
  pdf_ua_name("/Identity-H"),
  pdf_ua_name("/Identity-V"),
]

///|
fn pdf_ua_matterhorn_cmap_name_is_listed(name : PdfName) -> Bool {
  pdf_ua_matterhorn_cmap_names.contains(name)
}

///|
let pdf_ua_matterhorn_resources_key_name : PdfName = pdf_ua_name("/Resources")

///|
fn pdf_ua_matterhorn_resources_key() -> PdfName {
  pdf_ua_matterhorn_resources_key_name
}

///|
let pdf_ua_matterhorn_xobject_key_name : PdfName = pdf_ua_name("/XObject")

///|
fn pdf_ua_matterhorn_xobject_key() -> PdfName {
  pdf_ua_matterhorn_xobject_key_name
}

///|
let pdf_ua_matterhorn_ap_key_name : PdfName = pdf_ua_name("/AP")

///|
fn pdf_ua_matterhorn_ap_key() -> PdfName {
  pdf_ua_matterhorn_ap_key_name
}

///|
let pdf_ua_matterhorn_n_key_name : PdfName = pdf_ua_name("/N")

///|
fn pdf_ua_matterhorn_n_key() -> PdfName {
  pdf_ua_matterhorn_n_key_name
}

///|
let pdf_ua_matterhorn_mcid_key_name : PdfName = pdf_ua_name("/MCID")

///|
fn pdf_ua_matterhorn_mcid_key() -> PdfName {
  pdf_ua_matterhorn_mcid_key_name
}

///|
let pdf_ua_matterhorn_suspects_key_name : PdfName = pdf_ua_name("/Suspects")

///|
fn pdf_ua_matterhorn_suspects_key() -> PdfName {
  pdf_ua_matterhorn_suspects_key_name
}

///|
let pdf_ua_matterhorn_ref_key_name : PdfName = pdf_ua_name("/Ref")

///|
fn pdf_ua_matterhorn_ref_key() -> PdfName {
  pdf_ua_matterhorn_ref_key_name
}

///|
let pdf_ua_matterhorn_ct_key_name : PdfName = pdf_ua_name("/CT")

///|
fn pdf_ua_matterhorn_ct_key() -> PdfName {
  pdf_ua_matterhorn_ct_key_name
}

///|
let pdf_ua_matterhorn_alt_key_name : PdfName = pdf_ua_name("/Alt")

///|
fn pdf_ua_matterhorn_alt_key() -> PdfName {
  pdf_ua_matterhorn_alt_key_name
}

///|
let pdf_ua_matterhorn_actual_text_key_name : PdfName = pdf_ua_name(
  "/ActualText",
)

///|
fn pdf_ua_matterhorn_actual_text_key() -> PdfName {
  pdf_ua_matterhorn_actual_text_key_name
}

///|
let pdf_ua_matterhorn_id_key_name : PdfName = pdf_ua_name("/ID")

///|
fn pdf_ua_matterhorn_id_key() -> PdfName {
  pdf_ua_matterhorn_id_key_name
}

///|
let pdf_ua_matterhorn_a_key_name : PdfName = pdf_ua_name("/A")

///|
fn pdf_ua_matterhorn_a_key() -> PdfName {
  pdf_ua_matterhorn_a_key_name
}

///|
let pdf_ua_matterhorn_c_key_name : PdfName = pdf_ua_name("/C")

///|
fn pdf_ua_matterhorn_c_key() -> PdfName {
  pdf_ua_matterhorn_c_key_name
}

///|
let pdf_ua_matterhorn_scope_name : PdfName = pdf_ua_name("/Scope")

///|
fn pdf_ua_matterhorn_scope() -> PdfName {
  pdf_ua_matterhorn_scope_name
}

///|
let pdf_ua_matterhorn_encoding_key_name : PdfName = pdf_ua_name("/Encoding")

///|
fn pdf_ua_matterhorn_encoding_key() -> PdfName {
  pdf_ua_matterhorn_encoding_key_name
}

///|
let pdf_ua_matterhorn_cid_to_gid_map_key_name : PdfName = pdf_ua_name(
  "/CIDToGIDMap",
)

///|
fn pdf_ua_matterhorn_cid_to_gid_map_key() -> PdfName {
  pdf_ua_matterhorn_cid_to_gid_map_key_name
}

///|
let pdf_ua_matterhorn_usecmap_key_name : PdfName = pdf_ua_name("/UseCMap")

///|
fn pdf_ua_matterhorn_usecmap_key() -> PdfName {
  pdf_ua_matterhorn_usecmap_key_name
}

///|
let pdf_ua_matterhorn_wmode_key_name : PdfName = pdf_ua_name("/WMode")

///|
fn pdf_ua_matterhorn_wmode_key() -> PdfName {
  pdf_ua_matterhorn_wmode_key_name
}

///|
let pdf_ua_matterhorn_descendant_fonts_key_name : PdfName = pdf_ua_name(
  "/DescendantFonts",
)

///|
fn pdf_ua_matterhorn_descendant_fonts_key() -> PdfName {
  pdf_ua_matterhorn_descendant_fonts_key_name
}

///|
let pdf_ua_matterhorn_cid_system_info_key_name : PdfName = pdf_ua_name(
  "/CIDSystemInfo",
)

///|
fn pdf_ua_matterhorn_cid_system_info_key() -> PdfName {
  pdf_ua_matterhorn_cid_system_info_key_name
}

///|
let pdf_ua_matterhorn_registry_key_name : PdfName = pdf_ua_name("/Registry")

///|
fn pdf_ua_matterhorn_registry_key() -> PdfName {
  pdf_ua_matterhorn_registry_key_name
}

///|
let pdf_ua_matterhorn_ordering_key_name : PdfName = pdf_ua_name("/Ordering")

///|
fn pdf_ua_matterhorn_ordering_key() -> PdfName {
  pdf_ua_matterhorn_ordering_key_name
}

///|
let pdf_ua_matterhorn_struct_parent_key_name : PdfName = pdf_ua_name(
  "/StructParent",
)

///|
fn pdf_ua_matterhorn_struct_parent_key() -> PdfName {
  pdf_ua_matterhorn_struct_parent_key_name
}

///|
let pdf_ua_matterhorn_media_clip_name : PdfName = pdf_ua_name("/MediaClip")

///|
fn pdf_ua_matterhorn_media_clip() -> PdfName {
  pdf_ua_matterhorn_media_clip_name
}

///|
let pdf_ua_matterhorn_mcd_name : PdfName = pdf_ua_name("/MCD")

///|
fn pdf_ua_matterhorn_mcd() -> PdfName {
  pdf_ua_matterhorn_mcd_name
}

///|
let pdf_ua_matterhorn_printer_mark_name : PdfName = pdf_ua_name("/PrinterMark")

///|
fn pdf_ua_matterhorn_printer_mark() -> PdfName {
  pdf_ua_matterhorn_printer_mark_name
}
