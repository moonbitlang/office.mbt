///|
fn pdf_space_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_space_device_gray_name : @core.PdfName = pdf_space_name("/DeviceGray")

///|
let pdf_space_g_name : @core.PdfName = pdf_space_name("/G")

///|
let pdf_space_device_rgb_name : @core.PdfName = pdf_space_name("/DeviceRGB")

///|
let pdf_space_rgb_name : @core.PdfName = pdf_space_name("/RGB")

///|
let pdf_space_device_cmyk_name : @core.PdfName = pdf_space_name("/DeviceCMYK")

///|
let pdf_space_cmyk_name : @core.PdfName = pdf_space_name("/CMYK")

///|
let pdf_space_pattern_name : @core.PdfName = pdf_space_name("/Pattern")

///|
let pdf_space_calgray_name : @core.PdfName = pdf_space_name("/CalGray")

///|
let pdf_space_calrgb_name : @core.PdfName = pdf_space_name("/CalRGB")

///|
let pdf_space_calcmyk_name : @core.PdfName = pdf_space_name("/CalCMYK")

///|
let pdf_space_lab_name : @core.PdfName = pdf_space_name("/Lab")

///|
let pdf_space_iccbased_name : @core.PdfName = pdf_space_name("/ICCBased")

///|
let pdf_space_separation_name : @core.PdfName = pdf_space_name("/Separation")

///|
let pdf_space_indexed_name : @core.PdfName = pdf_space_name("/Indexed")

///|
let pdf_space_i_name : @core.PdfName = pdf_space_name("/I")

///|
let pdf_space_device_n_name : @core.PdfName = pdf_space_name("/DeviceN")

///|
/// A CIE tristimulus point used by calibrated PDF colour spaces.
///
/// The fields represent the `X`, `Y`, and `Z` components used for white point
/// and black point entries in `/CalGray`, `/CalRGB`, and `/Lab` dictionaries.
pub(all) struct PdfTristimulusPoint {
  x : Double
  y : Double
  z : Double
} derive(Debug, Eq, ToJson)

///|
/// Parsed representation of the PDF colour spaces supported by this package.
///
/// Device spaces represent the PDF built-ins. Calibrated and ICC-based spaces
/// preserve their calibration data, indexed spaces hold an expanded lookup
/// table, and separation or DeviceN spaces retain their tint transform objects
/// for round-tripping.
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
  PdfICCBased(
    Int,
    PdfColourSpace,
    Array[Double],
    @syntax.PdfObject?,
    @syntax.PdfObject
  )
  PdfIndexed(PdfColourSpace, Array[(Int, Array[Int])])
  PdfPattern
  PdfPatternWithBaseColourSpace(PdfColourSpace)
  PdfSeparation(@core.PdfName, PdfColourSpace, @syntax.PdfObject)
  PdfDeviceN(
    Array[@core.PdfName],
    PdfColourSpace,
    @syntax.PdfObject,
    @syntax.PdfObject
  )
} derive(Debug, Eq, ToJson)

///|
/// Return a diagnostic name for a colour space.
///
/// Built-in spaces use their PDF names. Composite spaces include the diagnostic
/// name of their alternate or base space, making the result useful for logs,
/// snapshots, and error messages rather than for serialization.
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
/// Return the PDF colourant name carried by a separation space.
///
/// Only `PdfSeparation` has a single associated colourant name in this API.
/// Other colour spaces, including `PdfDeviceN`, return `None`.
pub fn PdfColourSpace::name(self : PdfColourSpace) -> @core.PdfName? {
  match self {
    PdfSeparation(name, _, _) => Some(name)
    _ => None
  }
}

///|
/// Compatibility wrapper for `PdfColourSpace::debug_name`.
pub fn pdf_string_of_colour_space(space : PdfColourSpace) -> String {
  space.debug_name()
}

///|
/// Compatibility wrapper for `PdfColourSpace::name`.
pub fn pdf_name_of_colour_space(space : PdfColourSpace) -> @core.PdfName? {
  space.name()
}

///|
/// Parse a built-in PDF device colour-space name.
///
/// Accepts the standard names `/DeviceGray`, `/DeviceRGB`, `/DeviceCMYK`, and
/// `/Pattern`, together with the abbreviated resource names `/G`, `/RGB`, and
/// `/CMYK`.
pub fn pdf_colour_space_of_device_name(name : @core.PdfName) -> PdfColourSpace? {
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
/// Parse a simple colour-space object without consulting resources.
///
/// This recognizes device colour-space names, singleton arrays, and
/// pattern-with-base arrays. Use `PdfDocument::read_colour_space` when resource
/// lookup, calibrated spaces, ICC profiles, or indexed spaces are needed.
pub fn pdf_colour_space_of_object(
  object : @syntax.PdfObject,
) -> PdfColourSpace? {
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
