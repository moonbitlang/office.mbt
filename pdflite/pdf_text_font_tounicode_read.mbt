///|
fn PdfDocument::pdf_text_tounicode_of_font(
  self : PdfDocument,
  font : @syntax.PdfObject,
) -> Array[(Int, @core.PdfBytes)]? {
  match self.lookup_direct(pdf_text_tounicode_key_name, font) {
    Some(PdfStreamObject(_) as stream) =>
      try self.parse_cmap(stream) catch {
        _ => None
      } noraise {
        parsed => if parsed.map.length() == 0 { None } else { Some(parsed.map) }
      }
    _ => None
  }
}

///|
fn PdfFontDescriptor::pdf_text_with_tounicode(
  self : PdfFontDescriptor,
  tounicode : Array[(Int, @core.PdfBytes)],
) -> PdfFontDescriptor {
  { ..self, tounicode: Some(tounicode) }
}

///|
fn PdfFont::pdf_text_with_tounicode(
  self : PdfFont,
  tounicode : Array[(Int, @core.PdfBytes)]?,
) -> PdfFont {
  match tounicode {
    None => self
    Some(tounicode) =>
      match self {
        PdfFontSimple(simple) => {
          let descriptor = match simple.fontdescriptor {
            Some(descriptor) => descriptor
            None => pdf_text_empty_font_descriptor()
          }
          PdfFontSimple({
            ..simple,
            fontdescriptor: Some(descriptor.pdf_text_with_tounicode(tounicode)),
          })
        }
        PdfFontCIDKeyed(cid_font) => {
          let composite = {
            ..cid_font.composite,
            cid_fontdescriptor: cid_font.composite.cid_fontdescriptor.pdf_text_with_tounicode(
              tounicode,
            ),
          }
          PdfFontCIDKeyed({ ..cid_font, composite, })
        }
        PdfFontStandard(_) => self
      }
  }
}
