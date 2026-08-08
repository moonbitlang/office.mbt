///|
// Writing composite (CID-keyed) fonts. `PdfFontCIDKeyed` was previously
// readable but not writable, so a document holding CJK text could be
// parsed and never reproduced.
//
// A composite font is two dictionaries: a `/Type0` root naming an
// encoding and pointing at a single descendant, and a `/CIDFontType2`
// descendant carrying the CID system info, the widths, and the font
// descriptor. As for simple fonts, the descriptor's `/FontFile2` is
// optional — a non-embedded CID font with a `/W` array is legal, and is
// how a document references an installed CJK face.

///|
let pdf_text_cid_font_type2_name : @core.PdfName = pdf_text_static_name(
  "/CIDFontType2",
)

///|
let pdf_text_cid_to_gid_map_key_name : @core.PdfName = pdf_text_static_name(
  "/CIDToGIDMap",
)

///|
let pdf_text_identity_name : @core.PdfName = pdf_text_static_name("/Identity")

///|
/// `/W` groups consecutive CIDs that share a width, which is both what
/// the format expects and much smaller than one entry per CID. Runs are
/// emitted as `first [w w w]`; a single CID is still a one-element run.
fn pdf_text_cid_widths_array(
  widths : ArrayView[(Int, Double)],
) -> @syntax.PdfObject {
  let entries : Array[@syntax.PdfObject] = []
  let mut index = 0
  while index < widths.length() {
    let (first_cid, _) = widths[index]
    // gather the run of consecutive CIDs starting here
    let run : Array[@syntax.PdfObject] = []
    let mut last = index
    while last < widths.length() {
      let (cid, width) = widths[last]
      if cid != first_cid + (last - index) {
        break
      }
      run.push(pdf_text_integer_of_double(width))
      last += 1
    }
    entries.push(PdfInteger(first_cid))
    entries.push(PdfArray(run))
    index = last
  }
  PdfArray(entries)
}

///|
/// The `/Encoding` entry of a `/Type0` font: a predefined CMap by name,
/// or a reference to an embedded CMap stream.
fn pdf_text_cid_encoding_object(
  encoding : PdfCMapEncoding,
) -> @syntax.PdfObject {
  match encoding {
    PdfPredefinedCMap(name) => PdfNameObject(name)
    PdfCMap(number) => PdfIndirect(number)
    PdfExternalCMap(number, _) => PdfIndirect(number)
  }
}

///|
/// Write a CID-keyed font and return the object number of its `/Type0`
/// dictionary.
fn PdfDocument::pdf_text_make_cid_keyed_font(
  self : PdfDocument,
  font : PdfCIDKeyedFont,
) -> @syntax.PdfObject {
  let composite = font.composite
  let descriptor = composite.cid_fontdescriptor
  let descriptor_entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_text_type_key_name, PdfNameObject(pdf_text_font_descriptor_key_name)),
    (pdf_text_font_name_key_name, PdfNameObject(composite.cid_basefont)),
    (pdf_text_flags_key_name, PdfInteger(descriptor.flags)),
    (
      pdf_text_font_bbox_key_name,
      pdf_text_font_descriptor_bbox_object(descriptor.fontbbox),
    ),
    (
      pdf_text_italic_angle_key_name,
      pdf_text_integer_of_double(descriptor.italicangle),
    ),
    (pdf_text_ascent_key_name, pdf_text_integer_of_double(descriptor.ascent)),
    (pdf_text_descent_key_name, pdf_text_integer_of_double(descriptor.descent)),
    (
      pdf_text_cap_height_key_name,
      pdf_text_integer_of_double(descriptor.capheight),
    ),
    (pdf_text_stemv_key_name, pdf_text_integer_of_double(descriptor.stemv)),
  ]
  // as for simple fonts, an absent program means the consumer
  // substitutes the face; the widths still govern spacing
  match pdf_text_fontfile2_number(descriptor.fontfile) {
    Some(number) =>
      descriptor_entries.push(
        (pdf_text_font_file2_key_name, PdfIndirect(number)),
      )
    None => ()
  }
  let descriptor_number = self.add_object(PdfDictionary(descriptor_entries))
  let system_info = composite.cid_system_info
  let descendant_entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
    (pdf_text_subtype_key_name, PdfNameObject(pdf_text_cid_font_type2_name)),
    (pdf_text_base_font_key_name, PdfNameObject(composite.cid_basefont)),
    (
      pdf_text_cid_system_info_key_name,
      PdfDictionary([
        (pdf_text_registry_key_name, PdfString(system_info.registry)),
        (pdf_text_ordering_key_name, PdfString(system_info.ordering)),
        (pdf_text_supplement_key_name, PdfInteger(system_info.supplement)),
      ]),
    ),
    (pdf_text_font_descriptor_key_name, PdfIndirect(descriptor_number)),
    (
      pdf_text_dw_key_name,
      pdf_text_integer_of_double(composite.cid_default_width),
    ),
    // Identity: a CID is its own glyph index, which is what Identity-H
    // encoding means and what a subsetter preserving glyph ids produces
    (pdf_text_cid_to_gid_map_key_name, PdfNameObject(pdf_text_identity_name)),
  ]
  if composite.cid_widths.length() > 0 {
    descendant_entries.push(
      (pdf_text_w_key_name, pdf_text_cid_widths_array(composite.cid_widths)),
    )
  }
  let descendant_number = self.add_object(PdfDictionary(descendant_entries))
  let root_entries : Array[(@core.PdfName, @syntax.PdfObject)] = [
    (pdf_text_type_key_name, PdfNameObject(pdf_text_font_name)),
    (pdf_text_subtype_key_name, PdfNameObject(pdf_text_type0_name)),
    (pdf_text_base_font_key_name, PdfNameObject(font.basefont)),
    (pdf_text_encoding_key_name, pdf_text_cid_encoding_object(font.encoding)),
    (
      pdf_text_descendant_fonts_key_name,
      PdfArray([PdfIndirect(descendant_number)]),
    ),
  ]
  // a composite font's ToUnicode maps two-byte codes, so it is written
  // from the descriptor when one is supplied
  match descriptor.tounicode {
    Some(tounicode) =>
      root_entries.push(
        (
          pdf_text_tounicode_key_name,
          PdfIndirect(self.pdf_text_write_tounicode(tounicode)),
        ),
      )
    None => ()
  }
  PdfDictionary(root_entries)
}
