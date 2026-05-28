///|
fn pdf_dest_read_target_page(object : PdfObject) -> PdfTargetPage? {
  match object {
    PdfIndirect(number) => Some(TargetPageObject(number))
    PdfInteger(number) => Some(TargetOtherDocPageNumber(number))
    _ => None
  }
}

///|
fn PdfDocument::pdf_dest_optional_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double? raise PdfError {
  match object {
    PdfNull => None
    _ => Some(self.get_number(object))
  }
}

///|
fn pdf_dest_bytes_equal(left : PdfBytes, right : PdfBytes) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for i in 0..<left.length() {
      if left[i] != right[i] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn PdfDocument::pdf_dest_catalog(
  self : PdfDocument,
) -> PdfObject raise PdfError {
  self.catalog()
}

///|
fn PdfDocument::pdf_dest_lookup_string_destination(
  self : PdfDocument,
  key : PdfBytes,
) -> PdfObject? raise PdfError {
  let catalog = self.pdf_dest_catalog()
  match self.lookup_direct(pdf_dest_names_key(), catalog) {
    Some(names_dict) =>
      match self.lookup_direct(pdf_dest_dests_key(), names_dict) {
        Some(dests_tree) =>
          for entry in self.read_name_tree(dests_tree) {
            let (candidate, destination) = entry
            if pdf_dest_bytes_equal(candidate, key) {
              break Some(destination)
            }
          } nobreak {
            None
          }
        None => None
      }
    None => None
  }
}

///|
/// Reads and normalizes a PDF destination object.
///
/// When `shallow` is false, named and string destinations are resolved through
/// the document catalog when possible. Unknown or malformed destination shapes
/// are represented as `DestNull`.
pub fn PdfDocument::read_destination(
  self : PdfDocument,
  object : PdfObject,
  shallow? : Bool = false,
) -> PdfDestination raise PdfError {
  match self.direct(object) {
    PdfDictionary(_) as dictionary =>
      match self.lookup_direct(pdf_dest_d_key(), dictionary) {
        Some(destination) => self.read_destination(destination, shallow~)
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left, top, zoom]) if kind ==
      pdf_dest_type_xyz() =>
      match pdf_dest_read_target_page(page) {
        Some(target) =>
          DestXYZ(
            target,
            self.pdf_dest_optional_number(left),
            self.pdf_dest_optional_number(top),
            self.pdf_dest_optional_number(zoom),
          )
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left, top]) if kind ==
      pdf_dest_type_xyz() =>
      match pdf_dest_read_target_page(page) {
        Some(target) =>
          DestXYZ(
            target,
            self.pdf_dest_optional_number(left),
            self.pdf_dest_optional_number(top),
            None,
          )
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left]) if kind == pdf_dest_type_xyz() =>
      match pdf_dest_read_target_page(page) {
        Some(target) =>
          DestXYZ(target, self.pdf_dest_optional_number(left), None, None)
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind)]) if kind == pdf_dest_type_fit() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFit(target)
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), top]) if kind == pdf_dest_type_fith() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFitH(target, self.pdf_dest_optional_number(top))
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left]) if kind == pdf_dest_type_fitv() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFitV(target, self.pdf_dest_optional_number(left))
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left, bottom, right, top]) if kind ==
      pdf_dest_type_fitr() =>
      match pdf_dest_read_target_page(page) {
        Some(target) =>
          DestFitR(
            target,
            self.get_number(left),
            self.get_number(bottom),
            self.get_number(right),
            self.get_number(top),
          )
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind)]) if kind == pdf_dest_type_fitb() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFitB(target)
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), top]) if kind == pdf_dest_type_fitbh() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFitBH(target, self.pdf_dest_optional_number(top))
        None => DestNull
      }
    PdfArray([page, PdfNameObject(kind), left]) if kind == pdf_dest_type_fitbv() =>
      match pdf_dest_read_target_page(page) {
        Some(target) => DestFitBV(target, self.pdf_dest_optional_number(left))
        None => DestNull
      }
    PdfNameObject(name) =>
      if shallow {
        DestNamed(name)
      } else {
        let catalog = self.pdf_dest_catalog()
        match self.lookup_direct(pdf_dest_dests_key(), catalog) {
          Some(dests) =>
            match self.lookup_direct(name, dests) {
              Some(destination) => self.read_destination(destination, shallow~)
              None => DestNamed(name)
            }
          None => DestNamed(name)
        }
      }
    PdfString(key) =>
      if shallow {
        DestString(key)
      } else {
        match self.pdf_dest_lookup_string_destination(key) {
          Some(destination) => self.read_destination(destination, shallow~)
          None => DestString(key)
        }
      }
    _ => DestNull
  }
}

///|
/// Reads and normalizes a PDF destination object.
///
/// This is the standalone form of `PdfDocument::read_destination`.
pub fn pdf_read_destination(
  document : PdfDocument,
  object : PdfObject,
  shallow? : Bool = false,
) -> PdfDestination raise PdfError {
  document.read_destination(object, shallow~)
}
