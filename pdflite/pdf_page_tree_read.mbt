///|
fn pdf_page_default_mediabox() -> PdfObject {
  PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(612), PdfInteger(792)])
}

///|
fn PdfDocument::pdf_page_direct_child(
  self : PdfDocument,
  kid : PdfObject,
) -> PdfObject raise PdfError {
  match kid {
    PdfIndirect(number) => {
      let child = self.lookup_object_or_null(number)
      if child == PdfNull {
        raise PageTreeExpected
      }
      child
    }
    PdfDictionary(_) => kid
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_pages_of_branch(
  self : PdfDocument,
  node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
  depth : Int,
) -> Array[PdfPage] raise PdfError {
  let resources = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_resources_key(), node),
    inherited_resources,
  )
  let mediabox = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_mediabox_key(), node),
    inherited_mediabox,
  )
  let cropbox = pdf_page_inherited_object(
    self.lookup_direct(pdf_page_cropbox_key(), node),
    inherited_cropbox,
  )
  let rotate = self.pdf_page_inherited_rotation(node, inherited_rotate)
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) => {
      let pages : Array[PdfPage] = Array::new(capacity=kids.length())
      for kid in kids {
        for
          page in self.pdf_pages_of_node(
            self.pdf_page_direct_child(kid),
            resources,
            mediabox,
            cropbox,
            rotate,
            last_mediabox,
            depth + 1,
          ) {
          pages.push(page)
        }
      }
      pages
    }
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_content_object(
  self : PdfDocument,
  page : PdfObject,
) -> PdfObject? {
  match self.direct(page).lookup_immediate(pdf_page_contents_key()) {
    Some(PdfIndirect(number) as indirect) =>
      match self.lookup_object_or_null(number) {
        PdfArray(items) => Some(PdfArray(items))
        _ => Some(PdfArray([indirect]))
      }
    Some(value) => Some(value)
    None => None
  }
}

///|
fn PdfDocument::pdf_page_content_list(
  self : PdfDocument,
  contents : PdfObject?,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = Array::new(
    capacity=match contents {
      Some(PdfArray(items)) => items.length()
      Some(_) => 1
      None => 0
    },
  )
  match contents {
    None => ()
    Some(PdfArray(items)) =>
      for item in items {
        match self.direct(item) {
          PdfStreamObject(_) => output.push(item)
          _ => ()
        }
      }
    Some(object) =>
      match self.direct(object) {
        PdfStreamObject(_) => output.push(object)
        _ => ()
      }
  }
  output
}

///|
fn PdfDocument::pdf_page_leaf(
  self : PdfDocument,
  page_node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
) -> PdfPage raise PdfError {
  let page = self.direct(page_node)
  let resources = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_resources_key(), page),
      inherited_resources,
    ) {
    Some(value) => value
    None => PdfDictionary([])
  }
  let mediabox = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_mediabox_key(), page),
      inherited_mediabox,
    ) {
    Some(value) => {
      last_mediabox.val = value
      value
    }
    None => last_mediabox.val
  }
  let rotate = self.pdf_page_inherited_rotation(page, inherited_rotate)
  let rest = match
    pdf_page_inherited_object(
      self.lookup_direct(pdf_page_cropbox_key(), page),
      inherited_cropbox,
    ) {
    Some(cropbox) =>
      pdf_page_rest_object_from_page(page).add_dict_entry(
        pdf_page_cropbox_key(),
        cropbox,
      )
    None => pdf_page_rest_object_from_page(page)
  }
  {
    content: self.pdf_page_content_list(self.pdf_page_content_object(page)),
    mediabox,
    resources,
    rotate,
    rest,
  }
}

///|
fn PdfDocument::pdf_pages_of_node(
  self : PdfDocument,
  node : PdfObject,
  inherited_resources : PdfObject?,
  inherited_mediabox : PdfObject?,
  inherited_cropbox : PdfObject?,
  inherited_rotate : PdfPageRotation,
  last_mediabox : Ref[PdfObject],
  depth : Int,
) -> Array[PdfPage] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_pages() =>
      self.pdf_pages_of_branch(
        node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
        last_mediabox, depth,
      )
    None =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(_)) =>
          self.pdf_pages_of_branch(
            node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
            last_mediabox, depth,
          )
        _ => {
          let page = self.pdf_page_leaf(
            node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
            last_mediabox,
          )
          [page]
        }
      }
    _ => {
      let page = self.pdf_page_leaf(
        node, inherited_resources, inherited_mediabox, inherited_cropbox, inherited_rotate,
        last_mediabox,
      )
      [page]
    }
  }
}
