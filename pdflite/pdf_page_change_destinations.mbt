///|
priv struct PdfPageMatrixLookup {
  page_numbers : PdfPageNumberLookup
  matrices : @hashmap.HashMap[Int, @geometry.TransformMatrix]
}

///|
fn pdf_page_matrix_lookup(
  matrices : ArrayView[(Int, @geometry.TransformMatrix)],
  page_reference_numbers : ArrayView[Int],
) -> PdfPageMatrixLookup {
  let values : @hashmap.HashMap[Int, @geometry.TransformMatrix] = HashMap([])
  for entry in matrices {
    let (matrix_page_number, matrix) = entry
    if !values.contains(matrix_page_number) {
      values[matrix_page_number] = matrix
    }
  }
  {
    page_numbers: pdf_page_number_lookup(page_reference_numbers),
    matrices: values,
  }
}

///|
fn PdfPageMatrixLookup::matrix_for_page_number(
  self : PdfPageMatrixLookup,
  page_number : Int,
) -> @geometry.TransformMatrix? {
  self.matrices.get(page_number)
}

///|
fn PdfPageMatrixLookup::page_number_of_target(
  self : PdfPageMatrixLookup,
  target : @destination.PdfTargetPage,
) -> Int {
  match target {
    TargetPageObject(object_number) =>
      self.page_numbers.page_number(object_number)
    TargetOtherDocPageNumber(_) => 0
  }
}

///|
fn PdfDocument::pdf_page_matrix_for_destination_with_lookup(
  self : PdfDocument,
  destination : @destination.PdfDestination,
  lookup : PdfPageMatrixLookup,
) -> @geometry.TransformMatrix? raise @core.PdfError {
  let page_number = self.pdf_page_matrix_page_number_for_destination_with_lookup(
    destination, lookup,
  )
  if page_number == 0 {
    None
  } else {
    lookup.matrix_for_page_number(page_number)
  }
}

///|
fn PdfDocument::pdf_page_matrix_page_number_for_destination_with_lookup(
  self : PdfDocument,
  destination : @destination.PdfDestination,
  lookup : PdfPageMatrixLookup,
) -> Int raise @core.PdfError {
  match destination {
    DestNamed(_) | DestString(_) => {
      let resolved = self.read_destination(
        pdf_object_of_destination(destination),
      )
      if resolved == destination {
        0
      } else {
        self.pdf_page_matrix_page_number_for_destination_with_lookup(
          resolved, lookup,
        )
      }
    }
    DestAction(action) =>
      match
        (
          self.lookup_direct(pdf_dest_s_key(), action),
          self.lookup_direct(pdf_dest_d_key(), action),
        ) {
        (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
          pdf_dest_goto_name() =>
          self.pdf_page_matrix_page_number_for_destination_with_lookup(
            self.read_destination(raw_destination),
            lookup,
          )
        _ => 0
      }
    DestXYZ(target, _, _, _)
    | DestFitH(target, _)
    | DestFitV(target, _)
    | DestFitR(target, _, _, _, _)
    | DestFitBH(target, _)
    | DestFitBV(target, _) => lookup.page_number_of_target(target)
    _ => 0
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object_with_lookup(
  self : PdfDocument,
  raw_destination : @syntax.PdfObject,
  lookup : PdfPageMatrixLookup,
) -> @syntax.PdfObject? raise @core.PdfError {
  match
    self.pdf_page_transform_destination_object_with_shallow_lookup(
      raw_destination, lookup, false,
    ) {
    Some(destination) => Some(PdfIndirect(self.add_object(destination)))
    None => None
  }
}

///|
fn PdfDocument::pdf_page_transform_destination_object_with_shallow_lookup(
  self : PdfDocument,
  raw_destination : @syntax.PdfObject,
  lookup : PdfPageMatrixLookup,
  shallow : Bool,
) -> @syntax.PdfObject? raise @core.PdfError {
  let destination = self.read_destination(raw_destination, shallow~)
  match self.pdf_page_matrix_for_destination_with_lookup(destination, lookup) {
    Some(matrix) if matrix != @geometry.transform_identity_matrix =>
      Some(
        pdf_object_of_destination(
          self.transform_destination(matrix, destination),
        ),
      )
    _ => None
  }
}
