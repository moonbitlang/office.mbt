///|
/// Build cpdf add-rectangle content operators after placement is resolved.
pub fn pdf_addtext_rectangle_ops(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  colour : @colour.PdfContentColour,
  outline : Bool,
  line_width : Double,
  extgstate_name : PdfName?,
) -> Array[PdfContentOp] {
  let ops = [
    pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_addtext_cpdf_stamp()),
    pdf_addtext_colour_op(colour),
    pdf_addtext_colour_op_stroke(colour),
  ]
  if outline {
    ops.push(Op_w(line_width))
  }
  match extgstate_name {
    Some(name) => ops.push(Op_gs(name))
    None => ()
  }
  ops.push(Op_re(x, y, width, height))
  ops.push(if outline { Op_s } else { Op_f })
  ops.push(Op_EMC)
  ops.push(Op_Q)
  ops.push(pdf_content_end_artifact())
  ops
}

///|
fn pdf_addtext_fontpack_text_ops(
  fontpack : PdfFontPack,
  unique_fontnames : ArrayView[PdfName],
  font_size : Double,
  text : String,
) -> Array[PdfContentOp] raise PdfError {
  let codepoints = pdf_codepoints_of_utf8(@utf8.encode(text))
  let triples : Array[(Int, Int, PdfFont)] = Array::new(
    capacity=codepoints.length(),
  )
  for codepoint in codepoints {
    match fontpack.get_char(codepoint) {
      Some(triple) => triples.push(triple)
      None => ()
    }
  }
  let ops : Array[PdfContentOp] = Array::new(capacity=triples.length() * 2)
  for run in pdf_fontpack_collate_runs(triples) {
    guard run.length() > 0 else { continue }
    let font_index = run[0].1
    if font_index < 0 || font_index >= unique_fontnames.length() {
      raise SoftError("bad add-text fontpack font name list")
    }
    let bytes = Array::make(run.length(), b'\x00')
    for index, triple in run {
      bytes[index] = pdf_byte_of_int(triple.0)
    }
    ops.push(Op_Tf(unique_fontnames[font_index], font_size))
    ops.push(Op_Tj(Bytes::from_array(bytes)))
  }
  ops
}

///|
fn pdf_addtext_font_text_ops_with_bytes(
  fontpack : PdfFontPack?,
  unique_fontname : PdfName,
  unique_fontnames : ArrayView[PdfName],
  font_size : Double,
  text : String,
  text_bytes : PdfBytes,
) -> Array[PdfContentOp] raise PdfError {
  match fontpack {
    Some(fontpack) =>
      pdf_addtext_fontpack_text_ops(fontpack, unique_fontnames, font_size, text)
    None => [Op_Tf(unique_fontname, font_size), Op_Tj(text_bytes)]
  }
}

///|
fn pdf_addtext_text_matrix(
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> TransformMatrix {
  transform_matrix_of_transform([
    Translate(
      x - horizontal_offset + rotation_h_offset,
      y - vertical_offset + rotation_v_offset,
    ),
    Rotate(point2(0.0, 0.0), base_rotation + text_rotation),
  ])
}

///|
fn pdf_addtext_text_ops_with_bytes(
  fontpack : PdfFontPack?,
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  outline : Bool,
  line_width : Double,
  unique_fontname : PdfName,
  unique_fontnames : ArrayView[PdfName],
  extgstate_name : PdfName?,
  colour : @colour.PdfContentColour,
  font_size : Double,
  text : String,
  text_bytes : PdfBytes,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> Array[PdfContentOp] raise PdfError {
  let textops = pdf_addtext_font_text_ops_with_bytes(
    fontpack, unique_fontname, unique_fontnames, font_size, text, text_bytes,
  )
  let ops = [
    pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_addtext_cpdf_stamp()),
    Op_cm(
      pdf_addtext_text_matrix(
        x, y, base_rotation, horizontal_offset, vertical_offset, text_rotation, rotation_h_offset,
        rotation_v_offset,
      ),
    ),
    Op_BT,
  ]
  if outline {
    ops.push(Op_w(line_width))
    ops.push(Op_Tr(1))
  } else {
    ops.push(Op_Tr(0))
  }
  ops.push(pdf_addtext_colour_op(colour))
  ops.push(pdf_addtext_colour_op_stroke(colour))
  match extgstate_name {
    Some(name) => ops.push(Op_gs(name))
    None => ()
  }
  for op in textops {
    ops.push(op)
  }
  ops.push(Op_ET)
  ops.push(Op_EMC)
  ops.push(Op_Q)
  ops.push(pdf_content_end_artifact())
  ops
}

///|
/// Build cpdf add-text text-stamp content operators after placement is resolved.
///
/// This ports the source-level `cpdfaddtext.ml` `ops` helper, including
/// `/CPDFSTAMP` artifact wrapping, placement matrix, outline rendering mode,
/// colour operators, optional opacity graphics state, simple-font charcode
/// conversion, and fontpack run switching.
pub fn pdf_addtext_text_ops(
  font : PdfFont?,
  fontpack : PdfFontPack?,
  x : Double,
  y : Double,
  base_rotation : Double,
  horizontal_offset : Double,
  vertical_offset : Double,
  outline : Bool,
  line_width : Double,
  unique_fontname : PdfName,
  unique_fontnames : ArrayView[PdfName],
  extgstate_name : PdfName?,
  colour : @colour.PdfContentColour,
  font_size : Double,
  text : String,
  text_rotation : Double,
  rotation_h_offset : Double,
  rotation_v_offset : Double,
) -> Array[PdfContentOp] raise PdfError {
  let text_bytes = match font {
    Some(font) => pdf_addtext_charcodes_of_utf8(font, text)
    None => @utf8.encode(text)
  }
  pdf_addtext_text_ops_with_bytes(
    fontpack, x, y, base_rotation, horizontal_offset, vertical_offset, outline, line_width,
    unique_fontname, unique_fontnames, extgstate_name, colour, font_size, text, text_bytes,
    text_rotation, rotation_h_offset, rotation_v_offset,
  )
}
