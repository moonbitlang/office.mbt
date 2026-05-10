///|
fn pdf_space_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_space_device_gray_name : PdfName = pdf_space_name("/DeviceGray")

///|
let pdf_space_g_name : PdfName = pdf_space_name("/G")

///|
let pdf_space_device_rgb_name : PdfName = pdf_space_name("/DeviceRGB")

///|
let pdf_space_rgb_name : PdfName = pdf_space_name("/RGB")

///|
let pdf_space_device_cmyk_name : PdfName = pdf_space_name("/DeviceCMYK")

///|
let pdf_space_cmyk_name : PdfName = pdf_space_name("/CMYK")

///|
let pdf_space_pattern_name : PdfName = pdf_space_name("/Pattern")

///|
let pdf_space_calgray_name : PdfName = pdf_space_name("/CalGray")

///|
let pdf_space_calrgb_name : PdfName = pdf_space_name("/CalRGB")

///|
let pdf_space_calcmyk_name : PdfName = pdf_space_name("/CalCMYK")

///|
let pdf_space_lab_name : PdfName = pdf_space_name("/Lab")

///|
let pdf_space_iccbased_name : PdfName = pdf_space_name("/ICCBased")

///|
let pdf_space_separation_name : PdfName = pdf_space_name("/Separation")

///|
let pdf_space_indexed_name : PdfName = pdf_space_name("/Indexed")

///|
let pdf_space_i_name : PdfName = pdf_space_name("/I")

///|
let pdf_space_device_n_name : PdfName = pdf_space_name("/DeviceN")

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
pub fn pdf_string_of_colour_space(space : PdfColourSpace) -> String {
  space.debug_name()
}

///|
pub fn pdf_name_of_colour_space(space : PdfColourSpace) -> PdfName? {
  space.name()
}

///|
pub fn pdf_colour_space_of_device_name(name : PdfName) -> PdfColourSpace? {
  if name == pdf_space_device_gray_name || name == pdf_space_g_name {
    Some(PdfDeviceGray)
  } else if name == pdf_space_device_rgb_name || name == pdf_space_rgb_name {
    Some(PdfDeviceRGB)
  } else if name == pdf_space_device_cmyk_name || name == pdf_space_cmyk_name {
    Some(PdfDeviceCMYK)
  } else if name == pdf_space_pattern_name {
    Some(PdfPattern)
  } else {
    None
  }
}

