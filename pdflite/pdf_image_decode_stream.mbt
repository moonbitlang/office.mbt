///|
priv enum PdfImageDecodedStream {
  PdfImageRawStream(@syntax.PdfStream)
  PdfImageDctStream(@syntax.PdfStream)
  PdfImageJpxStream(@syntax.PdfStream)
  PdfImageJbig2Stream(@syntax.PdfStream)
}

///|
fn PdfDocument::pdf_image_decode_stream_stages(
  self : PdfDocument,
  current : @syntax.PdfStream,
  stages : Int,
) -> PdfImageDecodedStream raise PdfError {
  match self.pdf_stream_first_filter_direct(current.dictionary) {
    Some(filter) if filter == pdf_image_dctdecode_name() ||
      filter == pdf_image_dct_name() => PdfImageDctStream(current)
    Some(filter) if filter == pdf_image_jpxdecode_name() =>
      PdfImageJpxStream(current)
    Some(filter) if filter == pdf_image_jbig2decode_name() =>
      PdfImageJbig2Stream(current)
    Some(_) => {
      if stages >= 1024 {
        raise FilterExpected
      }
      self.pdf_image_decode_stream_stages(
        self.pdf_decode_stream_onestage_value_direct(current),
        stages + 1,
      )
    }
    None => PdfImageRawStream(current)
  }
}

///|
fn PdfDocument::pdf_image_decode_to_image(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> PdfImageDecodedStream raise PdfError {
  let current = match self.direct(image) {
    PdfStreamObject(stream) => stream
    _ => raise ParseStreamExpected
  }
  self.pdf_image_decode_stream_stages(current, 0)
}

///|
fn PdfDocument::pdf_image_jbig2_globals(
  self : PdfDocument,
  dictionary : @syntax.PdfObject,
) -> Int? {
  let first_decodeparms = match
    self.lookup_direct_or_else(
      pdf_image_decodeparms_key(),
      pdf_image_dp_key(),
      dictionary,
    ) {
    Some(PdfDictionary(_) as decodeparms) => Some(decodeparms)
    Some(PdfArray([first, ..])) =>
      match self.direct(first) {
        PdfDictionary(_) as decodeparms => Some(decodeparms)
        _ => None
      }
    _ => None
  }
  match first_decodeparms {
    Some(decodeparms) =>
      match decodeparms.lookup_immediate(pdf_image_jbig2_globals_key()) {
        Some(PdfIndirect(number)) => Some(number)
        _ => None
      }
    None => None
  }
}
