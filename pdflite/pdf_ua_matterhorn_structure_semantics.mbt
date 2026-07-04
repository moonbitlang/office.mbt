///|
fn PdfDocument::pdf_ua_matterhorn_check_13_004(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let figure = pdf_ua_name("/Figure")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, figure : @core.PdfName) -> Bool {
    if node.name == figure &&
      !node.has_attr(pdf_ua_matterhorn_alt_key()) &&
      !node.has_attr(pdf_ua_matterhorn_actual_text_key()) {
      true
    } else {
      for child in node.children {
        if check(child, figure) {
          return true
        }
      }
      false
    }
  }
  if check(tree, figure) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_002(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let headings = pdf_ua_matterhorn_heading_names(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
  match headings {
    [] => None
    [first, ..] =>
      if first == pdf_ua_name("/H1") {
        None
      } else {
        Some(Json::string(pdf_ua_matterhorn_name_text(first)))
      }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_003(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let headings = pdf_ua_matterhorn_heading_names(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
  let mut previous = 1
  for heading in headings {
    let current = pdf_ua_matterhorn_hnum(heading)
    if current > previous + 1 {
      return Some(
        Json::string(previous.to_string() + " -> " + current.to_string()),
      )
    }
    previous = current
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_006(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let h = pdf_ua_name("/H")
  fn check(node : PdfUAMatterhornStructNode, h : @core.PdfName) -> Bool {
    let mut count = 0
    for child in node.children {
      if child.name == h {
        count += 1
      }
    }
    if count > 1 {
      true
    } else {
      for child in node.children {
        if check(child, h) {
          return true
        }
      }
      false
    }
  }
  if check(self.pdf_ua_matterhorn_read_struct_tree(), h) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_14_007(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  let h = pdf_ua_name("/H")
  if tree.contains_name(fn(name) { name == h }) &&
    tree.contains_name(pdf_ua_matterhorn_is_hnum) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_15_003(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let th = pdf_ua_name("/TH")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, th : @core.PdfName) -> Bool {
    if node.name == th && !node.has_attr(pdf_ua_matterhorn_scope()) {
      true
    } else {
      for child in node.children {
        if check(child, th) {
          return true
        }
      }
      false
    }
  }
  if check(tree, th) {
    Some(Json::string("No scope, table organization not checked."))
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_17_002(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let formula = pdf_ua_name("/Formula")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, formula : @core.PdfName) -> Bool {
    if node.name == formula && !node.has_attr(pdf_ua_matterhorn_alt_key()) {
      true
    } else {
      for child in node.children {
        if check(child, formula) {
          return true
        }
      }
      false
    }
  }
  if check(tree, formula) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn pdf_ua_matterhorn_check_source_noop() -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_19_003(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let note = pdf_ua_name("/Note")
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  fn check(node : PdfUAMatterhornStructNode, note : @core.PdfName) -> Bool {
    if node.name == note && !node.has_attr(pdf_ua_matterhorn_id_key()) {
      true
    } else {
      for child in node.children {
        if check(child, note) {
          return true
        }
      }
      false
    }
  }
  if check(tree, note) {
    Some(Json::null())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_19_004(self : PdfDocument) -> Json? {
  let note = pdf_ua_name("/Note")
  let ids : Array[@core.PdfBytes] = []
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_s_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_id_key(), entry.2),
      ) {
      (Some(PdfNameObject(kind)), Some(PdfString(id))) if kind == note =>
        if ids.contains(id) {
          return Some(Json::null())
        } else {
          ids.push(id)
        }
      _ => ()
    }
  }
  None
}