///|
pub fn pdf_colour_space_of_object(object : PdfObject) -> PdfColourSpace? {
  match object {
    PdfNameObject(name) => pdf_colour_space_of_device_name(name)
    PdfArray([PdfNameObject(name), base]) if name == pdf_space_pattern_name =>
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
  pdf_space_whitepoint_key_name
}

///|
let pdf_space_whitepoint_key_name : PdfName = pdf_space_name("/WhitePoint")

///|
fn pdf_space_blackpoint_key() -> PdfName {
  pdf_space_blackpoint_key_name
}

///|
let pdf_space_blackpoint_key_name : PdfName = pdf_space_name("/BlackPoint")

///|
fn pdf_space_gamma_key() -> PdfName {
  pdf_space_gamma_key_name
}

///|
let pdf_space_gamma_key_name : PdfName = pdf_space_name("/Gamma")

///|
fn pdf_space_matrix_key() -> PdfName {
  pdf_space_matrix_key_name
}

///|
let pdf_space_matrix_key_name : PdfName = pdf_space_name("/Matrix")

///|
fn pdf_space_range_key() -> PdfName {
  pdf_space_range_key_name
}

///|
let pdf_space_range_key_name : PdfName = pdf_space_name("/Range")

///|
fn pdf_space_colorspace_key() -> PdfName {
  pdf_space_colorspace_key_name
}

///|
let pdf_space_colorspace_key_name : PdfName = pdf_space_name("/ColorSpace")

///|
fn pdf_space_n_key() -> PdfName {
  pdf_space_n_key_name
}

///|
let pdf_space_n_key_name : PdfName = pdf_space_name("/N")

///|
fn pdf_space_alternate_key() -> PdfName {
  pdf_space_alternate_key_name
}

///|
let pdf_space_alternate_key_name : PdfName = pdf_space_name("/Alternate")

///|
fn pdf_space_metadata_key() -> PdfName {
  pdf_space_metadata_key_name
}

///|
let pdf_space_metadata_key_name : PdfName = pdf_space_name("/Metadata")

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
fn PdfDocument::pdf_space_named_components(
  self : PdfDocument,
  resources : PdfObject,
  name : PdfName,
) -> Int raise PdfError {
  if name == pdf_space_calgray_name ||
    name == pdf_space_device_gray_name ||
    name == pdf_space_g_name {
    1
  } else if name == pdf_space_calrgb_name ||
    name == pdf_space_device_rgb_name ||
    name == pdf_space_rgb_name {
    3
  } else if name == pdf_space_calcmyk_name ||
    name == pdf_space_device_cmyk_name ||
    name == pdf_space_cmyk_name {
    4
  } else if name == pdf_space_pattern_name {
    raise ColourSpaceExpected
  } else {
    match self.lookup_direct(pdf_space_colorspace_key(), resources) {
      Some(colour_spaces) =>
        match self.lookup_direct(name, colour_spaces) {
          Some(resolved) => self.colour_space_components(resources, resolved)
          None => raise DictionaryKeyNotFound(name)
        }
      None => raise DictionaryKeyNotFound(pdf_space_colorspace_key())
    }
  }
}

///|
pub fn PdfDocument::colour_space_components(
  self : PdfDocument,
  resources : PdfObject,
  object : PdfObject,
) -> Int raise PdfError {
  match self.direct(object) {
    PdfNameObject(name) => self.pdf_space_named_components(resources, name)
    PdfArray([PdfNameObject(kind), alternate]) if kind == pdf_space_pattern_name =>
      self.colour_space_components(resources, alternate)
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_lab_name ||
      kind == pdf_space_calrgb_name => 3
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_calcmyk_name => 4
    PdfArray([PdfNameObject(kind), _]) if kind == pdf_space_calgray_name => 1
    PdfArray([PdfNameObject(kind), stream_object]) if kind ==
      pdf_space_iccbased_name =>
      match self.lookup_direct(pdf_space_n_key(), stream_object) {
        Some(PdfInteger(components)) => components
        _ => raise ColourSpaceExpected
      }
    PdfArray([PdfNameObject(kind), _, _, _]) if kind ==
      pdf_space_separation_name => 1
    PdfArray([PdfNameObject(kind), _, _, ..]) if kind == pdf_space_indexed_name ||
      kind == pdf_space_i_name => 1
    PdfArray([PdfNameObject(kind), PdfArray(names), _, ..]) if kind ==
      pdf_space_device_n_name => names.length()
    PdfArray([single]) => self.colour_space_components(resources, single)
    _ => raise ColourSpaceExpected
  }
}

///|
pub fn pdf_colour_space_components(
  document : PdfDocument,
  resources : PdfObject,
  object : PdfObject,
) -> Int raise PdfError {
  document.colour_space_components(resources, object)
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
fn PdfDocument::pdf_space_indexed_lookup_data(
  self : PdfDocument,
  lookup_data : PdfObject,
) -> BytesView? raise PdfError {
  match self.direct(lookup_data) {
    PdfString(data) => Some(data)
    PdfStreamObject(stream) =>
      Some(
        pdf_stream_data_view(self.pdf_decode_stream_value_direct(stream).data),
      )
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
pub fn pdf_read_colour_space(
  document : PdfDocument,
  resources : PdfObject,
  object : PdfObject,
) -> PdfColourSpace? raise PdfError {
  document.read_colour_space(resources, object)
}

///|
fn pdf_space_number_array_object(values : ArrayView[Double]) -> PdfObject {
  PdfArray([ for value in values => PdfReal(value) ])
}

///|
fn pdf_space_point_object(point : PdfTristimulusPoint) -> PdfObject {
  PdfArray([PdfReal(point.x), PdfReal(point.y), PdfReal(point.z)])
}

///|
fn pdf_space_indexed_find(
  table : ArrayView[(Int, Array[Int])],
  index : Int,
) -> Array[Int]? {
  for entry in table {
    if entry.0 == index {
      break Some(entry.1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_space_push_byte_component(output : Array[Byte], value : Int) -> Bool {
  if value < 0 || value > 255 {
    false
  } else {
    output.push(value.to_byte())
    true
  }
}

///|
fn pdf_space_indexed_lookup_bytes(
  table : ArrayView[(Int, Array[Int])],
) -> (Int, PdfBytes)? {
  guard table.length() > 0 else { return None }
  let components = table[0].1.length()
  let mut hival = table[0].0
  let mut valid = components > 0
  for entry in table {
    if entry.0 < 0 || entry.1.length() != components {
      valid = false
    } else if entry.0 > hival {
      hival = entry.0
    }
  }
  guard valid else { return None }
  let output : Array[Byte] = []
  for index in 0..<=hival {
    match pdf_space_indexed_find(table, index) {
      Some(values) =>
        for value in values {
          if !pdf_space_push_byte_component(output, value) {
            valid = false
          }
        }
      None => valid = false
    }
  }
  if valid {
    Some((hival, Bytes::from_array(output)))
  } else {
    None
  }
}

///|
fn pdf_space_empty_dictionary(object : PdfObject) -> Bool {
  match object {
    PdfDictionary(entries) => entries.length() == 0
    _ => false
  }
}

///|
pub fn pdf_object_of_colour_space(space : PdfColourSpace) -> PdfObject? {
  match space {
    PdfDeviceGray => Some(PdfNameObject(pdf_space_device_gray_name))
    PdfDeviceRGB => Some(PdfNameObject(pdf_space_device_rgb_name))
    PdfDeviceCMYK => Some(PdfNameObject(pdf_space_device_cmyk_name))
    PdfCalGray(whitepoint, blackpoint, gamma) =>
      Some(
        PdfArray([
          PdfNameObject(pdf_space_calgray_name),
          PdfDictionary([
            (pdf_space_whitepoint_key(), pdf_space_point_object(whitepoint)),
            (pdf_space_blackpoint_key(), pdf_space_point_object(blackpoint)),
            (pdf_space_gamma_key(), PdfReal(gamma)),
          ]),
        ]),
      )
    PdfCalRGB(whitepoint, blackpoint, gamma, matrix) =>
      Some(
        PdfArray([
          PdfNameObject(pdf_space_calrgb_name),
          PdfDictionary([
            (pdf_space_whitepoint_key(), pdf_space_point_object(whitepoint)),
            (pdf_space_blackpoint_key(), pdf_space_point_object(blackpoint)),
            (pdf_space_gamma_key(), pdf_space_number_array_object(gamma)),
            (pdf_space_matrix_key(), pdf_space_number_array_object(matrix)),
          ]),
        ]),
      )
    PdfLab(whitepoint, blackpoint, range) =>
      Some(
        PdfArray([
          PdfNameObject(pdf_space_lab_name),
          PdfDictionary([
            (pdf_space_whitepoint_key(), pdf_space_point_object(whitepoint)),
            (pdf_space_blackpoint_key(), pdf_space_point_object(blackpoint)),
            (pdf_space_range_key(), pdf_space_number_array_object(range)),
          ]),
        ]),
      )
    PdfICCBased(_, _, _, _, stream_object) =>
      Some(PdfArray([PdfNameObject(pdf_space_iccbased_name), stream_object]))
    PdfIndexed(base, table) =>
      match
        (
          pdf_space_indexed_component_count(base),
          pdf_object_of_colour_space(base),
          pdf_space_indexed_lookup_bytes(table),
        ) {
        (Some(_), Some(base_object), Some((hival, lookup))) =>
          Some(
            PdfArray([
              PdfNameObject(pdf_space_indexed_name),
              base_object,
              PdfInteger(hival),
              PdfString(lookup),
            ]),
          )
        _ => None
      }
    PdfPattern => Some(PdfNameObject(pdf_space_pattern_name))
    PdfPatternWithBaseColourSpace(base) =>
      match pdf_object_of_colour_space(base) {
        Some(base_object) =>
          Some(PdfArray([PdfNameObject(pdf_space_pattern_name), base_object]))
        None => None
      }
    PdfSeparation(name, alternate, tint) =>
      match pdf_object_of_colour_space(alternate) {
        Some(alternate_object) =>
          Some(
            PdfArray([
              PdfNameObject(pdf_space_separation_name),
              PdfNameObject(name),
              alternate_object,
              tint,
            ]),
          )
        None => None
      }
    PdfDeviceN(names, alternate, tint, attributes) =>
      match pdf_object_of_colour_space(alternate) {
        Some(alternate_object) => {
          let values : Array[PdfObject] = [
            PdfNameObject(pdf_space_device_n_name),
            PdfArray([ for name in names => PdfNameObject(name) ]),
            alternate_object,
            tint,
          ]
          if !pdf_space_empty_dictionary(attributes) {
            values.push(attributes)
          }
          Some(PdfArray(values))
        }
        None => None
      }
  }
}

///|
pub fn PdfDocument::write_colour_space(
  _self : PdfDocument,
  space : PdfColourSpace,
) -> PdfObject {
  match pdf_object_of_colour_space(space) {
    Some(object) => object
    None => PdfNull
  }
}

///|
pub fn pdf_write_colour_space(
  document : PdfDocument,
  space : PdfColourSpace,
) -> PdfObject {
  document.write_colour_space(space)
}
