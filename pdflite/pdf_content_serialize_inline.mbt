///|
fn pdf_content_inline_image_entry_bytes(
  key : PdfName,
  value : @syntax.PdfObject,
) -> PdfBytes raise PdfError {
  let key_bytes = pdf_write_object(PdfNameObject(key))
  let value_bytes = pdf_write_object(value)
  let output = Array::make(
    1 + key_bytes.length() + 1 + value_bytes.length(),
    b' ',
  )
  let mut position = 1
  position = pdf_content_copy_view(output, position, key_bytes)
  position += 1
  let _ = pdf_content_copy_view(output, position, value_bytes)
  Bytes::from_array(output)
}

///|
fn pdf_content_inline_image_bytes(
  dictionary : @syntax.PdfObject,
  decode_parms : @syntax.PdfObject?,
  data : PdfBytes,
) -> PdfBytes raise PdfError {
  let compress_inline_image = pdf_content_inline_filter_is_empty(dictionary)
  let (render_data, render_decode_parms, render_extra_entries) = if compress_inline_image {
    let encoded = @flate.pdf_flate_encode(data)
    (
      encoded,
      None,
      [
        (
          pdf_content_inline_f_name(),
          @syntax.PdfNameObject(pdf_content_inline_fl_name()),
        ),
        (pdf_content_inline_l_name(), PdfInteger(encoded.length())),
      ],
    )
  } else {
    (data, decode_parms, [])
  }
  match dictionary {
    PdfDictionary(entries) => {
      let decode_parms_entry_count = if render_decode_parms is Some(_) {
        1
      } else {
        0
      }
      let rendered_entries : Array[PdfBytes] = Array::new(
        capacity=entries.length() +
          render_extra_entries.length() +
          decode_parms_entry_count,
      )
      for entry in entries {
        let (key, value) = entry
        if !compress_inline_image ||
          (
            key != pdf_content_inline_filter_name() &&
            key != pdf_content_inline_f_name() &&
            key != pdf_content_inline_decode_parms_name() &&
            key != pdf_content_inline_dp_name() &&
            key != pdf_content_length_name() &&
            key != pdf_content_inline_l_name()
          ) {
          rendered_entries.push(
            pdf_content_inline_image_entry_bytes(key, value),
          )
        }
      }
      for entry in render_extra_entries {
        let (key, value) = entry
        rendered_entries.push(pdf_content_inline_image_entry_bytes(key, value))
      }
      match render_decode_parms {
        Some(value) =>
          rendered_entries.push(
            pdf_content_inline_image_entry_bytes(
              pdf_content_inline_dp_name(),
              value,
            ),
          )
        None => ()
      }
      let data_marker = pdf_content_ascii(" ID ")
      let end_marker = pdf_content_ascii(" EI")
      let mut length = pdf_content_inline_image_begin_operator.length()
      for entry in rendered_entries {
        length += entry.length()
      }
      length += data_marker.length() +
        render_data.length() +
        end_marker.length()
      let output = Array::make(length, b'\x00')
      let mut position = pdf_content_copy_view(
        output, 0, pdf_content_inline_image_begin_operator,
      )
      for entry in rendered_entries {
        position = pdf_content_copy_view(output, position, entry)
      }
      position = pdf_content_copy_view(output, position, data_marker)
      position = pdf_content_copy_view(output, position, render_data)
      let _ = pdf_content_copy_view(output, position, end_marker)
      Bytes::from_array(output)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_content_op_bytes(op : @content.PdfContentOp) -> PdfBytes raise PdfError {
  match op {
    Op_InlineImage(dictionary, decode_parms, data) =>
      pdf_content_inline_image_bytes(dictionary, decode_parms, data)
    Op_Unknown(bytes) => bytes
    _ => {
      let (operands, operator) = pdf_content_op_section(op)
      pdf_content_section_bytes(operands, operator)
    }
  }
}
