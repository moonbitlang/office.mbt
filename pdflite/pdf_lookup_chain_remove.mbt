///|
fn PdfDocument::remove_chain_from_object(
  self : PdfDocument,
  object : @syntax.PdfObject,
  chain : ArrayView[PdfName],
  chain_index : Int,
) -> (@syntax.PdfObject, Bool) raise PdfError {
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
/// absent. Empty chains raise `PdfError::DictionaryExpected`. A single-key chain is
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
