///|
fn PdfDocument::pdf_addtext_opacity_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  opacity : Double,
) -> (@syntax.PdfObject, @core.PdfName?) raise @core.PdfError {
  if opacity < 1.0 {
    let extgstate = match
      self.lookup_direct(pdf_addtext_extgstate_key(), resources) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    let name = extgstate.unique_key("gs")
    let opacity_dictionary = @syntax.PdfDictionary([
      (pdf_addtext_ca_key(), PdfReal(opacity)),
      (pdf_addtext_ca_stroke_key(), PdfReal(opacity)),
    ])
    (
      resources.add_dict_entry(
        pdf_addtext_extgstate_key(),
        extgstate.add_dict_entry(name, opacity_dictionary),
      ),
      Some(name),
    )
  } else {
    (resources, None)
  }
}

///|
/// Return resources updated with cpdf add-text opacity graphics state.
///
/// Opacity values below `1.0` allocate a unique `/gs*` entry under
/// `/ExtGState` with both fill and stroke alpha set. Opaque values leave the
/// resource dictionary unchanged and return no graphics-state name.
pub fn PdfDocument::addtext_opacity_resources(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  opacity : Double,
) -> (@syntax.PdfObject, @core.PdfName?) raise @core.PdfError {
  self.pdf_addtext_opacity_resources(resources, opacity)
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_opacity_resources`.
pub fn pdf_addtext_opacity_resources(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  opacity : Double,
) -> (@syntax.PdfObject, @core.PdfName?) raise @core.PdfError {
  document.addtext_opacity_resources(resources, opacity)
}

///|
/// Build the cpdf add-text fill colour operator.
pub fn pdf_addtext_colour_op(
  colour : @colour.PdfContentColour,
) -> @content.PdfContentOp {
  colour.pdf_tweak_fill_op()
}

///|
/// Source-spelled compatibility wrapper for cpdfaddtext's `colour_op`.
pub fn pdf_colour_op(
  colour : @colour.PdfContentColour,
) -> @content.PdfContentOp {
  pdf_addtext_colour_op(colour)
}

///|
/// Build the cpdf add-text stroke colour operator.
pub fn pdf_addtext_colour_op_stroke(
  colour : @colour.PdfContentColour,
) -> @content.PdfContentOp {
  colour.pdf_tweak_stroke_op()
}

///|
/// Source-spelled compatibility wrapper for cpdfaddtext's `colour_op_stroke`.
pub fn pdf_colour_op_stroke(
  colour : @colour.PdfContentColour,
) -> @content.PdfContentOp {
  pdf_addtext_colour_op_stroke(colour)
}
