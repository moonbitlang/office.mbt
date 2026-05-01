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
