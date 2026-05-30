///|
priv struct PdfPageNumberLookup {
  values : @hashmap.HashMap[Int, Int]
}

///|
fn pdf_page_number_lookup(
  page_reference_numbers : ArrayView[Int],
) -> PdfPageNumberLookup {
  let values : @hashmap.HashMap[Int, Int] = HashMap([])
  for index in 0..<page_reference_numbers.length() {
    let object_number = page_reference_numbers[index]
    if !values.contains(object_number) {
      values[object_number] = index + 1
    }
  }
  { values, }
}

///|
fn PdfPageNumberLookup::page_number(
  self : PdfPageNumberLookup,
  object_number : Int,
) -> Int {
  match self.values.get(object_number) {
    Some(page_number) => page_number
    None => 0
  }
}

///|
fn pdf_destination_page_number_of_target(
  page_numbers : PdfPageNumberLookup,
  target : @destination.PdfTargetPage,
) -> Int {
  match target {
    TargetOtherDocPageNumber(number) => number + 1
    TargetPageObject(object_number) => page_numbers.page_number(object_number)
  }
}

///|
fn PdfDocument::pdf_destination_page_number_with_lookup(
  self : PdfDocument,
  destination : @destination.PdfDestination,
  page_numbers : PdfPageNumberLookup,
) -> Int raise @core.PdfError {
  match destination {
    DestNamed(_) | DestString(_) => {
      let resolved = self.read_destination(
        pdf_object_of_destination(destination),
      )
      if resolved == destination {
        0
      } else {
        self.pdf_destination_page_number_with_lookup(resolved, page_numbers)
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
          self.pdf_destination_page_number_with_lookup(
            self.read_destination(raw_destination),
            page_numbers,
          )
        _ => 0
      }
    DestXYZ(target, _, _, _)
    | DestFit(target)
    | DestFitH(target, _)
    | DestFitV(target, _)
    | DestFitR(target, _, _, _, _)
    | DestFitB(target)
    | DestFitBH(target, _)
    | DestFitBV(target, _) =>
      pdf_destination_page_number_of_target(page_numbers, target)
    _ => 0
  }
}

///|
fn PdfDocument::pdf_destination_page_number(
  self : PdfDocument,
  destination : @destination.PdfDestination,
  page_reference_numbers : ArrayView[Int],
) -> Int raise @core.PdfError {
  self.pdf_destination_page_number_with_lookup(
    destination,
    pdf_page_number_lookup(page_reference_numbers),
  )
}
