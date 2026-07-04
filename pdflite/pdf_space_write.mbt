///|
fn pdf_space_number_array_object(
  values : ArrayView[Double],
) -> @syntax.PdfObject {
  PdfArray([ for value in values => PdfReal(value) ])
}

///|
fn pdf_space_point_object(point : PdfTristimulusPoint) -> @syntax.PdfObject {
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
fn pdf_space_indexed_lookup_bytes(
  table : ArrayView[(Int, Array[Int])],
) -> (Int, @core.PdfBytes)? {
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
  let output = Array::make((hival + 1) * components, b'\x00')
  let mut position = 0
  for index in 0..<=hival {
    match pdf_space_indexed_find(table, index) {
      Some(values) =>
        for value in values {
          if value < 0 || value > 255 {
            return None
          }
          output[position] = value.to_byte()
          position += 1
        }
      None => return None
    }
  }
  Some((hival, Bytes::from_array(output)))
}

///|
fn pdf_space_empty_dictionary(object : @syntax.PdfObject) -> Bool {
  match object {
    PdfDictionary(entries) => entries.length() == 0
    _ => false
  }
}

///|
/// Convert a parsed colour space back into a PDF object.
///
/// Returns `None` when the colour space cannot be serialized losslessly, such
/// as an indexed table with invalid component values or a base colour space that
/// itself cannot be represented.
pub fn pdf_object_of_colour_space(space : PdfColourSpace) -> @syntax.PdfObject? {
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
          let values : Array[@syntax.PdfObject] = [
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
/// Serialize a colour space for writing into a PDF object graph.
///
/// This delegates to `pdf_object_of_colour_space` and returns `PdfNull` when
/// the parsed colour space is not representable as a valid PDF object.
pub fn PdfDocument::write_colour_space(
  _self : PdfDocument,
  space : PdfColourSpace,
) -> @syntax.PdfObject {
  match pdf_object_of_colour_space(space) {
    Some(object) => object
    None => PdfNull
  }
}

///|
/// Compatibility wrapper for `PdfDocument::write_colour_space`.
pub fn pdf_write_colour_space(
  document : PdfDocument,
  space : PdfColourSpace,
) -> @syntax.PdfObject {
  document.write_colour_space(space)
}
