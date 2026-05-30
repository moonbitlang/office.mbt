///|
fn PdfDocument::pdf_tweak_append_page_content_ops_page(
  self : PdfDocument,
  page : @page.PdfPage,
  ops : ArrayView[@content.PdfContentOp],
  before : Bool,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  if ops.length() == 0 {
    page
  } else if before {
    self.prepend_operators(page, ops, fast~)
  } else {
    self.postpend_operators(page, ops, fast~)
  }
}

///|
fn PdfDocument::pdf_tweak_append_page_content_page(
  self : PdfDocument,
  page : @page.PdfPage,
  content : BytesView,
  before : Bool,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  if content.length() == 0 {
    page
  } else {
    let ops = self.parse_content_view_with_resources(page.resources, content)
    self.pdf_tweak_append_page_content_ops_page(page, ops, before, fast)
  }
}

///|
fn pdf_tweak_validate_page_count(
  length : Int,
  page_count : Int,
) -> Unit raise PdfError {
  if length != page_count {
    raise BadPageSpecification("append_page_content_multiple")
  }
}

///|
/// Append or prepend parsed content bytes to selected one-based pages.
///
/// `content` is byte-oriented PDF content syntax, matching the OCaml source's
/// `string` payload. Empty content is a no-op.
pub fn PdfDocument::append_page_content(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  content : BytesView,
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        document.pdf_tweak_append_page_content_page(page, content, before, fast),
      )
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content`.
pub fn pdf_append_page_content(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  content : BytesView,
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content(page_numbers, content, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content` argument order.
pub fn pdf_append_page_content_cpdf_order(
  content : BytesView,
  before : Bool,
  fast : Bool,
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content(page_numbers, content, before~, fast~)
}

///|
/// Append or prepend content operators to selected one-based pages.
pub fn PdfDocument::append_page_content_ops(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  ops : ArrayView[@content.PdfContentOp],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(
        document.pdf_tweak_append_page_content_ops_page(page, ops, before, fast),
      )
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_ops`.
pub fn pdf_append_page_content_ops(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  ops : ArrayView[@content.PdfContentOp],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_ops(page_numbers, ops, before~, fast~)
}

///|
/// Append or prepend one content byte payload per page.
///
/// The payload list must match the current page count. Empty per-page payloads
/// leave that page unchanged.
pub fn PdfDocument::append_page_content_multiple(
  self : PdfDocument,
  contents : ArrayView[Bytes],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  pdf_tweak_validate_page_count(contents.length(), pages.length())
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    rewritten.push(
      document.pdf_tweak_append_page_content_page(
        pages[index],
        contents[index],
        before,
        fast,
      ),
    )
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_multiple`.
pub fn pdf_append_page_content_multiple(
  document : PdfDocument,
  contents : ArrayView[Bytes],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple(contents, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content_multiple`
/// argument order.
pub fn pdf_append_page_content_multiple_cpdf_order(
  contents : ArrayView[Bytes],
  before : Bool,
  fast : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple(contents, before~, fast~)
}

///|
/// Append or prepend one content operator list per page.
pub fn PdfDocument::append_page_content_multiple_ops(
  self : PdfDocument,
  op_lists : ArrayView[Array[@content.PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  pdf_tweak_validate_page_count(op_lists.length(), pages.length())
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    rewritten.push(
      document.pdf_tweak_append_page_content_ops_page(
        pages[index],
        op_lists[index],
        before,
        fast,
      ),
    )
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::append_page_content_multiple_ops`.
pub fn pdf_append_page_content_multiple_ops(
  document : PdfDocument,
  op_lists : ArrayView[Array[@content.PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple_ops(op_lists, before~, fast~)
}

///|
/// Compatibility wrapper matching cpdftweak's `append_page_content_multiple_ops`
/// argument order.
pub fn pdf_append_page_content_multiple_ops_cpdf_order(
  op_lists : ArrayView[Array[@content.PdfContentOp]],
  before : Bool,
  fast : Bool,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple_ops(op_lists, before~, fast~)
}
