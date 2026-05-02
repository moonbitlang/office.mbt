///|
pub(all) struct PdfRectangle {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
} derive(Debug, Eq, ToJson)

///|
fn double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn PdfDocument::direct_depth(
  self : PdfDocument,
  object : PdfObject,
  depth : Int,
) -> PdfObject {
  if depth > 1024 {
    PdfNull
  } else {
    match object {
      PdfIndirect(number) =>
        match self.objects.get_entry(number) {
          Some({ data: ObjectParsed(value), .. }) =>
            self.direct_depth(value, depth + 1)
          Some({ data: ObjectParsedAlreadyDecrypted(value), .. }) =>
            self.direct_depth(value, depth + 1)
          _ => PdfNull
        }
      _ => object
    }
  }
}

///|
pub fn PdfDocument::direct(self : PdfDocument, object : PdfObject) -> PdfObject {
  self.direct_depth(object, 0)
}

///|
pub fn PdfDocument::lookup_direct(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for i = 0; i < entries.length(); i = i + 1 {
        let (name, value) = entries[i]
        if name == key {
          let direct_value = self.direct(value)
          break if direct_value == PdfNull { None } else { Some(direct_value) }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
pub fn PdfDocument::lookup_direct_or_else(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(first_key, object) {
    Some(value) => Some(value)
    None => self.lookup_direct(second_key, object)
  }
}

///|
fn pdf_lookup_array_index_name(name : PdfName) -> Int? {
  let bytes = name.bytes()
  guard bytes.length() >= 3 &&
    bytes[0].to_int() == 47 &&
    bytes[1].to_int() == 91 else {
    return None
  }
  let first = bytes[2].to_int()
  guard first >= 48 && first <= 57 else { return None }
  let mut value = 0
  let mut index = 2
  while index < bytes.length() {
    let byte = bytes[index].to_int()
    if byte < 48 || byte > 57 {
      break
    }
    value = value * 10 + byte - 48
    index += 1
  }
  Some(value)
}

///|
pub fn PdfDocument::lookup_direct_or_array(
  self : PdfDocument,
  name : PdfName,
  object : PdfObject,
) -> PdfObject? {
  match pdf_lookup_array_index_name(name) {
    Some(index) =>
      match object {
        PdfArray(values) =>
          match values.get(index) {
            Some(value) => Some(self.direct(value))
            None => None
          }
        _ => None
      }
    None => self.lookup_direct(name, object)
  }
}

///|
pub fn PdfDocument::lookup_chain(
  self : PdfDocument,
  start : PdfObject,
  keys : ArrayView[PdfName],
) -> PdfObject? {
  let mut current = start
  for i = 0; i < keys.length(); i = i + 1 {
    match self.lookup_direct_or_array(keys[i], current) {
      Some(next) => current = next
      None => break None
    }
  } nobreak {
    Some(current)
  }
}

///|
pub fn PdfDocument::get_number(
  self : PdfDocument,
  object : PdfObject,
) -> Double raise PdfError {
  match self.direct(object) {
    PdfReal(value) => value
    PdfInteger(value) => value.to_double()
    _ => raise NumberExpected
  }
}

///|
pub fn PdfDocument::parse_rectangle(
  self : PdfDocument,
  object : PdfObject,
) -> PdfRectangle raise PdfError {
  match self.direct(object) {
    PdfArray(values) if values.length() == 4 => {
      let x0 = try? self.get_number(values[0])
      let y0 = try? self.get_number(values[1])
      let x1 = try? self.get_number(values[2])
      let y1 = try? self.get_number(values[3])
      match (x0, y0, x1, y1) {
        (Ok(x0), Ok(y0), Ok(x1), Ok(y1)) =>
          {
            min_x: double_min(x0, x1),
            min_y: double_min(y0, y1),
            max_x: double_max(x0, x1),
            max_y: double_max(y0, y1),
          }
        _ => raise BadRectangle
      }
    }
    _ => raise RectangleExpected
  }
}

///|
pub fn PdfDocument::parse_matrix(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> TransformMatrix raise PdfError {
  match self.lookup_direct(key, object) {
    None => transform_identity_matrix
    Some(PdfArray(values)) if values.length() == 6 =>
      {
        a: self.get_number(values[0]),
        b: self.get_number(values[1]),
        c: self.get_number(values[2]),
        d: self.get_number(values[3]),
        e: self.get_number(values[4]),
        f: self.get_number(values[5]),
      }
    _ => raise MatrixMalformed
  }
}

///|
pub fn pdf_object_of_matrix(matrix : TransformMatrix) -> PdfObject {
  PdfArray([
    PdfReal(matrix.a),
    PdfReal(matrix.b),
    PdfReal(matrix.c),
    PdfReal(matrix.d),
    PdfReal(matrix.e),
    PdfReal(matrix.f),
  ])
}
