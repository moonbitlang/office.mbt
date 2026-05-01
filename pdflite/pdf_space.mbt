///|
fn pdf_space_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
pub(all) struct PdfTristimulusPoint {
  x : Double
  y : Double
  z : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfColourSpace {
  PdfDeviceGray
  PdfDeviceRGB
  PdfDeviceCMYK
  PdfCalGray(PdfTristimulusPoint, PdfTristimulusPoint, Double)
  PdfCalRGB(
    PdfTristimulusPoint,
    PdfTristimulusPoint,
    Array[Double],
    Array[Double]
  )
  PdfLab(PdfTristimulusPoint, PdfTristimulusPoint, Array[Double])
  PdfICCBased(Int, PdfColourSpace, Array[Double], PdfObject?, PdfObject)
  PdfIndexed(PdfColourSpace, Array[(Int, Array[Int])])
  PdfPattern
  PdfPatternWithBaseColourSpace(PdfColourSpace)
  PdfSeparation(PdfName, PdfColourSpace, PdfObject)
  PdfDeviceN(Array[PdfName], PdfColourSpace, PdfObject, PdfObject)
} derive(Debug, Eq, ToJson)

///|
pub fn PdfColourSpace::debug_name(self : PdfColourSpace) -> String {
  match self {
    PdfDeviceGray => "/DeviceGray"
    PdfDeviceRGB => "/DeviceRGB"
    PdfDeviceCMYK => "/DeviceCMYK"
    PdfCalGray(_, _, _) => "/CalGray"
    PdfCalRGB(_, _, _, _) => "/CalRGB"
    PdfLab(_, _, _) => "/Lab"
    PdfICCBased(_, alternate, _, _, _) =>
      "ICCBased (" + alternate.debug_name() + ")"
    PdfIndexed(alternate, _) => "Indexed (" + alternate.debug_name() + ")"
    PdfPattern => "/Pattern"
    PdfPatternWithBaseColourSpace(alternate) =>
      "PatternWithBaseColourspace (" + alternate.debug_name() + ")"
    PdfSeparation(_, alternate, _) =>
      "Separation (" + alternate.debug_name() + ")"
    PdfDeviceN(_, alternate, _, _) => "DeviceN (" + alternate.debug_name() + ")"
  }
}

///|
pub fn PdfColourSpace::name(self : PdfColourSpace) -> PdfName? {
  match self {
    PdfSeparation(name, _, _) => Some(name)
    _ => None
  }
}

///|
pub fn pdf_colour_space_of_device_name(name : PdfName) -> PdfColourSpace? {
  if name == pdf_space_name("/DeviceGray") || name == pdf_space_name("/G") {
    Some(PdfDeviceGray)
  } else if name == pdf_space_name("/DeviceRGB") ||
    name == pdf_space_name("/RGB") {
    Some(PdfDeviceRGB)
  } else if name == pdf_space_name("/DeviceCMYK") ||
    name == pdf_space_name("/CMYK") {
    Some(PdfDeviceCMYK)
  } else if name == pdf_space_name("/Pattern") {
    Some(PdfPattern)
  } else {
    None
  }
}

///|
pub fn pdf_colour_space_of_object(object : PdfObject) -> PdfColourSpace? {
  match object {
    PdfNameObject(name) => pdf_colour_space_of_device_name(name)
    PdfArray([PdfNameObject(name), base]) if name == pdf_space_name("/Pattern") =>
      match pdf_colour_space_of_object(base) {
        Some(base) => Some(PdfPatternWithBaseColourSpace(base))
        None => None
      }
    PdfArray([single]) => pdf_colour_space_of_object(single)
    _ => None
  }
}

///|
fn pdf_space_whitepoint_key() -> PdfName {
  pdf_space_name("/WhitePoint")
}

///|
fn pdf_space_blackpoint_key() -> PdfName {
  pdf_space_name("/BlackPoint")
}

///|
fn pdf_space_gamma_key() -> PdfName {
  pdf_space_name("/Gamma")
}

///|
fn pdf_space_matrix_key() -> PdfName {
  pdf_space_name("/Matrix")
}

///|
fn pdf_space_range_key() -> PdfName {
  pdf_space_name("/Range")
}

///|
fn pdf_space_colorspace_key() -> PdfName {
  pdf_space_name("/ColorSpace")
}

///|
fn pdf_space_n_key() -> PdfName {
  pdf_space_name("/N")
}

///|
fn pdf_space_alternate_key() -> PdfName {
  pdf_space_name("/Alternate")
}

///|
fn pdf_space_metadata_key() -> PdfName {
  pdf_space_name("/Metadata")
}

///|
fn pdf_space_empty_point() -> PdfTristimulusPoint {
  { x: 0.0, y: 0.0, z: 0.0 }
}

///|
fn PdfDocument::pdf_space_read_point(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
) -> PdfTristimulusPoint raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfArray([x, y, z])) =>
      { x: self.get_number(x), y: self.get_number(y), z: self.get_number(z) }
    _ => pdf_space_empty_point()
  }
}

