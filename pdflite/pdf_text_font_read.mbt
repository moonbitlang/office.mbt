///|
fn pdf_text_dictionary_has_key(object : PdfObject, key : PdfName) -> Bool {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, _) = entry
        if name == key {
          break true
        }
      } nobreak {
        false
      }
    None => false
  }
}

///|
fn pdf_text_find_immediate_indirect(object : PdfObject, key : PdfName) -> Int? {
  match object.dictionary_view() {
    Some(entries) =>
      for entry in entries {
        let (name, value) = entry
        if name == key {
          break match value {
            PdfIndirect(number) => Some(number)
            _ => None
          }
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
fn pdf_text_fontfile_of_descriptor(descriptor : PdfObject) -> PdfFontFile? {
  match
    pdf_text_find_immediate_indirect(descriptor, pdf_text_font_file_key_name) {
    Some(number) => Some(PdfFontFile(number))
    None =>
      match
        pdf_text_find_immediate_indirect(
          descriptor, pdf_text_font_file2_key_name,
        ) {
        Some(number) => Some(PdfFontFile2(number))
        None =>
          match
            pdf_text_find_immediate_indirect(
              descriptor, pdf_text_font_file3_key_name,
            ) {
            Some(number) => Some(PdfFontFile3(number))
            None => None
          }
      }
  }
}

///|
fn pdf_text_zero_rectangle() -> PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
fn pdf_text_empty_font_descriptor() -> PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: pdf_text_zero_rectangle(),
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn PdfDocument::pdf_text_optional_number(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(key, object) {
    Some(value) => self.get_number(value)
    None => 0.0
  }
}

///|
fn PdfDocument::pdf_text_optional_integer(
  self : PdfDocument,
  key : PdfName,
  object : PdfObject,
) -> Int raise PdfError {
  match self.lookup_direct(key, object) {
    Some(value) => self.get_number(value).to_int()
    None => 0
  }
}

///|
fn pdf_text_parse_charset(bytes : BytesView) -> Array[PdfName] raise PdfError {
  let cursor = byte_cursor_of_view(bytes)
  let names : Array[PdfName] = Array::new(capacity=bytes.length())
  let mut done = false
  while !done {
    cursor.drop_pdf_whitespace()
    match cursor.lex_pdf_name() {
      LexName(name) =>
        if name == pdf_text_slash_name {
          done = true
        } else {
          names.push(name)
        }
      _ => done = true
    }
  }
  names
}

///|
fn PdfDocument::pdf_text_font_charset(
  self : PdfDocument,
  descriptor : PdfObject,
) -> Array[PdfName]? raise PdfError {
  match self.lookup_direct(pdf_text_charset_key_name, descriptor) {
    Some(PdfString(bytes)) => Some(pdf_text_parse_charset(bytes))
    _ => None
  }
}

///|
/// Read the `/FontDescriptor` dictionary attached to a font.
///
/// Missing descriptors return `None`. Present descriptors are parsed
/// tolerantly for optional numeric fields, while malformed required shapes
/// such as an invalid `/FontBBox` still raise through the underlying object
/// readers.
pub fn PdfDocument::read_font_descriptor(
  self : PdfDocument,
  font : PdfObject,
) -> PdfFontDescriptor? raise PdfError {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
    None => None
    Some(descriptor) => {
      let fontbbox = match
        self.lookup_direct(pdf_text_font_bbox_key_name, descriptor) {
        Some(value) => self.parse_rectangle(value)
        None => pdf_text_zero_rectangle()
      }
      Some({
        ..pdf_text_empty_font_descriptor(),
        ascent: self.pdf_text_optional_number(
          pdf_text_ascent_key_name, descriptor,
        ),
        descent: self.pdf_text_optional_number(
          pdf_text_descent_key_name, descriptor,
        ),
        avgwidth: self.pdf_text_optional_number(
          pdf_text_avg_width_key_name, descriptor,
        ),
        maxwidth: self.pdf_text_optional_number(
          pdf_text_max_width_key_name, descriptor,
        ),
        fontbbox,
        flags: self.pdf_text_optional_integer(
          pdf_text_flags_key_name, descriptor,
        ),
        italicangle: self.pdf_text_optional_number(
          pdf_text_italic_angle_key_name, descriptor,
        ),
        capheight: self.pdf_text_optional_number(
          pdf_text_cap_height_key_name, descriptor,
        ),
        xheight: self.pdf_text_optional_number(
          pdf_text_xheight_key_name, descriptor,
        ),
        stemv: self.pdf_text_optional_number(
          pdf_text_stemv_key_name, descriptor,
        ),
        fontfile: pdf_text_fontfile_of_descriptor(descriptor),
        charset: self.pdf_text_font_charset(descriptor),
      })
    }
  }
}

///|
fn PdfDocument::pdf_text_font_metrics_descriptor(
  self : PdfDocument,
  font : PdfObject,
) -> PdfObject? {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) if subtype == pdf_text_type3_name => Some(font)
    _ => self.lookup_direct(pdf_text_font_descriptor_key_name, font)
  }
}

///|
fn PdfDocument::pdf_text_font_char_bound(
  self : PdfDocument,
  font : PdfObject,
  key : PdfName,
  error : PdfError,
) -> Int raise PdfError {
  match self.lookup_direct(key, font) {
    Some(PdfInteger(value)) if value >= 0 && value <= 255 => value
    _ => raise error
  }
}

///|
fn PdfDocument::pdf_text_font_missing_width(
  self : PdfDocument,
  descriptor : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(pdf_text_missing_width_key_name, descriptor) {
    Some(value) => self.get_number(value)
    None => 0.0
  }
}

///|
fn PdfDocument::pdf_text_font_widths_array(
  self : PdfDocument,
  font : PdfObject,
) -> Array[PdfObject] raise PdfError {
  match self.lookup_direct(pdf_text_widths_key_name, font) {
    Some(PdfArray(values)) => values
    _ => raise FontWidthsExpected
  }
}

///|
/// Read normalized one-byte font metrics for a simple or Type 3 font.
///
/// The result contains 256 entries when `/Widths`, `/FirstChar`, and
/// `/LastChar` are present and well formed. Missing metrics return `None`;
/// malformed bounds or width arrays raise the corresponding font error.
pub fn PdfDocument::read_font_metrics(
  self : PdfDocument,
  font : PdfObject,
) -> Array[Double]? raise PdfError {
  match self.pdf_text_font_metrics_descriptor(font) {
    None => None
    Some(descriptor) => {
      let firstchar = self.pdf_text_font_char_bound(
        font,
        pdf_text_first_char_key_name,
        FontFirstCharExpected,
      )
      let lastchar = self.pdf_text_font_char_bound(
        font,
        pdf_text_last_char_key_name,
        FontLastCharExpected,
      )
      guard lastchar >= firstchar else { raise FontWidthsExpected }
      let widths = self.pdf_text_font_widths_array(font)
      guard widths.length() == lastchar - firstchar + 1 else {
        raise FontWidthsExpected
      }
      let missingwidth = self.pdf_text_font_missing_width(descriptor)
      let metrics : Array[Double] = Array::new(capacity=256)
      for _ in 0..<firstchar {
        metrics.push(missingwidth)
      }
      for width in widths {
        metrics.push(
          self.get_number(width) catch {
            _ => raise FontWidthExpected
          },
        )
      }
      for _ in 0..<(255 - lastchar) {
        metrics.push(missingwidth)
      }
      Some(metrics)
    }
  }
}

///|
fn PdfDocument::pdf_text_read_type3_glyphs(
  self : PdfDocument,
  font : PdfObject,
) -> PdfType3Glyphs raise PdfError {
  let fontbbox = match self.lookup_direct(pdf_text_font_bbox_key_name, font) {
    Some(value) =>
      self.parse_rectangle(value) catch {
        _ => pdf_text_zero_rectangle()
      }
    None => pdf_text_zero_rectangle()
  }
  let charprocs = match self.lookup_direct(pdf_text_charprocs_key_name, font) {
    Some(PdfDictionary(entries)) => entries
    _ => raise FontCharProcsExpected
  }
  let resources = match self.lookup_direct(pdf_text_resources_key_name, font) {
    Some(value) => value
    None => PdfDictionary([])
  }
  {
    fontbbox,
    fontmatrix: self.parse_matrix(pdf_text_font_matrix_key_name, font),
    charprocs,
    resources,
  }
}

///|
fn PdfDocument::pdf_text_simple_font_type_of_name(
  self : PdfDocument,
  font : PdfObject,
  subtype : PdfName,
) -> PdfSimpleFontType? raise PdfError {
  if subtype == pdf_text_type1_name {
    Some(PdfType1)
  } else if subtype == pdf_text_mmtype1_name {
    Some(PdfMMType1)
  } else if subtype == pdf_text_type3_name {
    Some(PdfType3(self.pdf_text_read_type3_glyphs(font)))
  } else if subtype == pdf_text_true_type_name_value {
    Some(PdfTrueType)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_text_read_basefont(
  self : PdfDocument,
  font : PdfObject,
) -> PdfName? {
  match self.lookup_direct(pdf_text_base_font_key_name, font) {
    Some(PdfNameObject(name)) => Some(name)
    _ => None
  }
}

///|
/// Parse a simple-font dictionary.
///
/// Supported subtypes are Type1, MMType1, Type3, and TrueType. The returned
/// value includes optional descriptors, metrics, Type 3 CharProc data, and the
/// resolved simple-font encoding.
pub fn PdfDocument::read_simple_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfSimpleFont raise PdfError {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) =>
      match self.pdf_text_simple_font_type_of_name(font, subtype) {
        Some(fonttype) =>
          {
            fonttype,
            basefont: self.pdf_text_read_basefont(font),
            firstchar: 0,
            lastchar: 0,
            widths: [],
            fontdescriptor: self.read_font_descriptor(font),
            fontmetrics: self.read_font_metrics(font),
            encoding: self.read_encoding(font),
          }
        None => raise FontSubtypeExpected
      }
    _ => raise FontSubtypeExpected
  }
}

///|
fn PdfDocument::pdf_text_font_is_embedded(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
    Some(descriptor) =>
      pdf_text_dictionary_has_key(descriptor, pdf_text_font_file_key_name) ||
      pdf_text_dictionary_has_key(descriptor, pdf_text_font_file2_key_name) ||
      pdf_text_dictionary_has_key(descriptor, pdf_text_font_file3_key_name)
    None => false
  }
}

