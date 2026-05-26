///|
fn pdf_remove_text_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_remove_text_stamp_name : PdfName = pdf_remove_text_name("/CPDFSTAMP")

///|
fn pdf_remove_text_stamp() -> PdfName {
  pdf_remove_text_stamp_name
}

///|
fn pdf_remove_text_is_stamp_bmc(op : PdfContentOp) -> Bool {
  match op {
    Op_BMC(tag) => tag == pdf_remove_text_stamp()
    _ => false
  }
}

///|
fn pdf_remove_text_after_stamp(
  ops : ArrayView[PdfContentOp],
  start : Int,
) -> Int {
  let mut index = start
  let mut level = 1
  while index < ops.length() {
    let op = ops[index]
    if pdf_remove_text_is_stamp_bmc(op) {
      level += 1
      index += 1
    } else {
      match op {
        Op_EMC => {
          level -= 1
          index += 1
          if level == 0 {
            break index
          }
        }
        _ => index += 1
      }
    }
  } nobreak {
    ops.length()
  }
}

///|
/// Remove content marked as `/CPDFSTAMP`, matching cpdf's add-text cleanup.
///
/// Nested `/CPDFSTAMP ... EMC` sections are skipped as a unit. If a stamp block
/// is unterminated, all following operators are dropped, matching the OCaml
/// recursive removal behavior.
pub fn pdf_remove_added_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  let mut index = 0
  while index < ops.length() {
    let op = ops[index]
    if pdf_remove_text_is_stamp_bmc(op) {
      index = pdf_remove_text_after_stamp(ops, index + 1)
    } else {
      output.push(op)
      index += 1
    }
  }
  output
}

///|
fn pdf_remove_text_is_text_showing_op(op : PdfContentOp) -> Bool {
  match op {
    Op_Tj(_) | Op_TJ(_) | Op_quote(_) | Op_double_quote(_, _, _) => true
    _ => false
  }
}

///|
/// Remove text-showing operators while preserving text positioning/state ops.
pub fn pdf_remove_all_text_ops(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in ops {
    if !pdf_remove_text_is_text_showing_op(op) {
      output.push(op)
    }
  }
  output
}

///|
fn PdfDocument::pdf_remove_text_page(
  self : PdfDocument,
  page : PdfPage,
  transform : (ArrayView[PdfContentOp]) -> Array[PdfContentOp],
) -> PdfPage raise PdfError {
  let ops = self.pdf_page_parse_content_ops(page.resources, page.content)
  { ..page, content: [pdf_content_stream_of_ops(transform(ops))] }
}

///|
fn pdf_remove_text_all_text_xobject(
  document : PdfDocument,
  resources : PdfObject,
  streams : ArrayView[PdfObject],
) -> Array[PdfObject] raise PdfError {
  let ops = document.pdf_page_parse_content_ops(resources, streams)
  [pdf_content_stream_of_ops(pdf_remove_all_text_ops(ops))]
}

///|
/// Remove text added by cpdf add-text stamping from selected one-based pages.
pub fn PdfDocument::remove_added_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      rewritten.push(self.pdf_remove_text_page(page, pdf_remove_added_text_ops))
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_added_text`.
pub fn pdf_remove_added_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_added_text(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfremovetext's source-spelled `removetext`.
pub fn pdf_removetext(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_added_text(page_numbers)
}

///|
/// Remove all text-showing operators from selected one-based pages and their
/// referenced Form XObjects.
pub fn PdfDocument::remove_all_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      document.process_xobjects(page, pdf_remove_text_all_text_xobject)
      rewritten.push(
        document.pdf_remove_text_page(page, pdf_remove_all_text_ops),
      )
    } else {
      rewritten.push(page)
    }
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_all_text`.
pub fn pdf_remove_all_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.remove_all_text(page_numbers)
}

///|
/// Compatibility wrapper matching cpdfremovetext's page-list-first order.
pub fn pdf_remove_all_text_cpdf_order(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_all_text(page_numbers)
}
