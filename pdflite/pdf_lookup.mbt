///|
/// A normalized rectangle in PDF user-space coordinates.
///
/// `min_x` and `min_y` are always the lower bounds, and `max_x` and
/// `max_y` are always the upper bounds. Parsers normalize PDF rectangle arrays
/// whose coordinates are written in the opposite order.
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
/// Resolve an object through the document object table.
///
/// Direct objects are returned unchanged. Indirect references are followed
/// recursively through parsed entries in `self.objects`; missing, unparsed, or
/// excessively deep references resolve to `PdfNull` rather than raising.
pub fn PdfDocument::direct(self : PdfDocument, object : PdfObject) -> PdfObject {
  self.direct_depth(object, 0)
}

///|
/// Look up `key` in a dictionary or stream dictionary and resolve the value.
///
/// The containing object is first passed through `direct`. If the object is not
/// dictionary-like, the key is absent, or the resolved value is `PdfNull`, this
/// returns `None`.
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
/// Look up a required dictionary entry and resolve the value.
///
/// This is the raising counterpart to `lookup_direct`: it raises the caller
/// supplied `error` when the containing object is not dictionary-like, when the
/// key is absent, or when the resolved value is `PdfNull`.
pub fn PdfDocument::lookup_required(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
  error : PdfError,
) -> PdfObject raise PdfError {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for entry in entries {
        if entry.0 == key {
          let direct_value = self.direct(entry.1)
          break if direct_value == PdfNull { raise error } else { direct_value }
        }
      } nobreak {
        raise error
      }
    None => raise error
  }
}

