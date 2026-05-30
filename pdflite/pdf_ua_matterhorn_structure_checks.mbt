///|
fn pdf_ua_matterhorn_is_hnum(name : @core.PdfName) -> Bool {
  let text = pdf_ua_matterhorn_name_text(name)
  if text == "/H" || !text.has_prefix("/H") {
    false
  } else {
    let result : Result[Int, Error] = try? @strconv.from_str(
      text[2:].to_owned(),
    )
    result is Ok(_)
  }
}

///|
fn pdf_ua_matterhorn_hnum(name : @core.PdfName) -> Int {
  let text = pdf_ua_matterhorn_name_text(name)
  @strconv.from_str(text[2:].to_owned()) catch {
    _ => 0
  }
}

///|
fn pdf_ua_matterhorn_heading_names(
  node : PdfUAMatterhornStructNode,
) -> Array[@core.PdfName] {
  let headings : Array[@core.PdfName] = []
  if pdf_ua_matterhorn_is_hnum(node.name) {
    headings.push(node.name)
  }
  for child in node.children {
    for heading in pdf_ua_matterhorn_heading_names(child) {
      headings.push(heading)
    }
  }
  headings
}

///|
fn pdf_ua_matterhorn_table_children_source_order(
  children : Array[PdfUAMatterhornStructNode],
) -> Array[PdfUAMatterhornStructNode] {
  let caption = pdf_ua_name("/Caption")
  match children {
    [first, .. rest] if first.name == caption => rest.to_owned()
    _ => {
      let reversed = children.rev()
      match reversed {
        [first, .. rest] if first.name == caption => rest.rev()
        _ => reversed
      }
    }
  }
}

///|
fn pdf_ua_matterhorn_check_table_rows(
  children : Array[PdfUAMatterhornStructNode],
) -> Json? {
  let tr = pdf_ua_name("/TR")
  let th = pdf_ua_name("/TH")
  let td = pdf_ua_name("/TD")
  let mut all_tr = true
  for child in children {
    if child.name == tr {
      for cell in child.children {
        if cell.name != th && cell.name != td {
          return Some(Json::string("Every /TR element must be a /TH or /TD"))
        }
      }
    } else {
      all_tr = false
    }
  }
  if all_tr {
    None
  } else {
    Some(Json::null())
  }
}

