///|
fn PdfDocument::pdf_page_stamp_protect_content(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
  fast : Bool,
) -> Array[PdfObject] raise PdfError {
  let deficit = if fast {
    0
  } else {
    let ops = self.pdf_page_parse_content_ops(resources, content)
    let mut saves = 0
    let mut restores = 0
    for op in ops {
      match op {
        Op_q => saves += 1
        Op_Q => restores += 1
        _ => ()
      }
    }
    if saves > restores {
      saves - restores
    } else {
      0
    }
  }
  let begin_number = self.add_object(pdf_content_stream_of_ops([Op_q]))
  let end_ops : Array[PdfContentOp] = []
  for _ in 0..<deficit {
    end_ops.push(Op_Q)
  }
  end_ops.push(Op_Q)
  let end_number = self.add_object(pdf_content_stream_of_ops(end_ops))
  let output : Array[PdfObject] = [PdfIndirect(begin_number)]
  for object in content {
    output.push(object)
  }
  output.push(PdfIndirect(end_number))
  output
}

///|
fn pdf_page_stamp_concat_content(
  first : ArrayView[PdfObject],
  second : ArrayView[PdfObject],
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  for object in first {
    output.push(object)
  }
  for object in second {
    output.push(object)
  }
  output
}

///|
fn PdfDocument::pdf_page_stamp_pair(
  self : PdfDocument,
  overlay_page : PdfPage,
  under_page : PdfPage,
  relative_to_box : PdfName,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
  scale_to_fit : Bool,
  is_over : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let overlay_page = self.pdf_page_stamp_transform_overlay(
    overlay_page, under_page, relative_to_box, position, topline, midline, scale_to_fit,
    fast,
  )
  let under_content = self.pdf_page_stamp_protect_content(
    under_page.resources,
    under_page.content,
    fast,
  )
  let overlay_content = self.pdf_page_stamp_protect_content(
    overlay_page.resources,
    overlay_page.content,
    fast,
  )
  {
    ..under_page,
    content: if is_over {
      pdf_page_stamp_concat_content(under_content, overlay_content)
    } else {
      pdf_page_stamp_concat_content(overlay_content, under_content)
    },
    rest: self.combine_pdf_rests(under_page.rest, overlay_page.rest),
    resources: self.combine_pdf_resources(
      under_page.resources,
      overlay_page.resources,
    ),
  }
}