///|
/// Look up either of two alternative dictionary keys.
///
/// `first_key` is preferred. `second_key` is checked only when the first lookup
/// is absent or resolves to `PdfNull`.
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
/// Look up a dictionary entry, or address an array by a pseudo-key.
///
/// Names that begin with `/[` followed by decimal digits are treated as array
/// indexes when `object` is a `PdfArray`; other names are resolved with
/// `lookup_direct`. The returned value is resolved through `direct`.
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
/// Return the indirect object number stored under a dictionary key.
///
/// The containing object is resolved before lookup, but the entry itself is
/// inspected before dereferencing. This returns `Some(number)` only when the
/// immediate entry value is `PdfIndirect(number)`.
pub fn PdfDocument::indirect_number(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> Int? {
  match self.direct(object).dictionary_view() {
    Some(entries) =>
      for entry in entries {
        if entry.0 == key {
          break match entry.1 {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
fn pdf_lookup_wrap_chain(
  keys : ArrayView[PdfName],
  index : Int,
  value : PdfObject,
) -> PdfObject {
  if index >= keys.length() {
    value
  } else {
    pdf_dictionary([
      (keys[index], pdf_lookup_wrap_chain(keys, index + 1, value)),
    ])
  }
}

///|
fn pdf_lookup_replace_array_entry(
  values : ArrayView[PdfObject],
  index : Int,
  value : PdfObject,
  key : PdfName,
) -> PdfObject raise PdfError {
  if index < 0 || index >= values.length() {
    raise DictionaryKeyNotFound(key)
  } else {
    PdfArray(
      [
        for i in 0..<values.length() => {
          if i == index {
            value
          } else {
            values[i]
          }
        }
      ],
    )
  }
}

///|
fn PdfDocument::replace_chain_in_object(
  self : PdfDocument,
  object : PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
  value : PdfObject,
) -> PdfObject raise PdfError {
  let key = chain[chain_index]
  let final_key = chain_index + 1 == chain.length()
  match object {
    PdfDictionary(_) | PdfStreamObject(_) =>
      if final_key {
        object.add_dict_entry(key, value)
      } else {
        let replacement = match object.lookup_immediate(key) {
          Some(PdfIndirect(number)) => {
            let updated = self.replace_chain_in_object(
              self.lookup_object_or_null(number),
              chain,
              chain_index + 1,
              value,
            )
            self.add_object_given_number(number, updated)
            PdfIndirect(number)
          }
          Some(child) =>
            self.replace_chain_in_object(child, chain, chain_index + 1, value)
          None => pdf_lookup_wrap_chain(chain, chain_index + 1, value)
        }
        object.add_dict_entry(key, replacement)
      }
    PdfArray(values) =>
      match pdf_lookup_array_index_name(key) {
        Some(index) =>
          if final_key {
            pdf_lookup_replace_array_entry(values, index, value, key)
          } else {
            match values.get(index) {
              Some(PdfIndirect(number)) => {
                let updated = self.replace_chain_in_object(
                  self.lookup_object_or_null(number),
                  chain,
                  chain_index + 1,
                  value,
                )
                self.add_object_given_number(number, updated)
                object
              }
              Some(child) => {
                let updated = self.replace_chain_in_object(
                  child,
                  chain,
                  chain_index + 1,
                  value,
                )
                pdf_lookup_replace_array_entry(values, index, updated, key)
              }
              None => raise DictionaryKeyNotFound(key)
            }
          }
        None => raise DictionaryKeyNotFound(key)
      }
    _ => raise DictionaryExpected
  }
}

///|
/// Replace a value along a path rooted at the document trailer dictionary.
///
/// Each name in `chain` selects a dictionary entry. Names of the form `/[n]`
/// select array entries. Missing intermediate dictionary entries are created as
/// nested dictionaries, and indirect intermediate objects are updated in the
/// document object table. Raises when the chain is empty or when a non-container
/// or invalid array position is encountered.
pub fn PdfDocument::replace_chain(
  self : PdfDocument,
  chain : ArrayView[PdfName],
  value : PdfObject,
) -> Unit raise PdfError {
  if chain.length() == 0 {
    raise DictionaryExpected
  }
  self.trailer_dict = self.replace_chain_in_object(
    self.trailer_dict,
    chain,
    0,
    value,
  )
}

///|
fn PdfDocument::remove_chain_from_object(
  self : PdfDocument,
  object : PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
) -> (PdfObject, Bool) raise PdfError {
  let key = chain[chain_index]
  let final_key = chain_index + 1 == chain.length()
  match object {
    PdfDictionary(_) | PdfStreamObject(_) =>
      if final_key {
        match object.lookup_immediate(key) {
          Some(PdfNull) | None => (object, false)
          Some(_) => (object.remove_dict_entry(key), true)
        }
      } else {
        match object.lookup_immediate(key) {
          Some(PdfIndirect(number)) => {
            let (updated, removed) = self.remove_chain_from_object(
              self.lookup_object_or_null(number),
              chain,
              chain_index + 1,
            )
            if removed {
              self.add_object_given_number(number, updated)
            }
            (object, removed)
          }
          Some(PdfNull) | None => (object, false)
          Some(child) => {
            let (updated, removed) = self.remove_chain_from_object(
              child,
              chain,
              chain_index + 1,
            )
            if removed {
              (object.add_dict_entry(key, updated), true)
            } else {
              (object, false)
            }
          }
        }
      }
    PdfArray(values) =>
      match pdf_lookup_array_index_name(key) {
        Some(index) =>
          if final_key {
            raise DictionaryExpected
          } else {
            match values.get(index) {
              Some(PdfIndirect(number)) => {
                let (updated, removed) = self.remove_chain_from_object(
                  self.lookup_object_or_null(number),
                  chain,
                  chain_index + 1,
                )
                if removed {
                  self.add_object_given_number(number, updated)
                }
                (object, removed)
              }
              Some(child) => {
                let (updated, removed) = self.remove_chain_from_object(
                  child,
                  chain,
                  chain_index + 1,
                )
                if removed {
                  (
                    pdf_lookup_replace_array_entry(values, index, updated, key),
                    true,
                  )
                } else {
                  (object, false)
                }
              }
              None => (object, false)
            }
          }
        None => raise DictionaryKeyNotFound(key)
      }
    _ => raise DictionaryExpected
  }
}

///|
/// Remove a nested value along a path rooted at the trailer dictionary.
///
/// Returns `true` when an entry was removed and `false` when the path is
/// absent. Empty chains raise `DictionaryExpected`. A single-key chain is
/// treated as an invalid request when the key exists, preserving the trailer
/// root rather than removing one of its direct entries.
pub fn PdfDocument::remove_chain(
  self : PdfDocument,
  chain : ArrayView[PdfName],
) -> Bool raise PdfError {
  if chain.length() == 0 {
    raise DictionaryExpected
  }
  if chain.length() == 1 {
    match self.lookup_chain(self.trailer_dict, chain) {
      Some(_) => raise DictionaryExpected
      None => return false
    }
  }
  let (updated, removed) = self.remove_chain_from_object(
    self.trailer_dict,
    chain,
    0,
  )
  if removed {
    self.trailer_dict = updated
  }
  removed
}

///|
/// Follow a sequence of dictionary keys and array pseudo-keys.
///
/// Lookup starts from `start`; every successful step resolves indirect objects.
/// An empty key sequence returns `Some(start)`. If any step cannot be resolved,
/// the result is `None`.
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
/// Read a PDF numeric object as a `Double`.
///
/// The object is resolved first. PDF real numbers are returned directly and PDF
/// integers are widened to `Double`; any other object raises `NumberExpected`.
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
/// Parse and normalize a PDF rectangle array.
///
/// The input must resolve to an array of four numeric objects. Coordinates are
/// normalized so the result always has lower bounds in `min_x`/`min_y` and
/// upper bounds in `max_x`/`max_y`. Non-array inputs raise `RectangleExpected`;
/// malformed numeric entries raise `BadRectangle`.
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
/// Transform a rectangle and return the bounding PDF rectangle array.
///
/// All four corners are transformed with `matrix`, then the axis-aligned bounds
/// of those transformed points are written as `[minX minY maxX maxY]`.
pub fn PdfDocument::transform_rect(
  self : PdfDocument,
  matrix : TransformMatrix,
  object : PdfObject,
) -> PdfObject raise PdfError {
  let rectangle = self.parse_rectangle(object)
  let p0 = matrix.apply(point2(rectangle.min_x, rectangle.min_y))
  let p1 = matrix.apply(point2(rectangle.max_x, rectangle.max_y))
  let p2 = matrix.apply(point2(rectangle.min_x, rectangle.max_y))
  let p3 = matrix.apply(point2(rectangle.max_x, rectangle.min_y))
  PdfArray([
    PdfReal(double_min(double_min(p0.x, p1.x), double_min(p2.x, p3.x))),
    PdfReal(double_min(double_min(p0.y, p1.y), double_min(p2.y, p3.y))),
    PdfReal(double_max(double_max(p0.x, p1.x), double_max(p2.x, p3.x))),
    PdfReal(double_max(double_max(p0.y, p1.y), double_max(p2.y, p3.y))),
  ])
}

///|
fn PdfDocument::pdf_transform_number_or_none(
  self : PdfDocument,
  object : PdfObject,
) -> Double? {
  try self.get_number(object) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn PdfDocument::pdf_transform_quadpoint_chunk(
  self : PdfDocument,
  matrix : TransformMatrix,
  values : ArrayView[PdfObject],
  start : Int,
) -> Array[PdfObject] {
  let numbers : Array[Double] = []
  let mut valid = true
  for index in start..<(start + 8) {
    match self.pdf_transform_number_or_none(values[index]) {
      Some(value) => numbers.push(value)
      None => valid = false
    }
  }
  if valid {
    let output : Array[PdfObject] = []
    for index in 0..<4 {
      let point = matrix.apply(
        point2(numbers[index * 2], numbers[index * 2 + 1]),
      )
      output.push(PdfReal(point.x))
      output.push(PdfReal(point.y))
    }
    output
  } else {
    [
      for index in start..<(start + 8) => values[index]
    ]
  }
}

///|
/// Transform PDF annotation quadpoints in groups of eight coordinates.
///
/// Each complete group is interpreted as four `(x, y)` pairs and transformed by
/// `matrix`. A complete group containing a non-numeric value is preserved
/// unchanged, as is any trailing partial group. Non-array inputs are returned
/// unchanged.
pub fn PdfDocument::transform_quadpoints(
  self : PdfDocument,
  matrix : TransformMatrix,
  object : PdfObject,
) -> PdfObject {
  match self.direct(object) {
    PdfArray(values) => {
      let output : Array[PdfObject] = []
      let mut start = 0
      while start < values.length() {
        if start + 8 <= values.length() {
          for value in self.pdf_transform_quadpoint_chunk(matrix, values, start) {
            output.push(value)
          }
        } else {
          for index in start..<values.length() {
            output.push(values[index])
          }
        }
        start += 8
      }
      PdfArray(output)
    }
    _ => object
  }
}

///|
/// Read a transformation matrix from a dictionary entry.
///
/// If `key` is absent, the identity matrix is returned. Present values must be
/// arrays of six numbers in PDF matrix order `[a b c d e f]`; malformed arrays
/// raise `MatrixMalformed`, and non-numeric entries raise `NumberExpected`.
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
/// Convert a transformation matrix into its six-number PDF array form.
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
