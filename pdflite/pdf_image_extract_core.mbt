///|
fn PdfDocument::pdf_image_jbig2_global_data(
  self : PdfDocument,
  object_number : Int,
) -> @core.PdfBytes? raise @core.PdfError {
  match self.pdf_decode_stream_until_unknown(PdfIndirect(object_number)) {
    PdfStreamObject(stream) => Some(@syntax.pdf_stream_data_bytes(stream.data))
    _ => None
  }
}

///|
fn PdfDocument::pdf_image_extracted_files_of_image(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  name : String,
  image : @syntax.PdfObject,
  state : PdfImageExtractionState,
) -> Array[PdfExtractedImageFile] raise @core.PdfError {
  pdf_check_injectible(name)
  match self.get_image_24bpp(resources, image) {
    PdfJPEG(data, _) => [{ path: name + ".jpg", data }]
    PdfJPEG2000(data, _) => [{ path: name + ".jpx", data }]
    PdfJBIG2(data, _, None) => [{ path: name + ".jbig2", data }]
    PdfJBIG2(data, _, Some(global_number)) =>
      match state.jbig2_serial(global_number) {
        Some(serial) => [{ path: name + ".jbig2__" + serial.to_string(), data }]
        None =>
          match self.pdf_image_jbig2_global_data(global_number) {
            Some(global_data) => {
              let serial = state.add_jbig2_global(global_number)
              [
                {
                  path: pdf_image_join_directory_file(
                    pdf_image_dirname(name),
                    serial.to_string() + ".jbig2global",
                  ),
                  data: global_data,
                },
                { path: name + ".jbig2__" + serial.to_string(), data },
              ]
            }
            None => []
          }
      }
    PdfRawImage(width, height, PdfBPP24, data) =>
      [
        {
          path: name + ".pnm",
          data: pdf_image_pnm_24bpp_bytes(width, height, data),
        },
      ]
    PdfRawImage(_, _, _, _) => []
  }
}
