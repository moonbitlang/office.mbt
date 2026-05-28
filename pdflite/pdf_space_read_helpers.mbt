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
