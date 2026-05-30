///|
fn PdfDocument::pdf_ua_matterhorn_check_28_006(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationUnknown(_) {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationTrapNet {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_page_annotation_count(
  self : PdfDocument,
  page : @page.PdfPage,
) -> Int raise PdfError {
  self.annotations_of_page(page).length()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_008(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 &&
      self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 {
      match self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) {
        Some(PdfNameObject(name)) if name == pdf_ua_s_key() => ()
        Some(_) => return Some(Json::null())
        None => ()
      }
    }
  }
  None
}

///|
let pdf_ua_matterhorn_28_002_subtypes : Array[PdfName] = [
  pdf_annotation_stamp_name,
  pdf_annotation_line_name,
  pdf_ua_name("Square"),
  pdf_annotation_circle_name,
  pdf_annotation_polygon_name,
  pdf_annotation_polyline_name,
  pdf_annotation_highlight_name,
  pdf_annotation_underline_name,
  pdf_annotation_squiggly_name,
  pdf_annotation_strikeout_name,
  pdf_annotation_caret_name,
  pdf_annotation_ink_name,
  pdf_annotation_file_attachment_name,
  pdf_annotation_sound_name,
  pdf_annotation_movie_name,
  pdf_annotation_screen_name,
  pdf_annotation_trap_net_name,
  pdf_annotation_watermark_name,
  pdf_annotation_three_dee_name,
]

///|
fn pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype : PdfName) -> Bool {
  pdf_ua_matterhorn_28_002_subtypes.contains(subtype)
}

///|
fn pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(
  subtype : PdfName,
) -> Bool {
  pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) ||
  subtype == pdf_annotation_link_name ||
  subtype == pdf_annotation_printer_mark_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_parent_tree_entries(
  self : PdfDocument,
) -> Array[(Int, PdfObject)] {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_struct_tree_root_key(),
      pdf_structure_parent_tree_key(),
    ]) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn pdf_ua_matterhorn_parent_tree_lookup(
  parent_tree : ArrayView[(Int, PdfObject)],
  key : Int,
) -> PdfObject? {
  for entry in parent_tree {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_002(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  match self.lookup_direct(pdf_ua_s_key(), structure) {
                    Some(PdfNameObject(kind)) =>
                      if kind != pdf_ua_matterhorn_annot() {
                        return Some(Json::null())
                      }
                    _ => return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => return Some(Json::null())
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_004(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(subtype) &&
          self.lookup_direct(pdf_annotation_contents_key(), entry.2) is None {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  if self.lookup_direct(pdf_ua_matterhorn_alt_key(), structure)
                    is None {
                    return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
// Preserve cpdf source behavior: get_field_object_numbers only returns fields
// with /T, then 28-005 checks the returned fields for missing /T.
fn PdfDocument::pdf_ua_matterhorn_check_28_005(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_struct_parent_check(
  self : PdfDocument,
  object : PdfObject,
  parent_tree : ArrayView[(Int, PdfObject)],
  expected_type : PdfName,
  wrong_type_extra : String,
  missing_struct_parent_extra : String?,
) -> Json? {
  match self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), object) {
    Some(PdfInteger(key)) =>
      match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
        Some(structure) =>
          match self.lookup_direct(pdf_ua_s_key(), structure) {
            Some(PdfNameObject(kind)) if kind == expected_type => None
            _ => Some(Json::string(wrong_type_extra))
          }
        None => Some(Json::string("not found in parent tree"))
      }
    _ =>
      match missing_struct_parent_extra {
        Some(extra) => Some(Json::string(extra))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_010(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_widget_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_ua_matterhorn_form(),
            "type is not form",
            Some("not in structure tree"),
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_011(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_link_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_annotation_link_name,
            "type is not link",
            None,
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_012(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationLink && annotation.contents is None {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_media_clip_mcd_without_ct(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_ua_type_key(), object),
      self.lookup_direct(pdf_ua_s_key(), object),
      self.lookup_direct(pdf_ua_matterhorn_ct_key(), object),
    ) {
    (Some(PdfNameObject(kind)), Some(PdfNameObject(subtype)), None) =>
      kind == pdf_ua_matterhorn_media_clip() &&
      subtype == pdf_ua_matterhorn_mcd()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_014(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
// Preserve cpdf source behavior: 28-015 reports missing /Alt but checks the
// same missing /CT condition as 28-014.
fn PdfDocument::pdf_ua_matterhorn_check_28_015(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_016(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_printer_mark(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_printer_mark()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_017(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2)
      is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_normal_appearance_streams(
  self : PdfDocument,
  annotation : PdfObject,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  match self.lookup_direct(pdf_ua_matterhorn_ap_key(), annotation) {
    Some(appearance_dictionary) =>
      match
        self.lookup_direct(pdf_ua_matterhorn_n_key(), appearance_dictionary) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            output.push(self.direct(entry.1))
          }
        Some(appearance) => output.push(appearance)
        None => ()
      }
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_018(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) {
      for stream in self.pdf_ua_matterhorn_normal_appearance_streams(entry.2) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        let ops = self.parse_content_ops_with_resources(resources, [stream])
        if pdf_content_add_artifacts(ops) != ops {
          return Some(Json::null())
        }
      }
    }
  }
  None
}