///|
fn PdfDocument::pdf_text_font_is_symbolic(
  self : PdfDocument,
  font : PdfObject,
) -> Bool raise PdfError {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
    Some(descriptor) =>
      match self.lookup_direct(pdf_text_flags_key_name, descriptor) {
        Some(PdfInteger(flags)) => (flags & (1 << 3)) > 0
        _ => raise FontFlagsExpected
      }
    None => false
  }
}

///|
fn PdfDocument::pdf_text_default_base_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  if self.pdf_text_font_is_embedded(font) ||
    self.pdf_text_font_is_symbolic(font) {
    PdfImplicitInFontFile
  } else {
    PdfStandardEncoding
  }
}

///|
fn PdfDocument::read_encoding_base(
  self : PdfDocument,
  encoding_dictionary : PdfObject,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  match
    self.lookup_direct(pdf_text_base_encoding_key_name, encoding_dictionary) {
    Some(PdfNameObject(name)) =>
      match pdf_encoding_of_name(name) {
        Some(encoding) => encoding
        None => raise EncodingExpected
      }
    Some(_) => raise EncodingExpected
    None => self.pdf_text_default_base_encoding(font)
  }
}

///|
fn PdfDocument::read_encoding_differences(
  self : PdfDocument,
  differences : PdfObject,
) -> Array[PdfEncodingDifference] raise PdfError {
  match self.direct(differences) {
    PdfArray(values) => {
      let output : Array[PdfEncodingDifference] = Array::new(
        capacity=values.length(),
      )
      let mut next_code : Int? = None
      for value in values {
        match self.direct(value) {
          PdfInteger(code) => next_code = Some(code)
          PdfNameObject(name) =>
            match next_code {
              Some(code) => {
                output.push({ name, code })
                next_code = Some(code + 1)
              }
              None => raise EncodingDifferencesMalformed
            }
          _ => raise EncodingDifferencesMalformed
        }
      }
      output
    }
    _ => raise EncodingDifferencesMalformed
  }
}

