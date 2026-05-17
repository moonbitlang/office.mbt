///|
fn pdf_tweak_page_selected(
  page_numbers : ArrayView[Int],
  page_number : Int,
) -> Bool {
  for selected in page_numbers {
    if selected == page_number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_tweak_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_tweak_extgstate_key_name : PdfName = pdf_tweak_name("/ExtGState")

///|
fn pdf_tweak_extgstate_key() -> PdfName {
  pdf_tweak_extgstate_key_name
}

///|
let pdf_tweak_line_width_key_name : PdfName = pdf_tweak_name("/LW")

///|
fn pdf_tweak_line_width_key() -> PdfName {
  pdf_tweak_line_width_key_name
}

///|
fn pdf_tweak_number(object : PdfObject) -> Double? {
  match object {
    PdfReal(value) => Some(value)
    PdfInteger(value) => Some(value.to_double())
    _ => None
  }
}

///|
fn pdf_tweak_ctm_scale(stack : ArrayView[TransformMatrix]) -> Double {
  if stack.length() == 0 {
    1.0
  } else {
    stack[stack.length() - 1].decompose().scale
  }
}

///|
fn pdf_tweak_extgstate_line_width(
  document : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Double? {
  match document.lookup_direct(pdf_tweak_extgstate_key(), resources) {
    Some(extgstate) =>
      match document.lookup_direct(name, extgstate) {
        Some(gdict) =>
          match document.lookup_direct(pdf_tweak_line_width_key(), gdict) {
            Some(value) => pdf_tweak_number(value)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_tweak_append_page_content_ops_page(
  self : PdfDocument,
  page : PdfPage,
  ops : ArrayView[PdfContentOp],
  before : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
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
  page : PdfPage,
  content : BytesView,
  before : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
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
fn pdf_tweak_is_digit_byte(byte : Byte) -> Bool {
  byte >= 48 && byte <= 57
}

///|
fn pdf_tweak_parse_digits(
  bytes : BytesView,
  start : Int,
  finish : Int,
  source : String,
) -> Int raise PdfError {
  if start >= finish {
    raise BadPageSpecification(source)
  }
  let mut value = 0
  for index in start..<finish {
    value = value * 10 + bytes[index].to_int() - 48
  }
  value
}

///|
fn pdf_tweak_digit_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    index += 1
  }
  index
}

///|
fn pdf_tweak_split_chain(bytes : BytesView, start : Int) -> Array[PdfName] {
  let output : Array[PdfName] = []
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == 47 {
      let segment_start = index
      index += 1
      while index < bytes.length() && bytes[index].to_int() != 47 {
        index += 1
      }
      output.push(pdf_name_of_bytes(bytes[segment_start:index].to_owned()))
    } else {
      index = bytes.length()
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_find_chained_object(
  self : PdfDocument,
  start : PdfObject,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  match self.lookup_chain(start, chain) {
    Some(object) => object
    None => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_find_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  source : String,
) -> PdfObject raise PdfError {
  let object = if number == 0 {
    self.trailer_dict()
  } else {
    self.lookup_object_or_null(number)
  }
  self.pdf_tweak_find_chained_object(object, chain, source)
}

///|
/// Remove text rendering-mode operators so hidden text is rendered normally.
pub fn pdf_reveal_hidden_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_Tr(_) => ()
      _ => output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_reveal_hidden_text_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))],
  }
}

///|
fn pdf_tweak_reveal_hidden_text_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_reveal_hidden_text_ops(ops))]
}

///|
/// Reveal hidden text on selected one-based pages and their Form XObjects.
///
/// This ports the `cpdftweak.ml` reveal-hidden-text behavior by removing all
/// `Tr` text rendering-mode operators from selected content streams.
pub fn PdfDocument::reveal_hidden_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      document.process_xobjects(page, pdf_tweak_reveal_hidden_text_xobject)
      rewritten.push(document.pdf_tweak_reveal_hidden_text_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::reveal_hidden_text`.
pub fn pdf_reveal_hidden_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.reveal_hidden_text(page_numbers)
}

///|
/// Remove clipping-path setup sequences from parsed content operators.
///
/// This ports `cpdftweak.ml`'s `remove_clipping_ops`: only the exact `W n`
/// sequence is rewritten, becoming just `n`.
pub fn pdf_remove_clipping_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    if index + 1 < ops.length() && ops[index] == Op_W && ops[index + 1] == Op_n {
      output.push(Op_n)
      index += 2
    } else {
      output.push(ops[index])
      index += 1
    }
  }
  output
}

///|
fn PdfDocument::pdf_tweak_remove_clipping_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  { ..page, content: [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))] }
}

///|
fn pdf_tweak_remove_clipping_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_remove_clipping_ops(ops))]
}

///|
/// Remove clipping paths from selected one-based pages and their Form XObjects.
pub fn PdfDocument::remove_clipping(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      document.process_xobjects(page, pdf_tweak_remove_clipping_xobject)
      rewritten.push(document.pdf_tweak_remove_clipping_page(page))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_clipping`.
pub fn pdf_remove_clipping(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_clipping(page_numbers)
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
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
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
/// Append or prepend content operators to selected one-based pages.
pub fn PdfDocument::append_page_content_ops(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  ops : ArrayView[PdfContentOp],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
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
  ops : ArrayView[PdfContentOp],
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
  let rewritten : Array[PdfPage] = []
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
/// Append or prepend one content operator list per page.
pub fn PdfDocument::append_page_content_multiple_ops(
  self : PdfDocument,
  op_lists : ArrayView[Array[PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  pdf_tweak_validate_page_count(op_lists.length(), pages.length())
  let rewritten : Array[PdfPage] = []
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
  op_lists : ArrayView[Array[PdfContentOp]],
  before? : Bool = false,
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.append_page_content_multiple_ops(op_lists, before~, fast~)
}

///|
/// Find an object using cpdf's object-spec grammar.
///
/// `""` selects the trailer dictionary, `/A/B` follows a trailer-rooted chain,
/// `4/A` follows a chain from object 4, and `P1/A` follows a chain from the
/// first page object.
pub fn PdfDocument::find_object_by_spec(
  self : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    self.trailer_dict()
  } else if bytes[0].to_int() == 80 {
    let digit_end = pdf_tweak_digit_end(bytes, 1)
    let page_number = pdf_tweak_parse_digits(bytes, 1, digit_end, spec)
    let page_refs = self.page_reference_numbers()
    if page_number < 1 || page_number > page_refs.length() {
      raise BadPageSpecification(spec)
    }
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(page_refs[page_number - 1], chain, spec)
  } else if bytes[0].to_int() == 47 {
    let chain = pdf_tweak_split_chain(bytes, 0)
    self.pdf_tweak_find_chained_object(self.trailer_dict(), chain, spec)
  } else {
    let digit_end = pdf_tweak_digit_end(bytes, 0)
    let object_number = pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
    let chain = pdf_tweak_split_chain(bytes, digit_end)
    self.pdf_tweak_find_numbered_object(object_number, chain, spec)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::find_object_by_spec`.
pub fn pdf_find_object(
  document : PdfDocument,
  spec : String,
) -> PdfObject raise PdfError {
  document.find_object_by_spec(spec)
}

///|
/// Rewrite line widths to honor the cpdf thin-lines threshold.
///
/// Positive `width` is a minimum width. Negative `width` uses its absolute
/// value as a maximum width, matching `cpdftweak.ml`.
pub fn pdf_thin_lines_ops(
  document : PdfDocument,
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
  width : Double,
) -> Array[PdfContentOp] raise PdfError {
  let limit = if width < 0.0 { -width } else { width }
  let is_minimum = width >= 0.0
  let ctm_stack : Array[TransformMatrix] = [transform_identity_matrix]
  let output : Array[PdfContentOp] = []
  for op in ops {
    match op {
      Op_w(line_width) => {
        let adjusted_limit = limit / pdf_tweak_ctm_scale(ctm_stack)
        let keep = if is_minimum {
          line_width >= adjusted_limit
        } else {
          line_width <= adjusted_limit
        }
        if keep {
          output.push(op)
        } else {
          output.push(Op_w(adjusted_limit))
        }
      }
      Op_cm(matrix) => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        let index = ctm_stack.length() - 1
        ctm_stack[index] = transform_matrix_compose(ctm_stack[index], matrix)
        output.push(op)
      }
      Op_q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ctm_stack.push(ctm_stack[ctm_stack.length() - 1])
        output.push(op)
      }
      Op_Q => {
        if ctm_stack.length() == 0 {
          raise MatrixMalformed
        }
        ignore(ctm_stack.pop())
        output.push(op)
      }
      Op_gs(name) => {
        output.push(op)
        match pdf_tweak_extgstate_line_width(document, resources, name) {
          Some(line_width) => output.push(Op_w(line_width))
          None => ()
        }
      }
      _ => output.push(op)
    }
  }
  if limit > 1.0 || limit < 1.0 {
    output.insert(0, Op_w(limit))
  }
  output
}

///|
fn PdfDocument::pdf_tweak_thin_lines_page(
  self : PdfDocument,
  page : PdfPage,
  width : Double,
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  {
    ..page,
    content: [
      pdf_content_stream_of_ops(
        pdf_thin_lines_ops(self, page.resources, ops, width),
      ),
    ],
  }
}

///|
/// Set a minimum line width on selected one-based pages.
///
/// Passing a negative `width` sets the corresponding maximum line width, as in
/// cpdf's `thinlines` implementation.
pub fn PdfDocument::thin_lines(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = []
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if pdf_tweak_page_selected(page_numbers, page_number) {
      rewritten.push(document.pdf_tweak_thin_lines_page(page, width))
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::thin_lines`.
pub fn pdf_thin_lines(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  width : Double,
) -> PdfDocument raise PdfError {
  document.thin_lines(page_numbers, width)
}
