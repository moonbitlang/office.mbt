///|
fn pdf_draw_control_image_file_spec_for_async_io(
  spec : StringView,
  command : String,
) -> (String, String) raise @core.PdfError {
  let text = spec.to_owned()
  let mut separator = -1
  for index in 0..<text.length() {
    if text.at(index).to_int() == 61 {
      if separator >= 0 {
        @core.pdf_error(command + ": bad file specification")
      }
      separator = index
    }
  }
  if separator < 0 {
    @core.pdf_error(command + ": bad file specification")
  }
  (text[:separator].to_owned(), text[separator + 1:].to_owned())
}

///|
/// Read a JPEG file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addjpeg` file form: `Name=/path/to/image.jpg`.
pub async fn pdf_draw_control_add_jpeg_file(
  control : @pdflite.PdfDrawControl,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addjpeg",
  )
  control.add_jpeg_data(name, @fs.read_file(path).binary())
}

///|
/// Compatibility wrapper matching cpdfjpeg's `backup_jpeg_dimensions`.
///
/// The original cpdf implementation shells out to ImageMagick. This native
/// wrapper keeps the same file boundary but uses pdflite's SOF-marker scanner,
/// so `path_to_im` is accepted for API parity and otherwise ignored.
pub async fn pdf_backup_jpeg_dimensions(
  filename : StringView,
  path_to_im? : String = "",
) -> (Int, Int) {
  ignore(path_to_im)
  @codec.pdf_jpeg_backup_dimensions_view(@fs.read_file(filename).binary())
}

///|
/// Read a PNG file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addpng` file form: `Name=/path/to/image.png`.
pub async fn pdf_draw_control_add_png_file(
  control : @pdflite.PdfDrawControl,
  document : @pdflite.PdfDocument,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addpng",
  )
  control.add_png_data(document, name, @fs.read_file(path).binary())
}

///|
/// Read a JPEG2000 file and append it as a draw-control image XObject.
///
/// `spec` follows cpdf's `addjpeg2000` file form:
/// `Name=/path/to/image.jp2`.
pub async fn pdf_draw_control_add_jpeg2000_file(
  control : @pdflite.PdfDrawControl,
  spec : StringView,
) -> Unit {
  let (name, path) = pdf_draw_control_image_file_spec_for_async_io(
    spec, "addjpeg2000",
  )
  control.add_jpeg2000_data(name, @fs.read_file(path).binary())
}