///|
fn pdf_ua_matterhorn_check_table_sections(
  children : Array[PdfUAMatterhornStructNode],
) -> Json? {
  let tr = pdf_ua_name("/TR")
  for node in children {
    for child in node.children {
      if child.name != tr {
        return Some(
          Json::string("Element in /THead | /TBody | /TFoot not a /TR"),
        )
      }
    }
  }
  let tbody = pdf_ua_name("/TBody")
  let thead = pdf_ua_name("/THead")
  let tfoot = pdf_ua_name("/TFoot")
  let without_thead = match children {
    [first, .. rest] if first.name == thead => rest
    _ => children
  }
  let without_tfoot = match without_thead.rev() {
    [first, .. rest] if first.name == tfoot => rest
    reversed => reversed
  }
  for node in without_tfoot {
    if node.name != tbody {
      return Some(Json::string("Top-level /Table not of required form"))
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_table_node(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let table = pdf_ua_name("/Table")
  if node.name == table {
    let children = pdf_ua_matterhorn_table_children_source_order(node.children)
    match pdf_ua_matterhorn_check_table_rows(children) {
      None => None
      Some(Null) => pdf_ua_matterhorn_check_table_sections(children)
      Some(failure) => Some(failure)
    }
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_table_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_004(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  pdf_ua_matterhorn_check_table_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_list_child(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let l = pdf_ua_name("/L")
  let li = pdf_ua_name("/LI")
  if node.name == li && node.children.length() == 0 {
    Some(Json::string("Empty /LI"))
  } else if node.name == li {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_item_child(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  } else if node.name == l {
    pdf_ua_matterhorn_check_list_node(node)
  } else {
    Some(
      Json::string(
        "Unknown child of /LI: " + pdf_ua_matterhorn_name_text(node.name),
      ),
    )
  }
}

///|
fn pdf_ua_matterhorn_check_list_item_child(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let lbody = pdf_ua_name("/LBody")
  let lbl = pdf_ua_name("/Lbl")
  if node.name == lbody || node.name == lbl {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  } else {
    Some(Json::string("Child of /LI must be /Lbl or /LBody"))
  }
}

///|
fn pdf_ua_matterhorn_check_list_node(node : PdfUAMatterhornStructNode) -> Json? {
  let l = pdf_ua_name("/L")
  let caption = pdf_ua_name("/Caption")
  if node.name == l {
    let children = match node.children {
      [first, .. rest] if first.name == caption => rest
      _ => node.children
    }
    if children.length() == 0 {
      Some(Json::string("No /LI in /L"))
    } else {
      for child in children {
        match pdf_ua_matterhorn_check_list_child(child) {
          Some(failure) => return Some(failure)
          None => ()
        }
      }
      None
    }
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_list_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_005(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  pdf_ua_matterhorn_check_list_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_toci_position(
  node : PdfUAMatterhornStructNode,
  seen_toc : Ref[Bool],
) -> Json? {
  let toc = pdf_ua_name("/TOC")
  let toci = pdf_ua_name("/TOCI")
  if node.name == toc {
    seen_toc.val = true
  } else if node.name == toci && !seen_toc.val {
    return Some(Json::string("TOCI without TOC above"))
  }
  for child in node.children {
    match pdf_ua_matterhorn_check_toci_position(child, seen_toc) {
      Some(failure) => return Some(failure)
      None => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_toc_children(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let toc = pdf_ua_name("/TOC")
  let toci = pdf_ua_name("/TOCI")
  if node.name == toc {
    for child in node.children {
      if child.name != toc && child.name != toci {
        return Some(Json::string("/TOC children must be /TOC or /TOCI"))
      }
    }
  } else if node.name == toci {
    let lbl = pdf_ua_name("/Lbl")
    let reference = pdf_ua_name("/Reference")
    let p = pdf_ua_name("/P")
    let nonstruct = pdf_ua_name("/NonStruct")
    for child in node.children {
      if child.name != toc &&
        child.name != lbl &&
        child.name != reference &&
        child.name != p &&
        child.name != nonstruct {
        return Some(Json::string("Bad child of /TOCI"))
      }
    }
  }
  for child in node.children {
    match pdf_ua_matterhorn_check_toc_children(child) {
      Some(failure) => return Some(failure)
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_006(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  let tree = self.pdf_ua_matterhorn_read_struct_tree()
  let seen_toc : Ref[Bool] = { val: false }
  match pdf_ua_matterhorn_check_toci_position(tree, seen_toc) {
    Some(failure) => Some(failure)
    None => pdf_ua_matterhorn_check_toc_children(tree)
  }
}

///|
fn pdf_ua_matterhorn_check_ruby_node(node : PdfUAMatterhornStructNode) -> Json? {
  let ruby = pdf_ua_name("/Ruby")
  if node.name == ruby {
    let rb = pdf_ua_name("/RB")
    let rt = pdf_ua_name("/RT")
    let rp = pdf_ua_name("RP")
    for child in node.children {
      if child.name != rb && child.name != rt && child.name != rp {
        return Some(Json::null())
      }
    }
    None
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_ruby_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_007(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  pdf_ua_matterhorn_check_ruby_node(self.pdf_ua_matterhorn_read_struct_tree())
}

///|
fn pdf_ua_matterhorn_check_warichu_node(
  node : PdfUAMatterhornStructNode,
) -> Json? {
  let ruby = pdf_ua_name("/Ruby")
  if node.name == ruby {
    let wt = pdf_ua_name("/WT")
    let wp = pdf_ua_name("/WP")
    for child in node.children {
      if child.name != wt && child.name != wp {
        return Some(Json::null())
      }
    }
    None
  } else {
    for child in node.children {
      match pdf_ua_matterhorn_check_warichu_node(child) {
        Some(failure) => return Some(failure)
        None => ()
      }
    }
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_09_008(
  self : PdfDocument,
) -> Json? raise @core.PdfError {
  pdf_ua_matterhorn_check_warichu_node(
    self.pdf_ua_matterhorn_read_struct_tree(),
  )
}
