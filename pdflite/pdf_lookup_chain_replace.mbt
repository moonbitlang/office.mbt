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
