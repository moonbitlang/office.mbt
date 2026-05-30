///|
fn pdf_object_of_target_page(target : @destination.PdfTargetPage) -> PdfObject {
  match target {
    TargetPageObject(number) => PdfIndirect(number)
    TargetOtherDocPageNumber(number) => PdfInteger(number)
  }
}

///|
fn pdf_dest_optional_object(value : Double?) -> PdfObject {
  match value {
    Some(number) => PdfReal(number)
    None => PdfNull
  }
}

///|
/// Converts a normalized destination back to a PDF object.
pub fn pdf_object_of_destination(
  destination : @destination.PdfDestination,
) -> PdfObject {
  match destination {
    DestAction(action) => action
    DestNull => PdfNull
    DestNamed(name) => PdfNameObject(name)
    DestString(text) => PdfString(text)
    DestXYZ(target, left, top, zoom) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_xyz()),
        pdf_dest_optional_object(left),
        pdf_dest_optional_object(top),
        pdf_dest_optional_object(zoom),
      ])
    DestFit(target) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fit()),
      ])
    DestFitH(target, top) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fith()),
        pdf_dest_optional_object(top),
      ])
    DestFitV(target, left) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fitv()),
        pdf_dest_optional_object(left),
      ])
    DestFitR(target, left, bottom, right, top) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fitr()),
        PdfReal(left),
        PdfReal(bottom),
        PdfReal(right),
        PdfReal(top),
      ])
    DestFitB(target) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fitb()),
      ])
    DestFitBH(target, top) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fitbh()),
        pdf_dest_optional_object(top),
      ])
    DestFitBV(target, left) =>
      PdfArray([
        pdf_object_of_target_page(target),
        PdfNameObject(pdf_dest_type_fitbv()),
        pdf_dest_optional_object(left),
      ])
  }
}
