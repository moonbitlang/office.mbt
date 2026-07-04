///|
/// Extract an image as either encoded image bytes or 24bpp RGB data.
///
/// DCT/JPEG, JPX/JPEG2000, and JBIG2 streams are returned still encoded.
/// Other supported image streams are decoded, have supported `/Decode` arrays
/// applied, and are converted to `PdfRawImage(width, height, PdfBPP24, data)`
/// where `data` is RGBRGB byte order.
pub fn PdfDocument::get_image_24bpp(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  image : @syntax.PdfObject,
) -> PdfImage raise @core.PdfError {
  let decoded = self.pdf_image_decode_to_image(image)
  let decoded_stream = match decoded {
    PdfImageRawStream(stream)
    | PdfImageDctStream(stream)
    | PdfImageJpxStream(stream)
    | PdfImageJbig2Stream(stream) => stream
  }
  let width = self.pdf_image_lookup_int_or_else(
    pdf_image_width_key(),
    pdf_image_w_key(),
    decoded_stream.dictionary,
  )
  let height = self.pdf_image_lookup_int_or_else(
    pdf_image_height_key(),
    pdf_image_h_key(),
    decoded_stream.dictionary,
  )
  let data = @syntax.pdf_stream_data_bytes(decoded_stream.data)
  match decoded {
    PdfImageDctStream(_) =>
      PdfJPEG(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
    PdfImageJpxStream(_) =>
      PdfJPEG2000(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
    PdfImageJbig2Stream(_) =>
      PdfJBIG2(
        data,
        self.pdf_image_encoded_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
        self.pdf_image_jbig2_globals(decoded_stream.dictionary),
      )
    PdfImageRawStream(_) => {
      let decoded_data = pdf_image_apply_decode(
        data,
        self.pdf_image_bits_per_component_int(decoded_stream.dictionary),
        self.pdf_image_decode_values_with_defaults(
          resources,
          decoded_stream.dictionary,
        ),
      )
      PdfRawImage(
        width,
        height,
        PdfBPP24,
        self.pdf_image_raw_8bpp_as_rgb24_owned(
          resources,
          width,
          height,
          decoded_stream.dictionary,
          decoded_data,
        ),
      )
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::get_image_24bpp`.
pub fn pdf_get_image_24bpp(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  image : @syntax.PdfObject,
) -> PdfImage raise @core.PdfError {
  document.get_image_24bpp(resources, image)
}
