///|
fn pdf_merge_max_version(
  documents : ArrayView[PdfDocument],
) -> (Int, Int) raise PdfError {
  if documents.length() == 0 {
    raise PageTreeExpected
  }
  let mut major = documents[0].major
  let mut minor = documents[0].minor
  for i in 1..<documents.length() {
    let (candidate_major, candidate_minor) = documents[i].version()
    if candidate_major > major ||
      (candidate_major == major && candidate_minor > minor) {
      major = candidate_major
      minor = candidate_minor
    }
  }
  (major, minor)
}

///|
fn pdf_merge_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_merge_root_key_name : PdfName = pdf_merge_name("/Root")

///|
fn pdf_merge_root_key() -> PdfName {
  pdf_merge_root_key_name
}

///|
let pdf_merge_acroform_key_name : PdfName = pdf_merge_name("/AcroForm")

///|
fn pdf_merge_acroform_key() -> PdfName {
  pdf_merge_acroform_key_name
}

///|
let pdf_merge_open_action_key_name : PdfName = pdf_merge_name("/OpenAction")

///|
fn pdf_merge_open_action_key() -> PdfName {
  pdf_merge_open_action_key_name
}

///|
let pdf_merge_ocproperties_key_name : PdfName = pdf_merge_name("/OCProperties")

///|
fn pdf_merge_ocproperties_key() -> PdfName {
  pdf_merge_ocproperties_key_name
}

///|
let pdf_merge_outlines_key_name : PdfName = pdf_merge_name("/Outlines")

///|
fn pdf_merge_outlines_key() -> PdfName {
  pdf_merge_outlines_key_name
}

///|
let pdf_merge_page_labels_key_name : PdfName = pdf_merge_name("/PageLabels")

///|
fn pdf_merge_page_labels_key() -> PdfName {
  pdf_merge_page_labels_key_name
}

///|
let pdf_merge_pages_key_name : PdfName = pdf_merge_name("/Pages")

///|
fn pdf_merge_pages_key() -> PdfName {
  pdf_merge_pages_key_name
}

///|
let pdf_merge_struct_tree_root_key_name : PdfName = pdf_merge_name(
  "/StructTreeRoot",
)

///|
fn pdf_merge_struct_tree_root_key() -> PdfName {
  pdf_merge_struct_tree_root_key_name
}

///|
let pdf_merge_type_key_name : PdfName = pdf_merge_name("/Type")

///|
fn pdf_merge_type_key() -> PdfName {
  pdf_merge_type_key_name
}

///|
let pdf_merge_dests_key_name : PdfName = pdf_merge_name("/Dests")

///|
fn pdf_merge_dests_key() -> PdfName {
  pdf_merge_dests_key_name
}

///|
let pdf_merge_dest_key_name : PdfName = pdf_merge_name("/Dest")

///|
fn pdf_merge_dest_key() -> PdfName {
  pdf_merge_dest_key_name
}

///|
let pdf_merge_fields_key_name : PdfName = pdf_merge_name("/Fields")

///|
fn pdf_merge_fields_key() -> PdfName {
  pdf_merge_fields_key_name
}

///|
let pdf_merge_af_key_name : PdfName = pdf_merge_name("/AF")

///|
fn pdf_merge_af_key() -> PdfName {
  pdf_merge_af_key_name
}

///|
let pdf_merge_class_map_key_name : PdfName = pdf_merge_name("/ClassMap")

///|
fn pdf_merge_class_map_key() -> PdfName {
  pdf_merge_class_map_key_name
}

///|
let pdf_merge_id_tree_key_name : PdfName = pdf_merge_name("/IDTree")

///|
fn pdf_merge_id_tree_key() -> PdfName {
  pdf_merge_id_tree_key_name
}

///|
let pdf_merge_info_key_name : PdfName = pdf_merge_name("/Info")

///|
fn pdf_merge_info_key() -> PdfName {
  pdf_merge_info_key_name
}

///|
let pdf_merge_k_key_name : PdfName = pdf_merge_name("/K")

