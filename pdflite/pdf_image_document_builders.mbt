///|
fn PdfDocument::pdf_image_add_structure_tree(
  self : PdfDocument,
  subformat : PdfUASubformat?,
  title : String,
) -> Unit raise PdfError {
  let structure_root_number = self.add_object(PdfNull)
  let figure_number = self.add_object(PdfNull)
  let parent_tree_number = self.add_object(PdfNull)
  let figure_reference = @syntax.PdfIndirect(figure_number)
  let parent_tree = @syntax.PdfDictionary([
    (
      pdf_image_nums_key(),
      PdfArray([PdfInteger(1), PdfArray([figure_reference])]),
    ),
  ])
  self.add_object_given_number(parent_tree_number, parent_tree)
  match subformat {
    Some(PdfUA2) => {
      let ns_object = @syntax.PdfIndirect(
        self.add_object(
          PdfDictionary([
            (pdf_image_ns_key(), PdfString(pdf_image_pdfua2_namespace)),
          ]),
        ),
      )
      let document_number = self.add_object(PdfNull)
      self.add_object_given_number(
        document_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([figure_reference])),
          (pdf_image_p_key(), PdfIndirect(structure_root_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_document_name())),
          (pdf_image_ns_key(), ns_object),
        ]),
      )
      self.add_object_given_number(
        figure_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([PdfInteger(0)])),
          (pdf_image_p_key(), PdfIndirect(document_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_figure_name())),
          (pdf_image_alt_key(), PdfString(@utf8.encode(title))),
        ]),
      )
      self.add_object_given_number(
        structure_root_number,
        PdfDictionary([
          (pdf_image_namespaces_key(), PdfArray([ns_object])),
          (pdf_ua_type_key(), PdfNameObject(pdf_ua_struct_tree_root())),
          (pdf_structure_k_key(), PdfArray([PdfIndirect(document_number)])),
          (pdf_structure_parent_tree_key(), PdfIndirect(parent_tree_number)),
        ]),
      )
    }
    _ => {
      self.add_object_given_number(
        figure_number,
        PdfDictionary([
          (pdf_structure_k_key(), PdfArray([PdfInteger(0)])),
          (pdf_image_p_key(), PdfIndirect(structure_root_number)),
          (pdf_image_s_key(), PdfNameObject(pdf_image_figure_name())),
          (pdf_image_alt_key(), PdfString(@utf8.encode(title))),
        ]),
      )
      self.add_object_given_number(
        structure_root_number,
        PdfDictionary([
          (pdf_ua_type_key(), PdfNameObject(pdf_ua_struct_tree_root())),
          (pdf_structure_k_key(), PdfArray([figure_reference])),
          (pdf_structure_parent_tree_key(), PdfIndirect(parent_tree_number)),
        ]),
      )
    }
  }
  self.replace_chain(
    [pdf_structure_root_key(), pdf_structure_struct_tree_root_key()],
    PdfIndirect(structure_root_number),
  )
}

///|
fn pdf_image_title_for_subformat(
  subformat : PdfUASubformat?,
  title : String?,
) -> String raise PdfError {
  match (subformat, title) {
    (Some(_), Some(title)) => title
    (Some(_), None) => raise TitleExpected
    (None, Some(title)) => title
    (None, None) => ""
  }
}

///|
fn pdf_image_content_ops(
  structinfo : Bool,
  width : Int,
  height : Int,
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = Array::new(
    capacity=if structinfo { 4 } else { 2 },
  )
  if structinfo {
    output.push(
      Op_BDC(
        pdf_image_figure_name(),
        PdfDictionary([(pdf_image_mcid_key(), PdfInteger(0))]),
      ),
    )
  }
  output.push(
    Op_cm({
      ..@geometry.transform_identity_matrix,
      a: width.to_double(),
      d: height.to_double(),
    }),
  )
  output.push(Op_Do(pdf_image_i0_name()))
  if structinfo {
    output.push(Op_EMC)
  }
  output
}

///|
fn PdfDocument::pdf_image_add_image_page(
  self : PdfDocument,
  image : PdfObject,
  process_struct_tree : Bool,
  subformat : PdfUASubformat?,
  title : String?,
) -> Unit raise PdfError {
  let title = pdf_image_title_for_subformat(subformat, title)
  let structinfo = process_struct_tree || subformat != None
  let width = self.pdf_image_lookup_int_or_else(
    pdf_image_width_key(),
    pdf_image_w_key(),
    image,
  )
  let height = self.pdf_image_lookup_int_or_else(
    pdf_image_height_key(),
    pdf_image_h_key(),
    image,
  )
  let image_number = self.add_object(image)
  let page : @page.PdfPage = {
    content: [
      pdf_content_stream_of_ops(
        pdf_image_content_ops(structinfo, width, height),
      ),
    ],
    mediabox: PdfArray([
      PdfReal(0.0),
      PdfReal(0.0),
      PdfReal(width.to_double()),
      PdfReal(height.to_double()),
    ]),
    resources: PdfDictionary([
      (
        pdf_image_xobject_key(),
        PdfDictionary([(pdf_image_i0_name(), PdfIndirect(image_number))]),
      ),
    ]),
    rotate: Rotate0,
    rest: if structinfo {
      PdfDictionary([(pdf_image_struct_parents_key(), PdfInteger(1))])
    } else {
      PdfDictionary([])
    },
  }
  let page_root = self.add_pagetree([page])
  ignore(self.add_root(page_root, []))
  if structinfo {
    self.pdf_image_add_structure_tree(subformat, title)
  }
  match subformat {
    Some(subformat) => self.pdf_ua_apply_subformat_metadata(subformat, title)
    None => ()
  }
}

///|
/// Build a single-page PDF document that draws `image` at its natural size.
pub fn pdf_image_document_of_object(
  image : PdfObject,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Compatibility wrapper matching cpdfimage's `image_of_input`.
///
/// The input side is represented by a byte view instead of `Pdfio.input`;
/// `object_of_data` receives the document so PNG masks and similar side objects
/// can be added through the same document before the page is built.
pub fn pdf_image_of_input(
  data : BytesView,
  object_of_data : (PdfDocument, BytesView) -> (
    PdfObject,
    Array[(Int, PdfObject)],
  ) raise PdfError,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let (image, extra_objects) = object_of_data(document, data)
  for extra in extra_objects {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Build a single-page PDF document from JPEG data.
pub fn pdf_image_document_of_jpeg_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_image_document_of_object(
    pdf_image_object_of_jpeg_data(data),
    process_struct_tree~,
    subformat~,
    title~,
  )
}

///|
/// Build a single-page PDF document from JPEG2000 data.
pub fn pdf_image_document_of_jpeg2000_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_image_document_of_object(
    pdf_image_object_of_jpeg2000_data(data),
    process_struct_tree~,
    subformat~,
    title~,
  )
}

///|
/// Build a single-page PDF document from PNG data.
pub fn pdf_image_document_of_png_data(
  data : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let image = document.pdf_image_object_of_png_data(data)
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}

///|
/// Build a single-page PDF document from JBIG2 data.
pub fn pdf_image_document_of_jbig2_data(
  data : BytesView,
  global? : BytesView? = None,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let document = pdf_document_empty()
  let (image, extra_objects) = pdf_image_object_of_jbig2_data(data, global~)
  for extra in extra_objects {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_image_add_image_page(
    image, process_struct_tree, subformat, title,
  )
  document
}
