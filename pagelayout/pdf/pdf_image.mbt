///|
// PDF pages as images: an `ImageItem` whose media type is
// `application/pdf` draws a page of the PDF in `data`, as a Form XObject
// scaled into the item's box (see `@pdflite.PdfDocument::import_page`).

///|
/// The page a PDF image shows, when `mime` is `application/pdf`: the
/// `page` parameter (`application/pdf; page=3`), 1-based, or the first
/// page without one; 0 for a `page` parameter that is not a positive
/// integer. None for any other media type.
fn pdf_image_page(mime : String) -> Int? {
  let parts = mime.split(";").map(p => p.trim().to_owned()).to_array()
  guard parts.get(0) is Some(kind) && kind.to_lower() == "application/pdf" else {
    return None
  }
  let mut page = 1
  for part in parts[1:] {
    guard part.find("=") is Some(eq) else { continue }
    if part[:eq].trim().to_owned().to_lower() != "page" {
      continue
    }
    let value = part[eq + 1:].trim().trim(chars="\"").to_owned()
    // digits only, and few enough to be a page number
    page = if value != "" &&
      value.length() <= 9 &&
      value.iter().all(c => c >= '0' && c <= '9') {
      value.iter().fold(init=0, (n, c) => n * 10 + (c.to_int() - '0'.to_int()))
    } else {
      0
    }
  }
  Some(page)
}

///|
/// The documents behind PDF images, each read (and its page tree walked)
/// once: the error for bytes that are not a readable PDF.
priv struct PdfSources {
  documents : Map[Bytes, Result[@pdflite.PdfPageSource, @core.PdfError]]
}

///|
fn PdfSources::new() -> PdfSources {
  { documents: Map([]), }
}

///|
fn PdfSources::read(
  self : PdfSources,
  data : Bytes,
) -> @pdflite.PdfPageSource raise @core.PdfError {
  let source = match self.documents.get(data) {
    Some(source) => source
    None => {
      let source = Ok(
        @pdflite.PdfPageSource::new(@pdflite.pdf_read_document_from_bytes(data)),
      ) catch {
        error => Err(error)
      }
      self.documents[data] = source
      source
    }
  }
  match source {
    Ok(source) => source
    Err(error) => raise error
  }
}

///|
/// Import page `page` of the PDF `data` into `document`: the Form
/// XObject's number and the page's size, or None when the bytes are not a
/// readable PDF or it has no such page.
fn import_pdf_image(
  document : @pdflite.PdfDocument,
  sources : PdfSources,
  data : Bytes,
  page : Int,
) -> (Int, Double, Double)? {
  let source = sources.read(data) catch { _ => return None }
  let imported = document.import_page(source, page) catch { _ => return None }
  Some((imported.object, imported.width, imported.height))
}

///|
/// Why page `page` of the PDF `data` cannot be drawn, or None when it can.
fn pdf_image_verdict(
  scratch : @pdflite.PdfDocument,
  sources : PdfSources,
  data : Bytes,
  page : Int,
) -> String? {
  let source = sources.read(data) catch {
    _ => return Some("PDF this backend cannot read")
  }
  // importing into a scratch document checks what `render_pdf` will do
  try ignore(scratch.import_page(source, page)) catch {
    BadPageSpecification(_) => Some("PDF without the page to draw")
    _ => Some("PDF page this backend cannot import")
  } noraise {
    _ => None
  }
}
