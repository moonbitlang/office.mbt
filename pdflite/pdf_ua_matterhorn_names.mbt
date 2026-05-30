///|
let pdf_ua_matterhorn_artifact_name : @core.PdfName = pdf_ua_name("/Artifact")

///|
fn pdf_ua_matterhorn_artifact() -> @core.PdfName {
  pdf_ua_matterhorn_artifact_name
}

///|
let pdf_ua_matterhorn_span_name : @core.PdfName = pdf_ua_name("/Span")

///|
fn pdf_ua_matterhorn_span() -> @core.PdfName {
  pdf_ua_matterhorn_span_name
}

///|
let pdf_ua_matterhorn_annot_name : @core.PdfName = pdf_ua_name("/Annot")

///|
fn pdf_ua_matterhorn_annot() -> @core.PdfName {
  pdf_ua_matterhorn_annot_name
}

///|
let pdf_ua_matterhorn_form_name : @core.PdfName = pdf_ua_name("/Form")

///|
fn pdf_ua_matterhorn_form() -> @core.PdfName {
  pdf_ua_matterhorn_form_name
}

///|
let pdf_ua_matterhorn_type0_name : @core.PdfName = pdf_ua_name("/Type0")

///|
fn pdf_ua_matterhorn_type0() -> @core.PdfName {
  pdf_ua_matterhorn_type0_name
}

///|
let pdf_ua_matterhorn_cid_font_type2_name : @core.PdfName = pdf_ua_name(
  "/CIDFontType2",
)

///|
fn pdf_ua_matterhorn_cid_font_type2() -> @core.PdfName {
  pdf_ua_matterhorn_cid_font_type2_name
}

///|
let pdf_ua_matterhorn_cid_font_type0_name : @core.PdfName = pdf_ua_name(
  "/CIDFontType0",
)

///|
fn pdf_ua_matterhorn_cid_font_type0() -> @core.PdfName {
  pdf_ua_matterhorn_cid_font_type0_name
}

///|
let pdf_ua_matterhorn_identity_name : @core.PdfName = pdf_ua_name("/Identity")

///|
fn pdf_ua_matterhorn_identity() -> @core.PdfName {
  pdf_ua_matterhorn_identity_name
}

///|
let pdf_ua_matterhorn_identity_h_name : @core.PdfName = pdf_ua_name(
  "/Identity-H",
)

///|
fn pdf_ua_matterhorn_identity_h() -> @core.PdfName {
  pdf_ua_matterhorn_identity_h_name
}

///|
let pdf_ua_matterhorn_identity_v_name : @core.PdfName = pdf_ua_name(
  "/Identity-V",
)

///|
fn pdf_ua_matterhorn_identity_v() -> @core.PdfName {
  pdf_ua_matterhorn_identity_v_name
}

///|
let pdf_ua_matterhorn_tabs_key_name : @core.PdfName = pdf_ua_name("/Tabs")

///|
fn pdf_ua_matterhorn_tabs_key() -> @core.PdfName {
  pdf_ua_matterhorn_tabs_key_name
}

///|
let pdf_ua_matterhorn_adobe_name : @core.PdfName = pdf_ua_name("/Adobe")

///|
fn pdf_ua_matterhorn_adobe() -> @core.PdfName {
  pdf_ua_matterhorn_adobe_name
}

///|
let pdf_ua_matterhorn_gb1_name : @core.PdfName = pdf_ua_name("/GB1")

///|
let pdf_ua_matterhorn_cns1_name : @core.PdfName = pdf_ua_name("/CNS1")

///|
let pdf_ua_matterhorn_japan1_name : @core.PdfName = pdf_ua_name("/Japan1")

///|
let pdf_ua_matterhorn_korea1_name : @core.PdfName = pdf_ua_name("/Korea1")

