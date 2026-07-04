///|
fn PdfDocument::pdf_image_lookup_int_or_else(
  self : PdfDocument,
  first_key : @core.PdfName,
  second_key : @core.PdfName,
  image : @syntax.PdfObject,
) -> Int raise @core.PdfError {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(PdfInteger(value)) => value
    Some(_) => raise NumberExpected
    None => raise DictionaryKeyNotFound(first_key)
  }
}

///|
fn PdfDocument::pdf_image_bits_per_component_int(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Int? raise @core.PdfError {
  match self.image_bits_per_component(image) {
    Some(PdfInteger(value)) => Some(value)
    Some(_) => raise NumberExpected
    None => None
  }
}

///|
fn PdfDocument::pdf_image_decode_values(
  self : PdfDocument,
  image : @syntax.PdfObject,
) -> Array[Double]? raise @core.PdfError {
  match
    self.lookup_direct_or_else(pdf_image_decode_key(), pdf_image_d_key(), image) {
    Some(PdfArray(values)) => {
      let output : Array[Double] = Array::new(capacity=values.length())
      for value in values {
        output.push(self.get_number(value))
      }
      Some(output)
    }
    Some(_) => raise NumberExpected
    None => None
  }
}

///|
fn pdf_image_decode_identity_components(components : Int) -> Array[Double] {
  let values : Array[Double] = Array::new(capacity=components * 2)
  for _ in 0..<components {
    values.push(0.0)
    values.push(1.0)
  }
  values
}

///|
fn pdf_image_decode_lab_defaults(range : ArrayView[Double]) -> Array[Double] {
  let values : Array[Double] = [0.0, 1.0]
  for value in range {
    values.push(value)
  }
  values
}

///|
fn pdf_image_decode_defaults_for_space(
  colour_space : PdfColourSpace,
) -> Array[Double]? {
  match colour_space {
    PdfDeviceGray | PdfCalGray(_, _, _) | PdfSeparation(_, _, _) =>
      Some(pdf_image_decode_identity_components(1))
    PdfDeviceRGB | PdfCalRGB(_, _, _, _) =>
      Some(pdf_image_decode_identity_components(3))
    PdfDeviceCMYK => Some(pdf_image_decode_identity_components(4))
    PdfLab(_, _, range) => Some(pdf_image_decode_lab_defaults(range))
    PdfICCBased(_, _, range, _, _) => Some([ for value in range => value ])
    PdfIndexed(_, _) => Some(pdf_image_decode_identity_components(1))
    PdfDeviceN(names, _, _, _) =>
      Some(pdf_image_decode_identity_components(names.length()))
    PdfPattern | PdfPatternWithBaseColourSpace(_) => None
  }
}

///|
fn PdfDocument::pdf_image_decode_values_with_defaults(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  image : @syntax.PdfObject,
) -> Array[Double]? raise @core.PdfError {
  match self.pdf_image_decode_values(image) {
    Some(values) =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => Some(values)
        Some(_) =>
          match self.image_colour_space(image, resources) {
            PdfIndexed(_, _) => None
            _ => Some(values)
          }
      }
    None =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => None
        Some(_) =>
          pdf_image_decode_defaults_for_space(
            self.image_colour_space(image, resources),
          )
      }
  }
}

///|
fn PdfDocument::pdf_image_encoded_decode_values_with_defaults(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  image : @syntax.PdfObject,
) -> Array[Double]? raise @core.PdfError {
  match self.pdf_image_decode_values(image) {
    Some(values) => Some(values)
    None =>
      match
        self.lookup_direct_or_else(
          pdf_image_colorspace_key(),
          pdf_image_cs_key(),
          image,
        ) {
        None => None
        Some(_) =>
          pdf_image_decode_defaults_for_space(
            self.image_colour_space(image, resources),
          )
      }
  }
}
