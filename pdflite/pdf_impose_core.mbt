///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_transform_content(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  matrix : @geometry.TransformMatrix,
  content : ArrayView[@syntax.PdfObject],
  fast : Bool,
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  if fast {
    let output : Array[@syntax.PdfObject] = [
      pdf_content_stream_of_ops([Op_q, Op_cm(matrix)]),
    ]
    pdf_impose_push_objects(output, content)
    output.push(pdf_content_stream_of_ops([Op_Q]))
    output
  } else {
    let old_ops = self.parse_content_ops_with_resources(resources, content)
    let protected_ops = pdf_page_concat_ops(pdf_page_protect(old_ops), old_ops)
    [
      pdf_content_stream_of_ops(
        pdf_page_concat_ops(
          [Op_q, Op_cm(matrix)],
          pdf_page_concat_ops(protected_ops, [Op_Q]),
        ),
      ),
    ]
  }
}

///|
fn PdfDocument::pdf_impose_combine_page_resources(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> @syntax.PdfObject {
  let mut resources = pages[0].resources
  for index in 1..<pages.length() {
    resources = self.combine_pdf_resources(resources, pages[index].resources)
  }
  resources
}

///|
fn PdfDocument::pdf_impose_combine_page_rests(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
) -> @syntax.PdfObject {
  let mut rest = pages[0].rest
  for index in 1..<pages.length() {
    rest = self.combine_pdf_rests(rest, pages[index].rest)
  }
  rest
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_pages_core(
  self : PdfDocument,
  pages : ArrayView[@page.PdfPage],
  fit : Bool,
  x : Int,
  y : Int,
  columns : Bool,
  rtl : Bool,
  btt : Bool,
  center : Bool,
  margin : Double,
  output_mediabox : @syntax.PdfObject,
  fast : Bool,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
) -> @page.PdfPage raise @core.PdfError {
  if pages.length() == 0 {
    raise BadNumberArgument("impose: pages must not be empty")
  }
  let first_page = pages[0]
  let transforms = self.pdf_impose_transforms(
    fit,
    x,
    y,
    columns,
    rtl,
    btt,
    center,
    margin,
    first_page.mediabox,
    output_mediabox,
    fit_extra_hspace,
    fit_extra_vspace,
    pages.length(),
  )
  for index in 0..<pages.length() {
    self.transform_annotations(transforms[index], pages[index].rest)
  }
  let transformed_pages : Array[@page.PdfPage] = []
  for index in 0..<pages.length() {
    transformed_pages.push(
      self.pdf_impose_change_pattern_matrices_page(
        transforms[index],
        pages[index],
      ),
    )
  }
  let resources = self.pdf_impose_combine_page_resources(transformed_pages)
  let rest = self.pdf_impose_combine_page_rests(transformed_pages)
  let content : Array[@syntax.PdfObject] = []
  for index in 0..<transformed_pages.length() {
    pdf_impose_push_objects(
      content,
      self.pdf_impose_transform_content(
        resources,
        transforms[index],
        transformed_pages[index].content,
        fast,
      ),
    )
  }
  {
    mediabox: output_mediabox,
    rotate: first_page.rotate,
    content,
    resources,
    rest,
  }
}