///|
let pdf_ua_matterhorn_cmap_names : Array[@core.PdfName] = [
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
fn pdf_ua_matterhorn_cmap_name_is_listed(name : @core.PdfName) -> Bool {
  pdf_ua_matterhorn_cmap_names.contains(name)
}

///|
let pdf_ua_matterhorn_resources_key_name : @core.PdfName = pdf_ua_name(
  "/Resources",
)

///|
fn pdf_ua_matterhorn_resources_key() -> @core.PdfName {
  pdf_ua_matterhorn_resources_key_name
}

///|
let pdf_ua_matterhorn_xobject_key_name : @core.PdfName = pdf_ua_name("/XObject")

///|
fn pdf_ua_matterhorn_xobject_key() -> @core.PdfName {
  pdf_ua_matterhorn_xobject_key_name
}

///|
let pdf_ua_matterhorn_ap_key_name : @core.PdfName = pdf_ua_name("/AP")

///|
fn pdf_ua_matterhorn_ap_key() -> @core.PdfName {
  pdf_ua_matterhorn_ap_key_name
}

///|
let pdf_ua_matterhorn_n_key_name : @core.PdfName = pdf_ua_name("/N")

///|
fn pdf_ua_matterhorn_n_key() -> @core.PdfName {
  pdf_ua_matterhorn_n_key_name
}

///|
let pdf_ua_matterhorn_mcid_key_name : @core.PdfName = pdf_ua_name("/MCID")

///|
fn pdf_ua_matterhorn_mcid_key() -> @core.PdfName {
  pdf_ua_matterhorn_mcid_key_name
}

///|
let pdf_ua_matterhorn_suspects_key_name : @core.PdfName = pdf_ua_name(
  "/Suspects",
)

///|
fn pdf_ua_matterhorn_suspects_key() -> @core.PdfName {
  pdf_ua_matterhorn_suspects_key_name
}

///|
let pdf_ua_matterhorn_ref_key_name : @core.PdfName = pdf_ua_name("/Ref")

///|
fn pdf_ua_matterhorn_ref_key() -> @core.PdfName {
  pdf_ua_matterhorn_ref_key_name
}

///|
let pdf_ua_matterhorn_ct_key_name : @core.PdfName = pdf_ua_name("/CT")

///|
fn pdf_ua_matterhorn_ct_key() -> @core.PdfName {
  pdf_ua_matterhorn_ct_key_name
}

///|
let pdf_ua_matterhorn_alt_key_name : @core.PdfName = pdf_ua_name("/Alt")

///|
fn pdf_ua_matterhorn_alt_key() -> @core.PdfName {
  pdf_ua_matterhorn_alt_key_name
}

///|
let pdf_ua_matterhorn_actual_text_key_name : @core.PdfName = pdf_ua_name(
  "/ActualText",
)

///|
fn pdf_ua_matterhorn_actual_text_key() -> @core.PdfName {
  pdf_ua_matterhorn_actual_text_key_name
}

///|
let pdf_ua_matterhorn_id_key_name : @core.PdfName = pdf_ua_name("/ID")

///|
fn pdf_ua_matterhorn_id_key() -> @core.PdfName {
  pdf_ua_matterhorn_id_key_name
}

///|
let pdf_ua_matterhorn_a_key_name : @core.PdfName = pdf_ua_name("/A")

///|
fn pdf_ua_matterhorn_a_key() -> @core.PdfName {
  pdf_ua_matterhorn_a_key_name
}

///|
let pdf_ua_matterhorn_c_key_name : @core.PdfName = pdf_ua_name("/C")

///|
fn pdf_ua_matterhorn_c_key() -> @core.PdfName {
  pdf_ua_matterhorn_c_key_name
}

///|
let pdf_ua_matterhorn_scope_name : @core.PdfName = pdf_ua_name("/Scope")

///|
fn pdf_ua_matterhorn_scope() -> @core.PdfName {
  pdf_ua_matterhorn_scope_name
}

///|
let pdf_ua_matterhorn_encoding_key_name : @core.PdfName = pdf_ua_name(
  "/Encoding",
)

///|
fn pdf_ua_matterhorn_encoding_key() -> @core.PdfName {
  pdf_ua_matterhorn_encoding_key_name
}

///|
let pdf_ua_matterhorn_cid_to_gid_map_key_name : @core.PdfName = pdf_ua_name(
  "/CIDToGIDMap",
)

///|
fn pdf_ua_matterhorn_cid_to_gid_map_key() -> @core.PdfName {
  pdf_ua_matterhorn_cid_to_gid_map_key_name
}

///|
let pdf_ua_matterhorn_usecmap_key_name : @core.PdfName = pdf_ua_name("/UseCMap")

///|
fn pdf_ua_matterhorn_usecmap_key() -> @core.PdfName {
  pdf_ua_matterhorn_usecmap_key_name
}

///|
let pdf_ua_matterhorn_wmode_key_name : @core.PdfName = pdf_ua_name("/WMode")

///|
fn pdf_ua_matterhorn_wmode_key() -> @core.PdfName {
  pdf_ua_matterhorn_wmode_key_name
}

///|
let pdf_ua_matterhorn_descendant_fonts_key_name : @core.PdfName = pdf_ua_name(
  "/DescendantFonts",
)

///|
fn pdf_ua_matterhorn_descendant_fonts_key() -> @core.PdfName {
  pdf_ua_matterhorn_descendant_fonts_key_name
}

///|
let pdf_ua_matterhorn_cid_system_info_key_name : @core.PdfName = pdf_ua_name(
  "/CIDSystemInfo",
)

///|
fn pdf_ua_matterhorn_cid_system_info_key() -> @core.PdfName {
  pdf_ua_matterhorn_cid_system_info_key_name
}

///|
let pdf_ua_matterhorn_registry_key_name : @core.PdfName = pdf_ua_name(
  "/Registry",
)

///|
fn pdf_ua_matterhorn_registry_key() -> @core.PdfName {
  pdf_ua_matterhorn_registry_key_name
}

///|
let pdf_ua_matterhorn_ordering_key_name : @core.PdfName = pdf_ua_name(
  "/Ordering",
)

///|
fn pdf_ua_matterhorn_ordering_key() -> @core.PdfName {
  pdf_ua_matterhorn_ordering_key_name
}

///|
let pdf_ua_matterhorn_struct_parent_key_name : @core.PdfName = pdf_ua_name(
  "/StructParent",
)

///|
fn pdf_ua_matterhorn_struct_parent_key() -> @core.PdfName {
  pdf_ua_matterhorn_struct_parent_key_name
}

///|
let pdf_ua_matterhorn_media_clip_name : @core.PdfName = pdf_ua_name(
  "/MediaClip",
)

///|
fn pdf_ua_matterhorn_media_clip() -> @core.PdfName {
  pdf_ua_matterhorn_media_clip_name
}

///|
let pdf_ua_matterhorn_mcd_name : @core.PdfName = pdf_ua_name("/MCD")

///|
fn pdf_ua_matterhorn_mcd() -> @core.PdfName {
  pdf_ua_matterhorn_mcd_name
}

///|
let pdf_ua_matterhorn_printer_mark_name : @core.PdfName = pdf_ua_name(
  "/PrinterMark",
)

///|
fn pdf_ua_matterhorn_printer_mark() -> @core.PdfName {
  pdf_ua_matterhorn_printer_mark_name
}
