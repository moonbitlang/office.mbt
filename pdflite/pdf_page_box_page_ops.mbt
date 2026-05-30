///|
fn PdfDocument::pdf_page_box_object(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
  mediabox_if_missing : Bool,
) -> PdfObject raise PdfError {
  if box_name == pdf_page_mediabox_key() {
    page.mediabox
  } else {
    match self.lookup_direct(box_name, page.rest) {
      Some(value) => value
      None =>
        if mediabox_if_missing {
          page.mediabox
        } else {
          raise BadPageSpecification(
            "hard_box: box " + pdf_page_box_name_text(box_name) + " not found",
          )
        }
    }
  }
}

///|
fn PdfDocument::pdf_page_hard_box_page(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
  mediabox_if_missing : Bool,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  let bounds = self.parse_rectangle(
    self.pdf_page_box_object(page, box_name, mediabox_if_missing),
  )
  self.prepend_operators(
    page,
    [
      Op_re(
        bounds.min_x,
        bounds.min_y,
        bounds.max_x - bounds.min_x,
        bounds.max_y - bounds.min_y,
      ),
      Op_W,
      Op_n,
    ],
    fast~,
  )
}

///|
fn PdfDocument::pdf_page_remove_box_page(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
) -> @page.PdfPage raise PdfError {
  ignore(self)
  { ..page, rest: page.rest.remove_dict_entry(box_name) }
}

///|
fn PdfDocument::pdf_page_copy_box_source(
  self : PdfDocument,
  page : @page.PdfPage,
  from_box : PdfName,
  mediabox_if_missing : Bool,
) -> PdfObject? {
  if from_box == pdf_page_mediabox_key() {
    Some(page.mediabox)
  } else {
    match self.lookup_direct(from_box, page.rest) {
      Some(value) => Some(value)
      None => if mediabox_if_missing { Some(page.mediabox) } else { None }
    }
  }
}

///|
fn PdfDocument::pdf_page_copy_box_page(
  self : PdfDocument,
  page : @page.PdfPage,
  from_box : PdfName,
  to_box : PdfName,
  mediabox_if_missing : Bool,
) -> @page.PdfPage raise PdfError {
  match self.pdf_page_copy_box_source(page, from_box, mediabox_if_missing) {
    Some(value) =>
      if to_box == pdf_page_mediabox_key() {
        { ..page, mediabox: value }
      } else {
        { ..page, rest: page.rest.add_dict_entry(to_box, value) }
      }
    None => page
  }
}

///|
fn PdfDocument::pdf_page_set_mediabox_page(
  self : PdfDocument,
  page_number : Int,
  page : @page.PdfPage,
  boxes : ArrayView[(Double, Double, Double, Double)],
) -> @page.PdfPage {
  ignore(self)
  { ..page, mediabox: pdf_page_box_xywh_object(boxes[page_number - 1]) }
}

///|
fn PdfDocument::pdf_page_crop_page(
  self : PdfDocument,
  page_number : Int,
  page : @page.PdfPage,
  boxes : ArrayView[(Double, Double, Double, Double)],
  box_name : PdfName,
) -> @page.PdfPage raise PdfError {
  ignore(self)
  {
    ..page,
    rest: page.rest.add_dict_entry(
      box_name,
      pdf_page_box_xywh_object(boxes[page_number - 1]),
    ),
  }
}

///|
fn PdfDocument::pdf_page_set_box_page(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
  min_x : Double,
  max_x : Double,
  min_y : Double,
  max_y : Double,
) -> @page.PdfPage raise PdfError {
  ignore(self)
  {
    ..page,
    rest: page.rest.add_dict_entry(
      box_name,
      pdf_page_box_bounds_object((min_x, min_y, max_x, max_y)),
    ),
  }
}

///|
fn PdfDocument::pdf_page_change_box_object(
  self : PdfDocument,
  object : PdfObject,
  transform : (Double, Double, Double, Double) -> (
    Double,
    Double,
    Double,
    Double,
  ),
) -> PdfObject raise PdfError {
  let bounds = self.parse_rectangle(object)
  pdf_page_box_bounds_object(
    transform(bounds.min_x, bounds.min_y, bounds.max_x, bounds.max_y),
  )
}
