///|
fn pdf_dest_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_dest_d_key() -> PdfName {
  pdf_dest_name("/D")
}

///|
fn pdf_dest_root_key() -> PdfName {
  pdf_dest_name("/Root")
}

///|
fn pdf_dest_dests_key() -> PdfName {
  pdf_dest_name("/Dests")
}

///|
fn pdf_dest_names_key() -> PdfName {
  pdf_dest_name("/Names")
}

///|
fn pdf_dest_type_xyz() -> PdfName {
  pdf_dest_name("/XYZ")
}

///|
fn pdf_dest_type_fit() -> PdfName {
  pdf_dest_name("/Fit")
}

///|
fn pdf_dest_type_fith() -> PdfName {
  pdf_dest_name("/FitH")
}

///|
fn pdf_dest_type_fitv() -> PdfName {
  pdf_dest_name("/FitV")
}

///|
fn pdf_dest_type_fitr() -> PdfName {
  pdf_dest_name("/FitR")
}

///|
fn pdf_dest_type_fitb() -> PdfName {
  pdf_dest_name("/FitB")
}

///|
fn pdf_dest_type_fitbh() -> PdfName {
  pdf_dest_name("/FitBH")
}

///|
fn pdf_dest_type_fitbv() -> PdfName {
  pdf_dest_name("/FitBV")
}

///|
pub(all) enum PdfTargetPage {
  TargetPageObject(Int)
  TargetOtherDocPageNumber(Int)
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfDestination {
  DestAction(PdfObject)
  DestNull
  DestNamed(PdfName)
  DestString(PdfBytes)
  DestXYZ(PdfTargetPage, Double?, Double?, Double?)
  DestFit(PdfTargetPage)
  DestFitH(PdfTargetPage, Double?)
  DestFitV(PdfTargetPage, Double?)
  DestFitR(PdfTargetPage, Double, Double, Double, Double)
  DestFitB(PdfTargetPage)
  DestFitBH(PdfTargetPage, Double?)
  DestFitBV(PdfTargetPage, Double?)
} derive(Debug, Eq, ToJson)

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
fn PdfDocument::pdf_dest_lookup_string_destination(
  self : PdfDocument,
  key : PdfBytes,
) -> PdfObject? {
  let root_object = self.lookup_object_or_null(self.root())
  match self.lookup_direct(pdf_dest_names_key(), root_object) {
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
        match self.lookup_direct(pdf_dest_root_key(), self.trailer_dict()) {
          Some(catalog) =>
            match self.lookup_direct(pdf_dest_dests_key(), catalog) {
              Some(dests) =>
                match self.lookup_direct(name, dests) {
                  Some(destination) =>
                    self.read_destination(destination, shallow~)
                  None => DestNamed(name)
                }
              None => DestNamed(name)
            }
          None => raise RootExpected
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
fn pdf_object_of_target_page(target : PdfTargetPage) -> PdfObject {
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
pub fn pdf_object_of_destination(destination : PdfDestination) -> PdfObject {
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
