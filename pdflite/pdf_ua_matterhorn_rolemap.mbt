///|
fn pdf_ua_matterhorn_name_text(name : @core.PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
fn pdf_ua_matterhorn_standard_structure_types_2008() -> Array[@core.PdfName] {
  [
    pdf_ua_name("/Document"),
    pdf_ua_name("/Part"),
    pdf_ua_name("/Sect"),
    pdf_ua_name("/Div"),
    pdf_ua_name("/NonStruct"),
    pdf_ua_name("/P"),
    pdf_ua_name("/H1"),
    pdf_ua_name("/H2"),
    pdf_ua_name("/H3"),
    pdf_ua_name("/H4"),
    pdf_ua_name("/H5"),
    pdf_ua_name("/H6"),
    pdf_ua_name("/H"),
    pdf_ua_name("/Lbl"),
    pdf_ua_name("/Span"),
    pdf_ua_name("/Link"),
    pdf_ua_name("/Annot"),
    pdf_ua_name("/Form"),
    pdf_ua_name("/Ruby"),
    pdf_ua_name("/RB"),
    pdf_ua_name("/RT"),
    pdf_ua_name("/RP"),
    pdf_ua_name("/Warichu"),
    pdf_ua_name("/WT"),
    pdf_ua_name("/WP"),
    pdf_ua_name("/L"),
    pdf_ua_name("/LI"),
    pdf_ua_name("/LBody"),
    pdf_ua_name("/Table"),
    pdf_ua_name("/TR"),
    pdf_ua_name("/TH"),
    pdf_ua_name("/TD"),
    pdf_ua_name("/THead"),
    pdf_ua_name("/TBody"),
    pdf_ua_name("/TFoot"),
    pdf_ua_name("/Caption"),
    pdf_ua_name("/Figure"),
    pdf_ua_name("/Formula"),
    pdf_ua_name("/Art"),
    pdf_ua_name("/BlockQuote"),
    pdf_ua_name("/TOC"),
    pdf_ua_name("/TOCI"),
    pdf_ua_name("/Index"),
    pdf_ua_name("/Private"),
    pdf_ua_name("/Quote"),
    pdf_ua_name("/Note"),
    pdf_ua_name("/Reference"),
    pdf_ua_name("/Code"),
    pdf_ua_name("/BibEntry"),
  ]
}

///|
fn pdf_ua_matterhorn_standard_structure_type(name : @core.PdfName) -> Bool {
  pdf_ua_matterhorn_standard_structure_types_2008().contains(name)
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_is_circular(
  self : PdfUAStructTreeRoleMap,
  name : @core.PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while true {
    if remaining < 0 {
      return true
    }
    match self.mapped(current) {
      Some(next) => {
        current = next
        remaining -= 1
      }
      None => return false
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_has_circular_mapping(
  self : PdfUAStructTreeRoleMap,
) -> Bool {
  for entry in self.entries {
    if self.pdf_ua_matterhorn_role_is_circular(entry.0) {
      return true
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_terminates_at_standard(
  self : PdfUAStructTreeRoleMap,
  name : @core.PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while remaining >= 0 {
    match self.mapped(current) {
      Some(next) =>
        if pdf_ua_matterhorn_standard_structure_type(next) {
          return true
        } else {
          current = next
          remaining -= 1
        }
      None => return false
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_rolemap(
  self : PdfDocument,
) -> PdfUAStructTreeRoleMap {
  self.pdf_ua_struct_tree_rolemap()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_001(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  if rolemap.pdf_ua_matterhorn_has_circular_mapping() {
    None
  } else {
    for entry in rolemap.entries {
      if !rolemap.pdf_ua_matterhorn_role_terminates_at_standard(entry.0) {
        return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
      }
    }
    None
  }
}

///|
fn pdf_ua_matterhorn_circular_rolemap_extra() -> Json {
  Json::string("STOP. If rolemap circular, cannot proceed with other checks.")
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_003(self : PdfDocument) -> Json? {
  if self.pdf_ua_matterhorn_rolemap().pdf_ua_matterhorn_has_circular_mapping() {
    Some(pdf_ua_matterhorn_circular_rolemap_extra())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_004(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  for entry in rolemap.entries {
    if pdf_ua_matterhorn_standard_structure_type(entry.0) {
      return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
    }
  }
  None
}
