///|
fn pdf_async_io_join_directory_file(
  directory : StringView,
  filename : String,
) -> String {
  let text = directory.to_owned()
  if text.length() == 0 {
    filename
  } else {
    let last = text.at(text.length() - 1).to_int()
    if last == 47 || last == 92 {
      text + filename
    } else {
      text + "/" + filename
    }
  }
}

///|
/// Load cpdf's Standard 14 substitute font file from a directory.
///
/// This mirrors `cpdfembed.ml`'s `load_substitute`: choose the URW substitute
/// filename for `font`, read it from `directory`, and return the file bytes
/// together with the extension-stripped font name.
pub async fn pdf_load_standard_font_substitute_file(
  directory : StringView,
  font : @pdflite.PdfStandardFont,
) -> (@core.PdfBytes, String) {
  let filename = @pdflite.pdf_standard_font_substitute_filenames(font)[0]
  (
    @fs.read_file(pdf_async_io_join_directory_file(directory, filename)).binary(),
    @pdflite.pdf_standard_font_substitute_font_name(font),
  )
}

///|
/// Compatibility wrapper matching cpdfembed's `load_substitute`.
pub async fn pdf_load_substitute(
  directory : StringView,
  font : @pdflite.PdfStandardFont,
) -> (@core.PdfBytes, String) {
  pdf_load_standard_font_substitute_file(directory, font)
}

///|
/// Extract an embedded font file and write it to disk.
///
/// This is the native filesystem counterpart of cpdffont's `extract_fontfile`.
/// Font lookup and stream decoding are delegated to the core
/// `PdfDocument::extract_fontfile_bytes` API.
pub async fn pdf_extract_fontfile_to_file(
  document : @pdflite.PdfDocument,
  page_number : Int,
  font_name : String,
  path : StringView,
  permission? : Int = 0o644,
) -> Unit {
  match document.extract_fontfile_bytes(page_number, font_name) {
    Some(data) => @fs.write_file(path, data, create=permission)
    None => @core.pdf_error("extract_fontfile: unsupported or unfound font")
  }
}

///|
/// Compatibility wrapper matching cpdffont's `extract_fontfile` argument order.
pub async fn pdf_extract_fontfile(
  page_number : Int,
  font_name : String,
  path : StringView,
  document : @pdflite.PdfDocument,
  permission? : Int = 0o644,
) -> Unit {
  pdf_extract_fontfile_to_file(
    document,
    page_number,
    font_name,
    path,
    permission~,
  )
}
