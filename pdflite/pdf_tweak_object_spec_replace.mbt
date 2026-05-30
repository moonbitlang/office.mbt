///|
fn pdf_tweak_replace_array_entry(
  values : ArrayView[@syntax.PdfObject],
  index : Int,
  value : @syntax.PdfObject,
  source : String,
) -> @syntax.PdfObject raise PdfError {
  if index < 0 || index >= values.length() {
    raise BadPageSpecification(source)
  }
  PdfArray(
    [
      for i in 0..<values.length() => if i == index { value } else { values[i] }
    ],
  )
}

///|
fn pdf_tweak_chain_array_index(name : PdfName) -> Int? {
  let bytes = name.bytes()
  guard bytes.length() >= 3 &&
    bytes[0].to_int() == 47 &&
    bytes[1].to_int() == 91 else {
    return None
  }
  guard pdf_tweak_is_digit_byte(bytes[2]) else { return None }
  let mut value = 0
  let mut index = 2
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    value = value * 10 + bytes[index].to_int() - 48
    index += 1
  }
  Some(value)
}

///|
fn PdfDocument::pdf_tweak_replace_existing_chain(
  self : PdfDocument,
  object : @syntax.PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
  value : @syntax.PdfObject,
  source : String,
) -> @syntax.PdfObject raise PdfError {
  let key = chain[chain_index]
  let final_key = chain_index + 1 == chain.length()
  match object {
    PdfDictionary(_) | PdfStreamObject(_) =>
      if final_key {
        match object.lookup_immediate(key) {
          Some(_) => object.replace_dict_entry(key, value)
          None => raise BadPageSpecification(source)
        }
      } else {
        match object.lookup_immediate(key) {
          Some(PdfIndirect(number)) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              self.lookup_object_or_null(number),
              chain,
              chain_index + 1,
              value,
              source,
            )
            self.add_object_given_number(number, updated)
            object
          }
          Some(child) => {
            let updated = self.pdf_tweak_replace_existing_chain(
              child,
              chain,
              chain_index + 1,
              value,
              source,
            )
            object.replace_dict_entry(key, updated)
          }
          None => raise BadPageSpecification(source)
        }
      }
    PdfArray(values) =>
      match pdf_tweak_chain_array_index(key) {
        Some(index) =>
          if final_key {
            pdf_tweak_replace_array_entry(values, index, value, source)
          } else {
            match values.get(index) {
              Some(PdfIndirect(number)) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  self.lookup_object_or_null(number),
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                self.add_object_given_number(number, updated)
                object
              }
              Some(child) => {
                let updated = self.pdf_tweak_replace_existing_chain(
                  child,
                  chain,
                  chain_index + 1,
                  value,
                  source,
                )
                pdf_tweak_replace_array_entry(values, index, updated, source)
              }
              None => raise BadPageSpecification(source)
            }
          }
        None => raise BadPageSpecification(source)
      }
    _ => raise BadPageSpecification(source)
  }
}

///|
fn PdfDocument::pdf_tweak_replace_numbered_object(
  self : PdfDocument,
  number : Int,
  chain : ArrayView[PdfName],
  value : @syntax.PdfObject,
  source : String,
) -> Unit raise PdfError {
  if chain.length() == 0 {
    if number == 0 {
      self.set_trailer_dict(value)
    } else {
      self.add_object_given_number(number, value)
    }
  } else {
    let object = if number == 0 {
      self.trailer_dict()
    } else {
      self.lookup_object_or_null(number)
    }
    let updated = self.pdf_tweak_replace_existing_chain(
      object, chain, 0, value, source,
    )
    if number == 0 {
      self.set_trailer_dict(updated)
    } else {
      self.add_object_given_number(number, updated)
    }
  }
}
