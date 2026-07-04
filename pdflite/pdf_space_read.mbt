///|
fn pdf_space_read_indexed_table(
  data : BytesView,
  hival : Int,
  components : Int,
) -> Array[(Int, Array[Int])] raise @core.PdfError {
  if hival < 0 {
    raise InvalidReadLength(hival)
  }
  let count = hival + 1
  let required = count * components
  if data.length() < required {
    raise EndOfInput
  }
  let table : Array[(Int, Array[Int])] = []
  for index in 0..<count {
    let values : Array[Int] = []
    let offset = index * components
    for component in 0..<components {
      values.push(data[offset + component].to_int())
    }
    table.push((index, values))
  }
  table
}

///|
fn PdfDocument::pdf_space_indexed_lookup_data(
  self : PdfDocument,
  lookup_data : @syntax.PdfObject,
) -> BytesView? raise @core.PdfError {
  match self.direct(lookup_data) {
    PdfString(data) => Some(data)
    PdfStreamObject(stream) =>
      Some(
        @syntax.pdf_stream_data_view(
          self.pdf_decode_stream_value_direct(stream).data,
        ),
      )
    _ => None
  }
}

///|
fn PdfDocument::pdf_space_read_icc_based(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  stream_object : @syntax.PdfObject,
) -> PdfColourSpace? raise @core.PdfError {
  match self.direct(stream_object) {
    PdfStreamObject(stream) =>
      match self.lookup_direct(pdf_space_n_key(), stream.dictionary) {
        Some(PdfInteger(n)) =>
          match pdf_space_default_icc_alternate(n) {
            Some(default_alternate) => {
              let alternate = match
                self.lookup_direct(pdf_space_alternate_key(), stream.dictionary) {
                Some(alternate) => self.read_colour_space(resources, alternate)
                None => Some(default_alternate)
              }
              match alternate {
                Some(alternate) => {
                  let range = self.pdf_space_read_number_array(
                    stream.dictionary,
                    pdf_space_range_key(),
                    n * 2,
                    pdf_space_default_icc_range(n),
                  )
                  Some(
                    PdfICCBased(
                      n,
                      alternate,
                      range,
                      self.lookup_direct(
                        pdf_space_metadata_key(),
                        stream.dictionary,
                      ),
                      stream_object,
                    ),
                  )
                }
                None => None
              }
            }
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn PdfDocument::pdf_space_read_indexed(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  base_object : @syntax.PdfObject,
  hival_object : @syntax.PdfObject,
  lookup_data : @syntax.PdfObject,
) -> PdfColourSpace? raise @core.PdfError {
  let hival = match hival_object {
    PdfInteger(hival) => hival
    _ => raise NumberExpected
  }
  match self.read_colour_space(resources, base_object) {
    Some(base) =>
      match
        (
          pdf_space_indexed_component_count(base),
          self.pdf_space_indexed_lookup_data(lookup_data),
        ) {
        (Some(components), Some(data)) =>
          Some(
            PdfIndexed(
              base,
              pdf_space_read_indexed_table(data, hival, components),
            ),
          )
        _ => None
      }
    None => None
  }
}

///|
fn pdf_space_read_names(
  values : ArrayView[@syntax.PdfObject],
) -> Array[@core.PdfName]? {
  let names : Array[@core.PdfName] = []
  let mut valid = true
  for value in values {
    match value {
      PdfNameObject(name) => names.push(name)
      _ => valid = false
    }
  }
  if valid {
    Some(names)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_space_read_device_n(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  names : ArrayView[@syntax.PdfObject],
  alternate : @syntax.PdfObject,
  tint : @syntax.PdfObject,
  attributes? : @syntax.PdfObject = @syntax.pdf_dictionary([]),
) -> PdfColourSpace? raise @core.PdfError {
  match
    (pdf_space_read_names(names), self.read_colour_space(resources, alternate)) {
    (Some(names), Some(alternate)) =>
      Some(PdfDeviceN(names, alternate, tint, attributes))
    _ => None
  }
}

///|
/// Parse a colour-space object using the document and resource dictionary.
///
/// The parser resolves resource colour-space names and supports device spaces,
/// pattern spaces with a base space, calibrated Gray/RGB/Lab spaces, ICCBased
/// spaces, Indexed spaces, Separation spaces, and DeviceN spaces. Unsupported
/// or malformed colour spaces return `None`; malformed numeric fields may raise
/// `@core.PdfError`.
pub fn PdfDocument::read_colour_space(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  object : @syntax.PdfObject,
) -> PdfColourSpace? raise @core.PdfError {
  match self.direct(object) {
    PdfNameObject(name) =>
      match pdf_colour_space_of_device_name(name) {
        Some(space) => Some(space)
        None =>
          match self.lookup_direct(pdf_space_colorspace_key(), resources) {
            Some(colour_spaces) =>
              match self.lookup_direct(name, colour_spaces) {
                Some(resolved) => self.read_colour_space(resources, resolved)
                None => None
              }
            None => None
          }
      }
    PdfArray([PdfNameObject(name), base]) if name == pdf_space_pattern_name =>
      match self.read_colour_space(resources, base) {
        Some(base) => Some(PdfPatternWithBaseColourSpace(base))
        None => None
      }
    PdfArray([PdfNameObject(name), dictionary]) if name ==
      pdf_space_calgray_name =>
      Some(
        PdfCalGray(
          self.pdf_space_read_point(dictionary, pdf_space_whitepoint_key()),
          self.pdf_space_read_point(dictionary, pdf_space_blackpoint_key()),
          self.pdf_space_read_number(dictionary, pdf_space_gamma_key(), 1.0),
        ),
      )
    PdfArray([PdfNameObject(name), dictionary]) if name == pdf_space_calrgb_name =>
      Some(
        PdfCalRGB(
          self.pdf_space_read_point(dictionary, pdf_space_whitepoint_key()),
          self.pdf_space_read_point(dictionary, pdf_space_blackpoint_key()),
          self.pdf_space_read_number_array(
            dictionary,
            pdf_space_gamma_key(),
            3,
            [1.0, 1.0, 1.0],
          ),
          self.pdf_space_read_number_array(
            dictionary,
            pdf_space_matrix_key(),
            9,
            [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
          ),
        ),
      )
    PdfArray([PdfNameObject(name), dictionary]) if name == pdf_space_lab_name =>
      Some(
        PdfLab(
          self.pdf_space_read_point(dictionary, pdf_space_whitepoint_key()),
          self.pdf_space_read_point(dictionary, pdf_space_blackpoint_key()),
          self.pdf_space_read_number_array(
            dictionary,
            pdf_space_range_key(),
            4,
            [-100.0, 100.0, -100.0, 100.0],
          ),
        ),
      )
    PdfArray([PdfNameObject(name), stream_object]) if name ==
      pdf_space_iccbased_name =>
      self.pdf_space_read_icc_based(resources, stream_object)
    PdfArray([PdfNameObject(name), base, hival, lookup_data]) if name ==
      pdf_space_indexed_name ||
      name == pdf_space_i_name =>
      self.pdf_space_read_indexed(resources, base, hival, lookup_data)
    PdfArray([PdfNameObject(kind), PdfNameObject(name), alternate, tint]) if kind ==
      pdf_space_separation_name =>
      match self.read_colour_space(resources, alternate) {
        Some(alternate) => Some(PdfSeparation(name, alternate, tint))
        None => None
      }
    PdfArray([PdfNameObject(kind), PdfArray(names), alternate, tint]) if kind ==
      pdf_space_device_n_name =>
      self.pdf_space_read_device_n(resources, names, alternate, tint)
    PdfArray(
      [PdfNameObject(kind), PdfArray(names), alternate, tint, attributes]
    ) if kind == pdf_space_device_n_name =>
      self.pdf_space_read_device_n(
        resources,
        names,
        alternate,
        tint,
        attributes~,
      )
    PdfArray([single]) => self.read_colour_space(resources, single)
    _ => None
  }
}

///|
/// Compatibility wrapper for `PdfDocument::read_colour_space`.
pub fn pdf_read_colour_space(
  document : PdfDocument,
  resources : @syntax.PdfObject,
  object : @syntax.PdfObject,
) -> PdfColourSpace? raise @core.PdfError {
  document.read_colour_space(resources, object)
}
