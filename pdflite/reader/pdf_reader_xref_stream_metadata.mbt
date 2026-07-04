///|
/// Return a stream dictionary with xref-stream-only keys removed.
pub fn pdf_reader_stream_dictionary_without_xref_keys(
  dictionary : @syntax.PdfObject,
) -> @syntax.PdfObject raise @core.PdfError {
  dictionary
  .remove_dict_entry(pdf_reader_type_name())
  .remove_dict_entry(pdf_reader_w_name())
  .remove_dict_entry(pdf_reader_index_name())
  .remove_dict_entry(pdf_length_name())
  .remove_dict_entry(pdf_reader_filter_name())
  .remove_dict_entry(pdf_reader_short_filter_name())
  .remove_dict_entry(pdf_reader_decodeparms_name())
  .remove_dict_entry(pdf_reader_short_decodeparms_name())
}

///|
/// Return whether a dictionary declares an xref stream.
pub fn pdf_reader_xref_stream_type_ok(dictionary : @syntax.PdfObject) -> Bool {
  match dictionary.lookup_immediate(pdf_reader_type_name()) {
    Some(PdfNameObject(name)) => name == pdf_reader_xref_name()
    Some(_) => false
    None => dictionary.lookup_immediate(pdf_reader_w_name()) != None
  }
}

///|
/// Return whether an object is a stream object with xref-stream metadata.
pub fn pdf_reader_object_is_xref_stream(object : @syntax.PdfObject) -> Bool {
  match object {
    PdfStreamObject(stream) => pdf_reader_xref_stream_type_ok(stream.dictionary)
    _ => false
  }
}

///|
/// Read an optional integer array from a direct dictionary entry.
pub fn pdf_xref_stream_int_array(
  dictionary : @syntax.PdfObject,
  key : @core.PdfName,
) -> Array[Int]? raise @core.PdfError {
  match dictionary.lookup_immediate(key) {
    Some(PdfArray(values)) => {
      let output : Array[Int] = Array::new(capacity=values.length())
      for value in values {
        match value {
          PdfInteger(number) => output.push(number)
          _ => raise XRefEntryExpected
        }
      }
      Some(output)
    }
    Some(_) => raise XRefEntryExpected
    None => None
  }
}

///|
/// Read and validate xref-stream `/W` field widths.
pub fn pdf_xref_stream_widths(
  dictionary : @syntax.PdfObject,
) -> (Int, Int, Int) raise @core.PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_w_name()) {
    Some([w0, w1, w2]) if w0 >= 0 && w1 >= 0 && w2 >= 0 && w0 + w1 + w2 > 0 =>
      (w0, w1, w2)
    _ => raise XRefEntryExpected
  }
}

///|
/// Read and validate xref-stream `/Index` object-number ranges.
pub fn pdf_xref_stream_index_pairs(
  dictionary : @syntax.PdfObject,
) -> Array[(Int, Int)] raise @core.PdfError {
  match pdf_xref_stream_int_array(dictionary, pdf_reader_index_name()) {
    Some(values) => {
      if values.length() % 2 != 0 {
        raise XRefEntryExpected
      }
      let pairs : Array[(Int, Int)] = Array::new(capacity=values.length() / 2)
      for pair_index in 0..<(values.length() / 2) {
        let i = pair_index * 2
        let start = values[i]
        let length = values[i + 1]
        if start < 0 || length < 0 {
          raise XRefEntryExpected
        }
        pairs.push((start, length))
      }
      pairs
    }
    None =>
      match dictionary.lookup_immediate(pdf_reader_size_name()) {
        Some(PdfInteger(size)) if size >= 0 => [(0, size)]
        _ => raise XRefEntryExpected
      }
  }
}