///|
fn PdfDocument::pdf_space_read_number_array(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  length : Int,
  default : ArrayView[Double],
) -> Array[Double] raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(PdfArray(values)) if values.length() == length => {
      let output : Array[Double] = []
      for value in values {
        output.push(self.get_number(value))
      }
      output
    }
    _ => [ for value in default => value ]
  }
}

///|
fn PdfDocument::pdf_space_read_number(
  self : PdfDocument,
  dictionary : PdfObject,
  key : PdfName,
  default : Double,
) -> Double raise PdfError {
  match self.lookup_direct(key, dictionary) {
    Some(value) => self.get_number(value)
    None => default
  }
}

///|
fn pdf_space_default_icc_alternate(n : Int) -> PdfColourSpace? {
  match n {
    1 => Some(PdfDeviceGray)
    3 => Some(PdfDeviceRGB)
    4 => Some(PdfDeviceCMYK)
    _ => None
  }
}

///|
fn pdf_space_default_icc_range(n : Int) -> Array[Double] {
  let output : Array[Double] = []
  for _ in 0..<n {
    output.push(0.0)
    output.push(1.0)
  }
  output
}

///|
fn pdf_space_basic_table_colour_space(space : PdfColourSpace) -> PdfColourSpace {
  match space {
    PdfIndexed(alternate, _)
    | PdfSeparation(_, alternate, _)
    | PdfDeviceN(_, alternate, _, _)
    | PdfICCBased(_, alternate, _, _, _) =>
      pdf_space_basic_table_colour_space(alternate)
    _ => space
  }
}

///|
fn pdf_space_indexed_component_count(space : PdfColourSpace) -> Int? {
  match pdf_space_basic_table_colour_space(space) {
    PdfDeviceRGB | PdfCalRGB(_, _, _, _) | PdfLab(_, _, _) => Some(3)
    PdfDeviceCMYK => Some(4)
    _ => None
  }
}

