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
