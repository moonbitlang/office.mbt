///|
fn pdf_dest_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_dest_d_key_name : PdfName = pdf_dest_name("/D")

///|
fn pdf_dest_d_key() -> PdfName {
  pdf_dest_d_key_name
}

///|
let pdf_dest_s_key_name : PdfName = pdf_dest_name("/S")

///|
fn pdf_dest_s_key() -> PdfName {
  pdf_dest_s_key_name
}

///|
let pdf_dest_goto_name_value : PdfName = pdf_dest_name("/GoTo")

///|
fn pdf_dest_goto_name() -> PdfName {
  pdf_dest_goto_name_value
}

///|
let pdf_dest_dests_key_name : PdfName = pdf_dest_name("/Dests")

///|
fn pdf_dest_dests_key() -> PdfName {
  pdf_dest_dests_key_name
}

///|
let pdf_dest_names_key_name : PdfName = pdf_dest_name("/Names")

///|
fn pdf_dest_names_key() -> PdfName {
  pdf_dest_names_key_name
}

///|
let pdf_dest_type_xyz_name : PdfName = pdf_dest_name("/XYZ")

///|
fn pdf_dest_type_xyz() -> PdfName {
  pdf_dest_type_xyz_name
}

///|
let pdf_dest_type_fit_name : PdfName = pdf_dest_name("/Fit")

///|
fn pdf_dest_type_fit() -> PdfName {
  pdf_dest_type_fit_name
}

///|
let pdf_dest_type_fith_name : PdfName = pdf_dest_name("/FitH")

///|
fn pdf_dest_type_fith() -> PdfName {
  pdf_dest_type_fith_name
}

///|
let pdf_dest_type_fitv_name : PdfName = pdf_dest_name("/FitV")

///|
fn pdf_dest_type_fitv() -> PdfName {
  pdf_dest_type_fitv_name
}

///|
let pdf_dest_type_fitr_name : PdfName = pdf_dest_name("/FitR")

///|
fn pdf_dest_type_fitr() -> PdfName {
  pdf_dest_type_fitr_name
}

///|
let pdf_dest_type_fitb_name : PdfName = pdf_dest_name("/FitB")

///|
fn pdf_dest_type_fitb() -> PdfName {
  pdf_dest_type_fitb_name
}

///|
let pdf_dest_type_fitbh_name : PdfName = pdf_dest_name("/FitBH")

///|
fn pdf_dest_type_fitbh() -> PdfName {
  pdf_dest_type_fitbh_name
}

///|
let pdf_dest_type_fitbv_name : PdfName = pdf_dest_name("/FitBV")

///|
fn pdf_dest_type_fitbv() -> PdfName {
  pdf_dest_type_fitbv_name
}

///|
/// A destination target page reference.
///
/// PDF destination arrays may refer either to a page object or to a page number
/// in another document.
pub(all) enum PdfTargetPage {
  TargetPageObject(Int)
  TargetOtherDocPageNumber(Int)
} derive(Debug, Eq, ToJson)

///|
/// A normalized PDF destination.
///
/// The variants cover action dictionaries, named/string destinations, null
/// destinations, and all standard page-view destination array forms.
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
/// Converts a normalized destination back to a PDF object.
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
  target : PdfTargetPage,
) -> Int {
  match target {
    TargetOtherDocPageNumber(number) => number + 1
    TargetPageObject(object_number) => page_numbers.page_number(object_number)
  }
}

///|
fn PdfDocument::pdf_destination_page_number_with_lookup(
  self : PdfDocument,
  destination : PdfDestination,
  page_numbers : PdfPageNumberLookup,
) -> Int raise PdfError {
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
  destination : PdfDestination,
  page_reference_numbers : ArrayView[Int],
) -> Int raise PdfError {
  self.pdf_destination_page_number_with_lookup(
    destination,
    pdf_page_number_lookup(page_reference_numbers),
  )
}

///|
fn pdf_dest_clip(value : Double) -> Double {
  if value < -32768.0 {
    -32768.0
  } else if value > 32768.0 {
    32768.0
  } else {
    value
  }
}

///|
fn pdf_dest_transform_point(
  matrix : TransformMatrix,
  x : Double,
  y : Double,
) -> Point2 {
  let point = matrix.apply(point2(x, y))
  point2(pdf_dest_clip(point.x), pdf_dest_clip(point.y))
}

///|
/// Applies a page transform matrix to destination coordinates.
///
/// Only destinations tied to page objects are transformed. Named destinations,
/// string destinations, non-page-number actions, and already page-number-based
/// targets are preserved.
pub fn PdfDocument::transform_destination(
  self : PdfDocument,
  matrix : TransformMatrix,
  destination : PdfDestination,
) -> PdfDestination raise PdfError {
  match destination {
    DestFitH(TargetPageObject(_) as target, Some(top)) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestFitH(target, Some(point.y))
    }
    DestFitV(TargetPageObject(_) as target, Some(left)) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestFitV(target, Some(point.x))
    }
    DestFitBH(TargetPageObject(_) as target, Some(top)) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestFitBH(target, Some(point.y))
    }
    DestFitBV(TargetPageObject(_) as target, Some(left)) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestFitBV(target, Some(point.x))
    }
    DestXYZ(TargetPageObject(_) as target, Some(left), Some(top), zoom) => {
      let point = pdf_dest_transform_point(matrix, left, top)
      DestXYZ(target, Some(point.x), Some(point.y), zoom)
    }
    DestXYZ(TargetPageObject(_) as target, None, Some(top), zoom) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestXYZ(target, None, Some(point.y), zoom)
    }
    DestXYZ(TargetPageObject(_) as target, Some(left), None, zoom) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestXYZ(target, Some(point.x), None, zoom)
    }
    DestFitR(TargetPageObject(_) as target, left, bottom, right, top) => {
      let left_top = pdf_dest_transform_point(matrix, left, top)
      let right_bottom = pdf_dest_transform_point(matrix, right, bottom)
      DestFitR(target, left_top.x, right_bottom.y, right_bottom.x, left_top.y)
    }
    DestAction(action) =>
      match
        (
          self.lookup_direct(pdf_dest_s_key(), action),
          self.lookup_direct(pdf_dest_d_key(), action),
        ) {
        (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
          pdf_dest_goto_name() =>
          DestAction(
            action.add_dict_entry(
              pdf_dest_d_key(),
              pdf_object_of_destination(
                self.transform_destination(
                  matrix,
                  self.read_destination(raw_destination, shallow=true),
                ),
              ),
            ),
          )
        _ => destination
      }
    _ => destination
  }
}

///|
/// Applies a page transform matrix to destination coordinates.
///
/// This is the standalone form of `PdfDocument::transform_destination`.
pub fn pdf_transform_destination(
  document : PdfDocument,
  matrix : TransformMatrix,
  destination : PdfDestination,
) -> PdfDestination raise PdfError {
  document.transform_destination(matrix, destination)
}