///|
fn pdf_merge_k_key() -> PdfName {
  pdf_merge_k_key_name
}

///|
let pdf_merge_names_key_name : PdfName = pdf_merge_name("/Names")

///|
fn pdf_merge_names_key() -> PdfName {
  pdf_merge_names_key_name
}

///|
let pdf_merge_ns_key_name : PdfName = pdf_merge_name("/NS")

///|
fn pdf_merge_ns_key() -> PdfName {
  pdf_merge_ns_key_name
}

///|
let pdf_merge_parent_key_name : PdfName = pdf_merge_name("/P")

///|
fn pdf_merge_parent_key() -> PdfName {
  pdf_merge_parent_key_name
}

///|
let pdf_merge_pronunciation_lexicon_key_name : PdfName = pdf_merge_name(
  "/PronunciationLexicon",
)

///|
fn pdf_merge_pronunciation_lexicon_key() -> PdfName {
  pdf_merge_pronunciation_lexicon_key_name
}

///|
let pdf_merge_parent_tree_key_name : PdfName = pdf_merge_name("/ParentTree")

///|
fn pdf_merge_parent_tree_key() -> PdfName {
  pdf_merge_parent_tree_key_name
}

///|
fn PdfDocument::pdf_merge_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
let pdf_merge_role_map_key_name : PdfName = pdf_merge_name("/RoleMap")

///|
fn pdf_merge_role_map_key() -> PdfName {
  pdf_merge_role_map_key_name
}

///|
let pdf_merge_s_key_name : PdfName = pdf_merge_name("/S")

///|
fn pdf_merge_s_key() -> PdfName {
  pdf_merge_s_key_name
}

///|
let pdf_merge_namespaces_key_name : PdfName = pdf_merge_name("/Namespaces")

///|
fn pdf_merge_namespaces_key() -> PdfName {
  pdf_merge_namespaces_key_name
}

///|
let pdf_merge_struct_parent_key_name : PdfName = pdf_merge_name("/StructParent")

///|
fn pdf_merge_struct_parent_key() -> PdfName {
  pdf_merge_struct_parent_key_name
}

///|
let pdf_merge_struct_parents_key_name : PdfName = pdf_merge_name(
  "/StructParents",
)

///|
fn pdf_merge_struct_parents_key() -> PdfName {
  pdf_merge_struct_parents_key_name
}

///|
let pdf_merge_namedict_ap_key_name : PdfName = pdf_merge_name("/AP")

///|
let pdf_merge_namedict_javascript_key_name : PdfName = pdf_merge_name(
  "/JavaScript",
)

///|
let pdf_merge_namedict_templates_key_name : PdfName = pdf_merge_name(
  "/Templates",
)

///|
let pdf_merge_namedict_ids_key_name : PdfName = pdf_merge_name("/IDS")

///|
let pdf_merge_namedict_urls_key_name : PdfName = pdf_merge_name("/URLS")

///|
let pdf_merge_namedict_embedded_files_key_name : PdfName = pdf_merge_name(
  "/EmbeddedFiles",
)

///|
let pdf_merge_namedict_alternate_presentations_key_name : PdfName = pdf_merge_name(
  "/AlternatePresentations",
)

///|
let pdf_merge_namedict_renditions_key_name : PdfName = pdf_merge_name(
  "/Renditions",
)

///|
let pdf_merge_namedict_tree_key_names : Array[PdfName] = [
  pdf_merge_namedict_ap_key_name, pdf_merge_namedict_javascript_key_name, pdf_merge_pages_key_name,
  pdf_merge_namedict_templates_key_name, pdf_merge_namedict_ids_key_name, pdf_merge_namedict_urls_key_name,
  pdf_merge_namedict_embedded_files_key_name, pdf_merge_namedict_alternate_presentations_key_name,
  pdf_merge_namedict_renditions_key_name,
]

///|
fn pdf_merge_namedict_tree_keys() -> ArrayView[PdfName] {
  pdf_merge_namedict_tree_key_names
}

///|
let pdf_merge_document_name : PdfName = pdf_merge_name("/Document")