///|
fn pdf_text_is_true_type_name(name : PdfName) -> Bool {
  name == pdf_text_true_type_name_value
}

///|
fn pdf_text_is_simple_font_subtype_name(name : PdfName) -> Bool {
  name == pdf_text_type1_name ||
  name == pdf_text_mmtype1_name ||
  name == pdf_text_type3_name ||
  name == pdf_text_true_type_name_value
}

///|
fn pdf_text_is_standard14_subtype_name(name : PdfName) -> Bool {
  name == pdf_text_type1_name || name == pdf_text_true_type_name_value
}

///|
/// Read the simple-font encoding from a font dictionary.
///
/// Name encodings are recognized directly. Encoding dictionaries combine
/// `/BaseEncoding` and `/Differences`; TrueType encodings additionally fall
/// back to StandardEncoding for undefined entries. Missing or unrecognized
/// encodings use `PdfImplicitInFontFile`.
pub fn PdfDocument::read_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfEncoding raise PdfError {
  match self.lookup_direct(pdf_text_encoding_key_name, font) {
    Some(PdfNameObject(name)) =>
      match pdf_encoding_of_name(name) {
        Some(encoding) => encoding
        None => PdfImplicitInFontFile
      }
    Some(PdfDictionary(_) as encoding_dictionary) =>
      match self.lookup_direct(pdf_text_subtype_key_name, font) {
        Some(PdfNameObject(subtype)) if pdf_text_is_simple_font_subtype_name(
            subtype,
          ) => {
          let base = self.read_encoding_base(encoding_dictionary, font)
          let encoding = match
            self.lookup_direct(
              pdf_text_differences_key_name, encoding_dictionary,
            ) {
            Some(differences) =>
              PdfCustomEncoding(
                base,
                self.read_encoding_differences(differences),
              )
            None => base
          }
          if pdf_text_is_true_type_name(subtype) {
            PdfFillUndefinedWithStandard(encoding)
          } else {
            encoding
          }
        }
        _ => raise FontSubtypeExpected
      }
    Some(_) => PdfImplicitInFontFile
    None => PdfImplicitInFontFile
  }
}