///|
fn pdf_space_read_indexed_table(
  data : BytesView,
  hival : Int,
  components : Int,
) -> Array[(Int, Array[Int])] raise PdfError {
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
fn pdf_space_stream_data(object : PdfObject) -> BytesView raise PdfError {
  match pdf_decode_stream(object) {
    PdfStreamObject(stream) =>
      match stream.data {
        StreamGot(data) => data[:]
        _ => raise StreamDataExpected
      }
    _ => raise ParseStreamExpected
  }
}

///|
fn PdfDocument::pdf_space_indexed_lookup_data(
  self : PdfDocument,
  lookup_data : PdfObject,
) -> BytesView? raise PdfError {
  match self.direct(lookup_data) {
    PdfString(data) => Some(data[:])
    PdfStreamObject(_) as stream => Some(pdf_space_stream_data(stream))
    _ => None
  }
}

///|
fn PdfDocument::pdf_space_read_icc_based(
  self : PdfDocument,
  resources : PdfObject,
  stream_object : PdfObject,
) -> PdfColourSpace? raise PdfError {
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
  resources : PdfObject,
  base_object : PdfObject,
  hival_object : PdfObject,
  lookup_data : PdfObject,
) -> PdfColourSpace? raise PdfError {
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
fn pdf_space_read_names(values : ArrayView[PdfObject]) -> Array[PdfName]? {
  let names : Array[PdfName] = []
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
  resources : PdfObject,
  names : ArrayView[PdfObject],
  alternate : PdfObject,
  tint : PdfObject,
  attributes? : PdfObject = pdf_dictionary([]),
) -> PdfColourSpace? raise PdfError {
  match
    (pdf_space_read_names(names), self.read_colour_space(resources, alternate)) {
    (Some(names), Some(alternate)) =>
      Some(PdfDeviceN(names, alternate, tint, attributes))
    _ => None
  }
}

///|
pub fn PdfDocument::read_colour_space(
  self : PdfDocument,
  resources : PdfObject,
  object : PdfObject,
) -> PdfColourSpace? raise PdfError {
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
    PdfArray([PdfNameObject(name), base]) if name == pdf_space_name("/Pattern") =>
      match self.read_colour_space(resources, base) {
        Some(base) => Some(PdfPatternWithBaseColourSpace(base))
        None => None
      }
    PdfArray([PdfNameObject(name), dictionary]) if name ==
      pdf_space_name("/CalGray") =>
      Some(
        PdfCalGray(
          self.pdf_space_read_point(dictionary, pdf_space_whitepoint_key()),
          self.pdf_space_read_point(dictionary, pdf_space_blackpoint_key()),
          self.pdf_space_read_number(dictionary, pdf_space_gamma_key(), 1.0),
        ),
      )
    PdfArray([PdfNameObject(name), dictionary]) if name ==
      pdf_space_name("/CalRGB") =>
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
    PdfArray([PdfNameObject(name), dictionary]) if name ==
      pdf_space_name("/Lab") =>
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
      pdf_space_name("/ICCBased") =>
      self.pdf_space_read_icc_based(resources, stream_object)
    PdfArray([PdfNameObject(name), base, hival, lookup_data]) if name ==
      pdf_space_name("/Indexed") ||
      name == pdf_space_name("/I") =>
      self.pdf_space_read_indexed(resources, base, hival, lookup_data)
    PdfArray([PdfNameObject(kind), PdfNameObject(name), alternate, tint]) if kind ==
      pdf_space_name("/Separation") =>
      match self.read_colour_space(resources, alternate) {
        Some(alternate) => Some(PdfSeparation(name, alternate, tint))
        None => None
      }
    PdfArray([PdfNameObject(kind), PdfArray(names), alternate, tint]) if kind ==
      pdf_space_name("/DeviceN") =>
      self.pdf_space_read_device_n(resources, names, alternate, tint)
    PdfArray(
      [PdfNameObject(kind), PdfArray(names), alternate, tint, attributes]
    ) if kind == pdf_space_name("/DeviceN") =>
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
pub fn pdf_object_of_colour_space(space : PdfColourSpace) -> PdfObject? {
  match space {
    PdfDeviceGray => Some(PdfNameObject(pdf_space_name("/DeviceGray")))
    PdfDeviceRGB => Some(PdfNameObject(pdf_space_name("/DeviceRGB")))
    PdfDeviceCMYK => Some(PdfNameObject(pdf_space_name("/DeviceCMYK")))
    PdfPattern => Some(PdfNameObject(pdf_space_name("/Pattern")))
    PdfPatternWithBaseColourSpace(base) =>
      match pdf_object_of_colour_space(base) {
        Some(base_object) =>
          Some(
            PdfArray([PdfNameObject(pdf_space_name("/Pattern")), base_object]),
          )
        None => None
      }
    _ => None
  }
}
