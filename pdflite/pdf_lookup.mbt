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