///|
/// Return true if a font dictionary is an unembedded standard 14 font.
///
/// A matching Type1 or TrueType `/BaseFont` without explicit `/Widths` is
/// treated as a standard-font dictionary.
pub fn PdfDocument::is_standard14_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) if pdf_text_is_standard14_subtype_name(subtype) =>
      match self.lookup_direct(pdf_text_base_font_key_name, font) {
        Some(PdfNameObject(base_font)) =>
          pdf_standard_font_of_pdf_name(base_font) != None &&
          self.lookup_direct(pdf_text_widths_key_name, font) == None
        _ => false
      }
    _ => false
  }
}

///|
/// Return true if a font dictionary has a simple-font subtype.
pub fn PdfDocument::is_simple_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) =>
      pdf_text_is_simple_font_subtype_name(subtype)
    _ => false
  }
}

///|
/// Return true if a font dictionary is a Type 0 CID-keyed font.
pub fn PdfDocument::is_cidkeyed_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_type0_name
    _ => false
  }
}

///|
fn PdfDocument::pdf_text_cid_string_entry(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  error : PdfError,
) -> PdfBytes raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfString(bytes)) => bytes
    _ => raise error
  }
}

///|
/// Read a CID-system-info dictionary.
///
/// Registry and ordering are returned as byte strings, matching PDF string
/// semantics. Missing or malformed required fields raise `PdfError`.
pub fn PdfDocument::read_cid_system_info(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCIDSystemInfo raise PdfError {
  {
    registry: self.pdf_text_cid_string_entry(
      dictionary,
      pdf_text_registry_key_name,
      CIDRegistryExpected,
    ),
    ordering: self.pdf_text_cid_string_entry(
      dictionary,
      pdf_text_ordering_key_name,
      CIDOrderingExpected,
    ),
    supplement: match
      self.lookup_direct(pdf_text_supplement_key_name, dictionary) {
      Some(PdfInteger(value)) => value
      _ => raise CIDSupplementExpected
    },
  }
}

///|
fn PdfDocument::pdf_text_cid_number(
  self : PdfDocument,
  value : PdfObject,
  error : PdfError,
) -> Double raise PdfError {
  self.get_number(value) catch {
    _ => raise error
  }
}

///|
fn PdfDocument::pdf_text_read_cid_widths(
  self : PdfDocument,
  values : ArrayView[PdfObject],
) -> Array[(Int, Double)] raise PdfError {
  let output : Array[(Int, Double)] = Array::new(capacity=values.length())
  let mut index = 0
  while index < values.length() {
    match self.direct(values[index]) {
      PdfInteger(first_code) => {
        guard index + 1 < values.length() else { raise CIDWidthsExpected }
        match self.direct(values[index + 1]) {
          PdfArray(widths) => {
            for offset in 0..<widths.length() {
              output.push(
                (
                  first_code + offset,
                  self.pdf_text_cid_number(widths[offset], CIDWidthsExpected),
                ),
              )
            }
            index += 2
          }
          PdfInteger(last_code) => {
            guard index + 2 < values.length() && last_code >= first_code else {
              raise CIDWidthsExpected
            }
            let width = self.pdf_text_cid_number(
              values[index + 2],
              CIDWidthsExpected,
            )
            for code in first_code..<=last_code {
              output.push((code, width))
            }
            index += 3
          }
          _ => raise CIDWidthsExpected
        }
      }
      _ => raise CIDWidthsExpected
    }
  }
  output
}

///|
fn PdfDocument::pdf_text_read_cid_widths2(
  self : PdfDocument,
  values : ArrayView[PdfObject],
) -> Array[(Int, PdfCIDVerticalWidth)] raise PdfError {
  let output : Array[(Int, PdfCIDVerticalWidth)] = Array::new(
    capacity=values.length(),
  )
  let mut index = 0
  while index < values.length() {
    match self.direct(values[index]) {
      PdfInteger(first_code) => {
        guard index + 1 < values.length() else { raise CIDWidths2Expected }
        match self.direct(values[index + 1]) {
          PdfArray(widths) => {
            guard widths.length() % 3 == 0 else { raise CIDWidths2Expected }
            let mut code = first_code
            let mut width_index = 0
            while width_index < widths.length() {
              output.push(
                (
                  code,
                  {
                    width: self.pdf_text_cid_number(
                      widths[width_index],
                      CIDWidths2Expected,
                    ),
                    vx: self.pdf_text_cid_number(
                      widths[width_index + 1],
                      CIDWidths2Expected,
                    ),
                    vy: self.pdf_text_cid_number(
                      widths[width_index + 2],
                      CIDWidths2Expected,
                    ),
                  },
                ),
              )
              code += 1
              width_index += 3
            }
            index += 2
          }
          PdfInteger(last_code) => {
            guard index + 4 < values.length() && last_code >= first_code else {
              raise CIDWidths2Expected
            }
            let width = {
              width: self.pdf_text_cid_number(
                values[index + 2],
                CIDWidths2Expected,
              ),
              vx: self.pdf_text_cid_number(
                values[index + 3],
                CIDWidths2Expected,
              ),
              vy: self.pdf_text_cid_number(
                values[index + 4],
                CIDWidths2Expected,
              ),
            }
            for code in first_code..<=last_code {
              output.push((code, width))
            }
            index += 5
          }
          _ => raise CIDWidths2Expected
        }
      }
      _ => raise CIDWidths2Expected
    }
  }
  output
}

///|
fn PdfDocument::pdf_text_cid_widths(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[(Int, Double)] raise PdfError {
  match self.lookup_direct(pdf_text_w_key_name, dictionary) {
    Some(PdfArray(values)) => self.pdf_text_read_cid_widths(values)
    _ => []
  }
}

///|
fn PdfDocument::pdf_text_cid_widths2(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[(Int, PdfCIDVerticalWidth)] raise PdfError {
  match self.lookup_direct(pdf_text_w2_key_name, dictionary) {
    Some(PdfArray(values)) => self.pdf_text_read_cid_widths2(values)
    _ => []
  }
}

///|
fn PdfDocument::pdf_text_cid_default_width(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Double raise PdfError {
  match self.lookup_direct(pdf_text_dw_key_name, dictionary) {
    Some(value) => self.pdf_text_cid_number(value, CIDWidthsExpected)
    None => 1000.0
  }
}

///|
fn PdfDocument::pdf_text_cid_default_width2(
  self : PdfDocument,
  dictionary : PdfObject,
) -> Array[Double] raise PdfError {
  match self.lookup_direct(pdf_text_dw2_key_name, dictionary) {
    Some(PdfArray(values)) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(self.pdf_text_cid_number(value, CIDWidths2Expected))
      }
      output
    }
    _ => [880.0, -1000.0]
  }
}

///|
fn PdfDocument::pdf_text_read_descendant(
  self : PdfDocument,
  dictionary : PdfObject,
) -> PdfCompositeCIDFont raise PdfError {
  let cid_system_info = match
    self.lookup_direct(pdf_text_cid_system_info_key_name, dictionary) {
    Some(system_info) => self.read_cid_system_info(system_info)
    None => raise CIDSystemInfoExpected
  }
  let cid_basefont = match
    self.lookup_direct(pdf_text_base_font_key_name, dictionary) {
    Some(PdfNameObject(name)) => name
    _ => raise CIDBaseFontExpected
  }
  let cid_fontdescriptor = match self.read_font_descriptor(dictionary) {
    Some(fontdescriptor) => fontdescriptor
    None => raise CIDFontDescriptorExpected
  }
  {
    cid_system_info,
    cid_basefont,
    cid_fontdescriptor,
    cid_widths: self.pdf_text_cid_widths(dictionary),
    cid_widths2: self.pdf_text_cid_widths2(dictionary),
    cid_default_width: self.pdf_text_cid_default_width(dictionary),
    cid_default_width2: self.pdf_text_cid_default_width2(dictionary),
  }
}

///|
fn PdfDocument::pdf_text_read_cmap_encoding(
  self : PdfDocument,
  font : PdfObject,
) -> PdfCMapEncoding raise PdfError {
  match self.lookup_direct(pdf_text_encoding_key_name, font) {
    Some(PdfNameObject(name)) => PdfPredefinedCMap(name)
    Some(PdfStreamObject(_)) =>
      match pdf_text_find_immediate_indirect(font, pdf_text_encoding_key_name) {
        Some(number) =>
          try self.parse_cmap(PdfIndirect(number)) catch {
            _ => PdfCMap(number)
          } noraise {
            parsed => PdfExternalCMap(number, parsed)
          }
        None => raise CMapEncodingExpected
      }
    _ => raise CMapEncodingExpected
  }
}

///|
/// Parse a Type 0 font dictionary into a CID-keyed font.
///
/// This reads the descendant CIDFont, width data, descriptor, base font, and
/// CMap encoding. External CMap streams are parsed when possible while still
/// preserving the referenced stream object number.
pub fn PdfDocument::read_cidkeyed_font(
  self : PdfDocument,
  font : PdfObject,
) -> PdfCIDKeyedFont raise PdfError {
  let basefont = match self.lookup_direct(pdf_text_base_font_key_name, font) {
    Some(PdfNameObject(name)) => name
    _ => raise BaseFontExpected
  }
  let composite = match
    self.lookup_direct(pdf_text_descendant_fonts_key_name, font) {
    Some(PdfArray([descendant])) =>
      self.pdf_text_read_descendant(self.direct(descendant))
    _ => raise DescendantFontExpected
  }
  { basefont, composite, encoding: self.pdf_text_read_cmap_encoding(font) }
}
